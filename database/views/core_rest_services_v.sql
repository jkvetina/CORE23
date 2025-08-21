CREATE OR REPLACE FORCE VIEW core_rest_services_v AS
WITH t AS (
    SELECT
        h.id AS handler_id,
        --
        '/' || c.pattern || m.uri_prefix ||
        SUBSTR(s.pattern, 1, INSTR(s.pattern, '/'))     AS service_path,
        SUBSTR(s.pattern, INSTR(s.pattern, '/') + 1)    AS service_args,
        s.method,
        --
        c.parsing_schema AS schema_,--owner
        --
        CASE WHEN s.source_type = 'plsql/block'
            THEN REGEXP_SUBSTR(UPPER(DBMS_LOB.SUBSTR(h.source, 4000)), 'BEGIN\s+([A-Z0-9_]+)\.', 1, 1, NULL, 1)
            END AS package_name,
        --
        CASE WHEN s.source_type = 'plsql/block'
            THEN REGEXP_SUBSTR(UPPER(DBMS_LOB.SUBSTR(h.source, 4000)), 'BEGIN\s+[A-Z0-9_]+\.([A-Z0-9_]+)', 1, 1, NULL, 1)
            END AS procedure_name,
        --
        CASE WHEN s.source_type = 'plsql/block'
            THEN TRIM(REGEXP_SUBSTR(REGEXP_REPLACE(
                REPLACE(DBMS_LOB.SUBSTR(h.source, 4000), CHR(10), ' '),
                '\s+', ' '),
                '\(\s*(.*)\s*\)', 1, 1, NULL, 1))-- || ','
            END AS source_code,
        --
        h.updated_by,
        h.updated_on AS updated_at,
        h.comments
        --
    FROM user_ords_services s
    JOIN user_ords_modules m    ON m.id = s.module_id
    JOIN user_ords_schemas c    ON c.id = m.schema_id
    JOIN user_ords_templates t  ON t.id = s.template_id
    JOIN user_ords_handlers h   ON h.id = s.handler_id
    --
    WHERE s.status      = 'PUBLISHED'
        AND m.status    = 'PUBLISHED'
        AND c.status    = 'ENABLED'
        AND m.name      = core_jobs.get_group_name()
),
b AS (
    SELECT
        t.handler_id,
        NULLIF(':' || REPLACE(TRIM(s.column_value), '/', ''), ':')  AS bind_name,
        COUNT(t.handler_id) OVER (PARTITION BY t.handler_id)        AS binds_expected,
        --
        ROW_NUMBER() OVER (PARTITION BY t.handler_id ORDER BY INSTR(t.service_args, s.column_value)) AS r#
    FROM t
    JOIN APEX_STRING.SPLIT(t.service_args, ':') s
        ON 1 = 1
    WHERE TRIM(s.column_value) IS NOT NULL
    GROUP BY
        t.handler_id,
        t.service_args,
        s.column_value
),
g AS (
    SELECT
        g.handler_id,
        MIN(CASE WHEN g.binds_matched = g.binds_expected THEN 'VALID' END) AS status
    FROM (
        SELECT
            t.handler_id,
            g.argument_name,
            g.defaulted,
            --
            REGEXP_SUBSTR(t.source_code, g.argument_name || '\s*=>\s*(:[A-Z0-9_]+)', 1, 1, 'i', 1) AS bind_name,
            --
            COUNT(g.argument_name) OVER (PARTITION BY t.handler_id) AS args_expected,
            CASE WHEN s.column_value IS NOT NULL THEN 'Y' END AS arg_matched,
            --
            b.binds_expected,
            COUNT(b.bind_name) OVER (PARTITION BY t.handler_id) AS binds_matched
            --
        FROM t
        LEFT JOIN user_arguments g
            ON g.object_name    = t.procedure_name
            AND g.package_name  = t.package_name
            AND g.overload      IS NULL
        LEFT JOIN APEX_STRING.SPLIT(t.source_code, ',') s
            ON g.argument_name  = UPPER(TRIM(REGEXP_SUBSTR(s.column_value, '^([^=]+)', 1, 1, 'i', 1)))
        LEFT JOIN b
            ON b.handler_id     = t.handler_id
            AND b.bind_name     = REGEXP_SUBSTR(t.source_code, g.argument_name || '\s*=>\s*(:[A-Z0-9_]+)', 1, 1, 'i', 1)
    ) g
    GROUP BY
        g.handler_id
)
SELECT
    t.handler_id,
    t.service_path,
    t.service_args,
    t.method,
    --
    NVL(g.status, 'INVALID') AS status,
    CASE WHEN NVL(g.status, '-') != 'VALID' THEN 'RED' END AS status__style,
    --
    t.package_name,
    t.procedure_name,
    t.updated_at
FROM t
LEFT JOIN g
    ON g.handler_id = t.handler_id
ORDER BY
    1;
/

