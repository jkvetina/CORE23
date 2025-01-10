--
-- PACKAGE ................ 3
-- PACKAGE BODY ........... 3
-- PROCEDURE .............. 1
-- TRIGGER ................ 1
--

--
-- INIT
--

--
-- OBJECTS
--
@"./procedures/recompile.sql";
@"./packages/core_custom.spec.sql";
@"./packages/core.spec.sql";
@"./packages/core_tapi.spec.sql";
@"./packages/core.sql";
@"./packages/core_custom.sql";
@"./packages/core_tapi.sql";

--
-- TRIGGERS
--
@"./triggers/core_prevent_create_wrong_objects.sql";

--
-- GRANTS
--
@"./grants/XXNBL_MASTER.sql";

--
-- FINISH
--
