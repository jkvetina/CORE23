CREATE OR REPLACE FORCE VIEW core_daily_invalid_objects_v AS
SELECT
    t.owner,
    t.object_type,
    t.object_name
FROM all_objects t
WHERE 1 = 1
    AND t.owner         LIKE core.get_constant('G_OWNER_LIKE', 'CORE_CUSTOM')
    AND t.status        = 'INVALID'
ORDER BY
    1, 2, 3;
/
--
COMMENT ON TABLE core_daily_invalid_objects_v IS '11 | Invalid Objects';
--
COMMENT ON COLUMN core_daily_invalid_objects_v.owner            IS '';
COMMENT ON COLUMN core_daily_invalid_objects_v.object_type      IS '';
COMMENT ON COLUMN core_daily_invalid_objects_v.object_name      IS '';

