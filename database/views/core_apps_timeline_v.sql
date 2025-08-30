CREATE OR REPLACE FORCE VIEW core_apps_timeline_v AS
SELECT
    l.apex_user AS user_id,
    --
    COUNT(*) AS total,
    --
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '00' THEN 1 END), 0) AS "00",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '01' THEN 1 END), 0) AS "01",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '02' THEN 1 END), 0) AS "02",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '03' THEN 1 END), 0) AS "03",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '04' THEN 1 END), 0) AS "04",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '05' THEN 1 END), 0) AS "05",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '06' THEN 1 END), 0) AS "06",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '07' THEN 1 END), 0) AS "07",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '08' THEN 1 END), 0) AS "08",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '09' THEN 1 END), 0) AS "09",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '10' THEN 1 END), 0) AS "10",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '11' THEN 1 END), 0) AS "11",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '12' THEN 1 END), 0) AS "12",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '13' THEN 1 END), 0) AS "13",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '14' THEN 1 END), 0) AS "14",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '15' THEN 1 END), 0) AS "15",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '16' THEN 1 END), 0) AS "16",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '17' THEN 1 END), 0) AS "17",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '18' THEN 1 END), 0) AS "18",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '19' THEN 1 END), 0) AS "19",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '20' THEN 1 END), 0) AS "20",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '21' THEN 1 END), 0) AS "21",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '22' THEN 1 END), 0) AS "22",
    NULLIF(COUNT(CASE WHEN TO_CHAR(l.view_timestamp, 'HH24') = '23' THEN 1 END), 0) AS "23"
    --
FROM apex_workspace_activity_log l
LEFT JOIN apex_applications a
    ON a.application_id = l.application_id
WHERE 1 = 1
    AND a.application_id    IS NULL
    AND l.apex_user         NOT LIKE '%MONITOR%'
    --
    AND TO_CHAR(l.view_timestamp, 'YYYY-MM-DD') = core_jobs.get_start_date()
GROUP BY ALL
ORDER BY 1;
/
--
COMMENT ON TABLE core_apps_timeline_v IS '15 | Developers Timeline';
--
COMMENT ON COLUMN core_apps_timeline_v.user_id      IS '';
COMMENT ON COLUMN core_apps_timeline_v.total        IS '';

