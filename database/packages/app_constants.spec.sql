CREATE OR REPLACE PACKAGE app_constants AS

    --
    shared_objects_prefix       CONSTANT VARCHAR2(30)   := '';

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
    global_app_user_name        CONSTANT VARCHAR2(30)   := 'APP_USER_NAME';
    global_app_user_first_name  CONSTANT VARCHAR2(30)   := 'APP_USER_FIRST_NAME';
    global_app_user_email       CONSTANT VARCHAR2(30)   := 'APP_USER_EMAIL';
    global_app_user_roles       CONSTANT VARCHAR2(30)   := 'APP_USER_ROLES';
    --
    global_context_app          CONSTANT VARCHAR2(30)   := 'CONTEXT_APP';
    global_context_page         CONSTANT VARCHAR2(30)   := 'CONTEXT_PAGE';
    --
    global_workspace            CONSTANT VARCHAR2(30)   := 'WORKSPACE';
    global_env                  CONSTANT VARCHAR2(30)   := 'ENV';
    global_page_name            CONSTANT VARCHAR2(30)   := 'PAGE_NAME';
    --
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

END;
/

