CREATE OR REPLACE FORCE VIEW core_apps_traffic_v AS
WITH f AS (
    SELECT /*+ MATERIALIZE */
        TO_NUMBER(f.column_value)       AS app_id,
        core_reports.get_start_date()   AS start_date
    FROM TABLE (core_reports.get_apps()) f
),
t AS (
    SELECT /*+ MATERIALIZE */
        t.application_id,
        COUNT(CASE WHEN t.page_view_type = 'Rendering' THEN 1 END) AS page_views,
        COUNT(*) AS page_events,
        --
        COUNT(DISTINCT t.page_id)           AS pages_,
        COUNT(DISTINCT t.apex_user)         AS users_,
        COUNT(DISTINCT t.apex_session_id)   AS sessions_,
        --
        ROUND(MAX(t.elapsed_time), 2) AS max_time
        --
    FROM apex_workspace_activity_log t
    JOIN f
        ON f.app_id         = t.application_id
    WHERE t.view_date       >= f.start_date
        AND t.view_date     <  f.start_date + 1
    GROUP BY
        t.application_id
),
e AS (
    SELECT /*+ MATERIALIZE */
        e.application_id,
        COUNT(DISTINCT e.page_view_id)      AS errors_
    FROM apex_debug_messages e
    JOIN f
        ON f.app_id             = e.application_id
    WHERE e.message_level       = 1
        AND e.message_timestamp >= f.start_date
        AND e.message_timestamp <  f.start_date + 1
    GROUP BY
        e.application_id
)
SELECT
    a.application_id            AS app_id,
    a.application_name          AS app_name,
    --
    NULLIF(t.page_views, 0)     AS page_views,
    NULLIF(t.page_events, 0)    AS page_events,
    NULLIF(t.pages_, 0)         AS pages_,
    NULLIF(t.users_, 0)         AS users_,
    NULLIF(t.sessions_, 0)      AS sessions_,
    NULLIF(e.errors_, 0)        AS errors_,
    ROUND(t.max_time, 2)        AS max_time,
    --
    CASE WHEN e.errors_ > 0     THEN 'RED' END AS errors__style,
    CASE WHEN t.max_time > 1    THEN 'RED' END AS max_time__style
    --
FROM apex_applications a
JOIN t
    ON t.application_id         = a.application_id
JOIN e
    ON e.application_id         = a.application_id
WHERE a.is_working_copy         = 'No'
    AND a.application_group     NOT LIKE '\_\_%' ESCAPE '\';
/

