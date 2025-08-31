CREATE OR REPLACE FORCE VIEW core_daily_schedulers_v AS
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
    AND t.owner         LIKE core.get_constant('G_OWNER_LIKE', 'CORE_CUSTOM')
    AND t.log_date      >= core_reports.get_start_date()
    AND t.log_date      <  core_reports.get_end_date()
GROUP BY ALL
ORDER BY
    1, 2, 3;
/

