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
    AND t.view_date         >= core_jobs.get_start_date()
    AND t.view_date         <  core_jobs.get_end_date()
    AND t.error_message     IS NOT NULL
    AND t.error_message     NOT LIKE 'Your session has ended%'
GROUP BY ALL
ORDER BY
    1, 2, 3;
/
--
COMMENT ON TABLE core_daily_workspace_errors_v IS '41 | Workspace Errors';
--
COMMENT ON COLUMN core_daily_workspace_errors_v.app_id          IS '';
COMMENT ON COLUMN core_daily_workspace_errors_v.page_id         IS '';
COMMENT ON COLUMN core_daily_workspace_errors_v.error_          IS '';
COMMENT ON COLUMN core_daily_workspace_errors_v.count_          IS '';
COMMENT ON COLUMN core_daily_workspace_errors_v.recent_log_id   IS '';

