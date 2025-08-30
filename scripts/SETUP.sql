SET SERVEROUTPUT ON
CLEAR SCREEN

--
-- GRANT CORE OBJECTS TO SELECTED SCHEMAS
-- AND CREATE SYNONYMS IN EACH TARGET SCHEMA
-- (THIS MIGHT NEED MANUAL EXECUTION IF YOU ARE NOT DBA)
--
DECLARE
    v_core_owner    VARCHAR2(30) := USER;      -- EXECUTE SCRIPT AS THIS USER OR DBA
BEGIN
    -- check schema
    BEGIN
        SELECT u.username
        INTO v_core_owner
        FROM all_users u
        WHERE u.username = v_core_owner;
    EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20000, 'INVALID_CORE_SCHEMA');
    END;

    -- grant Core objects to other schemas
    FOR c IN (
        SELECT u.username
        FROM all_users u
        WHERE 1 = 1
            AND u.oracle_maintained = 'N'
            AND u.cloud_maintained  = 'NO'
            AND u.username          NOT IN ('ADMIN', 'DEV', 'MASTER')
            AND u.username          LIKE 'XX%'
        ORDER BY 1
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('  ' || c.username);
        DBMS_OUTPUT.PUT_LINE('  ' || RPAD('-', LENGTH(c.username), '-'));
        --
        FOR o IN (
            SELECT
                o.owner,
                o.object_type,
                o.object_name,
                CASE WHEN o.object_type IN ('PACKAGE', 'PROCEDURE') THEN 'EXECUTE' ELSE 'SELECT' END AS grant_what
            FROM all_objects o
            WHERE o.owner           = v_core_owner
                AND (o.object_name  LIKE 'CORE%' OR o.object_name = 'RECOMPILE')
                AND o.object_type   IN ('PACKAGE', 'PROCEDURE', 'TABLE')
            ORDER BY
                o.object_type,
                o.object_name
        ) LOOP
            EXECUTE IMMEDIATE
                'GRANT ' || o.grant_what || ' ON ' || o.owner || '.' || o.object_name
                    || ' TO ' || c.username || ' WITH GRANT OPTION';
            --
            DBMS_OUTPUT.PUT_LINE('    ' || LPAD(o.object_type, 12) || ' | ' || RPAD(o.object_name, 30) || ' ' || o.grant_what);
        END LOOP;
        --
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

