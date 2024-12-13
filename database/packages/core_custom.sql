CREATE OR REPLACE PACKAGE BODY core_custom AS

    FUNCTION get_env
    RETURN VARCHAR2
    AS
    BEGIN
        -- extract env name (cloud edition)
        RETURN REPLACE(
            REGEXP_REPLACE(SYS_CONTEXT('USERENV', 'DB_NAME'), '^[^_]*_', ''),
            'DYR', '');
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
        v_level     PLS_INTEGER;
        v_flag      VARCHAR2(16);
    BEGIN
        CASE in_type
            WHEN core.flag_error THEN
                APEX_DEBUG.ERROR (
                    p_message       => in_message
                                        || CASE WHEN in_arguments IS NOT NULL THEN CHR(10) || '^ARGS: '         || in_arguments END
                                        || CASE WHEN in_backtrace IS NOT NULL THEN CHR(10) || '^BACKTRACE: '    || in_backtrace END,
                    p_max_length    => 32767
                );
                --
            WHEN core.flag_warning THEN
                --APEX_DEBUG.WARN (
                APEX_DEBUG.MESSAGE (
                    p_message       => in_message
                                        || CASE WHEN in_arguments IS NOT NULL THEN CHR(10) || '^ARGS: '         || in_arguments END,
                    p_level         => 2,
                    p_max_length    => 32767,
                    p_force         => TRUE
                );
            ELSE
                -- prepare proper flags
                CASE in_type
                    WHEN core.flag_start THEN
                        v_level := 4;
                        v_flag  := ' [START] ';
                    WHEN core.flag_end THEN
                        v_level := 4;
                        v_flag  := ' [END] ';
                    ELSE
                        v_level := 6;
                        v_flag  := '';
                    END CASE;
                --
                APEX_DEBUG.MESSAGE (
                    p_message       => in_message || v_flag
                                        || CASE WHEN in_arguments IS NOT NULL THEN CHR(10) || '^ARGS: '         || in_arguments END,
                    p_max_length    => 32767,
                    p_level         => v_level,
                                    -- 1 = c_log_level_error            critical error
                                    -- 2 = c_log_level_warn             less critical error
                                    -- 4 = c_log_level_info constant    default level if debugging is enabled (for example, used by apex_application.debug)
                                    -- 5 = c_log_level_app_enter        application: messages when procedures/functions are entered
                                    -- 6 = c_log_level_app_trace        application: other messages within procedures/functions
                                    -- 8 = c_log_level_engine_enter     APEX engine: messages when procedures/functions are entered
                                    -- 9 = c_log_level_engine_trace     APEX engine: other messages within procedures/functions
                    p_force         => TRUE
                );
                --
                logger.log (
                    p_text    => in_message
                                        || CASE WHEN in_arguments IS NOT NULL THEN CHR(10) || '^ARGS: '         || in_arguments END,
                    p_scope   => ''
                    --p_extra   => in_payload
                    --p_params  in tab_param default logger.gc_empty_tab_param
                );
            END CASE;
        --
        COMMIT;
        --
        RETURN APEX_DEBUG.GET_LAST_MESSAGE_ID();
    EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
    END;

END;
/

