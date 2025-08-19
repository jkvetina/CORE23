CREATE OR REPLACE FORCE VIEW core_daily_broken_apex_components_v AS
SELECT
    t.application_id AS app_id,
    t.page_id,
    t.component_type_name,
    t.component_display_name,
    t.property_group_name,
    t.property_name,
    REGEXP_REPLACE(DBMS_LOB.SUBSTR(t.code_fragment, 4000, 1), '<[^>]*>', '') AS code_fragment,
    REGEXP_REPLACE(t.error_message, '<[^>]*>', '') AS error_
FROM apex_used_db_object_comp_props t
WHERE t.error_message IS NOT NULL
ORDER BY
    1, 2, 3, 4;
/
--
COMMENT ON TABLE core_daily_broken_apex_components_v IS '40 | Broken APEX Components | APEX Issues';
--
COMMENT ON COLUMN core_daily_broken_apex_components_v.app_id                    IS '';
COMMENT ON COLUMN core_daily_broken_apex_components_v.page_id                   IS '';
COMMENT ON COLUMN core_daily_broken_apex_components_v.component_type_name       IS '';
COMMENT ON COLUMN core_daily_broken_apex_components_v.component_display_name    IS '';
COMMENT ON COLUMN core_daily_broken_apex_components_v.property_group_name       IS '';
COMMENT ON COLUMN core_daily_broken_apex_components_v.property_name             IS '';
COMMENT ON COLUMN core_daily_broken_apex_components_v.code_fragment             IS '';
COMMENT ON COLUMN core_daily_broken_apex_components_v.error_                    IS '';

