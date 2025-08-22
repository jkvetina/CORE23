CREATE OR REPLACE PACKAGE BODY core_gen AS

    g_app_prefix        VARCHAR2(16)   := '';
    g_in_prefix         VARCHAR2(16)   := 'in_';
    g_rec_prefix        VARCHAR2(16)   := 'rec.';
    g_minimal_space     PLS_INTEGER    := 5;
    g_tab_width         PLS_INTEGER    := 4;
    --
    g_width_in          PLS_INTEGER;
    g_width_type        PLS_INTEGER;



    CURSOR c_primary_key_columns (in_table_name VARCHAR2) IS
        SELECT
            LOWER(c.table_name)     AS table_name,
            LOWER(c.column_name)    AS column_name,
            c.position              AS column_id,
            COUNT(*) OVER()         AS columns#
        FROM user_cons_columns c
        JOIN user_constraints n
            ON n.constraint_name    = c.constraint_name
        WHERE n.table_name          = UPPER(in_table_name)
            AND n.constraint_type   = 'P'
        ORDER BY c.position;





    PROCEDURE create_tapi (
        in_table_name           VARCHAR2,
        in_procedure_name       VARCHAR2
    )
    AS
        c_procedure_name        CONSTANT user_procedures.procedure_name%TYPE    := LOWER(NVL(in_procedure_name, in_table_name));
        c_table_name            CONSTANT user_tables.table_name%TYPE            := LOWER(in_table_name);
    BEGIN
        g_width_in := get_width (
            in_table_name       => c_table_name,
            in_prefix           => ''
        );
        g_width_type := get_width (
            in_table_name       => c_table_name,
            in_prefix           => c_table_name || '.%TYPE'
        );

        -- create procedure definition
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('    PROCEDURE ' || c_procedure_name || ' (');
        --
        FOR c IN (
            SELECT
                c.column_name,
                c.data_type,
                CASE WHEN LEAD(c.column_name) OVER(PARTITION BY c.table_name ORDER BY c.column_id) IS NOT NULL THEN ',' END AS comma
            FROM user_tab_columns c
            WHERE c.table_name      = UPPER(c_table_name)
                AND c.column_name   NOT IN (
                    'UPDATED_BY', 'UPDATED_AT', 'UPDATED_ON',
                    'CREATED_BY', 'CREATED_AT', 'CREATED_ON'
                )
            ORDER BY
                c.column_id
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('        '
                || RPAD('in_' || LOWER(c.column_name), g_width_in)
                || RPAD(c_table_name || '.' || LOWER(c.column_name) || '%TYPE', g_width_type) || ':= NULL' || c.comma
            );
        END LOOP;
        --
        DBMS_OUTPUT.PUT_LINE('    )');
        DBMS_OUTPUT.PUT_LINE('    AS');
        DBMS_OUTPUT.PUT_LINE('        rec ' || c_table_name || '%ROWTYPE;');
        DBMS_OUTPUT.PUT_LINE('    BEGIN');
        --
        FOR c IN (
            SELECT
                c.column_name,
                c.data_type
            FROM user_tab_columns c
            WHERE c.table_name      = UPPER(c_table_name)
                AND c.column_name   NOT IN (
                    'UPDATED_BY', 'UPDATED_AT', 'UPDATED_ON',
                    'CREATED_BY', 'CREATED_AT', 'CREATED_ON'
                )
            ORDER BY c.column_id
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('        '
                || RPAD('rec.' || LOWER(c.column_name), g_width_in)
                || ':= COALESCE('
                || RPAD('in_' || LOWER(c.column_name) || ',', g_width_in)
                || CASE WHEN c.data_type = 'DATE' THEN 'core.get_date(' END
                || 'core.get_grid_data(''' || UPPER(c.column_name) || ''')'
                || CASE WHEN c.data_type = 'DATE' THEN ')' END
                || ');'
            );
        END LOOP;
        --
        DBMS_OUTPUT.PUT_LINE('        --');
        DBMS_OUTPUT.PUT_LINE('        core.log_start(');
        DBMS_OUTPUT.PUT_LINE('        );');
        DBMS_OUTPUT.PUT_LINE('');

        -- append delete block
        DBMS_OUTPUT.PUT_LINE('        -- delete requested?');
        DBMS_OUTPUT.PUT_LINE('        IF core.get_grid_action() = ''D'' THEN');
        DBMS_OUTPUT.PUT_LINE('            DELETE FROM ' || c_table_name);
        --
        table_where (
            in_table_name   => c_table_name,
            in_prepend      => '            ',
            in_offset       => -8
        );
        --
        DBMS_OUTPUT.PUT_LINE('            --');
        DBMS_OUTPUT.PUT_LINE('            RETURN;');
        DBMS_OUTPUT.PUT_LINE('        END IF;');
        DBMS_OUTPUT.PUT_LINE('');

        -- detect sequence
        /*
        FOR c IN (
            SELECT
                LOWER(s.sequence_name)  AS seq_name,
                LOWER(c.column_name)    AS col_name
            FROM user_sequences s
            JOIN user_tab_cols c
                ON c.column_name    = REGEXP_REPLACE(s.sequence_name, '^(' || g_app_prefix || '_)', '')
                AND c.table_name    = UPPER(c_table_name)
            WHERE s.sequence_name   LIKE g_app_prefix || '\_%' ESCAPE '\'
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('        -- generate primary key if needed');
            DBMS_OUTPUT.PUT_LINE('        IF c_action = ''C'' AND rec.' || c.col_name || ' IS NULL THEN');
            DBMS_OUTPUT.PUT_LINE('            rec.' || c.col_name || ' := ' || c.seq_name || '.NEXTVAL;');
            DBMS_OUTPUT.PUT_LINE('        END IF;');
            DBMS_OUTPUT.PUT_LINE('');
        END LOOP;
        */

        -- add audit columns
        DBMS_OUTPUT.PUT_LINE('        -- audit columns');
        IF column_exists(c_table_name, 'CREATED_BY') THEN DBMS_OUTPUT.PUT_LINE('        ' || RPAD('rec.created_by', g_width_in) || ':= NVL(rec.created_by, core.get_user_id());'); END IF;
        IF column_exists(c_table_name, 'CREATED_AT') THEN DBMS_OUTPUT.PUT_LINE('        ' || RPAD('rec.created_at', g_width_in) || ':= NVL(rec.created_at, SYSDATE);'); END IF;
        IF column_exists(c_table_name, 'CREATED_ON') THEN DBMS_OUTPUT.PUT_LINE('        ' || RPAD('rec.created_on', g_width_in) || ':= NVL(rec.created_on, SYSDATE);'); END IF;
        IF column_exists(c_table_name, 'UPDATED_BY') THEN DBMS_OUTPUT.PUT_LINE('        ' || RPAD('rec.updated_by', g_width_in) || ':= core.get_user_id();'); END IF;
        IF column_exists(c_table_name, 'UPDATED_AT') THEN DBMS_OUTPUT.PUT_LINE('        ' || RPAD('rec.updated_at', g_width_in) || ':= SYSDATE;'); END IF;
        IF column_exists(c_table_name, 'UPDATED_ON') THEN DBMS_OUTPUT.PUT_LINE('        ' || RPAD('rec.updated_on', g_width_in) || ':= SYSDATE;'); END IF;
        DBMS_OUTPUT.PUT_LINE('');

        -- update record
        DBMS_OUTPUT.PUT_LINE('        -- upsert record');
        DBMS_OUTPUT.PUT_LINE('        UPDATE ' || c_table_name || ' t');
        DBMS_OUTPUT.PUT_LINE('        SET ROW = rec');
        --
        table_where (
            in_table_name   => c_table_name,
            in_prepend      => '        ',
            in_offset       => -8
        );

        -- insert record if update failed, return id
        DBMS_OUTPUT.PUT_LINE('        --');
        DBMS_OUTPUT.PUT_LINE('        IF SQL%ROWCOUNT = 0 THEN');
        DBMS_OUTPUT.PUT_LINE('            INSERT INTO ' || c_table_name || ' t');
        DBMS_OUTPUT.PUT_LINE('            VALUES rec');
        --
        FOR c IN (
            SELECT
                LISTAGG('t.' || LOWER(c.column_name), ', ') WITHIN GROUP (ORDER BY c.position) AS cols_
            FROM user_cons_columns c
            JOIN user_constraints n
                ON n.constraint_name    = c.constraint_name
            WHERE n.table_name          = UPPER(in_table_name)
                AND n.constraint_type   = 'P'
            ORDER BY
                c.position
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('            RETURN ' || c.cols_ ||
                CASE WHEN INSTR(c.cols_, ',') > 0 THEN CHR(10) || '            ' ELSE ' ' END || 'INTO ' ||
                REPLACE(c.cols_, 't.', 'rec.') || ';');
        END LOOP;
        --
        DBMS_OUTPUT.PUT_LINE('        END IF;');
        DBMS_OUTPUT.PUT_LINE('');

        -- send new primary key back
        DBMS_OUTPUT.PUT_LINE('        -- update primary key back to APEX grid for proper row refresh');
        --
        FOR c IN c_primary_key_columns(c_table_name) LOOP
            DBMS_OUTPUT.PUT_LINE('        core.set_grid_data(''' || UPPER(c.column_name) || ''', rec.' || c.column_name || ');');
        END LOOP;
        --
        DBMS_OUTPUT.PUT_LINE('        --');
        DBMS_OUTPUT.PUT_LINE('    EXCEPTION');
        DBMS_OUTPUT.PUT_LINE('    WHEN core.app_exception THEN');
        DBMS_OUTPUT.PUT_LINE('        RAISE;');
        DBMS_OUTPUT.PUT_LINE('    WHEN OTHERS THEN');
        DBMS_OUTPUT.PUT_LINE('        core.raise_error();');
        DBMS_OUTPUT.PUT_LINE('    END;');
        DBMS_OUTPUT.PUT_LINE('');
    END;



    FUNCTION get_width (
        in_table_name           VARCHAR2,
        in_prefix               VARCHAR2    := NULL
    )
    RETURN PLS_INTEGER
    ACCESSIBLE BY (core_gen)
    AS
        v_max_size              PLS_INTEGER;
    BEGIN
        -- check tables/views
        SELECT MAX(LENGTH(c.column_name)) INTO v_max_size
        FROM user_tab_columns c
        WHERE c.table_name      = UPPER(in_table_name);
        --
        RETURN CEIL((NVL(LENGTH(in_prefix), 0) + g_minimal_space + v_max_size) / g_tab_width) * g_tab_width;
    END;



    FUNCTION column_exists (
        in_table_name           VARCHAR2,
        in_column_name          VARCHAR2
    )
    RETURN BOOLEAN
    ACCESSIBLE BY (core_gen)
    AS
    BEGIN
        FOR c IN (
            SELECT 'Y' AS is_valid
            FROM user_tab_columns c
            WHERE c.table_name      = UPPER(in_table_name)
                AND c.column_name   = UPPER(in_column_name)
        ) LOOP
            RETURN TRUE;
        END LOOP;
        --
        RETURN FALSE;
    END;



    PROCEDURE table_where (
        in_table_name           VARCHAR2,
        in_prepend              VARCHAR2,
        in_offset               PLS_INTEGER := 0
    )
    ACCESSIBLE BY (core_gen)
    AS
    BEGIN
        FOR c IN c_primary_key_columns(in_table_name) LOOP
            DBMS_OUTPUT.PUT_LINE(
                in_prepend || CASE WHEN c.column_id = 1 THEN 'WHERE ' ELSE '    AND ' END ||
                RPAD('t.' || c.column_name, g_width_in + in_offset) || CASE WHEN c.column_id = 1 THEN '  ' END || '= rec.' || c.column_name ||
                CASE WHEN c.column_id = c.columns# THEN ';' END
            );
        END LOOP;
    END;

END;
/

