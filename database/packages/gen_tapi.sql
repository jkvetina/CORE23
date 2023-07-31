CREATE OR REPLACE PACKAGE BODY gen_tapi AS

    --
    -- @TODO: it would be uch cooler to actually use APEX_STRING.FORMAT and generate CLOB instead of DBMS_OUTPUT
    --

    g_width_in      PLS_INTEGER;
    g_width_type    PLS_INTEGER;

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





    FUNCTION get_width (
        in_table_name           VARCHAR2,
        in_prefix               VARCHAR2    := NULL
    )
    RETURN PLS_INTEGER
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
        in_prepend              VARCHAR2
    )
    AS
    BEGIN
        FOR c IN c_primary_key_columns(in_table_name) LOOP
            DBMS_OUTPUT.PUT_LINE(
                in_prepend || CASE WHEN c.column_id = 1 THEN 'WHERE ' ELSE '    AND ' END ||
                RPAD('t.' || c.column_name, g_width_in) || CASE WHEN c.column_id = 1 THEN '  ' END || '= rec.' || c.column_name ||
                CASE WHEN c.column_id = c.columns# THEN ';' END
            );
        END LOOP;
    END;



    FUNCTION table_where (
        in_table_name           VARCHAR2,
        in_where_prefix         VARCHAR2
    )
    RETURN VARCHAR2
    AS
        out_where               VARCHAR2(4000);
    BEGIN
        FOR c IN c_primary_key_columns(in_table_name) LOOP
            out_where := out_where ||
                CASE WHEN c.column_id = 1 THEN 'WHERE ' ELSE ' AND ' END ||
                    c.column_name || ' = ' || in_where_prefix || c.column_name;
        END LOOP;
        --
        RETURN out_where || ';';
    END;



    PROCEDURE create_tapi (
        in_table_name           VARCHAR2,
        in_procedure_name       VARCHAR2,
        in_tapi_package         VARCHAR2,
        in_auth_package         VARCHAR2,
        in_app_prefix           VARCHAR2
    )
    AS
        c_procedure_name        CONSTANT user_procedures.procedure_name%TYPE    := LOWER(NVL(in_procedure_name, in_table_name));
        c_table_name            CONSTANT user_tables.table_name%TYPE            := LOWER(in_table_name);
    BEGIN
        g_width_in := get_width (
            in_table_name       => c_table_name,
            in_prefix           => g_in_prefix
        );
        g_width_type := get_width (
            in_table_name       => c_table_name,
            in_prefix           => c_table_name || '.%TYPE'
        );

        --
        -- create procedure for upsert records with arguments
        --
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('    PROCEDURE ' || c_procedure_name || ' (');
        DBMS_OUTPUT.PUT_LINE('        ' || RPAD('rec', g_width_in) || 'IN OUT NOCOPY   ' || c_table_name || '%ROWTYPE,');
        DBMS_OUTPUT.PUT_LINE('        --');
        DBMS_OUTPUT.PUT_LINE('        ' || RPAD('in_action', g_width_in) || RPAD('CHAR', g_width_type) || ':= NULL,');

        -- list all primary key columns
        FOR c IN c_primary_key_columns (in_table_name) LOOP
            DBMS_OUTPUT.PUT_LINE('        '
                || RPAD(g_in_prefix || c.column_name, g_width_in)
                || RPAD(c.table_name || '.' || c.column_name || '%TYPE', g_width_type)
                || ':= NULL'
                || CASE WHEN c.column_id < c.columns# THEN ',' END
            );
        END LOOP;
        --
        DBMS_OUTPUT.PUT_LINE('    )');
        DBMS_OUTPUT.PUT_LINE('    AS');
        DBMS_OUTPUT.PUT_LINE('        ' || RPAD('c_action', g_width_in) || RPAD('CONSTANT CHAR', g_width_type) || ':= gen_tapi.get_action(in_action);');
        DBMS_OUTPUT.PUT_LINE('    BEGIN');
        --DBMS_OUTPUT.PUT_LINE('        --log_module();');
        --DBMS_OUTPUT.PUT_LINE('');

        -- auth evaluation
        DBMS_OUTPUT.PUT_LINE('        -- evaluate access to this table');
        DBMS_OUTPUT.PUT_LINE('        ' || in_auth_package || '.check_allowed_dml (');
        DBMS_OUTPUT.PUT_LINE('            in_table_name       => gen_tapi.get_table_name(),');
        DBMS_OUTPUT.PUT_LINE('            in_action           => c_action,');
        DBMS_OUTPUT.PUT_LINE('            in_user_id          => core.get_user_id(),');
        DBMS_OUTPUT.PUT_LINE('            in_client_id        => ' || CASE WHEN column_exists(c_table_name, 'PROJECT_ID') THEN 'rec.project_id' ELSE 'NULL' END || ',');
        DBMS_OUTPUT.PUT_LINE('            in_project_id       => ' || CASE WHEN column_exists(c_table_name, 'CLIENT_ID')  THEN 'rec.client_id'  ELSE 'NULL' END);
        DBMS_OUTPUT.PUT_LINE('        );');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('        -- delete record');
        DBMS_OUTPUT.PUT_LINE('        IF c_action = ''D'' THEN');
        DBMS_OUTPUT.PUT_LINE('            gen_tapi.' || c_procedure_name || '_d (');
        --
        FOR c IN c_primary_key_columns(in_table_name) LOOP
            DBMS_OUTPUT.PUT_LINE('                '
                || RPAD('in_' || c.column_name, g_width_in) || '=> NVL(in_' || c.column_name || ', rec.' || c.column_name || ')'
                || CASE WHEN c.column_id < c.columns# THEN ',' END
            );
        END LOOP;
        --
        DBMS_OUTPUT.PUT_LINE('            );');
        DBMS_OUTPUT.PUT_LINE('            --');
        DBMS_OUTPUT.PUT_LINE('            RETURN;  -- exit procedure');
        DBMS_OUTPUT.PUT_LINE('        END IF;');
        DBMS_OUTPUT.PUT_LINE('');

        -- are we renaming the primary key?
        FOR c IN c_primary_key_columns(in_table_name) LOOP
            DBMS_OUTPUT.PUT_LINE('        -- are we renaming the primary key?');
            DBMS_OUTPUT.PUT_LINE('        IF c_action = ''U'' AND in_' || c.column_name || ' != rec.' || c.column_name || ' THEN');
            DBMS_OUTPUT.PUT_LINE('            gen_tapi.rename_primary_key (');
            DBMS_OUTPUT.PUT_LINE('                in_column_name  => ''' || UPPER(c.column_name) || ''',');
            DBMS_OUTPUT.PUT_LINE('                in_old_key      => in_' || c.column_name || ',');
            DBMS_OUTPUT.PUT_LINE('                in_new_key      => rec.' || c.column_name);
            DBMS_OUTPUT.PUT_LINE('            );');
            DBMS_OUTPUT.PUT_LINE('        END IF;');
            DBMS_OUTPUT.PUT_LINE('');
        END LOOP;

        -- detect sequence
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

        -- overwrite some values
        DBMS_OUTPUT.PUT_LINE('        -- overwrite some values');
        IF column_exists(c_table_name, 'CREATED_BY') THEN DBMS_OUTPUT.PUT_LINE('        ' || RPAD('rec.created_by', g_width_in) || ':= NVL(rec.created_by, core.get_user_id());'); END IF;
        IF column_exists(c_table_name, 'CREATED_AT') THEN DBMS_OUTPUT.PUT_LINE('        ' || RPAD('rec.created_at', g_width_in) || ':= NVL(rec.created_at, SYSDATE);'); END IF;
        IF column_exists(c_table_name, 'UPDATED_BY') THEN DBMS_OUTPUT.PUT_LINE('        ' || RPAD('rec.updated_by', g_width_in) || ':= core.get_user_id();'); END IF;
        IF column_exists(c_table_name, 'UPDATED_AT') THEN DBMS_OUTPUT.PUT_LINE('        ' || RPAD('rec.updated_at', g_width_in) || ':= SYSDATE;'); END IF;
        DBMS_OUTPUT.PUT_LINE('');

        -- upsert record
        DBMS_OUTPUT.PUT_LINE('        -- upsert record');
        DBMS_OUTPUT.PUT_LINE('        UPDATE ' || c_table_name || ' t');
        DBMS_OUTPUT.PUT_LINE('        SET ROW = rec');
        --
        table_where (
            in_table_name   => c_table_name,
            in_prepend      => '        '
        );
        --
        DBMS_OUTPUT.PUT_LINE('        --');
        DBMS_OUTPUT.PUT_LINE('        IF SQL%ROWCOUNT = 0 THEN');
        DBMS_OUTPUT.PUT_LINE('            INSERT INTO ' || c_table_name);
        DBMS_OUTPUT.PUT_LINE('            VALUES rec;');
        DBMS_OUTPUT.PUT_LINE('        END IF;');
        DBMS_OUTPUT.PUT_LINE('    EXCEPTION');
        DBMS_OUTPUT.PUT_LINE('    WHEN core.app_exception THEN');
        DBMS_OUTPUT.PUT_LINE('        RAISE;');
        DBMS_OUTPUT.PUT_LINE('    WHEN OTHERS THEN');
        DBMS_OUTPUT.PUT_LINE('        core.raise_error();');
        DBMS_OUTPUT.PUT_LINE('    END;');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('');

        --
        -- create dedicated procedure to delete (cascade) records
        --
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('    PROCEDURE ' || c_procedure_name || '_d (');

        -- list all primary key columns
        FOR c IN c_primary_key_columns (in_table_name) LOOP
            DBMS_OUTPUT.PUT_LINE('        '
                || RPAD(g_in_prefix || c.column_name, g_width_in)
                || c.table_name || '.' || c.column_name || '%TYPE'
                || CASE WHEN c.column_id < c.columns# THEN ',' END
            );
        END LOOP;
        --
        DBMS_OUTPUT.PUT_LINE('    )');
        DBMS_OUTPUT.PUT_LINE('    AS');
        DBMS_OUTPUT.PUT_LINE('        --PRAGMA AUTONOMOUS_TRANSACTION;');
        DBMS_OUTPUT.PUT_LINE('    BEGIN');
        DBMS_OUTPUT.PUT_LINE('        -- need to be sorted properly');
        --
        FOR c IN (
            SELECT c.table_name
            FROM all_tab_cols c
            JOIN all_tables t
                ON t.owner          = c.owner
                AND t.table_name    = c.table_name
            WHERE c.owner           = core.get_owner()
                AND c.table_name    LIKE in_app_prefix || '\_%' ESCAPE '\'
                AND c.column_name   IN (
                    SELECT c.column_name
                    FROM user_tab_columns c
                    JOIN user_cons_columns n
                        ON n.table_name         = c.table_name
                        AND n.column_name       = c.column_name
                    JOIN user_constraints s
                        ON s.table_name         = n.table_name
                        AND s.constraint_name   = n.constraint_name
                        AND s.constraint_type   = 'P'
                    WHERE c.table_name          = UPPER(in_table_name)
                )
            GROUP BY c.table_name
            HAVING COUNT(c.column_name) = (
                SELECT COUNT(*)
                FROM user_cons_columns n
                JOIN user_constraints s
                    ON s.table_name         = n.table_name
                    AND s.constraint_name   = n.constraint_name
                    AND s.constraint_type   = 'P'
                WHERE n.table_name          = UPPER(in_table_name)
            )
            ORDER BY 1
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('        DELETE FROM ' || RPAD(LOWER(c.table_name), 30) || '  ' || table_where(c_table_name, 'in_'));
        END LOOP;
        --
        DBMS_OUTPUT.PUT_LINE('    EXCEPTION');
        DBMS_OUTPUT.PUT_LINE('    WHEN core.app_exception THEN');
        DBMS_OUTPUT.PUT_LINE('        RAISE;');
        DBMS_OUTPUT.PUT_LINE('    WHEN OTHERS THEN');
        DBMS_OUTPUT.PUT_LINE('        core.raise_error();');
        DBMS_OUTPUT.PUT_LINE('    END;');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('');

        --
        -- create procedure for upsert records with arguments
        --
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('    PROCEDURE save_' || c_procedure_name);
        DBMS_OUTPUT.PUT_LINE('    AS');
        DBMS_OUTPUT.PUT_LINE('        ' || RPAD('rec', g_width_in) || c_table_name || '%ROWTYPE;');
        DBMS_OUTPUT.PUT_LINE('        ' || RPAD('in_action', g_width_in) || 'CONSTANT CHAR := core.get_grid_action();');
        DBMS_OUTPUT.PUT_LINE('    BEGIN');
        DBMS_OUTPUT.PUT_LINE('        -- change record in table');
        --
        FOR c IN (
            SELECT c.column_name, c.data_type
            FROM user_tab_columns c
            WHERE c.table_name      = UPPER(c_table_name)
                AND c.column_name   NOT IN (
                    'UPDATED_BY',
                    'UPDATED_AT',
                    'CREATED_BY',
                    'CREATED_AT'
                )
            ORDER BY c.column_id
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('        '
                || RPAD('rec.' || LOWER(c.column_name), g_width_in)
                || ':= '
                || CASE WHEN c.data_type = 'DATE' THEN 'core.get_date(' END
                || 'core.get_grid_data(''' || UPPER(c.column_name) || ''')'
                || CASE WHEN c.data_type = 'DATE' THEN ')' END
                || ';'
            );
        END LOOP;
        --
        DBMS_OUTPUT.PUT_LINE('        --');
        DBMS_OUTPUT.PUT_LINE('        ' || in_tapi_package || '.' || c_procedure_name || ' (rec,');
        DBMS_OUTPUT.PUT_LINE('            ' || RPAD('in_action', g_width_in) || '=> in_action,');
        --
        FOR c IN c_primary_key_columns(c_table_name) LOOP
            DBMS_OUTPUT.PUT_LINE('            '
                || RPAD('in_' || c.column_name, g_width_in) || '=> NVL(core.get_grid_data(''OLD_' || UPPER(c.column_name) || ''')'
                || ', rec.' || c.column_name || ')'
                || CASE WHEN c.column_id != c.columns# THEN ',' END
            );
        END LOOP;
        --
        DBMS_OUTPUT.PUT_LINE('        );');
        DBMS_OUTPUT.PUT_LINE('        --');
        DBMS_OUTPUT.PUT_LINE('        IF in_action = ''D'' THEN');
        DBMS_OUTPUT.PUT_LINE('            RETURN;     -- exit this procedure');
        DBMS_OUTPUT.PUT_LINE('        END IF;');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('        -- update primary key back to APEX grid for proper row refresh');
        --
        FOR c IN c_primary_key_columns(c_table_name) LOOP
            DBMS_OUTPUT.PUT_LINE('        core.set_grid_data(''' || RPAD('OLD_' || UPPER(c.column_name) || ''',', g_width_in) || 'rec.' || c.column_name || ');');
        END LOOP;
        --
        DBMS_OUTPUT.PUT_LINE('    EXCEPTION');
        DBMS_OUTPUT.PUT_LINE('    WHEN core.app_exception THEN');
        DBMS_OUTPUT.PUT_LINE('        RAISE;');
        DBMS_OUTPUT.PUT_LINE('    WHEN OTHERS THEN');
        DBMS_OUTPUT.PUT_LINE('        core.raise_error();');
        DBMS_OUTPUT.PUT_LINE('    END;');
        DBMS_OUTPUT.PUT_LINE('');
    END;



    FUNCTION get_table_name
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN REGEXP_REPLACE(core.get_caller_name(3), '[^\.]+\.', g_app_prefix || '_');
    END;



    FUNCTION get_action (
        in_action               VARCHAR2        := NULL
    )
    RETURN CHAR
    AS
    BEGIN
        RETURN COALESCE(in_action, core.get_grid_action(), SUBSTR(core.get_request(), 1, 1));
    END;



    FUNCTION get_master_table (
        in_column_name          VARCHAR2
    )
    RETURN VARCHAR2
    AS
        out_table_name          all_constraints.table_name%TYPE;
    BEGIN
        SELECT n.table_name
        INTO out_table_name
        FROM all_constraints n
        JOIN all_cons_columns c
            ON c.owner              = n.owner
            AND c.constraint_name   = n.constraint_name
        WHERE n.owner               = core.get_owner()
            AND n.constraint_type   = 'P'
            AND c.table_name        LIKE g_app_prefix || '\_%' ESCAPE '\'
            AND c.column_name       = in_column_name
            AND c.position          = 1;
        --
        RETURN out_table_name;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION get_query (
        in_template             VARCHAR2,
        in_arg1                 VARCHAR2        := NULL,
        in_arg2                 VARCHAR2        := NULL,
        in_arg3                 VARCHAR2        := NULL,
        in_arg4                 VARCHAR2        := NULL,
        in_arg5                 VARCHAR2        := NULL,
        in_arg6                 VARCHAR2        := NULL,
        in_arg7                 VARCHAR2        := NULL,
        in_arg8                 VARCHAR2        := NULL
    )
    RETURN VARCHAR2
    AS
    BEGIN
        -- @TODO: check missing args
        RETURN TRIM(APEX_STRING.FORMAT(in_template,
            in_arg1,            -- %0
            in_arg2,            -- %1
            in_arg3,            -- %2
            in_arg4,            -- %3
            in_arg5,            -- %4
            in_arg6,            -- %5
            in_arg7,            -- %6
            in_arg8,            -- %7
            p_prefix => '!'));
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE rename_primary_key (
        in_column_name          VARCHAR2,
        in_old_key              VARCHAR2,
        in_new_key              VARCHAR2,
        in_merge                BOOLEAN         := TRUE
    )
    AS
        v_query                 VARCHAR2(2000);
    BEGIN
        -- rename in all related tables, need deferred foreign keys for this
        FOR c IN (
            SELECT c.table_name
            FROM all_tab_cols c
            JOIN all_tables t
                ON t.owner          = c.owner
                AND t.table_name    = c.table_name
            WHERE c.owner           = core.get_owner()
                AND c.table_name    LIKE g_app_prefix || '\_%' ESCAPE '\'
                AND c.column_name   = in_column_name
        ) LOOP
            -- @TODO: we should certainly log this
            BEGIN
                v_query := gen_tapi.get_query(q'!
                    !UPDATE %0
                    !SET %1   = :NEW_KEY_ID
                    !WHERE %1 = :OLD_KEY_ID
                    !',
                    c.table_name,           -- %0
                    in_column_name          -- %1
                );
                --
                EXECUTE IMMEDIATE v_query USING in_new_key, in_old_key;
                --
            EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                -- if this is the master table, we could remove the original row
                IF in_merge AND c.table_name = gen_tapi.get_master_table(in_column_name) THEN
                    v_query := gen_tapi.get_query(q'!
                        !DELETE %0
                        !WHERE %1 = :OLD_KEY_ID
                        !',
                        c.table_name,           -- %0
                        in_column_name          -- %1
                    );
                    --
                    EXECUTE IMMEDIATE v_query USING in_old_key;
                    --
                ELSE
                    RAISE;
                END IF;
            WHEN OTHERS THEN
                core.raise_error(NULL, c.table_name, in_column_name, in_old_key, in_new_key);
            END;
        END LOOP;
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;

END;
/
