CREATE OR REPLACE FORCE VIEW core_app_history_v AS
WITH s AS (
    SELECT /*+ MATERIALIZE */
        a.application_id,
        a.page_id,
        a.page_name,
        a.view_date,
        --
        NULLIF(SUM(CASE WHEN a.page_view_type = 'Rendering' THEN 1 ELSE 0 END), 0)      AS rendering,
        NULLIF(SUM(CASE WHEN a.page_view_type = 'Processing' THEN 1 ELSE 0 END), 0)     AS processing,
        NULLIF(SUM(CASE WHEN a.page_view_type = 'Ajax' THEN 1 ELSE 0 END), 0)           AS ajax,
        --
        COUNT(*)                            AS activity,
        COUNT(DISTINCT a.apex_user)         AS users,
        COUNT(DISTINCT a.apex_session_id)   AS sessions,
        --
        ROUND(AVG(a.elapsed_time),2)        AS avg_time,
        ROUND(MAX(a.elapsed_time), 2)       AS max_time
    FROM (
        SELECT
            a.application_id,
            a.page_id,
            a.page_name,
            TRUNC(a.view_date) AS view_date,
            a.page_view_type,
            a.elapsed_time,
            a.apex_user,
            a.apex_session_id
        FROM apex_workspace_activity_log a
        WHERE a.application_id = core.get_app_id()
    ) a
    GROUP BY
        a.application_id,
        a.page_id,
        a.page_name,
        a.view_date
)
SELECT
    s.page_id,
    s.page_name,
    --
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) -  0 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS today,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) -  1 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t1,       -- yesterday
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) -  2 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t2,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) -  3 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t3,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) -  4 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t4,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) -  5 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t5,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) -  6 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t6,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) -  7 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t7,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) -  8 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t8,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) -  9 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t9,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) - 10 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t10,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) - 11 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t11,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) - 12 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t12,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) - 13 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t13,
    NULLIF(SUM(CASE WHEN s.view_date = TRUNC(SYSDATE) - 14 THEN NVL(s.activity, 0) ELSE 0 END), 0) AS t14
FROM s
GROUP BY
    s.page_id,
    s.page_name
ORDER BY
    1, 2;
/
--
COMMENT ON TABLE core_app_history_v IS '';
--
COMMENT ON COLUMN core_app_history_v.page_id        IS '';
COMMENT ON COLUMN core_app_history_v.page_name      IS '';
COMMENT ON COLUMN core_app_history_v.today          IS '';
COMMENT ON COLUMN core_app_history_v.t1             IS '';
COMMENT ON COLUMN core_app_history_v.t2             IS '';
COMMENT ON COLUMN core_app_history_v.t3             IS '';
COMMENT ON COLUMN core_app_history_v.t4             IS '';
COMMENT ON COLUMN core_app_history_v.t5             IS '';
COMMENT ON COLUMN core_app_history_v.t6             IS '';
COMMENT ON COLUMN core_app_history_v.t7             IS '';
COMMENT ON COLUMN core_app_history_v.t8             IS '';
COMMENT ON COLUMN core_app_history_v.t9             IS '';
COMMENT ON COLUMN core_app_history_v.t10            IS '';
COMMENT ON COLUMN core_app_history_v.t11            IS '';
COMMENT ON COLUMN core_app_history_v.t12            IS '';
COMMENT ON COLUMN core_app_history_v.t13            IS '';
COMMENT ON COLUMN core_app_history_v.t14            IS '';

