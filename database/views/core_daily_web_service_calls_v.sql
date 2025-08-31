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
    AND t.request_date  >= core_reports.get_start_date()
    AND t.request_date  <  core_reports.get_end_date()
GROUP BY ALL
ORDER BY
    1, 2, 3;
/

