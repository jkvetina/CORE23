CREATE OR REPLACE TRIGGER core_prevent_create_wrong_objects
BEFORE CREATE ON SCHEMA
DECLARE
BEGIN
    -- prevent creating non CORE objects
    IF ORA_SYSEVENT = 'CREATE' AND ORA_DICT_OBJ_NAME NOT LIKE 'CORE%' THEN
        RAISE_APPLICATION_ERROR(-20000, 'Only the "CORE" objects are allowed!');
    END IF;
END;
/

