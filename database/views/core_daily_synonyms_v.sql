CREATE OR REPLACE FORCE VIEW core_daily_synonyms_v AS
SELECT
    s.synonym_name,
    g.type              AS object_type,
    s.table_owner       AS owner,
    s.table_name        AS object_name,
    --
    REPLACE (
        LISTAGG(g.privilege, ', ') WITHIN GROUP (ORDER BY g.privilege),
        'ALTER, DEBUG, DELETE, FLASHBACK, INDEX, INSERT, ON COMMIT REFRESH, QUERY REWRITE, READ, REFERENCES, SELECT, UPDATE', 'ALL'
        ) AS privileges,
    --
    CASE WHEN g.grantable = 'YES' THEN 'Y' END AS is_grantable,
    --
    o.status,
    CASE WHEN o.status != 'VALID' THEN 'RED' END AS status__style
    --
FROM user_synonyms s
LEFT JOIN user_tab_privs_recd g
    ON g.owner          = s.table_owner
    AND g.table_name    = s.table_name
LEFT JOIN all_objects o
    ON o.owner          = s.table_owner
    AND o.object_name   = s.table_name
    AND o.object_type   = g.type
GROUP BY
    s.synonym_name,
    s.table_owner,
    s.table_name,
    g.type,
    g.grantable,
    o.status
ORDER BY 1;
/
--
COMMENT ON TABLE core_daily_synonyms_v IS '22 | Synonyms ';
--
COMMENT ON COLUMN core_daily_synonyms_v.synonym_name    IS '';
COMMENT ON COLUMN core_daily_synonyms_v.object_type     IS '';
COMMENT ON COLUMN core_daily_synonyms_v.owner           IS '';
COMMENT ON COLUMN core_daily_synonyms_v.object_name     IS '';
COMMENT ON COLUMN core_daily_synonyms_v.privileges      IS '';
COMMENT ON COLUMN core_daily_synonyms_v.is_grantable    IS '';
COMMENT ON COLUMN core_daily_synonyms_v.status          IS '';
COMMENT ON COLUMN core_daily_synonyms_v.status__style   IS '';

