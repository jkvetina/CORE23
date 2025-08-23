CREATE OR REPLACE PACKAGE BODY core_jobs AS

    g_start_date        DATE;
    g_end_date          DATE;
    g_group_name        VARCHAR2(256);
    --
    g_date_format       CONSTANT VARCHAR2(32) := 'YYYY-MM-DD HH24:MI';



    CURSOR related_views (
        in_prefix   VARCHAR2
    )
    IS
        SELECT
            t.view_name,
            COALESCE(
                REGEXP_SUBSTR(c.comments, '\|\s*([^\|]+)', 1, 1, NULL, 1),
                INITCAP(REPLACE(REGEXP_SUBSTR(t.view_name, '^' || in_prefix || '_(.*)_V$', 1, 1, NULL, 1), '_', ' '))
            ) AS header3,
            REGEXP_SUBSTR(c.comments, '\|\s*([^\|]+)', 1, 2, NULL, 1) AS header2
        FROM user_views t
        LEFT JOIN user_tab_comments c
            ON c.table_name     = t.view_name
        WHERE t.view_name           LIKE in_prefix || '\_%\_V'   ESCAPE '\'
            AND t.view_name     NOT LIKE in_prefix || '\_\_%\_V' ESCAPE '\'
        ORDER BY
            c.comments || t.view_name;



    PROCEDURE job_scan_apps (
        in_app_id           PLS_INTEGER     := NULL,
        in_right_away       BOOLEAN         := FALSE
    )
    AS
        v_apps              apex_t_varchar2;
    BEGIN
        core.log_start (
            'right_away',   CASE WHEN in_right_away THEN 'Y' ELSE 'N' END,
            'app_id',       in_app_id
        );

        -- make sure we have a valid APEX session
        IF core.get_session_id() IS NULL THEN
            core.create_session (
                in_user_id  => USER,
                in_app_id   => NVL(in_app_id, core_custom.g_app_id)
            );
        END IF;

        -- prepare apps list
        IF in_app_id IS NOT NULL THEN
            v_apps := apex_t_varchar2(in_app_id);
        ELSE
            v_apps := core_custom.g_apps;
        END IF;

        -- rebuild requested apps
        FOR app_id IN VALUES OF v_apps LOOP
            core.log_debug('rebuild_app', app_id);
            --
            IF in_right_away THEN
                BEGIN
                    APEX_APP_OBJECT_DEPENDENCY.SCAN(p_application_id => app_id);
                EXCEPTION
                WHEN OTHERS THEN
                    core.log_error('SCAN FAILED: ' || app_id);
                END;
            ELSE
                core.create_job (
                    in_job_name         => 'REBUILD_APP_' || app_id,
                    in_statement        => 'APEX_APP_OBJECT_DEPENDENCY.SCAN(p_application_id => ' || app_id || ');',
                    in_job_class        => core_custom.g_job_class,
                    in_user_id          => USER,
                    in_app_id           => app_id,
                    in_session_id       => NULL,
                    in_priority         => 3,
                    in_comments         => 'Rescan ' || app_id
                );
            END IF;
        END LOOP;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE job_daily_developers
    AS
        v_developers            VARCHAR2(32767);
    BEGIN
        -- set NLS to avoid ORA-06502 issues
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ''. ''';
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_DATE_FORMAT = ''' || g_date_format || '''';

        -- send reports to all developers
        v_developers := APEX_STRING.JOIN(core_custom.g_developers, ',');
        --
        core_jobs.send_daily(v_developers);
        COMMIT;
        --
        core_jobs.send_apps(v_developers);
        COMMIT;
        --
        apex_mail.push_queue();
        COMMIT;
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE send_daily (
        in_recipients       VARCHAR2        := NULL,
        in_offset           PLS_INTEGER     := NULL,
        in_skip_scan        BOOLEAN         := FALSE
    )
    AS
        v_out               CLOB            := EMPTY_CLOB();
        v_subject           VARCHAR2(256);
        v_cursor            SYS_REFCURSOR;
        v_offset            PLS_INTEGER     := NVL(in_offset, 0);
    BEGIN
        -- set variables for the views
        g_start_date        := TRUNC(SYSDATE) - v_offset;
        g_end_date          := TRUNC(SYSDATE) - v_offset + 1;
        v_subject           := get_subject('Daily Overview', g_start_date);
        --
        core.log_start (
            'recipients',   in_recipients,
            'offset',       in_offset,
            'start_date',   g_start_date,
            'end_date',     g_end_date
        );

        -- make sure we have a valid APEX session
        IF core.get_session_id() IS NULL THEN
            core.create_session (
                in_user_id  => USER,
                in_app_id   => core_custom.g_app_id
            );
        END IF;

        -- make sure objects are valid
        recompile();

        -- make sure we have fresh app scan
        IF v_offset < 1 AND NOT in_skip_scan THEN
            job_scan_apps(in_right_away => TRUE);
        END IF;

        -- go thru all reports
        FOR c IN related_views('CORE_DAILY') LOOP
            IF c.header2 IS NOT NULL THEN
                v_out := v_out || TO_CLOB('<h2>' || c.header2 || '</h2>');
            END IF;
            --
            v_out := v_out || get_content (
                in_view_name    => c.view_name,
                in_header       => c.header3,
                in_offset       => in_offset
            );
        END LOOP;

        -- send mail to all developers
        send_mail (
            in_recipients   => in_recipients,
            in_subject      => v_subject,
            in_payload      => get_html_header(v_subject) || v_out || get_html_footer()
        );
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE send_apps (
        in_recipients       VARCHAR2        := NULL,
        in_offset           PLS_INTEGER     := NULL
    )
    AS
        v_out               CLOB            := EMPTY_CLOB();
        v_subject           VARCHAR2(256);
        v_header            VARCHAR2(256);
        v_cursor            SYS_REFCURSOR;
        v_offset            PLS_INTEGER     := NVL(in_offset, 0);
    BEGIN
        g_start_date        := TRUNC(SYSDATE) - v_offset;
        g_end_date          := TRUNC(SYSDATE) - v_offset + 1;
        v_subject           := get_subject('Applications', g_start_date);
        --
        core.log_start (
            'recipients',   in_recipients,
            'offset',       in_offset,
            'start_date',   g_start_date,
            'end_date',     g_start_date
        );

        -- go thru all reports
        FOR c IN related_views('CORE_APPS') LOOP
            IF c.header2 IS NOT NULL THEN
                v_out := v_out || TO_CLOB('<h2>' || c.header2 || '</h2>');
            END IF;
            --
            v_out := v_out || get_content (
                in_view_name    => c.view_name,
                in_header       => c.header3,
                in_offset       => in_offset
            );
        END LOOP;

        -- go thru all selected apps
        FOR c IN (
            SELECT
                a.application_id,
                'Application ' || a.application_id || ' &ndash; ' || a.application_name AS header2
            FROM apex_applications a
            JOIN TABLE (core_jobs.get_apps()) f
                ON TO_NUMBER(f.column_value) = a.application_id
            ORDER BY 1
        ) LOOP
            core.create_session (
                in_user_id  => USER,
                in_app_id   => c.application_id
            );

            v_out := v_out || TO_CLOB('<h2>' || c.header2 || '</h2>');

            -- go thru all app specific reports
            FOR a IN related_views('CORE_APP') LOOP
                IF a.header2 IS NOT NULL THEN
                    v_out := v_out || TO_CLOB('<h2>' || a.header2 || '</h2>');
                END IF;
                --
                v_out := v_out || get_content (
                    in_view_name    => a.view_name,
                    in_header       => a.header3,
                    in_offset       => in_offset
                );
            END LOOP;
        END LOOP;

        -- go thru all reports
        FOR g IN (
            SELECT DISTINCT
                m.name                              AS module_name,
                '/' || c.pattern || m.uri_prefix    AS module_pattern
            FROM user_ords_services s
            JOIN user_ords_modules m
                ON m.id             = s.module_id
            JOIN user_ords_schemas c
                ON c.id             = m.schema_id
            WHERE s.status          = 'PUBLISHED'
                AND m.status        = 'PUBLISHED'
                AND c.status        = 'ENABLED'
                AND m.uri_prefix    != '/hr/'
            ORDER BY
                1, 2
        ) LOOP
            v_out := v_out || TO_CLOB('<h2>REST Services</h2>');
            --
            g_group_name := g.module_name;
            --
            FOR c IN related_views('CORE_REST') LOOP
                v_out := v_out || get_content (
                    in_view_name    => c.view_name,
                    in_header       => REPLACE(c.header3, '{MODULE_NAME}', g.module_name),
                    in_offset       => in_offset
                );
            END LOOP;
        END LOOP;

        -- send mail to all developers
        send_mail (
            in_recipients   => in_recipients,
            in_subject      => v_subject,
            in_payload      => get_html_header(v_subject) || v_out || get_html_footer()
        );
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE send_mail (
        in_recipients       VARCHAR2,
        in_subject          VARCHAR2,
        in_payload          CLOB
    )
    AS
        v_id                NUMBER;
    BEGIN
        -- send mail to all developers
        FOR c IN (
            SELECT
                t.email
            FROM (
                SELECT
                    t.email
                FROM apex_workspace_developers t
                WHERE t.is_application_developer    = 'Yes'
                    AND t.email                     LIKE core_custom.g_developers_like
                    AND t.date_last_updated         > TRUNC(SYSDATE) - 90
                    AND in_recipients IS NULL
                UNION ALL
                SELECT
                    t.column_value AS email
                FROM TABLE(APEX_STRING.SPLIT(in_recipients, ',')) t
                WHERE in_recipients IS NOT NULL
            ) t
            WHERE t.email LIKE '%@%.%'
            GROUP BY
                t.email
        ) LOOP
            v_id := APEX_MAIL.SEND (
                p_to         => c.email,
                p_from       => core_custom.get_sender(),
                p_body       => TO_CLOB('Enable HTML to see the content'),
                p_body_html  => in_payload,
                p_subj       => in_subject
            );
            --
            core.log_debug (
                'mail_id',      v_id,
                'recipient',    c.email
            );
        END LOOP;
        --
        APEX_MAIL.PUSH_QUEUE();

        -- check for error on last recipient
        FOR c IN (
            SELECT
                t.id            AS mail_id,
                t.mail_send_error
            FROM apex_mail_queue t
            WHERE t.id                  = v_id
                AND t.mail_send_error   IS NOT NULL
        ) LOOP
            core.raise_error (
                'MAIL_SEND_ERROR',
                'mail_id',      c.mail_id,
                'error',        c.mail_send_error
            );
        END LOOP;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION get_subject (
        in_header           VARCHAR2,
        in_date             DATE := NULL
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN core_custom.g_project_name
            || ' - ' || in_header
            || CASE WHEN in_date IS NOT NULL THEN ', ' || REPLACE(TO_CHAR(in_date, g_date_format), ' 00:00', '') END
            || ' [' || core_custom.get_env() || ']';
    END;



    FUNCTION get_content (
        in_view_name        VARCHAR2,
        in_header           VARCHAR2        := NULL,
        in_offset           PLS_INTEGER     := NULL
    )
    RETURN CLOB
    AS
        v_cursor            SYS_REFCURSOR;
        v_out               CLOB;
    BEGIN
        OPEN v_cursor
            FOR 'SELECT * FROM ' || in_view_name;
        --
        v_out := get_content (
            io_cursor       => v_cursor,
            in_header       => in_header,
            in_view_name    => in_view_name,
            in_offset       => in_offset
        );
        --
        RETURN v_out;
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION get_content (
        io_cursor           IN OUT SYS_REFCURSOR,
        --
        in_view_name        VARCHAR2        := NULL,
        in_header           VARCHAR2        := NULL,
        in_offset           PLS_INTEGER     := NULL
    )
    RETURN CLOB
    AS
        v_cursor            PLS_INTEGER;
        v_desc              DBMS_SQL.DESC_TAB;
        v_cols              PLS_INTEGER;
        v_number            NUMBER;
        v_date              DATE;
        v_value             VARCHAR2(4000);
        v_header            VARCHAR2(32767);
        v_line              VARCHAR2(32767);
        v_align             VARCHAR2(2000);
        v_style             VARCHAR2(2000);
        v_out               CLOB            := EMPTY_CLOB();
        --
        TYPE t_array        IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(128);
        v_styles t_array;
    BEGIN
        v_cursor := DBMS_SQL.TO_CURSOR_NUMBER(io_cursor);

        -- get column names
        DBMS_SQL.DESCRIBE_COLUMNS(v_cursor, v_cols, v_desc);

        -- process headers
        FOR i IN 1 .. v_cols LOOP
            -- retrive value and do formatting
            v_align := ' align="left"';
            --
            IF v_desc(i).col_type = DBMS_SQL.NUMBER_TYPE THEN
                DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_number);
                v_align := ' align="right"';
            ELSIF v_desc(i).col_type = DBMS_SQL.DATE_TYPE THEN
                DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_date);
            ELSE
                DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_value, 4000);
            END IF;

            -- identify and store column position with style value
            IF v_desc(i).col_name LIKE '%\_\_STYLE' ESCAPE '\' THEN
                v_styles(REPLACE(RTRIM(v_desc(i).col_name, '_'), '__STYLE', '')) := i;
                CONTINUE;
            END IF;
            --
            v_value := get_column_name (
                in_table_name   => in_view_name,
                in_column_name  => v_desc(i).col_name,
                in_offset       => in_offset
            );
            v_line := v_line || '<th' || v_align || '>' || v_value || '</th>';
        END LOOP;
        --
        v_out := v_out || TO_CLOB('<table cellpadding="5" cellspacing="0" border="1"><thead><tr>' || v_line || '</tr></thead><tbody>');

        -- fetch data
        v_line := '';
        WHILE DBMS_SQL.FETCH_ROWS(v_cursor) > 0 LOOP
            v_line := '';
            --
            FOR i IN 1 .. v_cols LOOP
                -- process all columns except style ones
                IF RTRIM(v_desc(i).col_name, '_') LIKE '%\_\_STYLE' ESCAPE '\' THEN
                    CONTINUE;
                END IF;
                --
                v_align := '';
                --
                IF v_desc(i).col_type = DBMS_SQL.NUMBER_TYPE THEN
                    DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_number);
                    v_value := TO_CHAR(v_number);
                    v_align := ' align="right"';
                ELSIF v_desc(i).col_type = DBMS_SQL.DATE_TYPE THEN
                    DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_date);
                    v_value := CASE WHEN v_date IS NOT NULL THEN TO_CHAR(v_date, g_date_format) END;
                ELSE
                    DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_value);
                END IF;

                -- apply styles
                IF v_styles.EXISTS(v_desc(i).col_name) THEN
                    DBMS_SQL.COLUMN_VALUE(v_cursor, v_styles(v_desc(i).col_name), v_style);
                    v_align := v_align
                        || ' style="' || CASE
                            WHEN v_style = 'RED' THEN 'color: #f00;'
                            ELSE v_style END || '"';
                END IF;
                --
                v_line := v_line || '<td' || v_align || '>' || TRIM(v_value) || '</td>';
            END LOOP;
            --
            v_out := v_out || '<tr>' || v_line || '</tr>';
        END LOOP;

        -- cleanup
        close_cursor(v_cursor);

        -- prepend headers
        IF v_line IS NULL THEN
            v_out := '';
        END IF;
        --
        RETURN
            CASE WHEN in_header IS NOT NULL THEN TO_CLOB('<h3>' || in_header || '</h3>') END ||
            v_out ||
            CASE
                WHEN v_line IS NOT NULL THEN TO_CLOB('</tbody></table><br />')
                ELSE TO_CLOB('<p>No data found.</p><br />')
                END;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        close_cursor(v_cursor);
        RAISE;
    WHEN OTHERS THEN
        close_cursor(v_cursor);
        core.raise_error();
    END;



    FUNCTION get_column_name (
        in_table_name       VARCHAR2,
        in_column_name      VARCHAR2,
        in_offset           PLS_INTEGER     := NULL
    )
    RETURN VARCHAR2
    AS
        v_column_name       user_col_comments.comments%TYPE;
    BEGIN
        SELECT MAX(t.comments)
        INTO v_column_name
        FROM user_col_comments t
        WHERE t.table_name      = in_table_name
            AND t.column_name   = in_column_name;
        --
        IF REGEXP_LIKE(v_column_name, '\{Mon fmDD, -\d+\}') THEN
            v_column_name := TO_CHAR(TRUNC(SYSDATE) - in_offset - TO_NUMBER(REGEXP_SUBSTR(v_column_name, '\-(\d+)', 1, 1, NULL, 1)), 'Mon fmDD');
        END IF;
        --
        RETURN NVL(v_column_name, INITCAP(REPLACE(in_column_name, '_', ' ')));
    END;



    PROCEDURE close_cursor (
        io_cursor           IN OUT PLS_INTEGER
    )
    AS
    BEGIN
        DBMS_SQL.CLOSE_CURSOR(io_cursor);
    EXCEPTION
    WHEN OTHERS THEN
        NULL;
    END;



    FUNCTION get_html_header (
        in_title            VARCHAR2
    )
    RETURN CLOB
    AS
    BEGIN
        RETURN TO_CLOB(
            '<!DOCTYPE HTML>' ||
            '<html>' ||
            '<head>' ||
            '<meta http-equiv="Content-Type" content="text/html; charset=utf-8">' ||
            '<meta name="viewport" content="width=device-width">' ||
            '<style>' ||
                'table {' ||
                '    border: 0;' ||
                '    border-spacing: 0;' ||
                '    border-collapse: collapse;' ||
                '    mso-table-lspace: 0pt;' ||
                '    mso-table-rspace: 0pt;' ||
                '}' ||
            '</style>' ||
            '</head>' ||
            '<body>' ||
            '<h1>' || in_title || '</h1>'
        );
    END;



    FUNCTION get_html_footer
    RETURN CLOB
    AS
    BEGIN
        RETURN TO_CLOB(
            '<div><br />&copy; ' || TO_CHAR(SYSDATE, 'YYYY') || ' ' || core_custom.g_copyright || '. All rights reserved.</div></body></html>'
        );
    END;



    FUNCTION get_start_date
    RETURN DATE
    AS
    BEGIN
        RETURN g_start_date;
    END;



    FUNCTION get_end_date
    RETURN DATE
    AS
    BEGIN
        RETURN g_end_date;
    END;



    FUNCTION get_apps
    RETURN apex_t_varchar2
    AS
    BEGIN
        RETURN core_custom.g_apps;
    END;



    FUNCTION get_group_name
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN g_group_name;
    END;

END;
/

