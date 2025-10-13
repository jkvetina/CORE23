CREATE OR REPLACE PACKAGE BODY core_lock AS

    g_lock_length       CONSTANT NUMBER     := 20/1440;
    g_check_hash        CONSTANT BOOLEAN    := TRUE;



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
        in_expire_at        core_locks.expire_at%TYPE       := NULL,
        in_hash_check       BOOLEAN                         := TRUE
    )
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --
        rec                 core_locks%ROWTYPE;
        v_hash_check        BOOLEAN := in_hash_check;
    BEGIN
        -- check if we have a valid user
        rec.locked_by := COALESCE(in_locked_by, get_user());
        IF rec.locked_by IS NULL THEN
            core.raise_error('USER_ERROR: USE_PROXY_USER_OR_SET_CLIENT_ID');
        END IF;

        -- get current object
        rec.object_payload  := get_object();

        -- check hash only on objects with source code
        IF in_object_type IN ('PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'FUNCTION', 'TRIGGER', 'VIEW') THEN
            rec.object_hash := get_clob_hash(rec.object_payload);
        END IF;
        --
        IF (NOT g_check_hash OR rec.object_hash IS NULL) THEN
            v_hash_check := FALSE;
        END IF;

        -- check recent log for current object
        FOR c IN (
            SELECT
                t.lock_id,
                t.locked_by,
                t.expire_at,
                t.object_hash
            FROM core_locks t
            WHERE t.object_owner    = in_object_owner
                AND t.object_type   = in_object_type
                AND t.object_name   = in_object_name
            ORDER BY
                t.lock_id DESC
            FETCH FIRST 1 ROWS ONLY
        ) LOOP
            IF c.locked_by = rec.locked_by THEN
                -- same user, so just extend the lock
                rec.lock_id := c.lock_id;
                --
            ELSIF c.expire_at >= SYSDATE THEN
                -- for different user we need to check the expire date first
                core.raise_error('LOCK_TIME_ERROR: OBJECT_LOCKED_BY `' || c.locked_by || '` [' || c.lock_id || ']');
                --
            ELSIF v_hash_check AND c.object_hash IS NOT NULL AND c.object_hash != rec.object_hash THEN
                -- check object hash
                -- when you take over an object, you should compile it right away, without any changes
                -- that will make sure you are not overriding any changes done by someone else in the meantime
                core.raise_error('LOCK_HASH_ERROR: OBJECT_CHANGED_BY `' || c.locked_by || '` [' || c.lock_id || ']');
            END IF;
        END LOOP;
        --
        IF rec.lock_id IS NOT NULL THEN
            core_lock.extend_lock (
                in_lock_id => rec.lock_id
            );
        ELSE
            rec.lock_id         := core_lock_id.NEXTVAL;
            rec.object_owner    := in_object_owner;
            rec.object_type     := in_object_type;
            rec.object_name     := in_object_name;
            rec.locked_at       := SYSDATE;
            rec.counter         := 1;
            rec.expire_at       := NVL(in_expire_at, rec.locked_at + g_lock_length);
            --
            INSERT INTO core_locks VALUES rec;
        END IF;
        --
        COMMIT;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        ROLLBACK;
        RAISE;
    WHEN OTHERS THEN
        ROLLBACK;
        core.raise_error();
    END;



    PROCEDURE extend_lock (
        in_lock_id          core_locks.lock_id%TYPE,
        in_time             NUMBER
    )
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --
        rec                 core_locks%ROWTYPE;
    BEGIN
        rec.expire_at       := SYSDATE + NVL(in_time, g_lock_length);
        rec.object_payload  := get_object();
        rec.object_hash     := get_clob_hash(rec.object_payload);
        --
        UPDATE core_locks t
        SET t.counter           = NVL(t.counter, 0) + 1,
            t.expire_at         = rec.expire_at,
            t.object_payload    = rec.object_payload,
            t.object_hash       = NVL(rec.object_hash, t.object_hash)
        WHERE t.lock_id         = in_lock_id;
        --
        COMMIT;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        ROLLBACK;
        RAISE;
    WHEN OTHERS THEN
        ROLLBACK;
        core.raise_error();
    END;



    PROCEDURE extend_lock (
        in_lock_id          core_locks.lock_id%TYPE,
        in_expire_at        core_locks.expire_at%TYPE       := NULL
    )
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --
        rec                 core_locks%ROWTYPE;
    BEGIN
        rec.expire_at       := NVL(in_expire_at, SYSDATE + g_lock_length);
        rec.object_payload  := get_object();
        rec.object_hash     := get_clob_hash(rec.object_payload);
        --
        UPDATE core_locks t
        SET t.counter           = NVL(t.counter, 0) + 1,
            t.expire_at         = rec.expire_at,
            t.object_payload    = rec.object_payload,
            t.object_hash       = NVL(rec.object_hash, t.object_hash)
        WHERE t.lock_id         = in_lock_id;
        --
        COMMIT;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        ROLLBACK;
        RAISE;
    WHEN OTHERS THEN
        ROLLBACK;
        core.raise_error();
    END;



    PROCEDURE unlock (
        in_lock_id          core_locks.lock_id%TYPE         := NULL,
        in_locked_by        core_locks.locked_by%TYPE       := NULL,
        in_object_name      core_locks.object_name%TYPE     := NULL,
        in_object_type      core_locks.object_type%TYPE     := NULL
    )
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --
    BEGIN
        IF in_lock_id IS NULL AND in_locked_by IS NULL AND in_object_name IS NULL THEN
            core.raise_error('ARGUMENTS_MISSING');
        END IF;
        --
        FOR c IN (
            SELECT
                t.object_type,
                t.object_name,
                t.lock_id
            FROM core_locks t
            WHERE 1 = 1
                AND (t.lock_id      = in_lock_id        OR in_lock_id       IS NULL)
                AND (t.locked_by    = in_locked_by      OR in_locked_by     IS NULL)
                AND (t.object_name  = in_object_name    OR in_object_name   IS NULL)
                AND (t.object_type  = in_object_type    OR in_object_type   IS NULL)
                AND (t.expire_at    >= SYSDATE)
            UNION ALL
            --
            SELECT
                t.object_type,
                t.object_name,
                MAX(t.lock_id) AS lock_id
            FROM core_locks t
            WHERE 1 = 1
                AND (t.lock_id      = in_lock_id        OR in_lock_id       IS NULL)
                AND (t.locked_by    = in_locked_by      OR in_locked_by     IS NULL)
                AND (t.object_name  = in_object_name    OR in_object_name   IS NULL)
                AND (t.object_type  = in_object_type    OR in_object_type   IS NULL)
            GROUP BY
                t.object_type,
                t.object_name
        ) LOOP
            UPDATE core_locks t
            SET t.expire_at     = NULL,
                t.object_hash   = ''
            WHERE t.lock_id     = c.lock_id;
            --
            IF SQL%ROWCOUNT > 0 THEN
                DBMS_OUTPUT.PUT_LINE(c.object_type || ' ' || c.object_name || ' UNLOCKED [' || c.lock_id || ']');
            END IF;
        END LOOP;
        --
        COMMIT;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        ROLLBACK;
        RAISE;
    WHEN OTHERS THEN
        ROLLBACK;
        core.raise_error();
    END;



    FUNCTION get_object
    RETURN CLOB
    AS
        v_sql_text      ora_name_list_t;    -- TABLE OF VARCHAR2(64);
        v_out           CLOB;
    BEGIN
        FOR i IN 1 .. ora_sql_txt(v_sql_text) LOOP
            v_out := v_out || TO_CLOB(RTRIM(v_sql_text(i)));
        END LOOP;
        --
        RETURN v_out;
    END;



    FUNCTION get_clob_hash (
        in_payload          CLOB,
        in_type             PLS_INTEGER := NULL
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN DBMS_CRYPTO.HASH(in_payload, NVL(in_type, DBMS_CRYPTO.HASH_SH256));
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
    END;

END;
/



