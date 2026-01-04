CREATE OR REPLACE PACKAGE core
AUTHID CURRENT_USER RESETTABLE
AS

    /**
     * This package is part of the CORE project under MIT licence.
     * https://github.com/jkvetina/CORE23
     *
     * Copyright (c) Jan Kvetina, 2023
     *
     *                                                      (R)
     *                      ---                  ---
     *                    #@@@@@@              &@@@@@@
     *                    @@@@@@@@     .@      @@@@@@@@
     *          -----      @@@@@@    @@@@@@,   @@@@@@@      -----
     *       &@@@@@@@@@@@    @@@   &@@@@@@@@@.  @@@@   .@@@@@@@@@@@#
     *           @@@@@@@@@@@   @  @@@@@@@@@@@@@  @   @@@@@@@@@@@
     *             \@@@@@@@@@@   @@@@@@@@@@@@@@@   @@@@@@@@@@
     *               @@@@@@@@@   @@@@@@@@@@@@@@@  &@@@@@@@@
     *                 @@@@@@@(  @@@@@@@@@@@@@@@  @@@@@@@@
     *                  @@@@@@(  @@@@@@@@@@@@@@,  @@@@@@@
     *                  .@@@@@,   @@@@@@@@@@@@@   @@@@@@
     *                   @@@@@@  *@@@@@@@@@@@@@   @@@@@@
     *                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@.
     *                    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@
     *                    @@@@@@@@@@@@@@@@@@@@@@@@@@@@
     *                     .@@@@@@@@@@@@@@@@@@@@@@@@@
     *                       .@@@@@@@@@@@@@@@@@@@@@
     *                            jankvetina.cz
     *                               -------
     *
     */

    -- package name holding constants, used as get_constant() default
    c_constants                 CONSTANT VARCHAR2(30)   := core_custom.master_constants;
    c_constants_owner           CONSTANT VARCHAR2(30)   := core_custom.master_owner;

    -- global items to hold application + page context
    c_context_name_app          CONSTANT VARCHAR2(30)   := core_custom.global_context_app;
    c_context_name_page         CONSTANT VARCHAR2(30)   := core_custom.global_context_page;
    c_master_id                 CONSTANT PLS_INTEGER    := core_custom.master_id;

    -- code for app exception
    app_exception_code          CONSTANT PLS_INTEGER    := core_custom.app_exception_code;
    assert_exception_code       CONSTANT PLS_INTEGER    := core_custom.assert_exception_code;

    -- some constants, used also in APEX app substitutions
    c_format_date               CONSTANT VARCHAR2(32)   := core_custom.format_date;
    c_format_date_time          CONSTANT VARCHAR2(32)   := core_custom.format_date_time;
    c_format_date_short         CONSTANT VARCHAR2(32)   := core_custom.format_date_short;
    --
    c_app_proxy                 CONSTANT VARCHAR2(128)  := core_custom.global_app_proxy;
    c_app_wallet                CONSTANT VARCHAR2(128)  := core_custom.global_app_wallet;
    --
    c_smtp_from                 CONSTANT VARCHAR2(128)  := core_custom.global_smtp_from;
    c_smtp_host                 CONSTANT VARCHAR2(128)  := core_custom.global_smtp_host;
    c_smtp_port                 CONSTANT NUMBER(8)      := core_custom.global_smtp_port;
    c_smtp_timeout              CONSTANT NUMBER(8)      := core_custom.global_smtp_timeout;
    c_smtp_username             CONSTANT VARCHAR2(128)  := core_custom.global_smtp_username;
    c_smtp_password             CONSTANT VARCHAR2(128)  := core_custom.global_smtp_password;

    -- for dynamic page items
    c_page_item_wild            CONSTANT VARCHAR2(2)    := '$';
    c_page_item_prefix          CONSTANT VARCHAR2(2)    := 'P';

    -- flags use in logging
    flag_error                  CONSTANT CHAR           := core_custom.flag_error;
    flag_warning                CONSTANT CHAR           := core_custom.flag_warning;
    flag_debug                  CONSTANT CHAR           := core_custom.flag_debug;
    flag_start                  CONSTANT CHAR           := core_custom.flag_start;
    flag_end                    CONSTANT CHAR           := core_custom.flag_end;

    -- start assert messages with these prefixes
    c_assert_message            CONSTANT VARCHAR2(30)   := core_custom.global_assert_message;
    c_constraint_prefix         CONSTANT VARCHAR2(30)   := core_custom.global_constraint_prefix;
    c_not_null_prefix           CONSTANT VARCHAR2(30)   := core_custom.global_not_null_prefix;



    --
    -- EXCEPTIONS
    --

    -- application exception used to propagate message to the user
    app_exception       EXCEPTION; PRAGMA EXCEPTION_INIT(app_exception, app_exception_code);

    -- define assert exception
    assert_exception    EXCEPTION; PRAGMA EXCEPTION_INIT(assert_exception, assert_exception_code);

    -- possible exception when parsing call stack
    bad_depth           EXCEPTION; PRAGMA EXCEPTION_INIT(bad_depth, -64610);



    --
    -- CUSTOM TYPES
    --

    -- for bulk set_item(s)
    TYPE type_page_items IS RECORD (
        column_name     VARCHAR2(30),
        item_name       VARCHAR2(64),
        item_value      VARCHAR2(2000)
    );
    --
    TYPE t_page_items IS TABLE OF type_page_items;





    FUNCTION get_id
    RETURN NUMBER;



    FUNCTION get_id (
        in_position1            NUMBER,
        in_position2            NUMBER := NULL,
        in_position3            NUMBER := NULL,
        in_position4            NUMBER := NULL,
        in_position5            NUMBER := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_token (
        in_size                 NUMBER := 6
    )
    RETURN VARCHAR2;



    FUNCTION get_yn (
        in_boolean              BOOLEAN
    )
    RETURN CHAR
    DETERMINISTIC;



    FUNCTION get_slug (
        in_name                 VARCHAR2,
        in_separator            VARCHAR2    := NULL,
        in_lowercase            BOOLEAN     := FALSE,
        in_envelope             BOOLEAN     := FALSE
    )
    RETURN VARCHAR2;



    FUNCTION get_context_app (
        in_context_name         VARCHAR2 := NULL
    )
    RETURN NUMBER;



    FUNCTION get_context_page (
        in_context_name         VARCHAR2 := NULL
    )
    RETURN NUMBER;



    PROCEDURE set_contexts (
        in_context_name_app     VARCHAR2 := NULL,
        in_context_name_page    VARCHAR2 := NULL
    );



    FUNCTION get_master_id
    RETURN NUMBER;



    FUNCTION get_app_id
    RETURN NUMBER;



    FUNCTION get_app_owner (
        in_app_id               NUMBER      := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_app_name (
        in_app_id               NUMBER      := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_app_workspace (
        in_app_id               NUMBER      := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_app_home_url (
        in_app_id               NUMBER,
        in_full                 CHAR        := NULL
    )
    RETURN VARCHAR2
    DETERMINISTIC;



    FUNCTION get_app_login_url (
        in_app_id               NUMBER,
        in_full                 CHAR        := NULL
    )
    RETURN VARCHAR2
    DETERMINISTIC;



    FUNCTION get_user_id
    RETURN VARCHAR2;



    FUNCTION get_user_lang
    RETURN VARCHAR2;



    FUNCTION get_tenant_id (
        in_user_id      VARCHAR2 := NULL
    )
    RETURN NUMBER;



    FUNCTION get_substitution (
        in_name                 VARCHAR2,
        in_app_id               NUMBER      := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_preference (
        in_name                 VARCHAR2
    )
    RETURN VARCHAR2;



    PROCEDURE set_preference (
        in_name                 VARCHAR2,
        in_value                VARCHAR2
    );



    FUNCTION get_app_setting (
        in_name                 VARCHAR2
    )
    RETURN VARCHAR2;



    PROCEDURE set_app_setting (
        in_name                 VARCHAR2,
        in_value                VARCHAR2
    );



    FUNCTION get_constant (
        in_name                 VARCHAR2,
        in_package              VARCHAR2        := NULL,
        in_owner                VARCHAR2        := NULL,
        in_private              CHAR            := NULL,    -- Y = package body
        in_prefix               VARCHAR2        := NULL,
        in_env                  VARCHAR2        := NULL,
        in_silent               BOOLEAN         := FALSE
    )
    RETURN VARCHAR2
    RESULT_CACHE;



    FUNCTION get_constant_num (
        in_name                 VARCHAR2,
        in_package              VARCHAR2        := NULL,
        in_owner                VARCHAR2        := NULL,
        in_private              CHAR            := NULL,    -- Y = package body
        in_prefix               VARCHAR2        := NULL,
        in_env                  VARCHAR2        := NULL,
        in_silent               BOOLEAN         := FALSE
    )
    RETURN NUMBER
    RESULT_CACHE;



    FUNCTION is_developer (
        in_user                 VARCHAR2        := NULL,
        in_deep_check           BOOLEAN         := FALSE
    )
    RETURN BOOLEAN;



    FUNCTION is_developer_y (
        in_user                 VARCHAR2        := NULL,
        in_deep_check           BOOLEAN         := FALSE
    )
    RETURN CHAR;



    FUNCTION is_authorized (
        in_auth_scheme          VARCHAR2
    )
    RETURN CHAR;



    FUNCTION get_debug_level (
        in_session_id           NUMBER      := NULL
    )
    RETURN NUMBER;



    FUNCTION get_debug
    RETURN BOOLEAN;



    PROCEDURE set_debug (
        in_level                NUMBER      := NULL,
        in_session_id           NUMBER      := NULL
    );



    PROCEDURE create_security_context (
        in_workspace            VARCHAR2    := NULL,
        in_app_id               NUMBER      := NULL
    );



    PROCEDURE create_session (
        in_user_id              VARCHAR2,
        in_app_id               NUMBER,
        in_page_id              NUMBER      := NULL,
        in_session_id           NUMBER      := NULL,
        in_workspace            VARCHAR2    := NULL,
        in_postauth             BOOLEAN     := FALSE
    );



    PROCEDURE attach_session (
        in_session_id           NUMBER,
        in_app_id               NUMBER,
        in_page_id              NUMBER      := NULL,
        in_workspace            VARCHAR2    := NULL,
        in_postauth             BOOLEAN     := FALSE
    );



    PROCEDURE exit_session;



    PROCEDURE print_items;



    PROCEDURE set_action (
        in_action_name          VARCHAR2,
        in_module_name          VARCHAR2        := NULL
    );



    FUNCTION get_session_id
    RETURN NUMBER;



    FUNCTION get_workspace
    RETURN VARCHAR2;



    FUNCTION get_client_id (
        in_user_id              VARCHAR2        := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_env
    RETURN VARCHAR2;



    FUNCTION get_page_id
    RETURN NUMBER;



    FUNCTION get_page_is_modal (
        in_page_id              NUMBER      := NULL,
        in_app_id               NUMBER      := NULL
    )
    RETURN CHAR;



    FUNCTION get_page_group (
        in_page_id              NUMBER      := NULL,
        in_app_id               NUMBER      := NULL
    )
    RETURN apex_application_pages.page_group%TYPE;



    FUNCTION get_page_name (
        in_page_id              NUMBER      := NULL,
        in_app_id               NUMBER      := NULL,
        in_name                 VARCHAR2    := NULL,
        in_replace              CHAR        := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_page_title (
        in_page_id              NUMBER      := NULL,
        in_app_id               NUMBER      := NULL,
        in_title                VARCHAR2    := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_page_url (
        in_page_id              NUMBER      := NULL,
        in_app_id               NUMBER      := NULL,
        in_names                VARCHAR2    := NULL,
        in_values               VARCHAR2    := NULL,
        in_overload             VARCHAR2    := NULL,    -- JSON object to overload passed items/values
        in_session_id           NUMBER      := NULL,
        in_reset                CHAR        := 'Y',     -- reset page items
        in_plain                CHAR        := 'Y'      -- remove JS
    )
    RETURN VARCHAR2;



    FUNCTION get_request_url (
        in_arguments_only       BOOLEAN                     := FALSE
    )
    RETURN VARCHAR2;



    FUNCTION get_request
    RETURN VARCHAR2;



    FUNCTION get_request (
        in_name                 VARCHAR2,
        in_escape               VARCHAR2    := '\'
    )
    RETURN BOOLEAN;



    FUNCTION get_icon (
        in_name                 VARCHAR2,
        in_title                VARCHAR2    := NULL,
        in_style                VARCHAR2    := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_grid_action
    RETURN VARCHAR2;



    FUNCTION get_grid_data (
        in_column_name          VARCHAR2
    )
    RETURN VARCHAR2;



    PROCEDURE set_grid_data (
        in_column_name          VARCHAR2,
        in_value                VARCHAR2
    );



    FUNCTION get_item_name (
        in_name                 apex_application_page_items.item_name%TYPE,
        in_page_id              apex_application_page_items.page_id%TYPE            := NULL,
        in_app_id               apex_application_page_items.application_id%TYPE     := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_item (
        in_name                 VARCHAR2
    )
    RETURN VARCHAR2;



    FUNCTION get_number_item (
        in_name                 VARCHAR2
    )
    RETURN NUMBER;



    FUNCTION get_date_item (
        in_name                 VARCHAR2,
        in_format               VARCHAR2        := NULL
    )
    RETURN DATE;



    FUNCTION get_date (
        in_value                VARCHAR2,
        in_format               VARCHAR2        := NULL
    )
    RETURN DATE;



    FUNCTION get_date (
        in_date                 DATE            := NULL,
        in_format               VARCHAR2        := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_date_time (
        in_date                 DATE            := NULL,
        in_format               VARCHAR2        := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_time_bucket (
        in_date                 DATE,
        in_interval             NUMBER
    )
    RETURN NUMBER
    DETERMINISTIC;



    FUNCTION get_duration (
        in_interval             INTERVAL DAY TO SECOND
    )
    RETURN VARCHAR2;



    FUNCTION get_duration (
        in_interval             NUMBER
    )
    RETURN VARCHAR2;



    FUNCTION get_duration (
        in_start                TIMESTAMP,
        in_end                  TIMESTAMP       := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_timer (
        in_timestamp            VARCHAR2
    )
    RETURN VARCHAR2;



    FUNCTION get_local_date (
        in_utc_timestamp        DATE,
        in_timezone             VARCHAR2
    )
    RETURN DATE
    DETERMINISTIC;



    FUNCTION get_utc_date (
        in_timestamp            DATE,
        in_timezone             VARCHAR2
    )
    RETURN DATE
    DETERMINISTIC;



    PROCEDURE set_item (
        in_name                 VARCHAR2,
        in_value                VARCHAR2        := NULL,
        in_if_exists            BOOLEAN         := FALSE,   -- set only if item exists
        in_throw                BOOLEAN         := FALSE    -- throw error if not found
    );



    PROCEDURE set_date_item (
        in_name                 VARCHAR2,
        in_value                DATE
    );



    PROCEDURE set_page_items (
        in_query                VARCHAR2,
        in_page_id              NUMBER          := NULL
    );



    FUNCTION set_page_items (
        in_query                VARCHAR2,
        in_page_id              NUMBER          := NULL
    )
    RETURN t_page_items PIPELINED;



    PROCEDURE set_page_items (
        in_cursor               SYS_REFCURSOR,
        in_page_id              NUMBER          := NULL
    );



    FUNCTION set_page_items (
        in_cursor               SYS_REFCURSOR,
        in_page_id              NUMBER          := NULL
    )
    RETURN t_page_items PIPELINED;



    FUNCTION set_page_items__ (
        io_cursor       IN OUT  PLS_INTEGER,
        in_page_id              NUMBER          := NULL
    )
    RETURN t_page_items;



    FUNCTION get_cursor_number (
        io_cursor       IN OUT  SYS_REFCURSOR
    )
    RETURN PLS_INTEGER;



    PROCEDURE close_cursor (
        io_cursor       IN OUT  PLS_INTEGER
    );



    PROCEDURE clear_items;



    FUNCTION get_page_items (
        in_page_id              NUMBER      := NULL,
        in_filter               VARCHAR2    := '%'
    )
    RETURN VARCHAR2;



    FUNCTION get_global_items (
        in_filter               VARCHAR2    := '%'
    )
    RETURN VARCHAR2;



    PROCEDURE apply_items (
        in_items                VARCHAR2
    );



    PROCEDURE create_job (
        in_job_name             VARCHAR2,
        in_statement            VARCHAR2,
        in_user_id              VARCHAR2        := NULL,
        in_app_id               NUMBER          := NULL,
        in_session_id           NUMBER          := NULL,
        in_priority             PLS_INTEGER     := NULL,
        in_schedule_name        VARCHAR2        := NULL,
        in_start_date           DATE            := NULL,
        in_enabled              BOOLEAN         := TRUE,
        in_autodrop             BOOLEAN         := TRUE,
        in_force_replace        BOOLEAN         := FALSE,
        in_context_id           NUMBER          := NULL,
        in_comments             VARCHAR2        := NULL,
        in_job_class            VARCHAR2        := NULL,
        in_job_type             VARCHAR2        := NULL
    );



    PROCEDURE stop_job (
        in_job_name             VARCHAR2,
        in_app_id               NUMBER      := NULL
    );



    PROCEDURE drop_job (
        in_job_name             VARCHAR2,
        in_app_id               NUMBER      := NULL
    );



    PROCEDURE run_job (
        in_job_name             VARCHAR2,
        in_app_id               NUMBER      := NULL
    );



    FUNCTION get_arguments (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_as_list              BOOLEAN     := FALSE
    )
    RETURN VARCHAR2;



    PROCEDURE raise_error (
        in_message              VARCHAR2    := NULL,            -- message for user, translatable
        --
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,            -- logger_log.parent_id
        in_payload              CLOB        := NULL,
        in_rollback             BOOLEAN     := FALSE,
        in_as_list              BOOLEAN     := FALSE,
        in_concat               BOOLEAN     := FALSE
    );



    FUNCTION log__ (
        in_type                 CHAR,
        in_message              VARCHAR2,
        in_arguments            VARCHAR2,
        in_payload              CLOB        := NULL,
        in_context_id           NUMBER      := NULL,
        in_caller               VARCHAR2    := NULL
    )
    RETURN NUMBER;



    FUNCTION log_error (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,            -- logger_log.parent_id
        in_payload              CLOB        := NULL
    )
    RETURN NUMBER;



    PROCEDURE log_error (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,            -- logger_log.parent_id
        in_payload              CLOB        := NULL
    );



    FUNCTION log_warning (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,            -- logger_log.parent_id
        in_payload              CLOB        := NULL
    )
    RETURN NUMBER;



    PROCEDURE log_warning (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,            -- logger_log.parent_id
        in_payload              CLOB        := NULL
    );



    FUNCTION log_debug (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,            -- logger_log.parent_id
        in_payload              CLOB        := NULL
    )
    RETURN NUMBER;



    PROCEDURE log_debug (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,            -- logger_log.parent_id
        in_payload              CLOB        := NULL
    );



    FUNCTION log_start (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,            -- logger_log.parent_id
        in_payload              CLOB        := NULL
    )
    RETURN NUMBER;



    PROCEDURE log_start (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,            -- logger_log.parent_id
        in_payload              CLOB        := NULL
    );



    FUNCTION log_end (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,            -- logger_log.parent_id
        in_payload              CLOB        := NULL
    )
    RETURN NUMBER;



    PROCEDURE log_end (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,            -- logger_log.parent_id
        in_payload              CLOB        := NULL
    );



    FUNCTION handle_apex_error (
        p_error                 APEX_ERROR.T_ERROR
    )
    RETURN APEX_ERROR.T_ERROR_RESULT;



    FUNCTION get_translated (
        in_message              VARCHAR2
    )
    RETURN VARCHAR2;



    PROCEDURE refresh_mviews (
        in_name_like            VARCHAR2        := NULL,
        in_percent              NUMBER          := NULL,
        in_method               CHAR            := NULL,
        in_parallelism          NUMBER          := NULL,
        in_atomic               BOOLEAN         := FALSE
    );



    PROCEDURE recalc_table_stats (
        in_owner            VARCHAR2,
        in_table_name       VARCHAR2,
        in_percent          NUMBER
    );



    PROCEDURE shrink_table (
        in_owner                VARCHAR2,
        in_table_name           VARCHAR2,
        in_drop_indexes         BOOLEAN := FALSE,
        in_row_movement         BOOLEAN := FALSE
    );



    FUNCTION get_caller_name (
        in_offset               PLS_INTEGER     := NULL,
        in_add_line             BOOLEAN         := FALSE
    )
    RETURN VARCHAR2;



    FUNCTION get_caller_line (
        in_offset               PLS_INTEGER     := NULL
    )
    RETURN NUMBER;



    FUNCTION get_hash (
        in_payload              VARCHAR2
    )
    RETURN VARCHAR2
    DETERMINISTIC;



    FUNCTION get_call_stack (
        in_offset               PLS_INTEGER     := NULL,
        in_skip_others          BOOLEAN         := FALSE,
        in_line_numbers         BOOLEAN         := TRUE,
        in_splitter             VARCHAR2        := CHR(10)
    )
    RETURN VARCHAR2;



    FUNCTION get_error_stack
    RETURN VARCHAR2;



    FUNCTION get_shorter_stack (
        in_stack                VARCHAR2
    )
    RETURN VARCHAR2;



    PROCEDURE send_push_notification (
        in_title                VARCHAR2,
        in_message              VARCHAR2,
        in_user_id              VARCHAR2    := NULL,
        in_app_id               NUMBER      := NULL,
        in_target_url           VARCHAR2    := NULL,
        in_icon_url             VARCHAR2    := NULL,
        in_asap                 BOOLEAN     := TRUE
    );



    PROCEDURE send_mail (
        in_to                   VARCHAR2,
        in_subject              VARCHAR2,
        in_body                 CLOB,
        in_cc                   VARCHAR2        := NULL,
        in_bcc                  VARCHAR2        := NULL,
        in_from                 VARCHAR2        := NULL,
        in_attach_name          VARCHAR2        := NULL,
        in_attach_mime          VARCHAR2        := NULL,
        in_attach_data          CLOB            := NULL,
        in_compress             BOOLEAN         := FALSE
    );



    FUNCTION send_request (
        in_url                  VARCHAR2,
        in_method               VARCHAR2    := NULL,
        in_content_type         VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL
    )
    RETURN VARCHAR2;



    FUNCTION clob_to_blob (
        in_clob CLOB
    )
    RETURN BLOB;



    PROCEDURE clob_append (
        io_clob             IN OUT NOCOPY   CLOB,
        in_content                          VARCHAR2
    );



    FUNCTION get_long_string (
        in_table_name           VARCHAR2,
        in_column_name          VARCHAR2,
        in_where_col1_name      VARCHAR2,
        in_where_val1           VARCHAR2,
        in_where_col2_name      VARCHAR2    := NULL,
        in_where_val2           VARCHAR2    := NULL,
        in_owner                VARCHAR2    := NULL
    )
    RETURN VARCHAR2;



    PROCEDURE download_file (
        in_file_name                        VARCHAR2,
        in_file_payload     IN OUT NOCOPY   BLOB
    );



    PROCEDURE redirect (
        in_page_id              NUMBER          := NULL,
        in_names                VARCHAR2        := NULL,
        in_values               VARCHAR2        := NULL,
        in_overload             VARCHAR2        := NULL,    -- JSON object to overload passed items/values
        in_transform            BOOLEAN         := FALSE,   -- to pass all page items to new page
        in_reset                CHAR            := NULL
    );



    PROCEDURE assert_true (
        in_error_message        VARCHAR2,
        in_bool_expression      BOOLEAN
    );



    PROCEDURE assert_false (
        in_error_message        VARCHAR2,
        in_bool_expression      BOOLEAN
    );



    PROCEDURE assert_not_null (
        in_error_message        VARCHAR2,
        in_value                VARCHAR2
    );



    PROCEDURE add_grid_filter (
        in_static_id            VARCHAR2,
        in_column_name          VARCHAR2,
        in_filter_value         VARCHAR2        := NULL,
        in_operator             VARCHAR2        := 'EQ',
        in_region_id            VARCHAR2        := NULL
    );



    FUNCTION get_view_source (
        in_view_name            VARCHAR2,
        in_owner                VARCHAR2    := NULL,
        in_trim                 CHAR        := NULL
    )
    RETURN VARCHAR2;



    FUNCTION search_clob (
        in_payload              CLOB,
        in_search_start         VARCHAR2,
        in_search_stop          VARCHAR2,
        in_occurence            PLS_INTEGER     := 1,
        in_overlap              PLS_INTEGER     := NULL,
        in_new_line             VARCHAR2        := NULL
    )
    RETURN VARCHAR2;



    FUNCTION search_clob_count (
        in_payload              CLOB,
        in_search_start         VARCHAR2,
        in_overlap              PLS_INTEGER     := NULL,
        in_new_line             VARCHAR2        := NULL
    )
    RETURN PLS_INTEGER;



    FUNCTION call_procedure (
        in_package_name         VARCHAR2,
        in_procedure_name       VARCHAR2,
        in_owner                VARCHAR2    := NULL,
        in_prefix               VARCHAR2    := NULL
    )
    RETURN BOOLEAN;



    PROCEDURE call_procedure (
        in_package_name         VARCHAR2,
        in_procedure_name       VARCHAR2,
        in_owner                VARCHAR2    := NULL,
        in_prefix               VARCHAR2    := NULL
    );



    PROCEDURE update_app_version (
        in_app_id           PLS_INTEGER     := NULL,
        in_version          VARCHAR2        := NULL,
        in_proceed          BOOLEAN         := TRUE,
        in_skip_main        BOOLEAN         := FALSE,
        in_keep_older       BOOLEAN         := FALSE
    );

END;
/

