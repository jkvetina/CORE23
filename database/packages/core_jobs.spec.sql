CREATE OR REPLACE PACKAGE core_jobs AS

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

