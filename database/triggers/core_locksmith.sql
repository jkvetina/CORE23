CREATE OR REPLACE TRIGGER core_locksmith
AFTER DDL ON SCHEMA
DECLARE
    rec             core_locks%ROWTYPE;
BEGIN
    -- ignore procedure scanning objects
    IF ORA_DICT_OBJ_TYPE = 'PROCEDURE' AND ORA_DICT_OBJ_NAME LIKE 'DEPSCAN$%' THEN
        RETURN;
    END IF;

    -- get username, but we dont want generic users
    BEGIN
        rec.locked_by := core_lock.get_user();
    EXCEPTION
    WHEN OTHERS THEN
        NULL;
    END;

    -- log the event in the audit log, here, we it is fine to log just in the generic log
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

    -- evaluate only specific events and specific object types
    IF ORA_SYSEVENT IN ('CREATE', 'ALTER', 'DROP')
        AND ORA_DICT_OBJ_TYPE IN (
            'TABLE', 'VIEW', 'MATERIALIZED VIEW',
            'PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'FUNCTION', 'TRIGGER'
        )
        AND ORA_DICT_OBJ_NAME NOT LIKE 'CORE_LOCK%'
    THEN
        core_lock.create_lock (
            in_object_owner     => ORA_DICT_OBJ_OWNER,
            in_object_type      => ORA_DICT_OBJ_TYPE,
            in_object_name      => ORA_DICT_OBJ_NAME,
            in_locked_by        => rec.locked_by,
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

