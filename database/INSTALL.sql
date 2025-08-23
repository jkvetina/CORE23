--
-- JOB .................... 2
-- PACKAGE ................ 4
-- PACKAGE BODY ........... 4
-- PROCEDURE .............. 1
-- VIEW .................. 23
--

--
-- INIT
--

--
-- OBJECTS
--
@"./views/core_apps_overview_v.sql";
@"./views/core_apps_timeline_v.sql";
@"./views/core_apps_traffic_v.sql";
@"./views/core_apps_workspace_files_v.sql";
@"./views/core_app_component_changes_v.sql";
@"./views/core_app_history_v.sql";
@"./views/core_app_performance_v.sql";
@"./views/core_daily_apex_debug_messages_v.sql";
@"./views/core_daily_broken_apex_components_v.sql";
@"./views/core_daily_compile_errors_v.sql";
@"./views/core_daily_disabled_objects_v.sql";
@"./views/core_daily_failed_authentication_v.sql";
@"./views/core_daily_invalid_objects_v.sql";
@"./views/core_daily_mail_queue_errors_v.sql";
@"./views/core_daily_materialized_views_v.sql";
@"./views/core_daily_missing_vpd_policies_v.sql";
@"./views/core_daily_schedulers_v.sql";
@"./views/core_daily_synonyms_v.sql";
@"./views/core_daily_versions_v.sql";
@"./views/core_daily_web_service_calls_v.sql";
@"./views/core_daily_workspace_errors_v.sql";
@"./views/core_daily__column_names_v.sql";
@"./views/core_rest_services_v.sql";
@"./procedures/recompile.sql";
@"./packages/core_custom.spec.sql";
@"./packages/core.spec.sql";
@"./packages/core_gen.spec.sql";
@"./packages/core_jobs.spec.sql";
@"./packages/core.sql";
@"./packages/core_custom.sql";
@"./packages/core_gen.sql";
@"./packages/core_jobs.sql";

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
