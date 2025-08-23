CREATE OR REPLACE PACKAGE BODY core_lock AS

    g_lock_length       CONSTANT NUMBER := 20/1440;



    PROCEDURE create_lock (
        in_object_owner     core_locks.object_owner%TYPE,
        in_object_type      core_locks.object_type%TYPE,
        in_object_name      core_locks.object_name%TYPE,
        in_locked_by        core_locks.locked_by%TYPE,
        in_expire_at        core_locks.expire_at%TYPE       := NULL
    )
    AS
    BEGIN
        INSERT INTO core_locks (
            object_owner,
            object_type,
            object_name,
            locked_by,
            locked_at,
            expire_at
        )
        VALUES (
            in_object_owner,
            in_object_type,
            in_object_name,
            in_locked_by,
            SYSDATE,
            NVL(in_expire_at, SYSDATE + g_lock_length)
        );
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
        SET t.expire_at     = SYSDATE + NVL(in_time, g_lock_length)
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
        SET t.expire_at     = NVL(in_expire_at, SYSDATE + g_lock_length)
        WHERE t.lock_id     = in_lock_id;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE unlock (
        in_lock_id          core_locks.lock_id%TYPE
    )
    AS
    BEGIN
        UPDATE core_locks t
        SET t.expire_at     = NULL
        WHERE t.lock_id     = in_lock_id;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;

END;
/

