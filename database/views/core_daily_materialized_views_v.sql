CREATE OR REPLACE FORCE VIEW core_daily_materialized_views_v AS
SELECT
    t.mview_name,
    MAX(TO_CHAR(t.last_refresh_end_time, 'YYYY-MM-DD HH24:MI'))             AS last_refreshed_at,
    MAX(ROUND(86400 * (t.last_refresh_end_time - t.last_refresh_date), 0))  AS last_timer,
    t.staleness,
    CASE
        WHEN t.staleness != 'FRESH' THEN 'RED'
        END AS staleness__style,
    --
    t.compile_state,
    CASE
        WHEN t.compile_state != 'VALID' THEN 'RED'
        END AS compile_state__style,
    --
    LISTAGG(i.index_name, ', ') WITHIN GROUP (ORDER BY i.index_name) AS indexes
    --
FROM all_mviews t
LEFT JOIN all_indexes i
    ON i.owner          = t.owner
    AND i.table_name    = t.mview_name
WHERE 1 = 1
    AND t.owner         LIKE core.get_constant('G_OWNER_LIKE', 'CORE_CUSTOM')
GROUP BY ALL
ORDER BY 1;
/

