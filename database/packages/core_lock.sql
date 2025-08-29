CREATE OR REPLACE PACKAGE BODY core_lock AS

    g_lock_length       CONSTANT NUMBER := 20/1440;



    FUNCTION get_user
    RETURN core_locks.locked_by%TYPE
    AS
    BEGIN
        -- get username, proxy first, then SQL Workshop, APEX...
        -- not adding schema on purpose, we dont want generic users
        RETURN COALESCE (
            NULLIF(SYS_CONTEXT('USERENV', 'PROXY_USER'), 'ORDS_PUBLIC_USER'),
            REGEXP_REPLACE(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), ':\d+$', ''),
            REGEXP_REPLACE(SYS_CONTEXT('USERENV', 'CLIENT_INFO'), '^[^:]+:', '')
        );
    END;



    PROCEDURE create_lock (
        in_object_owner     core_locks.object_owner%TYPE,
        in_object_type      core_locks.object_type%TYPE,
        in_object_name      core_locks.object_name%TYPE,
        in_locked_by        core_locks.locked_by%TYPE       := NULL,
        in_expire_at        core_locks.expire_at%TYPE       := NULL
    )
    AS
        rec                 core_locks%ROWTYPE;
    BEGIN
        -- check if we have a valid user
        rec.locked_by := COALESCE(in_locked_by, get_user());
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
            WHERE t.object_owner    = in_object_owner
                AND t.object_type   = in_object_type
                AND t.object_name   = in_object_name
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
        IF rec.lock_id IS NOT NULL THEN
            core_lock.extend_lock (
                in_lock_id => rec.lock_id
            );
        ELSE
            INSERT INTO core_locks (
                object_owner,
                object_type,
                object_name,
                locked_by,
                locked_at,
                counter,
                expire_at
                --object_payload
            )
            VALUES (
                in_object_owner,
                in_object_type,
                in_object_name,
                rec.locked_by,
                SYSDATE,
                1,
                NVL(in_expire_at, SYSDATE + g_lock_length)
                --get_object()
            );
        END IF;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE extend_lock (
        in_lock_id          core_locks.lock_id%TYPE,
        in_time             NUMBER
    )
    AS
    BEGIN
        UPDATE core_locks t
        SET t.counter       = NVL(t.counter, 0) + 1,
            t.expire_at     = SYSDATE + NVL(in_time, g_lock_length)
        WHERE t.lock_id     = in_lock_id;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE extend_lock (
        in_lock_id          core_locks.lock_id%TYPE,
        in_expire_at        core_locks.expire_at%TYPE       := NULL
    )
    AS
    BEGIN
        UPDATE core_locks t
        SET t.counter       = NVL(t.counter, 0) + 1,
            t.expire_at     = NVL(in_expire_at, SYSDATE + g_lock_length)
        WHERE t.lock_id     = in_lock_id;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE unlock (
        in_lock_id          core_locks.lock_id%TYPE         := NULL,
        in_locked_by        core_locks.locked_by%TYPE       := NULL,
        in_object_name      core_locks.object_name%TYPE     := NULL,
        in_object_type      core_locks.object_type%TYPE     := NULL,
        in_remove_hash      BOOLEAN                         := TRUE
    )
    AS
    BEGIN
        IF in_lock_id IS NULL AND in_locked_by IS NULL AND in_object_name IS NULL THEN
            core.raise_error('ARGUMENTS_MISSING');
        END IF;
        --
        UPDATE core_locks t
        SET t.expire_at         = NULL,
            t.object_hash       = CASE WHEN NOT in_remove_hash THEN t.object_hash END
        WHERE 1 = 1
            AND (t.lock_id      = in_lock_id        OR in_lock_id       IS NULL)
            AND (t.locked_by    = in_locked_by      OR in_locked_by     IS NULL)
            AND (t.object_name  = in_object_name    OR in_object_name   IS NULL)
            AND (t.object_type  = in_object_type    OR in_object_type   IS NULL);
        --
        DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQL%ROWCOUNT) || ' OBJECTS UNLOCKED');
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION get_object
    RETURN CLOB
    AS
        v_sql_text      ora_name_list_t;    -- TABLE OF VARCHAR2(64);
        v_out           CLOB;
    BEGIN
        FOR i IN 1 .. ora_sql_txt(v_sql_text) LOOP
            v_out := v_out || TO_CLOB(v_sql_text(i));
        END LOOP;
        --
        RETURN v_out;
    END;

END;
/

