CREATE OR REPLACE FORCE VIEW core_app_performance_v AS
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
            AND a.application_id    = core.get_app_id()
            AND a.view_date         >= core_jobs.get_start_date()
            AND a.view_date         <  core_jobs.get_end_date()
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
/
--
COMMENT ON TABLE core_app_performance_v IS '12 | Performance';
--
COMMENT ON COLUMN core_app_performance_v.app_id                     IS '';
COMMENT ON COLUMN core_app_performance_v.page_id                    IS '';
COMMENT ON COLUMN core_app_performance_v.page_name                  IS '';
COMMENT ON COLUMN core_app_performance_v.users_                     IS '';
COMMENT ON COLUMN core_app_performance_v.rendering_count            IS '';
COMMENT ON COLUMN core_app_performance_v.rendering_avg              IS '';
COMMENT ON COLUMN core_app_performance_v.rendering_max              IS '';
COMMENT ON COLUMN core_app_performance_v.processing_count           IS '';
COMMENT ON COLUMN core_app_performance_v.processing_avg             IS '';
COMMENT ON COLUMN core_app_performance_v.processing_max             IS '';
COMMENT ON COLUMN core_app_performance_v.ajax_count                 IS '';
COMMENT ON COLUMN core_app_performance_v.ajax_avg                   IS '';
COMMENT ON COLUMN core_app_performance_v.ajax_max                   IS '';
COMMENT ON COLUMN core_app_performance_v.rendering_avg__style       IS '';
COMMENT ON COLUMN core_app_performance_v.rendering_max__style       IS '';
COMMENT ON COLUMN core_app_performance_v.processing_avg__style      IS '';
COMMENT ON COLUMN core_app_performance_v.processing_max__style      IS '';
COMMENT ON COLUMN core_app_performance_v.ajax_avg__style            IS '';
COMMENT ON COLUMN core_app_performance_v.ajax_max__style            IS '';

