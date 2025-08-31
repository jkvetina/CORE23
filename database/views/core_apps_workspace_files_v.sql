CREATE OR REPLACE FORCE VIEW core_apps_workspace_files_v AS
SELECT
    f.file_name,
    DBMS_LOB.GETLENGTH(f.file_content) AS file_size,
    f.last_updated_by   AS updated_by,
    f.last_updated_on   AS updated_at,
    --
    CASE
        WHEN f.last_updated_on >= core_jobs.get_start_date()
            THEN 'RED'
        END AS updated_at__style
    --
FROM apex_workspace_static_files f
WHERE (
        f.file_name     LIKE '%.css'
        OR f.file_name  LIKE '%.js'
    )
    AND f.file_name     NOT LIKE '%.min.%'
ORDER BY 1;
/
--
COMMENT ON TABLE core_apps_workspace_files_v IS '';
--
COMMENT ON COLUMN core_apps_workspace_files_v.file_name             IS '';
COMMENT ON COLUMN core_apps_workspace_files_v.file_size             IS '';
COMMENT ON COLUMN core_apps_workspace_files_v.updated_at__style     IS '';

