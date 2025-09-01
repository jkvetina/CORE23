--
-- DATA ................... 2
-- JOB .................... 2
-- PACKAGE ................ 5
-- PACKAGE BODY ........... 5
-- PROCEDURE .............. 1
-- SEQUENCE ............... 1
-- TABLE .................. 3
-- TRIGGER ................ 1
-- VIEW .................. 22
--

--
-- INIT
--

--
-- SEQUENCES
--
@"./sequences/core_lock_id.sql";

--
-- TABLES
--
@"./tables/core_locks.sql";
@"./tables/core_report_views.sql";
@"./tables/core_report_cols.sql";

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
@"./views/core_rest_services_v.sql";
@"./procedures/recompile.sql";
@"./packages/core_custom.spec.sql";
@"./packages/core.spec.sql";
@"./packages/core_gen.spec.sql";
@"./packages/core_lock.spec.sql";
@"./packages/core_reports.spec.sql";
@"./packages/core.sql";
@"./packages/core_custom.sql";
@"./packages/core_gen.sql";
@"./packages/core_lock.sql";
@"./packages/core_reports.sql";

--
-- TRIGGERS
--
@"./triggers/core_prevent_create_wrong_objects.sql";
@"./triggers/core_locksmith.sql";

EXEC recompile;

--
-- DATA
--
@"./data/core_report_views.sql";
@"./data/core_report_cols.sql";

--
-- GRANTS
--
@"./grants/MASTER.sql";

--
-- JOBS
--
@"./jobs/core_daily_developers.sql";
@"./jobs/core_daily_versions.sql";

--
-- FINISH
--
