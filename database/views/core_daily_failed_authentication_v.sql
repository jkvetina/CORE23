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
    AND t.access_date               >= core_reports.get_start_date()
    AND t.access_date               <  core_reports.get_end_date()
GROUP BY ALL
ORDER BY
    1, 2, 3, 4;
/

