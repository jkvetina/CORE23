CREATE OR REPLACE PACKAGE BODY core_customized AS

    FUNCTION get_env
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN '';
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
            p_message       => in_message || '|' || in_arguments || '|' || in_payload || in_backtrace || in_callstack,
            p_max_length    => 32767,
            p_force         => TRUE
        );
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

