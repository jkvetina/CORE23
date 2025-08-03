CREATE OR REPLACE PACKAGE BODY core_jobs AS

    PROCEDURE job_scan_apps
    AS
    BEGIN
        IF core.get_session_id() IS NULL THEN
            core.create_session (
                in_user_id  => USER,
                in_app_id   => core_custom.g_app_id
            );
        END IF;
        --
        core.log_start();

        -- rebuild requested apps
        FOR app_id IN VALUES OF core_custom.g_apps LOOP
            core.log_debug('rebuild_app', app_id);
            core.create_job (
                in_job_name         => 'REBUILD_APP_' || app_id,
                in_statement        => 'APEX_APP_OBJECT_DEPENDENCY.SCAN(p_application_id => ' || app_id || ');',
                in_job_class        => core_custom.g_job_class,
                in_user_id          => USER,
                in_app_id           => core_custom.g_app_id,
                in_session_id       => core.get_session_id(),
                in_priority         => 3,
                in_comments         => 'Rescan ' || app_id
            );
        END LOOP;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE send_daily (
        in_recipient        VARCHAR2 := NULL
    )
    AS
        v_out               CLOB            := EMPTY_CLOB();
        v_subject           VARCHAR2(64)    := 'Daily Overview [' || core_custom.get_env() || ']';
        v_cursor            SYS_REFCURSOR;
        v_id                NUMBER;
    BEGIN
        IF core.get_session_id() IS NULL THEN
            core.create_session (
                in_user_id  => USER,
                in_app_id   => core_custom.g_app_id
            );
        END IF;

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.owner,
                t.object_type,
                t.object_name
            FROM all_objects t
            WHERE 1 = 1
                AND t.owner     LIKE core_custom.g_owner_like
                AND t.status    = 'INVALID'
            ORDER BY
                1, 2, 3;
        --
        v_out := v_out || get_content(v_cursor, 'Invalid Objects');

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.owner,
                t.name,
                t.type,
                t.line,
                t.position,
                t.text              AS error
            FROM all_errors t
            WHERE 1 = 1
                AND t.owner         LIKE core_custom.g_owner_like
                AND t.attribute     = 'ERROR'
            ORDER BY
                1, 2, 3,
                t.sequence;
        --
        v_out := v_out || get_content(v_cursor, 'Compile Errors');

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.owner,
                t.job_name,
                t.actual_start_date             AS start_date,
                t.status,
                core.get_timer(t.run_duration)  AS run_duration,
                core.get_timer(t.cpu_used)      AS cpu_used,
                t.errors
                --
            FROM all_scheduler_job_run_details t
            WHERE 1 = 1
                AND t.owner     LIKE core_custom.g_owner_like
                AND t.log_date  >= TRUNC(SYSDATE) - 1
                AND t.log_date  <  TRUNC(SYSDATE)
            ORDER BY
                1, 2, 3, 4;
        --
        v_out := v_out || get_content(v_cursor, 'Schedulers');

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.application_id,
                t.page_id,
                t.message_level AS level_,
                t.message,
                t.apex_user,
                --
                COUNT(*) AS count_
                --
            FROM apex_debug_messages t
            WHERE 1 = 1
                AND t.message_timestamp >= TRUNC(SYSDATE) - 1
                AND t.message_timestamp <  TRUNC(SYSDATE)
                AND t.message_level     < 4
            GROUP BY
                t.application_id,
                t.page_id,
                t.message_level,
                t.message,
                t.apex_user
            ORDER BY
                1, 2, 3, 4;
        --
        v_out := v_out || get_content(v_cursor, 'APEX Debug Messages');

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.application_id,
                t.page_id,
                t.component_type_name,
                t.component_display_name,
                t.property_group_name,
                t.property_name,
                DBMS_LOB.SUBSTR(t.code_fragment, 4000, 1) AS code_fragment,
                t.error_message
            FROM apex_used_db_object_comp_props t
            WHERE t.error_message IS NOT NULL
            ORDER BY
                1, 2, 3, 4;
        --
        v_out := v_out || get_content(v_cursor, 'Broken APEX Components');

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.application_id,
                t.page_id,
                t.error_message,
                --
                COUNT(*) AS count_
                --
            FROM apex_workspace_activity_log t
            WHERE 1 = 1
                AND t.view_date         >= TRUNC(SYSDATE) - 1
                AND t.view_date         <  TRUNC(SYSDATE)
                AND t.error_message     IS NOT NULL
            GROUP BY
                t.application_id,
                t.page_id,
                t.error_message
            ORDER BY
                1, 2, 3;
        --
        v_out := v_out || get_content(v_cursor, 'Workspace Errors');

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.app_id,
                t.mail_send_error,
                --
                SUM(t.mail_send_count) AS mail_send_count
                --
            FROM apex_mail_queue t
            WHERE 1 = 1
                AND t.mail_message_created  >= TRUNC(SYSDATE) - 1
                AND t.mail_message_created  <  TRUNC(SYSDATE)
                AND t.mail_send_error       IS NOT NULL
            GROUP BY
                t.app_id,
                t.mail_send_error
            ORDER BY
                1, 2;
        --
        v_out := v_out || get_content(v_cursor, 'Mail Queue Errors');

        -- finalize content
        v_out := get_html_header('Daily Overview') || v_out || get_html_footer();

        -- send mail to all developers
        IF in_recipient IS NOT NULL THEN
            v_id := APEX_MAIL.SEND (
                p_to         => in_recipient,
                p_from       => get_sender(),
                p_body       => TO_CLOB('Enable HTML to see the content'),
                p_body_html  => v_out,
                p_subj       => v_subject
            );
            --
            core.log_debug (
                'mail_id',      v_id,
                'recipient',    in_recipient
            );
        ELSE
            FOR c IN (
                SELECT t.email
                FROM apex_workspace_developers t
                WHERE t.is_application_developer    = 'Yes'
                    AND t.email                     LIKE core_custom.g_developers
                    AND t.date_last_updated         > TRUNC(SYSDATE) - 90
            ) LOOP
                APEX_MAIL.SEND (
                    p_to         => c.email,
                    p_from       => get_sender(),
                    p_body       => TO_CLOB('Enable HTML to see the content'),
                    p_body_html  => v_out,
                    p_subj       => v_subject
                );
                --
                core.log_debug (
                    'mail_id',      v_id,
                    'recipient',    c.email
                );
            END LOOP;
        END IF;
        --
        APEX_MAIL.PUSH_QUEUE();

        -- check for error
        FOR c IN (
            SELECT
                t.id            AS mail_id,
                t.mail_send_error
            FROM apex_mail_queue t
            WHERE t.id          = v_id
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



    FUNCTION get_content (
        io_cursor           IN OUT SYS_REFCURSOR,
        in_header           VARCHAR2 := NULL
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
        v_out               CLOB            := EMPTY_CLOB();
    BEGIN
        v_cursor := DBMS_SQL.TO_CURSOR_NUMBER(io_cursor);

        -- get column names
        DBMS_SQL.DESCRIBE_COLUMNS(v_cursor, v_cols, v_desc);
        --
        FOR i IN 1 .. v_cols LOOP
            IF v_desc(i).col_type = DBMS_SQL.NUMBER_TYPE THEN
                DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_number);
            ELSIF v_desc(i).col_type = DBMS_SQL.DATE_TYPE THEN
                DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_date);
            ELSE
                DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_value, 4000);
            END IF;
            --
            v_line := v_line || '<td>' || INITCAP(TRIM(REPLACE(v_desc(i).col_name, '_', ' '))) || '</td>';
        END LOOP;
        --
        v_out := v_out || TO_CLOB('<table cellpadding="5" cellspacing="0" border="1"><thead><tr>' || v_line || '</tr></thead><tbody>');

        -- fetch data
        v_line := '';
        WHILE DBMS_SQL.FETCH_ROWS(v_cursor) > 0 LOOP
            v_line := '';
            --
            FOR i IN 1 .. v_cols LOOP
                IF v_desc(i).col_type = DBMS_SQL.NUMBER_TYPE THEN
                    DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_number);
                    v_value := TO_CHAR(v_number);
                ELSIF v_desc(i).col_type = DBMS_SQL.DATE_TYPE THEN
                    DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_date);
                    v_value := TO_CHAR(v_date);
                ELSE
                    DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_value);
                END IF;
                --
                v_line := v_line || '<td>' || v_value || '</td>';
            END LOOP;
            --
            v_out := v_out || '<tr>' || v_line || '</tr>';
        END LOOP;

        -- cleanup
        close_cursor(v_cursor);
        --
        IF v_line IS NOT NULL THEN
            RETURN CASE WHEN in_header IS NOT NULL THEN TO_CLOB('<h2>' || in_header || '</h2>') END ||
                v_out || TO_CLOB('</tbody></table><br />');
        ELSE
            RETURN EMPTY_CLOB();
        END IF;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        close_cursor(v_cursor);
        RAISE;
    WHEN OTHERS THEN
        close_cursor(v_cursor);
        core.raise_error();
    END;



    PROCEDURE close_cursor (
        io_cursor       IN OUT PLS_INTEGER
    )
    AS
    BEGIN
        DBMS_SQL.CLOSE_CURSOR(io_cursor);
    EXCEPTION
    WHEN OTHERS THEN
        NULL;
    END;



    FUNCTION get_sender (
        in_env              VARCHAR2 := NULL
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN CASE COALESCE(in_env, core_custom.get_env())
            WHEN 'DEV'  THEN core_custom.g_sender_dev
            WHEN 'UAT'  THEN core_custom.g_sender_uat
            WHEN 'PROD' THEN core_custom.g_sender_prod
            ELSE NULL END;
    END;



    FUNCTION get_html_header (
        in_title        VARCHAR2
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

END;
/

