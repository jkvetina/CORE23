CREATE OR REPLACE FORCE VIEW core_daily_apex_debug_messages_v AS
SELECT
    t.application_id    AS app_id,
    t.page_id,
    t.apex_user         AS user_,
    --
    CASE t.message_level
        WHEN 1 THEN 'E'
        WHEN 2 THEN 'W'
        ELSE TO_CHAR(t.message_level)
        END AS type_,
    --
    REGEXP_REPLACE(
        TRIM(REGEXP_REPLACE(REGEXP_REPLACE(t.message, '#\d+', ''), 'id "\d+"', 'id ?')),
        '<[^>]*>', '') AS error_,
    --
    COUNT(*)    AS count_,
    MAX(t.id)   AS recent_log_id
    --
FROM apex_debug_messages t
WHERE 1 = 1
    AND t.message_timestamp >= core_reports.get_start_date()
    AND t.message_timestamp <  core_reports.get_end_date()
    AND t.message_level     IN (1, 2)
    AND t.message           NOT LIKE '%ORA-20876: Stop APEX Engine%'
GROUP BY ALL
ORDER BY
    1, 2, 3, 4;
/

