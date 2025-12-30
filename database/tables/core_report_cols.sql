CREATE TABLE IF NOT EXISTS core_report_cols (
    view_name                       VARCHAR2(64)          CONSTRAINT core_report_cols_nn_view_name NOT NULL,
    column_name                     VARCHAR2(64)          CONSTRAINT core_report_cols_nn_column_name NOT NULL,
    report_name                     VARCHAR2(256)         CONSTRAINT core_report_cols_nn_report_name NOT NULL,
    --
    CONSTRAINT core_report_cols_pk
        PRIMARY KEY (
            view_name,
            column_name
        ),
    --
    CONSTRAINT core_report_cols_fk_view_name
        FOREIGN KEY (view_name)
        REFERENCES core_report_views (view_name)
);
--
COMMENT ON TABLE core_report_cols IS '';
--
COMMENT ON COLUMN core_report_cols.view_name        IS '';
COMMENT ON COLUMN core_report_cols.column_name      IS '';
COMMENT ON COLUMN core_report_cols.report_name      IS '';

