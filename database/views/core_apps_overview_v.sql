CREATE OR REPLACE FORCE VIEW core_apps_overview_v AS
SELECT
    t.application_group     AS app_group,
    t.application_id        AS app_id,
    t.application_name      AS app_name,
    t.version,
    --t.build_status,
    t.pages,
    t.last_updated_by       AS updated_by,
    t.last_updated_on       AS updated_at,
    --
    CASE WHEN t.last_updated_on >= core_jobs.get_start_date() THEN 'RED' END AS updated_at__style,
    --
    COALESCE (
        TO_CHAR(t.last_dependency_analyzed_at, 'YYYY-MM-DD HH24:MI'),
        CASE WHEN f.column_value IS NOT NULL THEN 'MISSING' END
    ) AS analyzed_at,
    --
    CASE WHEN f.column_value IS NULL THEN 'RED' END AS app_id__style,
    CASE WHEN f.column_value IS NULL THEN 'RED' END AS app_name__style,
    --
    CASE WHEN f.column_value IS NOT NULL
        AND (t.last_dependency_analyzed_at IS NULL OR t.last_dependency_analyzed_at < TRUNC(SYSDATE))
        THEN 'RED' END AS analyzed_at__style
    --
FROM apex_applications t
LEFT JOIN TABLE (core_jobs.get_apps()) f
    ON TO_NUMBER(f.column_value)    = t.application_id
WHERE t.is_working_copy             = 'No'
    AND t.application_group         NOT LIKE '\_\_%' ESCAPE '\'
ORDER BY
    1, 2;
/
--
COMMENT ON TABLE core_apps_overview_v IS '10 | Overview | APEX Applications';
--
COMMENT ON COLUMN core_apps_overview_v.app_group            IS '';
COMMENT ON COLUMN core_apps_overview_v.app_id               IS '';
COMMENT ON COLUMN core_apps_overview_v.app_name             IS '';
COMMENT ON COLUMN core_apps_overview_v.version              IS '';
COMMENT ON COLUMN core_apps_overview_v.pages                IS '';
COMMENT ON COLUMN core_apps_overview_v.updated_at__style    IS '';
COMMENT ON COLUMN core_apps_overview_v.analyzed_at          IS '';
COMMENT ON COLUMN core_apps_overview_v.app_id__style        IS '';
COMMENT ON COLUMN core_apps_overview_v.app_name__style      IS '';
COMMENT ON COLUMN core_apps_overview_v.analyzed_at__style   IS '';

