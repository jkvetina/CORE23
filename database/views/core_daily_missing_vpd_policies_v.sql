CREATE OR REPLACE FORCE VIEW core_daily_missing_vpd_policies_v AS
SELECT
    t.owner,
    t.table_name,
    '[MISSING]'         AS status,
    'RED'               AS status__style
FROM all_tables t
JOIN all_tab_cols c
    ON c.owner          = t.owner
    AND c.table_name    = t.table_name
    AND c.column_name   = 'TENANT_ID'
LEFT JOIN all_policies p
    ON p.object_owner   = t.owner
    AND p.object_name   = t.table_name
WHERE 1 = 1
    AND t.owner         LIKE core.get_constant('G_OWNER_LIKE', 'CORE_CUSTOM')
    AND t.table_name    LIKE core.get_constant('GLOBAL_PREFIX', 'CORE_CUSTOM') || '%' ESCAPE '\'
    AND p.policy_name   IS NULL
ORDER BY 1;
/

