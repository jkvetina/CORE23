CREATE OR REPLACE PACKAGE core_jobs AS

    PROCEDURE job_scan_apps (
        in_app_id           PLS_INTEGER     := NULL,
        in_right_away       BOOLEAN         := FALSE
    );



    PROCEDURE job_daily_developers;



    PROCEDURE send_daily (
        in_recipients       VARCHAR2        := NULL,
        in_offset           PLS_INTEGER     := NULL,
        in_skip_scan        BOOLEAN         := FALSE
    );



    PROCEDURE send_performance (
        in_recipients       VARCHAR2        := NULL,
        in_offset           PLS_INTEGER     := NULL
    );



    PROCEDURE send_mail (
        in_recipients       VARCHAR2,
        in_subject          VARCHAR2,
        in_payload          CLOB
    );



    FUNCTION get_column_name (
        in_name             VARCHAR2
    )
    RETURN VARCHAR2;



    FUNCTION get_subject (
        in_header           VARCHAR2,
        in_date             DATE := NULL
    )
    RETURN VARCHAR2;



    FUNCTION get_content (
        io_cursor           IN OUT SYS_REFCURSOR,
        --
        in_header2          VARCHAR2        := NULL,
        in_header3          VARCHAR2        := NULL
    )
    RETURN CLOB;



    PROCEDURE close_cursor (
        io_cursor           IN OUT PLS_INTEGER
    );



    FUNCTION get_html_header (
        in_title            VARCHAR2
    )
    RETURN CLOB;



    FUNCTION get_html_footer
    RETURN CLOB;

END;
/

