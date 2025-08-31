CREATE OR REPLACE FORCE VIEW core_daily_mail_queue_errors_v AS
SELECT
    t.app_id,
    REPLACE(REPLACE(t.mail_send_error, '<', '"'), '>', '"') AS error_,
    --
    SUM(t.mail_send_count)  AS count_,
    MAX(t.id)               AS recent_id
    --
FROM apex_mail_queue t
WHERE 1 = 1
    AND t.mail_message_created  >= core_reports.get_start_date()
    AND t.mail_message_created  <  core_reports.get_end_date()
    AND t.mail_send_error       IS NOT NULL
GROUP BY ALL
ORDER BY
    1, 2;
/

