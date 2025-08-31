CREATE OR REPLACE FORCE VIEW core_apps_traffic_v AS
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
LEFT JOIN TABLE (core_reports.get_apps()) f
    ON TO_NUMBER(f.column_value)    = t.application_id
JOIN apex_workspace_log_archive a
    ON a.application_id             = t.application_id
    AND a.log_day                   = core_reports.get_start_date()
WHERE t.is_working_copy             = 'No'
    AND t.application_group         NOT LIKE '\_\_%' ESCAPE '\'
ORDER BY
    1, 2;
/

