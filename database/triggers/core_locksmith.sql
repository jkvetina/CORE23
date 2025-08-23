CREATE OR REPLACE TRIGGER core_locksmith
AFTER DDL ON SCHEMA
DECLARE
    v_sql_text      ora_name_list_t;    -- TABLE OF VARCHAR2(64);
    rec             core_locks%ROWTYPE;
BEGIN
    -- get username, proxy first, then SQL Workshop, APEX...
    -- not adding schema on purpose, we dont want generic users
    rec.locked_by := core_lock.get_user();
    --
    core.log_start (
        'event',            ORA_SYSEVENT,
        'object_owner',     ORA_DICT_OBJ_OWNER,
        'object_type',      ORA_DICT_OBJ_TYPE,
        'object_name',      ORA_DICT_OBJ_NAME,
        'user',             rec.locked_by,
        'user_host',        SYS_CONTEXT('USERENV', 'HOST'),
        'user_ip',          SYS_CONTEXT('USERENV', 'IP_ADDRESS'),
        'user_lang',        REGEXP_REPLACE(SYS_CONTEXT('USERENV', 'LANGUAGE'), '^([^\.]+)', 1, 1, NULL, 1),
        'user_zone',        SESSIONTIMEZONE
    );
    --
    /*
    -- log whole object source in chunks of 64 bytes
    FOR i IN 1 .. ora_sql_txt(v_sql_text) LOOP
        core.log_debug (
            'chunk',    i,
            'content',  v_sql_text(i)
        );
    END LOOP;
    */

    -- evaluate only specific events and specific object types
    IF ORA_SYSEVENT IN ('CREATE', 'ALTER')
        AND ORA_DICT_OBJ_TYPE IN (
            'TABLE', 'VIEW', 'MATERIALIZED VIEW',
            'PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'FUNCTION', 'TRIGGER'
        )
    THEN
        core_lock.create_lock (
            in_object_owner     => ORA_DICT_OBJ_OWNER,
            in_object_type      => ORA_DICT_OBJ_TYPE,
            in_object_name      => ORA_DICT_OBJ_NAME,
            in_locked_by        => NULL,
            in_expire_at        => NULL
        );
    END IF;
    --
EXCEPTION
WHEN core.app_exception THEN
    RAISE;
WHEN OTHERS THEN
    core.raise_error();
END;
/

