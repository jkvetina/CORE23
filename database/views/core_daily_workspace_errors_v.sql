CREATE OR REPLACE FORCE VIEW core_daily_workspace_errors_v AS
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
    AND t.view_date         >= core_reports.get_start_date()
    AND t.view_date         <  core_reports.get_end_date()
    AND t.error_message     IS NOT NULL
    AND t.error_message     NOT LIKE 'Your session has ended%'
GROUP BY ALL
ORDER BY
    1, 2, 3;
/

