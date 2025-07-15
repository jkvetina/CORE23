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
        -- prepare message
        v_message := CASE
            WHEN in_type IN (core.flag_error, core.flag_warning)
                THEN in_message
                    || CASE WHEN in_arguments IS NOT NULL THEN CHR(10) || '^ARGS: '         || in_arguments END
                    || CASE WHEN in_backtrace IS NOT NULL THEN CHR(10) || '^BACKTRACE: '    || in_backtrace END
                --
            ELSE
                in_message
                    || CASE in_type
                        WHEN core.flag_start    THEN ' [START] '
                        WHEN core.flag_end      THEN ' [END] '
                        END
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

            IF in_payload IS NOT NULL THEN
                APEX_DEBUG.MESSAGE (
                    p_message       => 'PAYLOAD: ' || DBMS_LOB.SUBSTR(in_payload, 32000),
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

END;
/

