CREATE OR REPLACE FORCE VIEW core_daily_disabled_objects_v AS
SELECT
    t.owner,
    'CONSTRAINT'        AS object_type,
    t.constraint_name   AS object_name,
    t.table_name
FROM all_constraints t
WHERE 1 = 1
    AND t.owner         LIKE core.get_constant('G_OWNER_LIKE', 'CORE_CUSTOM')
    AND t.status        = 'DISABLED'
UNION ALL
SELECT
    t.owner,
    'INDEX'             AS object_type,
    t.index_name        AS object_name,
    t.table_name
FROM all_indexes t
WHERE 1 = 1
    AND t.owner         LIKE core.get_constant('G_OWNER_LIKE', 'CORE_CUSTOM')
    AND (t.status       != 'VALID' OR t.funcidx_status != 'ENABLED')
UNION ALL
SELECT
    t.owner,
    'TRIGGER'           AS object_type,
    t.trigger_name      AS object_name,
    t.table_name
FROM all_triggers t
WHERE 1 = 1
    AND t.owner         LIKE core.get_constant('G_OWNER_LIKE', 'CORE_CUSTOM')
    AND t.status        = 'DISABLED'
ORDER BY
    1, 2, 3;
/
--
COMMENT ON TABLE core_daily_disabled_objects_v IS '12 | Disabled Objects';
--
COMMENT ON COLUMN core_daily_disabled_objects_v.owner           IS '';
COMMENT ON COLUMN core_daily_disabled_objects_v.object_type     IS '';
COMMENT ON COLUMN core_daily_disabled_objects_v.object_name     IS '';
COMMENT ON COLUMN core_daily_disabled_objects_v.table_name      IS '';

