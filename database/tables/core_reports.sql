CREATE TABLE IF NOT EXISTS core_reports (
    view_name                       VARCHAR2(64)          NOT NULL,
    report_name                     VARCHAR2(256)         NOT NULL,
    group_name                      VARCHAR2(256),
    sort#                           NUMBER(4,0),
    --
    CONSTRAINT core_reports_pk
        PRIMARY KEY (view_name)
);
--
COMMENT ON TABLE core_reports IS '';
--
COMMENT ON COLUMN core_reports.view_name        IS '';
COMMENT ON COLUMN core_reports.report_name      IS '';
COMMENT ON COLUMN core_reports.group_name       IS '';
COMMENT ON COLUMN core_reports.sort#            IS '';

