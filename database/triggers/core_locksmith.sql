CREATE OR REPLACE TRIGGER core_locksmith
AFTER DDL ON SCHEMA
DECLARE
    v_sql_text      ora_name_list_t;    -- TABLE OF VARCHAR2(64);
    rec             core_locks%ROWTYPE;
BEGIN
    -- get username, proxy first, then SQL Workshop, APEX...
    -- not adding schema on purpose, we dont want generic users
    rec.locked_by := COALESCE (
        NULLIF(SYS_CONTEXT('USERENV', 'PROXY_USER'), 'ORDS_PUBLIC_USER'),
        REGEXP_REPLACE(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), ':\d+$', ''),
        REGEXP_REPLACE(SYS_CONTEXT('USERENV', 'CLIENT_INFO'), '^[^:]+:', '')
    );
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
        -- check if we have a valid user
        IF rec.locked_by IS NULL THEN
            core.raise_error('USER_ERROR: USE PROXY_USER OR CLIENT_ID');
        END IF;

        -- check recent log for current object
        FOR c IN (
            SELECT
                t.lock_id,
                t.locked_by,
                t.expire_at
            FROM core_locks t
            WHERE t.object_owner    = ORA_DICT_OBJ_OWNER
                AND t.object_type   = ORA_DICT_OBJ_TYPE
                AND t.object_name   = ORA_DICT_OBJ_NAME
            ORDER BY
                t.lock_id DESC
            FETCH FIRST 1 ROWS ONLY
        ) LOOP
            IF c.locked_by = rec.locked_by THEN
                -- same user, so update last record with new expire day
                rec.lock_id := c.lock_id;
                --
            ELSIF c.expire_at >= SYSDATE THEN
                -- for different user we need to check the expire date first
                core.raise_error('LOCK_ERROR: OBJECT LOCKED BY "' || c.locked_by || '" [' || c.lock_id || ']');
            END IF;
        END LOOP;
        --
        rec.object_owner    := ORA_DICT_OBJ_OWNER;
        rec.object_type     := ORA_DICT_OBJ_TYPE;
        rec.object_name     := ORA_DICT_OBJ_NAME;
        --
        IF rec.lock_id IS NOT NULL THEN
            core_lock.extend_lock (
                in_lock_id          => rec.lock_id
            );
        ELSE
            core_lock.create_lock (
                in_object_owner     => rec.object_owner,
                in_object_type      => rec.object_type,
                in_object_name      => rec.object_name,
                in_locked_by        => rec.locked_by
            );
        END IF;
    END IF;
    --
EXCEPTION
WHEN core.app_exception THEN
    RAISE;
WHEN OTHERS THEN
    core.raise_error();
END;
/

