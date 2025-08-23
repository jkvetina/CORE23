CREATE OR REPLACE PACKAGE core_gen AUTHID CURRENT_USER AS

    PROCEDURE create_tapi (
        in_table_name           VARCHAR2,
        in_procedure_name       VARCHAR2,
        in_grid                 BOOLEAN := TRUE,
        in_form                 BOOLEAN := FALSE
    );



    FUNCTION get_width (
        in_table_name           VARCHAR2,
        in_prefix               VARCHAR2    := NULL
    )
    RETURN PLS_INTEGER
    ACCESSIBLE BY (core_gen);



    FUNCTION column_exists (
        in_table_name           VARCHAR2,
        in_column_name          VARCHAR2
    )
    RETURN BOOLEAN
    ACCESSIBLE BY (core_gen);



    PROCEDURE table_where (
        in_table_name           VARCHAR2,
        in_prepend              VARCHAR2,
        in_offset               PLS_INTEGER := 0
    )
    ACCESSIBLE BY (core_gen);

END;
/

