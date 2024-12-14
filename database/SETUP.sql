SET SERVEROUTPUT ON
CLEAR SCREEN

--
-- GRANT CORE OBJECTS TO SELECTED SCHEMAS
-- AND CREATE SYNONYMS IN EACH TARGET SCHEMA
-- (THIS MIGHT NEED MANUAL EXECUTION IF YOU ARE NOT DBA)
--
DECLARE
    v_core_owner  CONSTANT VARCHAR2(30) := 'APPS';
BEGIN
    FOR c IN (
        SELECT u.username
        FROM all_users u
        WHERE 1 = 1
            AND u.oracle_maintained = 'N'
            AND u.cloud_maintained  = 'NO'
            AND u.username          != v_core_owner
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('-- PROCESSING: ' || c.username);
        --
        EXECUTE IMMEDIATE 'GRANT EXECUTE ON ' || v_core_owner || '.core'        || ' TO ' || c.username;
        EXECUTE IMMEDIATE 'GRANT EXECUTE ON ' || v_core_owner || '.core_custom' || ' TO ' || c.username;
        EXECUTE IMMEDIATE 'GRANT EXECUTE ON ' || v_core_owner || '.core_tapi'   || ' TO ' || c.username;
        EXECUTE IMMEDIATE 'GRANT EXECUTE ON ' || v_core_owner || '.recompile'   || ' TO ' || c.username;
        --
        DBMS_OUTPUT.PUT_LINE('CREATE OR REPLACE SYNONYM ' || c.username || '.core         FOR ' || v_core_owner || '.core;');
        DBMS_OUTPUT.PUT_LINE('CREATE OR REPLACE SYNONYM ' || c.username || '.core_custom  FOR ' || v_core_owner || '.core_custom;');
        DBMS_OUTPUT.PUT_LINE('CREATE OR REPLACE SYNONYM ' || c.username || '.core_tapi    FOR ' || v_core_owner || '.core_tapi;');
        DBMS_OUTPUT.PUT_LINE('CREATE OR REPLACE SYNONYM ' || c.username || '.recompile    FOR ' || v_core_owner || '.recompile;');
    END LOOP;
END;
/

--
-- CHECK GRANTS - ALSO CHECK IF SYNONYMS EXISTS - SHOW AS PIVOT
--
SELECT *
FROM all_tab_privs
WHERE grantor = 'APPS';

