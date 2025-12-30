CREATE OR REPLACE PACKAGE BODY core_custom AS

    FUNCTION get_env
    RETURN VARCHAR2
    AS
    BEGIN
        -- extract env name (cloud edition)
        RETURN REPLACE (
            REGEXP_REPLACE(SYS_CONTEXT('USERENV', 'DB_NAME'), '^[^_]*_', ''),
            env_name_strip, '');
    END;



    FUNCTION get_user_id
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN COALESCE (
            core.get_item('G_USER_ID'),
            SYS_CONTEXT('APEX$SESSION', 'APP_USER'),
            SYS_CONTEXT('USERENV', 'PROXY_USER'),
            SYS_CONTEXT('USERENV', 'SESSION_USER'),
            USER
        );
    END;



    FUNCTION get_tenant_id (
        in_user_id      VARCHAR2 := NULL
    )
    RETURN NUMBER
    AS
    BEGIN
        RETURN TO_NUMBER(COALESCE (
            core.get_item('G_TENANT_ID'),
            SYS_CONTEXT('APEX$SESSION', 'APP_TENANT_ID')
        ));
    END;



    FUNCTION get_sender (
        in_env              VARCHAR2 := NULL
    )
    RETURN VARCHAR2
    AS
        v_sender apex_applications.email_from%TYPE;
    BEGIN
        v_sender := COALESCE(
            core.get_constant (
                in_name     => 'G_SENDER_' || COALESCE(in_env, core_custom.get_env()),
                in_package  => 'CORE_CUSTOM',
                in_owner    => core_custom.master_owner,
                in_silent   => TRUE
            ),
            core_custom.g_sender
        );
        --
        IF v_sender IS NULL THEN
            SELECT MAX(a.email_from)
            INTO v_sender
            FROM apex_applications a
            WHERE a.application_id = core.get_app_id();
        END IF;
        --
        IF v_sender IS NULL THEN
            core.raise_error('NO_MAIL_SENDER_DEFINED');
        END IF;
        --
        RETURN v_sender;
    END;



    FUNCTION log__ (
        in_type             CHAR,
        in_message          VARCHAR2,
        in_arguments        VARCHAR2    := NULL,
        in_payload          CLOB        := NULL,
        in_context_id       NUMBER      := NULL,
        --
        in_app_id           NUMBER      := NULL,
        in_page_id          NUMBER      := NULL,
        in_user_id          VARCHAR2    := NULL,
        in_session_id       NUMBER      := NULL,
        --
        in_caller           VARCHAR2    := NULL,
        in_backtrace        VARCHAR2    := NULL,
        in_callstack        VARCHAR2    := NULL
    )
    RETURN NUMBER
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --
        rec                 core_logs%ROWTYPE;
    BEGIN
        rec.log_id          := core_log_id.NEXTVAL;
        rec.log_parent      := in_context_id;
        rec.app_id          := COALESCE(in_app_id,  core.get_app_id(),  0);
        rec.page_id         := COALESCE(in_page_id, core.get_page_id(), 0);
        rec.user_id         := COALESCE(in_user_id, core.get_user_id(), USER);
        rec.session_id      := COALESCE(in_session_id, core.get_session_id());
        rec.flag            := in_type;
        rec.caller          := in_caller;
        rec.message         := in_message;
        rec.arguments       := in_arguments;
        rec.payload         := in_payload;
        rec.backtrace       := in_backtrace;
        rec.callstack       := in_callstack;
        rec.created_at      := SYSDATE;
        --
        INSERT INTO core_logs
        VALUES rec;

        -- finish transaction
        COMMIT;
        --
        RETURN rec.log_id;
        --
    EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END;

END;
/


exec recompile;

alter trigger CORE_LOCKSMITH disable;
alter trigger CORE_LOCKSMITH enable;
