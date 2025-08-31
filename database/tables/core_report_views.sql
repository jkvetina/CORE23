CREATE TABLE IF NOT EXISTS core_report_views (
    view_name                       VARCHAR2(64)          NOT NULL,
    report_name                     VARCHAR2(256)         NOT NULL,
    group_name                      VARCHAR2(256),
    sort#                           NUMBER(4,0),
    --
    CONSTRAINT core_report_views_pk
        PRIMARY KEY (view_name)
);
--
COMMENT ON TABLE core_report_views IS '';
--
COMMENT ON COLUMN core_report_views.view_name       IS '';
COMMENT ON COLUMN core_report_views.report_name     IS '';
COMMENT ON COLUMN core_report_views.group_name      IS '';
COMMENT ON COLUMN core_report_views.sort#           IS '';

