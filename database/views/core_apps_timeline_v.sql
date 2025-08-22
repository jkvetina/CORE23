CREATE OR REPLACE FORCE VIEW core_apps_timeline_v AS
SELECT
    l.apex_user AS user_id,
    --
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '00' THEN 1 END), 0) AS h00,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '01' THEN 1 END), 0) AS h01,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '02' THEN 1 END), 0) AS h02,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '03' THEN 1 END), 0) AS h03,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '04' THEN 1 END), 0) AS h04,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '05' THEN 1 END), 0) AS h05,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '06' THEN 1 END), 0) AS h06,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '07' THEN 1 END), 0) AS h07,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '08' THEN 1 END), 0) AS h08,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '09' THEN 1 END), 0) AS h09,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '10' THEN 1 END), 0) AS h10,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '11' THEN 1 END), 0) AS h11,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '12' THEN 1 END), 0) AS h12,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '13' THEN 1 END), 0) AS h13,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '14' THEN 1 END), 0) AS h14,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '15' THEN 1 END), 0) AS h15,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '16' THEN 1 END), 0) AS h16,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '17' THEN 1 END), 0) AS h17,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '18' THEN 1 END), 0) AS h18,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '19' THEN 1 END), 0) AS h19,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '20' THEN 1 END), 0) AS h20,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '21' THEN 1 END), 0) AS h21,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '22' THEN 1 END), 0) AS h22,
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '23' THEN 1 END), 0) AS h23,
    --
    COUNT(*) AS count_
    --
FROM apex_workspace_activity_log l
WHERE l.application_id      >= 4000
    AND l.apex_user         NOT LIKE '%MONITOR%'
    AND l.application_name  IS NULL
    --
    AND TO_CHAR(l.view_timestamp, 'YYYY-MM-DD') = core_jobs.get_start_date()
GROUP BY ALL
ORDER BY 1;
/
--
COMMENT ON TABLE core_apps_timeline_v IS '15 | Developers Timeline';
--
COMMENT ON COLUMN core_apps_timeline_v.user_id      IS '';
COMMENT ON COLUMN core_apps_timeline_v.h00          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h01          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h02          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h03          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h04          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h05          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h06          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h07          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h08          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h09          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h10          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h11          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h12          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h13          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h14          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h15          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h16          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h17          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h18          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h19          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h20          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h21          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h22          IS '';
COMMENT ON COLUMN core_apps_timeline_v.h23          IS '';
COMMENT ON COLUMN core_apps_timeline_v.count_       IS '';

