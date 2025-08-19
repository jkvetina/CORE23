CREATE OR REPLACE FORCE VIEW core_daily_failed_authentication_v AS
SELECT
    t.application_id            AS app_id,
    t.application_name          AS app_name,
    t.authentication_method     AS auth_method,
    t.user_name,
    REGEXP_REPLACE(t.custom_status_text, '<[^>]*>', '') AS error_,
    t.ip_address,
    --
    COUNT(*)                    AS attempts,
    MAX(t.access_date)          AS last_access_date
    --
FROM apex_workspace_access_log t
WHERE t.application_schema_owner    NOT LIKE 'APEX_2%'
    AND t.authentication_result     != 'AUTH_SUCCESS'
    AND t.access_date               >= core_jobs.get_start_date()
    AND t.access_date               <  core_jobs.get_end_date()
GROUP BY ALL
ORDER BY
    1, 2, 3, 4;
/
--
COMMENT ON TABLE core_daily_failed_authentication_v IS '30 | Failed Authentication | Security Issues';
--
COMMENT ON COLUMN core_daily_failed_authentication_v.app_id             IS '';
COMMENT ON COLUMN core_daily_failed_authentication_v.app_name           IS '';
COMMENT ON COLUMN core_daily_failed_authentication_v.auth_method        IS '';
COMMENT ON COLUMN core_daily_failed_authentication_v.user_name          IS '';
COMMENT ON COLUMN core_daily_failed_authentication_v.error_             IS '';
COMMENT ON COLUMN core_daily_failed_authentication_v.ip_address         IS '';
COMMENT ON COLUMN core_daily_failed_authentication_v.attempts           IS '';
COMMENT ON COLUMN core_daily_failed_authentication_v.last_access_date   IS '';

