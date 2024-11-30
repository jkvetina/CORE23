CREATE OR REPLACE PACKAGE core_customized AS

    FUNCTION get_env
    RETURN VARCHAR2;



    --
    -- There are several logging functions/procedures in the CORE package,
    --
    -- core.log_error       -- for errors, obviously
    -- core.log_warning     -- for warnings
    -- core.log_debug       -- for less important messages
    -- core.log_request     -- for url parameters
    -- core.log_module      -- to mark start of a procedure/function
    -- core.log_success     -- to mark successful end of the module
    --
    -- the default destination was the APEX_DEBUG_MESSAGES, so this package
    -- will allow you to switch to Logger or your own logging thingy...
    --

    PROCEDURE log_error (
        in_message          VARCHAR2,
        in_arguments        VARCHAR2,
        in_payload          VARCHAR2,
        in_backtrace        VARCHAR2,
        in_callstack        VARCHAR2
    );



    PROCEDURE log_warning (
        in_message          VARCHAR2,
        in_arguments        VARCHAR2,
        in_payload          VARCHAR2,
        in_backtrace        VARCHAR2,
        in_callstack        VARCHAR2
    );



    PROCEDURE log_debug (
        in_message          VARCHAR2,
        in_arguments        VARCHAR2,
        in_payload          VARCHAR2,
        in_backtrace        VARCHAR2,
        in_callstack        VARCHAR2
    );



    PROCEDURE log_module (
        in_message          VARCHAR2,
        in_arguments        VARCHAR2,
        in_payload          VARCHAR2,
        in_backtrace        VARCHAR2,
        in_callstack        VARCHAR2
    );

END;
/

