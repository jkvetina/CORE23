CREATE OR REPLACE PACKAGE BODY core_jobs AS

    PROCEDURE job_scan_apps
    AS
    BEGIN
        core.log_start();

        -- rebuild requested apps
        FOR app_id IN VALUES OF core_custom.g_apps LOOP
            core.log_debug('rebuild_app', app_id);
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
        END LOOP;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE send_daily (
        in_recipients       VARCHAR2        := NULL,
        in_offset           PLS_INTEGER     := 1
    )
    AS
        v_out               CLOB            := EMPTY_CLOB();
        v_subject           VARCHAR2(256)   := core_custom.g_project_name || ' - Daily Overview, ' || TO_CHAR(TRUNC(SYSDATE) - in_offset, 'YYYY-MM-DD') || ' [' || core_custom.get_env() || ']';
        v_cursor            SYS_REFCURSOR;
        v_start_date        DATE            := TRUNC(SYSDATE) - in_offset;      -- >=
        v_end_date          DATE            := TRUNC(SYSDATE) - in_offset + 1;  -- <
    BEGIN
        IF core.get_session_id() IS NULL THEN
            core.create_session (
                in_user_id  => USER,
                in_app_id   => core_custom.g_app_id
            );
        END IF;

        --
        recompile();

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
                'CONSTRAINT'        AS object_type,
                t.constraint_name   AS object_name,
                t.table_name
            FROM user_constraints t
            WHERE t.status = 'DISABLED'
            UNION ALL
            SELECT
                'INDEX'             AS object_type,
                t.index_name        AS object_name,
                t.table_name
            FROM user_indexes t
            WHERE (t.status         != 'VALID'
                OR t.funcidx_status != 'ENABLED')
            UNION ALL
            SELECT
                'TRIGGER'           AS object_type,
                t.trigger_name      AS object_name,
                t.table_name
            FROM user_triggers t
            WHERE t.status = 'DISABLED'
            ORDER BY
                1, 2;
        --
        v_out := v_out || get_content(v_cursor, 'Disabled Objects');

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
                AND t.log_date  >= v_start_date
                AND t.log_date  <  v_end_date
            ORDER BY
                1, 2, 3, 4;
        --
        v_out := v_out || get_content(v_cursor, 'Schedulers');

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.mview_name,
                MAX(TO_CHAR(t.last_refresh_end_time, 'YYYY-MM-DD HH24:MI:SS'))          AS last_refreshed_at,
                MAX(ROUND(86400 * (t.last_refresh_end_time - t.last_refresh_date), 0))  AS last_timer,
                t.staleness,
                t.compile_state,
                --
                LISTAGG(i.index_name, ', ') WITHIN GROUP (ORDER BY i.index_name) AS indexes
                --
            FROM all_mviews t
            LEFT JOIN all_indexes i
                ON i.owner          = t.owner
                AND i.table_name    = t.mview_name
            WHERE 1 = 1
                AND t.owner         LIKE core_custom.g_owner_like
            GROUP BY
                t.mview_name,
                t.staleness,
                t.compile_state
            ORDER BY 1;
        --
        v_out := v_out || get_content(v_cursor, 'Materialized Views');

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.application_id AS app_id,
                t.page_id,
                t.component_type_name,
                t.component_display_name,
                t.property_group_name,
                t.property_name,
                DBMS_LOB.SUBSTR(t.code_fragment, 4000, 1) AS code_fragment,
                t.error_message AS error
            FROM apex_used_db_object_comp_props t
            WHERE t.error_message IS NOT NULL
            ORDER BY
                1, 2, 3, 4;
        --
        v_out := v_out || get_content(v_cursor, 'Broken APEX Components');

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.application_id AS app_id,
                t.page_id,
                TRIM(REGEXP_REPLACE(REGEXP_REPLACE(t.error_message, '#\d+', ''), 'id "\d+"', 'id ?')) AS error,
                --
                COUNT(*) AS count_
                --
            FROM apex_workspace_activity_log t
            WHERE 1 = 1
                AND t.view_date         >= v_start_date
                AND t.view_date         <  v_end_date
                AND t.error_message     IS NOT NULL
                AND t.error_message     NOT LIKE 'Your session has ended%'
            GROUP BY
                t.application_id,
                t.page_id,
                TRIM(REGEXP_REPLACE(REGEXP_REPLACE(t.error_message, '#\d+', ''), 'id "\d+"', 'id ?'))
            ORDER BY
                1, 2, 3;
        --
        v_out := v_out || get_content(v_cursor, 'Workspace Errors');

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.application_id AS app_id,
                t.page_id,
                t.message_level AS level_,
                TRIM(REGEXP_REPLACE(REGEXP_REPLACE(t.message, '#\d+', ''), 'id "\d+"', 'id ?')) AS error,
                t.apex_user AS user_,
                --
                COUNT(*) AS count_
                --
            FROM apex_debug_messages t
            WHERE 1 = 1
                AND t.message_timestamp >= v_start_date
                AND t.message_timestamp <  v_end_date
                AND t.message_level     < 4
            GROUP BY
                t.application_id,
                t.page_id,
                t.message_level,
                TRIM(REGEXP_REPLACE(REGEXP_REPLACE(t.message, '#\d+', ''), 'id "\d+"', 'id ?')),
                t.apex_user
            ORDER BY
                1, 2, 3, 4;
        --
        v_out := v_out || get_content(v_cursor, 'APEX Debug Messages');

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.workspace_name,
                APEX_STRING_UTIL.GET_DOMAIN(t.url) AS host,
                t.http_method,
                t.status_code,
                --
                ROUND(AVG(t.elapsed_sec), 2) AS elapsed_sec_avg,
                COUNT(*) AS count_
                --
            FROM apex_webservice_log t
            WHERE 1 = 1
                AND t.request_date  >= v_start_date
                AND t.request_date  <  v_end_date
            GROUP BY
                t.workspace_name,
                APEX_STRING_UTIL.GET_DOMAIN(t.url),
                t.http_method,
                t.status_code
            ORDER BY
                1, 2, 3;
        --
        v_out := v_out || get_content(v_cursor, 'Web Service Calls');

        -- append content
        OPEN v_cursor FOR
            SELECT
                t.app_id,
                REPLACE(REPLACE(t.mail_send_error, '<', '"'), '>', '"') AS error,
                --
                SUM(t.mail_send_count) AS count_
                --
            FROM apex_mail_queue t
            WHERE 1 = 1
                AND t.mail_message_created  >= v_start_date
                AND t.mail_message_created  <  v_end_date
                AND t.mail_send_error       IS NOT NULL
            GROUP BY
                t.app_id,
                REPLACE(REPLACE(t.mail_send_error, '<', '"'), '>', '"')
            ORDER BY
                1, 2;
        --
        v_out := v_out || get_content(v_cursor, 'Mail Queue Errors');

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



    PROCEDURE send_performance (
        in_recipients       VARCHAR2        := NULL,
        in_offset           PLS_INTEGER     := 1
    )
    AS
        v_out               CLOB            := EMPTY_CLOB();
        v_subject           VARCHAR2(256)   := core_custom.g_project_name || ' - Performance, ' || TO_CHAR(TRUNC(SYSDATE) - in_offset, 'YYYY-MM-DD') || ' [' || core_custom.get_env() || ']';
        v_header            VARCHAR2(256);
        v_cursor            SYS_REFCURSOR;
    BEGIN
        -- go thru all selected apps
        FOR app_id IN VALUES OF core_custom.g_apps LOOP
            core.create_session (
                in_user_id  => USER,
                in_app_id   => app_id
            );
            --
            BEGIN
                SELECT 'Application ' || app_id || ' &ndash; ' || a.application_name
                INTO v_header
                FROM apex_applications a
                WHERE a.application_id = app_id;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                CONTINUE;
            END;
            --
            OPEN v_cursor FOR
                WITH t AS (
                    SELECT
                        a.id,
                        --
                        CASE WHEN GROUPING_ID(a.id) = 0 THEN a.application_id       END AS application_id,
                        CASE WHEN GROUPING_ID(a.id) = 0 THEN a.page_id              END AS page_id,
                        CASE WHEN GROUPING_ID(a.id) = 0 THEN a.page_name            END AS page_name,
                        CASE WHEN GROUPING_ID(a.id) = 0 THEN a.view_date            END AS view_date,
                        CASE WHEN GROUPING_ID(a.id) = 0 THEN MAX(a.page_view_type)  END AS page_view_type,
                        --
                        SUM(a.elapsed_time) AS elapsed_time,
                        --
                        COUNT(DISTINCT a.apex_user) AS count_users
                        --
                    FROM (
                        SELECT
                            CASE WHEN page_view_type = 'Rendering' THEN a.id
                                ELSE LAG(CASE WHEN page_view_type = 'Rendering' THEN a.id END IGNORE NULLS) OVER (ORDER BY a.id)
                                END AS request_id,
                            a.id,
                            a.application_id,
                            a.page_id,
                            a.page_name,
                            a.apex_user,
                            a.view_date,
                            a.elapsed_time,
                            a.page_view_type,
                            a.view_timestamp,
                            a.apex_session_id
                        FROM apex_workspace_activity_log a
                        WHERE 1 = 1
                            AND a.application_id    = app_id
                            AND a.application_id    IS NOT NULL
                            AND a.application_name  IS NOT NULL     -- to remove other workspaces
                            AND a.view_date         >= CASE WHEN in_offset < 1 THEN SYSDATE ELSE TRUNC(SYSDATE) END - in_offset
                            AND a.view_date         <  CASE WHEN in_offset < 1 THEN SYSDATE ELSE TRUNC(SYSDATE) END - in_offset + 1
                    ) a
                    GROUP BY
                        a.request_id,
                        a.application_id,
                        a.page_id,
                        a.page_name,
                        a.view_date,
                        a.id
                    HAVING a.request_id IS NOT NULL
                )
                SELECT 
                    t.application_id AS app_id,
                    t.page_id,
                    t.page_name,
                    MAX(t.count_users) AS users_,
                    --
                    NULLIF(COUNT(CASE WHEN t.page_view_type = 'Rendering'   THEN t.id END), 0)              AS rendering_count,
                    ROUND(AVG(   CASE WHEN t.page_view_type = 'Rendering'   THEN t.elapsed_time END), 2)    AS rendering_avg,
                    ROUND(MAX(   CASE WHEN t.page_view_type = 'Rendering'   THEN t.elapsed_time END), 2)    AS rendering_max,
                    --
                    NULLIF(COUNT(CASE WHEN t.page_view_type = 'Processing'  THEN t.id END), 0)              AS processing_count,
                    ROUND(AVG(   CASE WHEN t.page_view_type = 'Processing'  THEN t.elapsed_time END), 2)    AS processing_avg,
                    ROUND(MAX(   CASE WHEN t.page_view_type = 'Processing'  THEN t.elapsed_time END), 2)    AS processing_max,
                    --
                    NULLIF(COUNT(CASE WHEN t.page_view_type = 'Ajax'        THEN t.id END), 0)              AS ajax_count,
                    ROUND(AVG(   CASE WHEN t.page_view_type = 'Ajax'        THEN t.elapsed_time END), 2)    AS ajax_avg,
                    ROUND(MAX(   CASE WHEN t.page_view_type = 'Ajax'        THEN t.elapsed_time END), 2)    AS ajax_max
                    --
                FROM t
                GROUP BY
                    t.application_id,
                    t.page_id,
                    t.page_name
                ORDER BY
                    1, 2;
            --
            v_out := v_out || get_content(v_cursor, v_header, in_red => 1);
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
            SELECT t.email
            FROM apex_workspace_developers t
            WHERE t.is_application_developer    = 'Yes'
                AND t.email                     LIKE core_custom.g_developers_like
                AND t.date_last_updated         > TRUNC(SYSDATE) - 90
                AND in_recipients IS NULL
            UNION ALL
            SELECT t.column_value AS email
            FROM TABLE(APEX_STRING.SPLIT(in_recipients, ',')) t
            WHERE in_recipients IS NOT NULL
        ) LOOP
            v_id := APEX_MAIL.SEND (
                p_to         => c.email,
                p_from       => get_sender(),
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



    FUNCTION get_content (
        io_cursor           IN OUT SYS_REFCURSOR,
        --
        in_header           VARCHAR2        := NULL,
        in_red              NUMBER          := NULL
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
        v_align             VARCHAR2(128);
        v_out               CLOB            := EMPTY_CLOB();
    BEGIN
        v_cursor := DBMS_SQL.TO_CURSOR_NUMBER(io_cursor);

        -- get column names
        DBMS_SQL.DESCRIBE_COLUMNS(v_cursor, v_cols, v_desc);
        --
        FOR i IN 1 .. v_cols LOOP
            v_align := '';
            --
            IF v_desc(i).col_type = DBMS_SQL.NUMBER_TYPE THEN
                DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_number);
                v_align := ' align="right"';
            ELSIF v_desc(i).col_type = DBMS_SQL.DATE_TYPE THEN
                DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_date);
                v_align := ' align="left"';
            ELSE
                DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_value, 4000);
                v_align := ' align="left"';
            END IF;
            --
            v_line := v_line || '<th' || v_align || '>' || INITCAP(TRIM(REPLACE(v_desc(i).col_name, '_', ' '))) || '</th>';
        END LOOP;
        --
        v_out := v_out || TO_CLOB('<table cellpadding="5" cellspacing="0" border="1"><thead><tr>' || v_line || '</tr></thead><tbody>');

        -- fetch data
        v_line := '';
        WHILE DBMS_SQL.FETCH_ROWS(v_cursor) > 0 LOOP
            v_line := '';
            --
            FOR i IN 1 .. v_cols LOOP
                v_align := '';
                --
                IF v_desc(i).col_type = DBMS_SQL.NUMBER_TYPE THEN
                    DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_number);
                    v_value := TO_CHAR(v_number);
                    v_align := ' align="right"';
                    --
                    IF in_red IS NOT NULL AND v_number >= in_red AND (v_desc(i).col_name LIKE '%MAX' OR v_desc(i).col_name LIKE '%AVG') THEN
                        v_align := v_align || ' style="color: red;"';
                    END IF;
                    --
                ELSIF v_desc(i).col_type = DBMS_SQL.DATE_TYPE THEN
                    DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_date);
                    v_value := TO_CHAR(v_date);
                ELSE
                    DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_value);
                END IF;
                --
                v_line := v_line || '<td' || v_align || '>' || v_value || '</td>';
            END LOOP;
            --
            v_out := v_out || '<tr>' || v_line || '</tr>';
        END LOOP;

        -- cleanup
        close_cursor(v_cursor);
        --
        IF v_line IS NOT NULL THEN
            RETURN
                CASE WHEN in_header IS NOT NULL THEN TO_CLOB('<h2>' || in_header || '</h2>') END ||
                v_out || TO_CLOB('</tbody></table><br />');
        ELSE
            RETURN TO_CLOB('<h2>' || in_header || '</h2><p>No data found.</p><br />');
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
        RETURN COALESCE(
            core.get_constant (
                in_name     => 'G_SENDER_' || in_env,
                in_package  => 'CORE_CUSTOM', 
                in_owner    => core_custom.master_owner,
                in_silent   => TRUE
            ),
            core_custom.g_sender
        );
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

END;
/

