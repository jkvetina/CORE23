SET SERVEROUTPUT ON
CLEAR SCREEN

--
-- GRANT CORE OBJECTS TO SELECTED SCHEMAS
-- AND CREATE SYNONYMS IN EACH TARGET SCHEMA
-- (THIS MIGHT NEED MANUAL EXECUTION IF YOU ARE NOT DBA)
--
DECLARE
    v_core_owner  CONSTANT VARCHAR2(30) := 'CORE';      -- EXECUTE SCRIPT AS THIS USER OR DBA
BEGIN
    FOR c IN (
        SELECT u.username
        FROM all_users u
        WHERE 1 = 1
            AND u.oracle_maintained = 'N'
            AND u.cloud_maintained  = 'NO'
            AND u.username          != v_core_owner
                AND u.username      NOT IN ('ADMIN')
        ORDER BY 1
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('-- PROCESSING: ' || c.username);
        --
        FOR o IN (
            SELECT
                o.owner,
                o.object_type,
                o.object_name
            FROM all_objects o
            WHERE o.owner           = v_core_owner
                AND o.object_type   NOT LIKE '%BODY'
        ) LOOP
            EXECUTE IMMEDIATE
                'GRANT EXECUTE ON ' || o.owner || '.' || o.object_name || ' TO ' || c.username || ' WITH GRANT OPTION';
            --
            EXECUTE IMMEDIATE
                'DROP ' || o.object_type || ' IF EXISTS ' || c.username || '.' || o.object_name;
            --
            EXECUTE IMMEDIATE
                'CREATE OR REPLACE SYNONYM ' || c.username || '.' || o.object_name
                || ' FOR ' || v_core_owner || '.' || o.object_name;
        END LOOP;
        --
        DBMS_UTILITY.COMPILE_SCHEMA(schema => c.username);
    END LOOP;
END;
/

--
-- CHECK GRANTS - ALSO CHECK IF SYNONYMS EXISTS - SHOW AS PIVOT
--
SELECT *
FROM all_tab_privs
WHERE grantor = 'CORE';

--
-- VERIFY SYNONYMS FROM TARGET SCHEMA
--
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
    g.grantable,
    o.status
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

