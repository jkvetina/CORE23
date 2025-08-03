CREATE OR REPLACE PACKAGE core_jobs AS

    -- filter all objects
    g_owner_like            CONSTANT VARCHAR2(16)   := '%';
    --
    g_sender_dev            CONSTANT VARCHAR2(128)  := '';
    g_sender_uat            CONSTANT VARCHAR2(128)  := '';
    g_sender_prod           CONSTANT VARCHAR2(128)  := '';

    -- receivers for daily emails
    g_developers            CONSTANT VARCHAR2(128)  := '%@%';
    g_copyright             CONSTANT VARCHAR2(128)  := '';

    -- main application to create APEX session
    g_app_id                CONSTANT PLS_INTEGER    := 800;

    -- list of apps to scan (to ignore working copies, clones and test apps)
    g_apps apex_t_varchar2 := apex_t_varchar2(
        800
    );



    PROCEDURE job_scan_apps;



    FUNCTION get_sender (
        in_env              VARCHAR2 := NULL
    )
    RETURN VARCHAR2;



    PROCEDURE send_daily (
        in_recipient        VARCHAR2 := NULL
    );



    FUNCTION get_content (
        io_cursor           IN OUT SYS_REFCURSOR,
        in_header           VARCHAR2 := NULL
    )
    RETURN CLOB;



    PROCEDURE close_cursor (
        io_cursor       IN OUT PLS_INTEGER
    );



    FUNCTION get_html_header (
        in_title        VARCHAR2
    )
    RETURN CLOB;



    FUNCTION get_html_footer
    RETURN CLOB;

END;
/

