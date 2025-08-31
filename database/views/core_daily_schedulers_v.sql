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
    AND t.log_date      >= core_jobs.get_start_date()
    AND t.log_date      <  core_jobs.get_end_date()
GROUP BY ALL
ORDER BY
    1, 2, 3;
/
--
COMMENT ON TABLE core_daily_schedulers_v IS '';
--
COMMENT ON COLUMN core_daily_schedulers_v.owner             IS '';
COMMENT ON COLUMN core_daily_schedulers_v.job_name          IS '';
COMMENT ON COLUMN core_daily_schedulers_v.last_start_date   IS '';
COMMENT ON COLUMN core_daily_schedulers_v.status            IS '';
COMMENT ON COLUMN core_daily_schedulers_v.status__style     IS '';
COMMENT ON COLUMN core_daily_schedulers_v.run_duration      IS '';
COMMENT ON COLUMN core_daily_schedulers_v.cpu_used          IS '';
COMMENT ON COLUMN core_daily_schedulers_v.count_            IS '';
COMMENT ON COLUMN core_daily_schedulers_v.error_            IS '';

