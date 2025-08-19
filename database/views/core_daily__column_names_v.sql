CREATE OR REPLACE FORCE VIEW core_daily__column_names_v AS
WITH t (column_name, translated) AS (
    SELECT 'DB_VERSION',    'DB Version'    FROM DUAL UNION ALL
    SELECT 'ORDS_VERSION',  'ORDS Version'  FROM DUAL UNION ALL
    SELECT 'APEX_VERSION',  'APEX Version'  FROM DUAL UNION ALL
    SELECT 'APEX_PATCHED',  'APEX Patched'  FROM DUAL
)
SELECT
    t.column_name,
    t.translated
FROM t;
/

