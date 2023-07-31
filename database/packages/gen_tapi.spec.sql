CREATE OR REPLACE PACKAGE gen_tapi AS

    g_app_prefix                VARCHAR2(16)   := '';
    g_in_prefix                 VARCHAR2(16)   := 'in_';
    g_rec_prefix                VARCHAR2(16)   := 'rec.';
    g_minimal_space             PLS_INTEGER    := 5;
    g_tab_width                 PLS_INTEGER    := 4;



    FUNCTION get_width (
        in_table_name           VARCHAR2,
        in_prefix               VARCHAR2    := NULL
    )
    RETURN PLS_INTEGER;



    FUNCTION column_exists (
        in_table_name           VARCHAR2,
        in_column_name          VARCHAR2
    )
    RETURN BOOLEAN;



    FUNCTION table_where (
        in_table_name           VARCHAR2,
        in_where_prefix         VARCHAR2
    )
    RETURN VARCHAR2;



    PROCEDURE create_tapi (
        in_table_name           VARCHAR2,
        in_procedure_name       VARCHAR2,
        in_tapi_package         VARCHAR2,
        in_auth_package         VARCHAR2,
        in_app_prefix           VARCHAR2
    );



    FUNCTION get_table_name
    RETURN VARCHAR2;



    FUNCTION get_action (
        in_action               VARCHAR2        := NULL
    )
    RETURN CHAR;



    FUNCTION get_master_table (
        in_column_name          VARCHAR2
    )
    RETURN VARCHAR2;



    FUNCTION get_query (
        in_template             VARCHAR2,
        in_arg1                 VARCHAR2        := NULL,
        in_arg2                 VARCHAR2        := NULL,
        in_arg3                 VARCHAR2        := NULL,
        in_arg4                 VARCHAR2        := NULL,
        in_arg5                 VARCHAR2        := NULL,
        in_arg6                 VARCHAR2        := NULL,
        in_arg7                 VARCHAR2        := NULL,
        in_arg8                 VARCHAR2        := NULL
    )
    RETURN VARCHAR2;



    PROCEDURE rename_primary_key (
        in_column_name          VARCHAR2,
        in_old_key              VARCHAR2,
        in_new_key              VARCHAR2,
        in_merge                BOOLEAN         := TRUE
    );

END;
/

