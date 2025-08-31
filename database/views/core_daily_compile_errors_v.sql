CREATE OR REPLACE FORCE VIEW core_daily_compile_errors_v AS
SELECT
    t.owner,
    t.name,
    t.type,
    t.line,
    t.position,
    REGEXP_REPLACE(t.text, '<[^>]*>', '') AS error_
FROM all_errors t
WHERE 1 = 1
    AND t.owner         LIKE core.get_constant('G_OWNER_LIKE', 'CORE_CUSTOM')
    AND t.attribute     = 'ERROR'
ORDER BY
    1, 2, 3,
    t.sequence;
/
--
COMMENT ON TABLE core_daily_compile_errors_v IS '';
--
COMMENT ON COLUMN core_daily_compile_errors_v.owner         IS '';
COMMENT ON COLUMN core_daily_compile_errors_v.name          IS '';
COMMENT ON COLUMN core_daily_compile_errors_v.type          IS '';
COMMENT ON COLUMN core_daily_compile_errors_v.line          IS '';
COMMENT ON COLUMN core_daily_compile_errors_v.position      IS '';
COMMENT ON COLUMN core_daily_compile_errors_v.error_        IS '';

