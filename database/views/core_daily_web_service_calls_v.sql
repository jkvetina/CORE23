CREATE OR REPLACE FORCE VIEW core_daily_web_service_calls_v AS
SELECT
    t.workspace_name                    AS workspace,
    APEX_STRING_UTIL.GET_DOMAIN(t.url)  AS host,
    t.http_method                       AS method,
    t.status_code,
    --
    CASE
        WHEN t.status_code <= 299 THEN 'Success'
        WHEN t.status_code <= 399 THEN 'Redirection'
        WHEN t.status_code <= 499 THEN 'Client Error'
        WHEN t.status_code <= 599 THEN 'Server Error'
        END AS status,
    --
    CASE
        WHEN t.status_code <= 299 THEN ''
        WHEN t.status_code <= 399 THEN ''
        WHEN t.status_code <= 499 THEN 'RED'
        WHEN t.status_code <= 599 THEN 'RED'
        END AS status__style,
    --
    ROUND(AVG(t.elapsed_sec), 2) AS elapsed_sec_avg,
    ROUND(MAX(t.elapsed_sec), 2) AS elapsed_sec_max,
    COUNT(*) AS count_
    --
FROM apex_webservice_log t
WHERE 1 = 1
    AND t.request_date  >= core_jobs.get_start_date()
    AND t.request_date  <  core_jobs.get_end_date()
GROUP BY ALL
ORDER BY
    1, 2, 3;
/
--
COMMENT ON TABLE core_daily_web_service_calls_v IS '44 | Web Service Calls';
--
COMMENT ON COLUMN core_daily_web_service_calls_v.workspace          IS '';
COMMENT ON COLUMN core_daily_web_service_calls_v.host               IS '';
COMMENT ON COLUMN core_daily_web_service_calls_v.method             IS '';
COMMENT ON COLUMN core_daily_web_service_calls_v.status_code        IS '';
COMMENT ON COLUMN core_daily_web_service_calls_v.status             IS '';
COMMENT ON COLUMN core_daily_web_service_calls_v.status__style      IS '';
COMMENT ON COLUMN core_daily_web_service_calls_v.elapsed_sec_avg    IS '';
COMMENT ON COLUMN core_daily_web_service_calls_v.elapsed_sec_max    IS '';
COMMENT ON COLUMN core_daily_web_service_calls_v.count_             IS '';

