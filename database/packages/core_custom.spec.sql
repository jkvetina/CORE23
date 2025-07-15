CREATE OR REPLACE PACKAGE core_custom
AUTHID CURRENT_USER
AS

    --
    -- CONSTANTS SHARED IN BETWEEN ALL APPS, WHICH YOU SET JUST ONCE
    --

    -- global prefix for database objects
    global_prefix               CONSTANT VARCHAR2(30)   := '';

    -- remove string from env name
    env_name_strip              CONSTANT VARCHAR2(30)   := '';

    -- id for the Master application
    master_id                   CONSTANT PLS_INTEGER    := 800;

    -- package name holding constants, used as get_constant() default
    master_owner                CONSTANT VARCHAR2(30)   := 'MASTER';
    master_constants            CONSTANT VARCHAR2(30)   := 'CORE_CUSTOM';

    -- specify special pages
    page_id_help                CONSTANT PLS_INTEGER    := 980;
    page_id_login               CONSTANT PLS_INTEGER    := 9999;

    -- code for app exception
    app_exception_code          CONSTANT PLS_INTEGER    := -20990;
    assert_exception_code       CONSTANT PLS_INTEGER    := -20992;

    -- flags use in logging
    flag_error                  CONSTANT CHAR           := 'E';     -- error
    flag_warning                CONSTANT CHAR           := 'W';     -- warning
    flag_debug                  CONSTANT CHAR           := 'D';     -- debug
    flag_start                  CONSTANT CHAR           := 'S';     -- start of any module (procedure/function)
    flag_end                    CONSTANT CHAR           := 'F';     -- end of the module (with timer)

    -- start assert messages with these prefixes
    global_assert_message       CONSTANT VARCHAR2(30)   := 'ASSERT_FAILED|';
    global_constraint_prefix    CONSTANT VARCHAR2(30)   := 'CONSTRAINT_ERROR|';
    global_not_null_prefix      CONSTANT VARCHAR2(30)   := 'NOT_NULL|';

    -- formats used by your packages and app substitutions
    format_date                 CONSTANT VARCHAR2(32)   := 'YYYY-MM-DD';
    format_date_time            CONSTANT VARCHAR2(32)   := 'YYYY-MM-DD HH24:MI:SS';
    format_date_short           CONSTANT VARCHAR2(32)   := 'YYYY-MM-DD HH24:MI';
    format_time                 CONSTANT VARCHAR2(32)   := 'HH24:MI:SS';
    format_time_short           CONSTANT VARCHAR2(32)   := 'HH24:MI';
    format_number               CONSTANT VARCHAR2(32)   := 'FM999G999G999G999G999G990D00';
    format_number_currency      CONSTANT VARCHAR2(32)   := 'FML999G999G999G999G999G990D00';
    format_integer              CONSTANT VARCHAR2(32)   := 'FM999G999G999G999G999G990';
    format_integer_currency     CONSTANT VARCHAR2(32)   := 'FML999G999G999G999G999G990';

    -- global item names
    global_context_app          CONSTANT VARCHAR2(30)   := 'CONTEXT_APP';
    global_context_page         CONSTANT VARCHAR2(30)   := 'CONTEXT_PAGE';
    global_workspace            CONSTANT VARCHAR2(30)   := 'WORKSPACE';
    global_env                  CONSTANT VARCHAR2(30)   := 'ENV';
    global_page_name            CONSTANT VARCHAR2(30)   := 'PAGE_NAME';
    global_formats              CONSTANT VARCHAR2(30)   := 'FORMAT_';

    -- for old school http requests
    global_app_proxy            CONSTANT VARCHAR2(128)  := '';
    global_app_wallet           CONSTANT VARCHAR2(128)  := '';

    -- for old school sending emails
    global_smtp_from            CONSTANT VARCHAR2(128)  := '';
    global_smtp_host            CONSTANT VARCHAR2(128)  := '';
    global_smtp_port            CONSTANT NUMBER(8)      := NULL;
    global_smtp_timeout         CONSTANT NUMBER(8)      := NULL;
    global_smtp_username        CONSTANT VARCHAR2(128)  := '';
    global_smtp_password        CONSTANT VARCHAR2(128)  := '';



    --
    -- YOUR CUSTOMIZATIONS FOR SOME CORE FUNCTIONS
    --

    FUNCTION get_env
    RETURN VARCHAR2;



    FUNCTION get_user_id
    RETURN VARCHAR2;



    FUNCTION get_tenant_id (
        in_user_id      VARCHAR2 := NULL
    )
    RETURN NUMBER;



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
    RETURN NUMBER;

END;
/

