CREATE OR REPLACE PACKAGE BODY core_custom AS

    FUNCTION get_env
    RETURN VARCHAR2
    AS
    BEGIN
        -- extract env name (cloud edition)
        RETURN REGEXP_REPLACE(SYS_CONTEXT('USERENV', 'DB_NAME'), '^[^_]*_', '');
    END;



    PROCEDURE log_error (
        in_message          VARCHAR2,
        in_arguments        VARCHAR2,
        in_payload          VARCHAR2,
        in_backtrace        VARCHAR2,
        in_callstack        VARCHAR2
    )
    AS
    BEGIN
        APEX_DEBUG.ERROR (
            p_message       => in_message || '|' || in_arguments || '|' || in_payload || in_backtrace || in_callstack,
            p_max_length    => 32767
        );
    END;



    PROCEDURE log_warning (
        in_message          VARCHAR2,
        in_arguments        VARCHAR2,
        in_payload          VARCHAR2,
        in_backtrace        VARCHAR2,
        in_callstack        VARCHAR2
    )
    AS
    BEGIN
        --APEX_DEBUG.WARN (
        APEX_DEBUG.MESSAGE (
            p_message       => in_message || '|' || in_arguments || '|' || in_payload || in_backtrace || in_callstack,
            p_max_length    => 32767,
            p_force         => TRUE
        );
    END;



    PROCEDURE log_debug (
        in_message          VARCHAR2,
        in_arguments        VARCHAR2,
        in_payload          VARCHAR2,
        in_backtrace        VARCHAR2,
        in_callstack        VARCHAR2
    )
    AS
    BEGIN
        APEX_DEBUG.MESSAGE (
            p_message       => in_message || '|' || in_arguments || '|' || in_payload,
            p_max_length    => 32767,
            p_force         => TRUE
        );
        /*
        logger.log (
            p_text    => in_message || ' LEN:' || LENGTH(in_payload),
            p_scope   => '',
            p_extra   => in_payload
            --p_params  in tab_param default logger.gc_empty_tab_param);
        );
        */
    END;



    PROCEDURE log_module (
        in_message          VARCHAR2,
        in_arguments        VARCHAR2,
        in_payload          VARCHAR2,
        in_backtrace        VARCHAR2,
        in_callstack        VARCHAR2
    )
    AS
    BEGIN
        APEX_DEBUG.MESSAGE (
            p_message       => in_message || '|' || in_arguments || '|' || in_payload || in_backtrace || in_callstack,
            p_max_length    => 32767,
            p_force         => TRUE
        );
    END;

END;
/

