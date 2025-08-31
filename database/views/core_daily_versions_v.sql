CREATE OR REPLACE FORCE VIEW core_daily_versions_v AS
SELECT
    d.version_full          AS db_version,
    r.version_no            AS apex_version,
    p.installed_on          AS apex_patched,
    ords.installed_version  AS ords_version
FROM product_component_version d
CROSS JOIN apex_release r
JOIN apex_patches p
    ON p.images_version = r.version_no;
/

