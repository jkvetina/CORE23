CREATE OR REPLACE PACKAGE BODY core_jobs AS

    g_start_date    DATE;
    g_end_date      DATE;

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
        v_developers := APEX_STRING.JOIN(core_custom.g_developers, ',');
        --
        core_jobs.send_daily(v_developers);
        COMMIT;
        --
        core_jobs.send_performance(v_developers);
        COMMIT;
        --
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
        v_start_date        DATE;
        v_end_date          DATE;
    BEGIN
        v_start_date        := TRUNC(SYSDATE) - v_offset;
        v_end_date          := TRUNC(SYSDATE) - v_offset + 1;
        v_subject           := get_subject('Daily Overview', v_start_date);
        --
        core.log_start (
            'recipients',   in_recipients,
            'offset',       in_offset,
            'start_date',   v_start_date,
            'end_date',     v_end_date
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

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    d.version_full          AS db_version,
                    r.version_no            AS apex_version,
                    p.installed_on          AS apex_patched,
                    ords.installed_version  AS ords_version
                FROM product_component_version d
                CROSS JOIN apex_release r
                JOIN apex_patches p
                    ON p.images_version = r.version_no;
            --
            v_out := v_out || get_content(v_cursor, 'Versions');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
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
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
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
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    t.owner,
                    t.name,
                    t.type,
                    t.line,
                    t.position,
                    REGEXP_REPLACE(t.text, '<[^>]*>', '') AS error_
                FROM all_errors t
                WHERE 1 = 1
                    AND t.owner         LIKE core_custom.g_owner_like
                    AND t.attribute     = 'ERROR'
                ORDER BY
                    1, 2, 3,
                    t.sequence;
            --
            v_out := v_out || get_content(v_cursor, 'Compile Errors');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    t.owner,
                    t.job_name,
                    MAX(t.actual_start_date)            AS last_start_date,
                    t.status,
                    CASE
                        WHEN t.status != 'SUCCEEDED' THEN 'RED'
                        END AS status__style,
                    --
                    MAX(core.get_timer(t.run_duration)) AS run_duration,
                    MAX(core.get_timer(t.cpu_used))     AS cpu_used,
                    COUNT(*)                            AS count_,
                    --
                    REGEXP_REPLACE(t.errors, '<[^>]*>', '') AS error_
                    --
                FROM all_scheduler_job_run_details t
                WHERE 1 = 1
                    AND t.owner     LIKE core_custom.g_owner_like
                    AND t.log_date  >= v_start_date
                    AND t.log_date  <  v_end_date
                GROUP BY ALL
                ORDER BY
                    1, 2, 3;
            --
            v_out := v_out || get_content(v_cursor, 'Schedulers');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    t.mview_name,
                    MAX(TO_CHAR(t.last_refresh_end_time, 'YYYY-MM-DD HH24:MI'))             AS last_refreshed_at,
                    MAX(ROUND(86400 * (t.last_refresh_end_time - t.last_refresh_date), 0))  AS last_timer,
                    t.staleness,
                    CASE
                        WHEN t.staleness != 'FRESH' THEN 'RED'
                        END AS staleness__style,
                    --
                    t.compile_state,
                    CASE
                        WHEN t.compile_state != 'VALID' THEN 'RED'
                        END AS compile_state__style,
                    --
                    LISTAGG(i.index_name, ', ') WITHIN GROUP (ORDER BY i.index_name) AS indexes
                    --
                FROM all_mviews t
                LEFT JOIN all_indexes i
                    ON i.owner          = t.owner
                    AND i.table_name    = t.mview_name
                WHERE 1 = 1
                    AND t.owner         LIKE core_custom.g_owner_like
                GROUP BY ALL
                ORDER BY 1;
            --
            v_out := v_out || get_content(v_cursor, 'Materialized Views');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    t.application_id            AS app_id,
                    t.application_name          AS app_name,
                    t.authentication_method     AS auth_method,
                    t.user_name,
                    REGEXP_REPLACE(t.custom_status_text, '<[^>]*>', '') AS error_,
                    t.ip_address,
                    --
                    COUNT(*)                    AS attempts,
                    MAX(t.access_date)          AS last_access_date
                    --
                FROM apex_workspace_access_log t
                WHERE t.application_schema_owner    NOT LIKE 'APEX_2%'
                    AND t.authentication_result     != 'AUTH_SUCCESS'
                    AND t.access_date               >= v_start_date
                    AND t.access_date               <  v_end_date
                GROUP BY ALL
                ORDER BY
                    1, 2, 3, 4;
            --
            v_out := v_out || get_content(v_cursor, 'Failed Authentication');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    t.application_id AS app_id,
                    t.page_id,
                    t.component_type_name,
                    t.component_display_name,
                    t.property_group_name,
                    t.property_name,
                    REGEXP_REPLACE(DBMS_LOB.SUBSTR(t.code_fragment, 4000, 1), '<[^>]*>', '') AS code_fragment,
                    REGEXP_REPLACE(t.error_message, '<[^>]*>', '') AS error_
                FROM apex_used_db_object_comp_props t
                WHERE t.error_message IS NOT NULL
                ORDER BY
                    1, 2, 3, 4;
            --
            v_out := v_out || get_content(v_cursor, 'Broken APEX Components');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    t.workspace_name                    AS workspace,
                    APEX_STRING_UTIL.GET_DOMAIN(t.url)  AS host,
                    t.http_method                       AS method,
                    t.status_code,
                    --
                    CASE
                        WHEN t.status_code <= 299 THEN 'Success'
                        WHEN t.status_code <= 399 THEN 'Redirection'
                        WHEN t.status_code <= 499 THEN 'Client Error'
                        WHEN t.status_code <= 599 THEN 'Server Error'
                        END AS status,
                    --
                    CASE
                        WHEN t.status_code <= 299 THEN ''
                        WHEN t.status_code <= 399 THEN ''
                        WHEN t.status_code <= 499 THEN 'RED'
                        WHEN t.status_code <= 599 THEN 'RED'
                        END AS status__style,
                    --
                    ROUND(AVG(t.elapsed_sec), 2) AS elapsed_sec_avg,
                    ROUND(MAX(t.elapsed_sec), 2) AS elapsed_sec_max,
                    COUNT(*) AS count_
                    --
                FROM apex_webservice_log t
                WHERE 1 = 1
                    AND t.request_date  >= v_start_date
                    AND t.request_date  <  v_end_date
                GROUP BY ALL
                ORDER BY
                    1, 2, 3;
            --
            v_out := v_out || get_content(v_cursor, 'Web Service Calls');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    t.app_id,
                    REPLACE(REPLACE(t.mail_send_error, '<', '"'), '>', '"') AS error_,
                    --
                    SUM(t.mail_send_count)  AS count_,
                    MAX(t.id)               AS recent_id
                    --
                FROM apex_mail_queue t
                WHERE 1 = 1
                    AND t.mail_message_created  >= v_start_date
                    AND t.mail_message_created  <  v_end_date
                    AND t.mail_send_error       IS NOT NULL
                GROUP BY ALL
                ORDER BY
                    1, 2;
            --
            v_out := v_out || get_content(v_cursor, 'Mail Queue Errors');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    t.application_id AS app_id,
                    t.page_id,
                    REGEXP_REPLACE(
                        TRIM(REGEXP_REPLACE(REGEXP_REPLACE(t.error_message, '#\d+', ''), 'id "\d+"', 'id ?')),
                        '<[^>]*>', '') AS error_,
                    --
                    COUNT(*)    AS count_,
                    MAX(t.id)   AS recent_log_id
                    --
                FROM apex_workspace_activity_log t
                WHERE 1 = 1
                    AND t.view_date         >= v_start_date
                    AND t.view_date         <  v_end_date
                    AND t.error_message     IS NOT NULL
                    AND t.error_message     NOT LIKE 'Your session has ended%'
                GROUP BY ALL
                ORDER BY
                    1, 2, 3;
            --
            v_out := v_out || get_content(v_cursor, 'Workspace Errors');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    t.application_id    AS app_id,
                    t.page_id,
                    t.apex_user         AS user_,
                    --
                    CASE t.message_level
                        WHEN 1 THEN 'E'
                        WHEN 2 THEN 'W'
                        ELSE TO_CHAR(t.message_level)
                        END AS type_,
                    --
                    REGEXP_REPLACE(
                        TRIM(REGEXP_REPLACE(REGEXP_REPLACE(t.message, '#\d+', ''), 'id "\d+"', 'id ?')),
                        '<[^>]*>', '') AS error_,
                    --
                    COUNT(*)    AS count_,
                    MAX(t.id)   AS recent_log_id
                    --
                FROM apex_debug_messages t
                WHERE 1 = 1
                    AND t.message_timestamp >= v_start_date
                    AND t.message_timestamp <  v_end_date
                    AND t.message_level     IN (1, 2)
                    AND t.message           NOT LIKE '%ORA-20876: Stop APEX Engine%'
                GROUP BY ALL
                ORDER BY
                    1, 2, 3, 4;
            --
            v_out := v_out || get_content(v_cursor, 'APEX Debug Messages');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    t.table_name,
                    '[MISSING]'         AS status,
                    'RED'               AS status__style
                FROM user_tables t
                JOIN user_tab_cols c
                    ON c.table_name     = t.table_name
                    AND c.column_name   = 'TENANT_ID'
                LEFT JOIN user_policies p
                    ON p.object_name    = t.table_name
                WHERE t.table_name      LIKE core_custom.global_prefix || '%' ESCAPE '\'
                    AND p.policy_name   IS NULL
                ORDER BY 1;
            --
            v_out := v_out || get_content(v_cursor, 'Missing VPD Policies');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    s.synonym_name,
                    g.type              AS object_type,
                    s.table_owner       AS owner,
                    s.table_name        AS object_name,
                    --
                    REPLACE (
                        LISTAGG(g.privilege, ', ') WITHIN GROUP (ORDER BY g.privilege),
                        'ALTER, DEBUG, DELETE, FLASHBACK, INDEX, INSERT, ON COMMIT REFRESH, QUERY REWRITE, READ, REFERENCES, SELECT, UPDATE', 'ALL'
                        ) AS privileges,
                    --
                    CASE WHEN g.grantable = 'YES' THEN 'Y' END AS is_grantable,
                    --
                    o.status,
                    CASE WHEN o.status != 'VALID' THEN 'RED' END AS status__style
                    --
                FROM user_synonyms s
                LEFT JOIN user_tab_privs_recd g
                    ON g.owner          = s.table_owner
                    AND g.table_name    = s.table_name
                LEFT JOIN all_objects o
                    ON o.owner          = s.table_owner
                    AND o.object_name   = s.table_name
                    AND o.object_type   = g.type
                GROUP BY
                    s.synonym_name,
                    s.table_owner,
                    s.table_name,
                    g.type,
                    g.grantable,
                    o.status
                ORDER BY 1;
            --
            v_out := v_out || get_content(v_cursor, 'Synonyms');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

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
        in_offset           PLS_INTEGER     := NULL
    )
    AS
        v_out               CLOB            := EMPTY_CLOB();
        v_subject           VARCHAR2(256);
        v_header            VARCHAR2(256);
        v_cursor            SYS_REFCURSOR;
        v_offset            PLS_INTEGER     := NVL(in_offset, 0);
        v_start_date        DATE;
        v_end_date          DATE;
    BEGIN
        v_start_date        := TRUNC(SYSDATE) - v_offset;
        v_end_date          := TRUNC(SYSDATE) - v_offset + 1;
        v_subject           := get_subject('APEX Traffic and Performance', v_start_date);
        --
        core.log_start (
            'recipients',   in_recipients,
            'offset',       in_offset,
            'start_date',   v_start_date,
            'end_date',     v_end_date
        );

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    t.application_group     AS app_group,
                    t.application_id        AS app_id,
                    t.application_name      AS app_name,
                    t.version,
                    --t.build_status,
                    t.pages,
                    t.last_updated_by       AS updated_by,
                    t.last_updated_on       AS updated_at,
                    --
                    CASE WHEN t.last_updated_on >= v_start_date THEN 'RED' END AS updated_at__style,
                    --
                    COALESCE (
                        TO_CHAR(t.last_dependency_analyzed_at, 'YYYY-MM-DD HH24:MI'),
                        CASE WHEN f.column_value IS NOT NULL THEN 'MISSING' END
                    ) AS analyzed_at,
                    --
                    CASE WHEN f.column_value IS NULL THEN 'RED' END AS app_id__style,
                    CASE WHEN f.column_value IS NULL THEN 'RED' END AS app_name__style,
                    --
                    CASE WHEN f.column_value IS NOT NULL
                        AND (t.last_dependency_analyzed_at IS NULL OR t.last_dependency_analyzed_at < TRUNC(SYSDATE))
                        THEN 'RED' END AS analyzed_at__style
                    --
                FROM apex_applications t
                LEFT JOIN TABLE(core_custom.g_apps) f
                    ON TO_NUMBER(f.column_value)    = t.application_id
                WHERE t.is_working_copy             = 'No'
                    AND t.application_group         NOT LIKE '\_\_%' ESCAPE '\'
                ORDER BY
                    1, 2;
            --
            v_out := v_out || get_content(v_cursor, 'APEX Applications', 'Overview');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    t.application_id        AS app_id,
                    t.application_name      AS app_name,
                    --
                    NULLIF(a.page_views, 0)         AS page_views,
                    NULLIF(a.page_events, 0)        AS page_events,
                    NULLIF(a.distinct_pages, 0)     AS pages_,
                    NULLIF(a.distinct_users, 0)     AS users_,
                    NULLIF(a.distinct_sessions, 0)  AS sessions_,
                    NULLIF(a.error_count, 0)        AS errors_,
                    ROUND(a.maximum_render_time, 2) AS render_time_max,
                    --
                    CASE WHEN a.error_count > 0         THEN 'RED' END AS errors__style,
                    CASE WHEN a.maximum_render_time > 1 THEN 'RED' END AS render_time_max__style
                    --
                FROM apex_applications t
                LEFT JOIN TABLE(core_custom.g_apps) f
                    ON TO_NUMBER(f.column_value)    = t.application_id
                JOIN apex_workspace_log_archive a
                    ON a.application_id             = t.application_id
                    AND a.log_day                   = v_start_date
                WHERE t.is_working_copy             = 'No'
                    AND t.application_group         NOT LIKE '\_\_%' ESCAPE '\'
                ORDER BY
                    1, 2;
            --
            v_out := v_out || get_content(v_cursor, NULL, 'Traffic');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- append content
        BEGIN
            OPEN v_cursor FOR
                SELECT
                    f.file_name,
                    DBMS_LOB.GETLENGTH(f.file_content) AS file_size,
                    f.last_updated_by   AS updated_by,
                    f.last_updated_on   AS updated_at,
                    --
                    CASE WHEN f.last_updated_on >= v_start_date THEN 'RED' END AS updated_at__style
                    --
                FROM apex_workspace_static_files f
                WHERE (
                        f.file_name     LIKE '%.css'
                        OR f.file_name  LIKE '%.js'
                    )
                    AND f.file_name     NOT LIKE '%.min.%'
                ORDER BY 1;
            --
            v_out := v_out || get_content(v_cursor, 'Workspace Files');
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error();
        END;

        -- REST Services

        -- Developers

        -- Users (pivot)

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

            -- append content
            BEGIN
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
                                AND a.view_date         >= v_start_date
                                AND a.view_date         <  v_end_date
                        ) a
                        GROUP BY
                            a.id,
                            a.request_id,
                            a.application_id,
                            a.page_id,
                            a.page_name,
                            a.view_date
                        HAVING a.request_id IS NOT NULL
                    ),
                    d AS (
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
                        GROUP BY ALL
                    )
                    SELECT
                        d.app_id,
                        d.page_id,
                        d.page_name,
                        d.users_,
                        --
                        d.rendering_count,
                        d.rendering_avg,
                        d.rendering_max,
                        d.processing_count,
                        d.processing_avg,
                        d.processing_max,
                        d.ajax_count,
                        d.ajax_avg,
                        d.ajax_max,
                        --
                        CASE WHEN d.rendering_avg   >= 1 THEN 'RED' END AS rendering_avg__style,
                        CASE WHEN d.rendering_max   >= 1 THEN 'RED' END AS rendering_max__style,
                        CASE WHEN d.processing_avg  >= 1 THEN 'RED' END AS processing_avg__style,
                        CASE WHEN d.processing_max  >= 1 THEN 'RED' END AS processing_max__style,
                        CASE WHEN d.ajax_avg        >= 1 THEN 'RED' END AS ajax_avg__style,
                        CASE WHEN d.ajax_max        >= 1 THEN 'RED' END AS ajax_max__style
                    FROM d
                    ORDER BY
                        1, 2;
                --
                v_out := v_out || get_content(v_cursor, v_header, 'Performance');
            EXCEPTION
            WHEN OTHERS THEN
                core.raise_error();
            END;

            -- append content
            BEGIN
                OPEN v_cursor FOR
                    SELECT
                        g.developer,
                        g.page_id,
                        g.page_name,
                        --
                        COUNT(DISTINCT g.component_id) AS components,
                        --
                        NULLIF(COUNT(CASE WHEN g.audit_action = 'Insert' THEN 1 END), 0) AS inserted_,
                        NULLIF(COUNT(CASE WHEN g.audit_action = 'Update' THEN 1 END), 0) AS updated_,
                        NULLIF(COUNT(CASE WHEN g.audit_action = 'Delete' THEN 1 END), 0) AS deleted_
                        --
                    FROM apex_developer_activity_log g
                    WHERE 1 = 1
                        AND g.application_id    = app_id
                        AND g.audit_date        >= v_start_date
                        AND g.audit_date        <  v_end_date
                        AND g.developer         != USER
                    GROUP BY ALL
                    ORDER BY
                        1, 2, 3;
                --
                v_out := v_out || get_content(v_cursor, NULL, 'Component Changes');
            EXCEPTION
            WHEN OTHERS THEN
                core.raise_error();
            END;
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
            || CASE WHEN in_date IS NOT NULL THEN ', ' || REPLACE(TO_CHAR(in_date, 'YYYY-MM-DD HH24:MI'), ' 00:00', '') END
            || ' [' || core_custom.get_env() || ']';
    END;



    FUNCTION get_content (
        in_query            VARCHAR2,
        in_header           VARCHAR2        := NULL
    )
    RETURN CLOB
    AS
        v_cursor            SYS_REFCURSOR;
        v_out               CLOB;
    BEGIN
        OPEN v_cursor FOR in_query;
        --
        v_out := get_content (
            io_cursor       => v_cursor,
            in_header       => in_header
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
        in_header           VARCHAR2        := NULL
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
        v_style             VARCHAR2(64);
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
            v_line := v_line || '<th' || v_align || '>' || get_column_name(v_desc(i).col_name) || '</th>';
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
                    v_value := CASE WHEN v_date IS NOT NULL THEN TO_CHAR(v_date, 'YYYY-MM-DD HH24:MI') END;
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
        in_name             VARCHAR2
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN REPLACE(REPLACE(REPLACE(
            INITCAP(TRIM(REPLACE(in_name, '_', ' '))),
            'Db ',      'DB '),
            'Apex ',    'APEX '),
            'Ords ',    'ORDS ');
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

END;
/

