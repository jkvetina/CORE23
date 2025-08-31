CREATE OR REPLACE FORCE VIEW core_app_component_changes_v AS
SELECT
    g.developer,
    g.page_id,
    g.page_name,
    --
    COUNT(DISTINCT g.component_id) AS components,
    --
    NULLIF(COUNT(CASE WHEN g.audit_action = 'Insert' THEN 1 END), 0) AS inserted_,
    NULLIF(COUNT(CASE WHEN g.audit_action = 'Update' THEN 1 END), 0) AS updated_,
    NULLIF(COUNT(CASE WHEN g.audit_action = 'Delete' THEN 1 END), 0) AS deleted_
    --
FROM apex_developer_activity_log g
WHERE 1 = 1
    AND g.application_id    = core.get_app_id()
    AND g.audit_date        >= core_reports.get_start_date()
    AND g.audit_date        <  core_reports.get_end_date()
    AND g.developer         != USER
GROUP BY ALL
ORDER BY
    1, 2, 3;
/

