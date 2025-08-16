DECLARE
    in_job_name             CONSTANT VARCHAR2(128)  := 'CORE_DAILY_VERSIONS';
    in_run_immediatelly     CONSTANT BOOLEAN        := FALSE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--');
    DBMS_OUTPUT.PUT_LINE('-- REPLACE JOB ' || UPPER(in_job_name));
    DBMS_OUTPUT.PUT_LINE('--');
    --
    BEGIN
        DBMS_SCHEDULER.DROP_JOB(in_job_name, TRUE);
    EXCEPTION
    WHEN OTHERS THEN
        NULL;
    END;
    --
    DBMS_SCHEDULER.CREATE_JOB (
        job_name            => in_job_name,
        job_type            => 'PLSQL_BLOCK',
        job_action          => 'core.update_app_version (
    in_app_id       => NULL,
    in_version      => NULL,
    in_proceed      => TRUE,
    in_skip_main    => TRUE,
    in_keep_older   => FALSE
);',
        number_of_arguments => 0,
        start_date          => NULL,
        repeat_interval     => 'FREQ=HOURLY; BYMINUTE=58; BYSECOND=0',
        end_date            => NULL,
        enabled             => FALSE,
        auto_drop           => TRUE,
        comments            => ''
    );
    --
    DBMS_SCHEDULER.SET_ATTRIBUTE(in_job_name, 'JOB_PRIORITY', 3);
    DBMS_SCHEDULER.ENABLE(in_job_name);
    COMMIT;
    --
    IF in_run_immediatelly THEN
        DBMS_SCHEDULER.RUN_JOB(in_job_name);
        COMMIT;
    END IF;
END;
/

