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
            APEX_APPLICATION.G_USER,
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
        in_type                 CHAR,
        in_message              VARCHAR2,
        in_arguments            VARCHAR2,
        in_payload              CLOB        := NULL,
        in_context_id           NUMBER      := NULL,
        --
        in_app_id               NUMBER      := NULL,
        in_page_id              NUMBER      := NULL,
        in_user_id              VARCHAR2    := NULL,
        in_session_id           NUMBER      := NULL,
        --
        in_caller               VARCHAR2    := NULL,
        in_backtrace            VARCHAR2    := NULL,
        in_callstack            VARCHAR2    := NULL
    )
    RETURN NUMBER
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --
        v_message       VARCHAR2(32767);
    BEGIN
        -- enable debug for non APEX sessions
        IF (
            NVL(SYS_CONTEXT('USERENV', 'CLIENT_INFO'), '?') != SYS_CONTEXT('APEX$SESSION', 'WORKSPACE_ID') || ':' || SYS_CONTEXT('APEX$SESSION', 'APP_USER') OR
            NVL(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), '?') != SYS_CONTEXT('APEX$SESSION', 'APP_USER') || ':' || SYS_CONTEXT('APEX$SESSION', 'APP_SESSION')
        ) THEN
            IF NULLIF(core.get_page_id(), 0) IS NULL AND core.get_page_id() NOT IN (9999) THEN
                APEX_DEBUG.ENABLE(p_level => core_custom.default_debug_level);
            END IF;
        END IF;

        -- prepare message
        v_message := CASE
            WHEN in_type IN (core.flag_error, core.flag_warning)
                THEN ''
                    || CASE in_type
                        WHEN core.flag_error    THEN '[ERROR] '
                        WHEN core.flag_warning  THEN '[WARN] '
                        END
                    || in_message
                    || CASE WHEN in_arguments IS NOT NULL THEN CHR(10) || '^ARGS: '         || in_arguments END
                    || CASE WHEN in_backtrace IS NOT NULL THEN CHR(10) || '^BACKTRACE: '    || in_backtrace END
                --
            ELSE ''
                || CASE in_type
                    WHEN core.flag_start    THEN '[START] '
                    WHEN core.flag_end      THEN '[END] '
                    ELSE '[DEBUG] '
                    END
                || in_message
                || CASE WHEN in_arguments IS NOT NULL THEN CHR(10) || '^ARGS: '         || in_arguments END
            END;

        -- actually log the message into apex_debug_messages view
        CASE in_type
            WHEN core.flag_error THEN
                APEX_DEBUG.ERROR (
                    p_message       => v_message,
                    p_max_length    => 32767
                );
                --
            WHEN core.flag_warning THEN
                --APEX_DEBUG.WARN (
                APEX_DEBUG.MESSAGE (
                    p_message       => v_message,
                    p_level         => 2,
                    p_max_length    => 32767,
                    p_force         => TRUE
                );
                --
            ELSE
                APEX_DEBUG.MESSAGE (
                    p_message       => v_message,
                    p_max_length    => 32767,
                    p_level         => CASE in_type
                                            WHEN core.flag_start    THEN 4
                                            WHEN core.flag_end      THEN 4
                                            ELSE 6
                                            END,
                                            -- 1 = c_log_level_error            critical error
                                            -- 2 = c_log_level_warn             less critical error
                                            -- 4 = c_log_level_info constant    default level if debugging is enabled (for example, used by apex_application.debug)
                                            -- 5 = c_log_level_app_enter        application: messages when procedures/functions are entered
                                            -- 6 = c_log_level_app_trace        application: other messages within procedures/functions
                                            -- 8 = c_log_level_engine_enter     APEX engine: messages when procedures/functions are entered
                                            -- 9 = c_log_level_engine_trace     APEX engine: other messages within procedures/functions
                    p_force         => TRUE
                );
            END CASE;

            -- show payload
            IF in_payload IS NOT NULL THEN
                APEX_DEBUG.MESSAGE (
                    p_message       => '[PAYLOAD] ' || DBMS_LOB.SUBSTR(in_payload, 32000),
                    p_max_length    => 32767,
                    p_level         => 6,
                    p_force         => TRUE
                );
            END IF;

            -- you can use Logger or anything you want instead
            /*
            logger.log (
                p_text    => v_message,
                p_scope   => ''
                p_extra   => in_payload
            );
            */

        -- also show in console
        DBMS_OUTPUT.PUT_LINE(v_message);

        -- finish transaction
        COMMIT;
        --
        RETURN APEX_DEBUG.GET_LAST_MESSAGE_ID();
        --
    EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END;



    PROCEDURE custom_log (
        in_flag                 core_logs.flag%TYPE,
        in_action_name          core_logs.action_name%TYPE,
        in_module_name          core_logs.module_name%TYPE  := NULL,
        in_module_line          core_logs.module_line%TYPE  := NULL,
        in_arguments            core_logs.arguments%TYPE    := NULL,
        in_payload              core_logs.payload%TYPE      := NULL,
        in_debug_id             core_logs.debug_id%TYPE     := NULL,
        in_parent               core_logs.log_parent%TYPE   := NULL
    )
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO core_logs (
            --log_id,
            log_parent,
            app_id,
            page_id,
            user_id,
            flag,
            --
            action_name,
            module_name,
            module_line,
            arguments,
            payload,
            --
            debug_id,
            session_id,
            created_at
        )
        VALUES (
            --NULL,--core_log_id.NEXTVAL,
            in_parent,
            core.get_app_id(),
            core.get_page_id(),
            core.get_user_id(),
            in_flag,
            --
            in_action_name,
            in_module_name,
            in_module_line,
            in_arguments,
            in_payload,
            --
            in_debug_id,
            core.get_session_id(),
            SYSDATE
        );
        --
        COMMIT;
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
