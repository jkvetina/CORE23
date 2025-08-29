CREATE OR REPLACE PACKAGE core_lock AS

    FUNCTION get_user
    RETURN core_locks.locked_by%TYPE;



    PROCEDURE create_lock (
        in_object_owner     core_locks.object_owner%TYPE,
        in_object_type      core_locks.object_type%TYPE,
        in_object_name      core_locks.object_name%TYPE,
        in_locked_by        core_locks.locked_by%TYPE       := NULL,
        in_expire_at        core_locks.expire_at%TYPE       := NULL
    );



    PROCEDURE extend_lock (
        in_lock_id          core_locks.lock_id%TYPE,
        in_time             NUMBER
    );



    PROCEDURE extend_lock (
        in_lock_id          core_locks.lock_id%TYPE,
        in_expire_at        core_locks.expire_at%TYPE       := NULL
    );



    PROCEDURE unlock (
        in_lock_id          core_locks.lock_id%TYPE         := NULL,
        in_locked_by        core_locks.locked_by%TYPE       := NULL,
        in_object_name      core_locks.object_name%TYPE     := NULL,
        in_object_type      core_locks.object_type%TYPE     := NULL,
        in_remove_hash      BOOLEAN                         := TRUE
    );



    FUNCTION get_object
    RETURN CLOB;

END;
/

