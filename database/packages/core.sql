CREATE OR REPLACE PACKAGE BODY core AS

    FUNCTION get_id
    RETURN NUMBER
    AS
    BEGIN
        RETURN TO_NUMBER(SYS_GUID(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
    END;



    FUNCTION get_id (
        in_position1            NUMBER,
        in_position2            NUMBER := NULL,
        in_position3            NUMBER := NULL,
        in_position4            NUMBER := NULL,
        in_position5            NUMBER := NULL
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN RTRIM(REGEXP_REPLACE (
            SYS_GUID(),
            '^(.{' || REPLACE(in_position1
                || CASE WHEN in_position2 IS NOT NULL THEN ',' || in_position2 END
                || CASE WHEN in_position3 IS NOT NULL THEN ',' || in_position3 END
                || CASE WHEN in_position4 IS NOT NULL THEN ',' || in_position4 END
                || CASE WHEN in_position5 IS NOT NULL THEN ',' || in_position5 END,
                ',', '})(.{') || '})(.{0})',
            '\1'
                || CASE WHEN in_position1 IS NOT NULL THEN '-\2' END
                || CASE WHEN in_position2 IS NOT NULL THEN '-\3' END
                || CASE WHEN in_position3 IS NOT NULL THEN '-\4' END
                || CASE WHEN in_position4 IS NOT NULL THEN '-\5' END
                || CASE WHEN in_position5 IS NOT NULL THEN '-\6' END
        ), '-');
    END;



    FUNCTION get_token (
        in_size                 NUMBER := 6
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN LPAD(TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(1, TO_CHAR(POWER(10, in_size) - 1)))), in_size, '0');
    END;



    FUNCTION get_yn (
        in_boolean              BOOLEAN
    )
    RETURN CHAR
    DETERMINISTIC
    AS
    BEGIN
        RETURN CASE WHEN in_boolean THEN 'Y' ELSE 'N' END;
    END;



    FUNCTION get_slug (
        in_name                 VARCHAR2,
        in_separator            VARCHAR2    := NULL,
        in_lowercase            BOOLEAN     := FALSE,
        in_envelope             BOOLEAN     := FALSE
    )
    RETURN VARCHAR2
    AS
        v_content               VARCHAR2(32767);
    BEGIN
        v_content := NVL(UPPER(REPLACE(APEX_STRING_UTIL.GET_SLUG(APEX_ESCAPE.STRIPHTML(in_name)), '-', '_')), '_');
        --
        IF in_separator IS NOT NULL THEN
            v_content := REPLACE(v_content, '_', in_separator);
        END IF;
        --
        IF in_lowercase THEN
            v_content := LOWER(v_content);
        END IF;
        --
        IF in_envelope THEN
            v_content := NVL(in_separator, '_') || v_content || NVL(in_separator, '_');
        END IF;
        --
        RETURN v_content;
    END;



    FUNCTION get_context_app (
        in_context_name         VARCHAR2 := NULL
    )
    RETURN NUMBER
    AS
        v_app_id PLS_INTEGER;
    BEGIN
        BEGIN
            v_app_id := core.get_number_item(NVL(in_context_name, c_context_name_app));
        EXCEPTION
        WHEN OTHERS THEN
            NULL;
        END;
        --
        RETURN COALESCE(v_app_id, APEX_APPLICATION.G_FLOW_ID);
    END;



    FUNCTION get_context_page (
        in_context_name         VARCHAR2 := NULL
    )
    RETURN NUMBER
    AS
        v_page_id PLS_INTEGER;
    BEGIN
        BEGIN
            v_page_id := core.get_number_item(NVL(in_context_name, c_context_name_page));
        EXCEPTION
        WHEN OTHERS THEN
            NULL;
        END;
        --
        RETURN COALESCE(v_page_id, APEX_APPLICATION.G_FLOW_STEP_ID);
    END;



    PROCEDURE set_contexts (
        in_context_name_app     VARCHAR2 := NULL,
        in_context_name_page    VARCHAR2 := NULL
    )
    AS
    BEGIN
        --
        -- in the Master app these CONTEXT items have to be unprotected,
        -- because we have to pass them in the navigation links for Master pages,
        -- because without this when using multiple tabs with different apps
        -- it will override the navigation with recent app
        --
        -- set only if there is no CONTEXT_APP item referenced in the url address
        IF INSTR(UPPER(core.get_request_url()), c_context_name_app) = 0 THEN
            core.set_item(NVL(in_context_name_app,  c_context_name_app),    core.get_app_id());
            core.set_item(NVL(in_context_name_page, c_context_name_page),   core.get_page_id());
        END IF;
        --
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION get_master_id
    RETURN NUMBER
    AS
    BEGIN
        RETURN c_master_id;
    END;



    FUNCTION get_app_id
    RETURN NUMBER
    AS
    BEGIN
        RETURN APEX_APPLICATION.G_FLOW_ID;
    END;



    FUNCTION get_app_owner (
        in_app_id               NUMBER      := NULL
    )
    RETURN VARCHAR2
    AS
        out_owner               apex_applications.owner%TYPE;
    BEGIN
        SELECT MIN(a.owner)
        INTO out_owner
        FROM apex_applications a
        WHERE a.application_id = COALESCE(in_app_id, core.get_context_app());
        --
        RETURN COALESCE(out_owner, APEX_UTIL.GET_DEFAULT_SCHEMA, USER);
    END;



    FUNCTION get_app_workspace (
        in_app_id               NUMBER      := NULL
    )
    RETURN VARCHAR2
    AS
        out_name                apex_applications.workspace%TYPE;
    BEGIN
        SELECT a.workspace INTO out_name
        FROM apex_applications a
        WHERE a.application_id = COALESCE(in_app_id, core.get_context_app());
        --
        RETURN out_name;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    FUNCTION get_app_name (
        in_app_id               NUMBER      := NULL
    )
    RETURN VARCHAR2
    AS
        out_name                apex_applications.application_name%TYPE;
    BEGIN
        SELECT a.application_name INTO out_name
        FROM apex_applications a
        WHERE a.application_id = COALESCE(in_app_id, core.get_context_app());
        --
        RETURN out_name;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    FUNCTION get_app_home_url (
        in_app_id               NUMBER,
        in_full                 CHAR        := NULL
    )
    RETURN VARCHAR2
    DETERMINISTIC
    AS
        out_url                 apex_applications.home_link%TYPE;
    BEGIN
        BEGIN
            SELECT
                CASE WHEN in_full IS NOT NULL
                    THEN REPLACE(APEX_UTIL.HOST_URL('APEX_PATH'), 'http://:', '')
                    END ||
                RTRIM(REPLACE(REPLACE(REPLACE(
                    a.home_link,
                    '&' || 'APP_ID.',       a.application_id),
                    '&' || 'SESSION.',      '&' || 'APP_SESSION.'),     -- keep session
                    '&' || 'DEBUG.',        ''),
                    ':'
                )
            INTO out_url
            FROM apex_applications a
            WHERE a.application_id      = in_app_id;
            --
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
        END;
        --
        RETURN out_url;
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION get_app_login_url (
        in_app_id               NUMBER,
        in_full                 CHAR        := NULL
    )
    RETURN VARCHAR2
    DETERMINISTIC
    AS
        out_url                 apex_applications.login_url%TYPE;
    BEGIN
        BEGIN
            SELECT
                CASE WHEN in_full IS NOT NULL
                    THEN REPLACE(APEX_UTIL.HOST_URL('APEX_PATH'), 'http://:', '')
                    END ||
                RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(
                    a.login_url,
                    '&' || 'APP_ID.',       a.application_id),
                    '&' || 'SESSION.',      '0'),
                    '&' || 'APP_SESSION.',  '0'),
                    '&' || 'DEBUG.',        ''),
                    ':'
                )
            INTO out_url
            FROM apex_applications a
            WHERE a.application_id = in_app_id;
            --
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
        END;
        --
        RETURN out_url;
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION get_user_id
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN core_custom.get_user_id();
    END;



    FUNCTION get_user_lang
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN REPLACE(UPPER(SUBSTR(OWA_UTIL.GET_CGI_ENV('HTTP_ACCEPT_LANGUAGE'), 1, 2)), 'CS', 'CZ');
    EXCEPTION
    WHEN OTHERS THEN
        RETURN 'EN';
    END;



    FUNCTION get_tenant_id (
        in_user_id      VARCHAR2 := NULL
    )
    RETURN NUMBER
    AS
    BEGIN
        RETURN core_custom.get_tenant_id(in_user_id);
    END;



    FUNCTION get_substitution (
        in_name                 VARCHAR2,
        in_app_id               NUMBER      := NULL
    )
    RETURN VARCHAR2
    AS
        out_value               apex_application_substitutions.substitution_value%TYPE;
    BEGIN
        SELECT s.substitution_value
        INTO out_value
        FROM apex_application_substitutions s
        WHERE s.application_id          = COALESCE(in_app_id, core.get_context_app())
            AND s.substitution_string   = in_name;
        --
        RETURN out_value;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    FUNCTION get_preference (
        in_name                 VARCHAR2
    )
    RETURN VARCHAR2
    AS
    BEGIN
        -- apex_workspace_preferences.preference_value%TYPE;
        RETURN APEX_UTIL.GET_PREFERENCE (
            p_preference    => in_name
        );
    END;



    PROCEDURE set_preference (
        in_name                 VARCHAR2,
        in_value                VARCHAR2
    )
    AS
    BEGIN
        core.log_start (
            'name',     in_name,
            'value',    in_value
        );
        --
        APEX_UTIL.SET_PREFERENCE (
            p_preference    => in_name,
            p_value         => in_value
        );
        --
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION get_app_setting (
        in_name                 VARCHAR2
    )
    RETURN VARCHAR2
    AS
    BEGIN
        -- apex_application_settings.value%TYPE;
        RETURN APEX_APP_SETTING.GET_VALUE (
            p_name      => in_name
        );
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    PROCEDURE set_app_setting (
        in_name                 VARCHAR2,
        in_value                VARCHAR2
    )
    AS
    BEGIN
        core.log_start (
            'name',     in_name,
            'value',    in_value
        );
        --
        APEX_APP_SETTING.SET_VALUE (
            p_name          => in_name,
            p_value         => in_value,
            p_raise_error   => TRUE
        );
        --
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error('SET_SETTING',
            'name',     in_name,
            'value',    in_value
        );
    END;



    FUNCTION get_constant (
        in_name                 VARCHAR2,
        in_package              VARCHAR2        := NULL,
        in_owner                VARCHAR2        := NULL,
        in_private              CHAR            := NULL,    -- Y = package body
        in_prefix               VARCHAR2        := NULL,
        in_env                  VARCHAR2        := NULL,
        in_silent               BOOLEAN         := FALSE
    )
    RETURN VARCHAR2
    RESULT_CACHE
    AS
        v_found                 PLS_INTEGER;
        out_value               VARCHAR2(4000);
        --
        PRAGMA UDF;
    BEGIN
        SELECT
            NULLIF(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        REGEXP_REPLACE(
                            LTRIM(SUBSTR(s.text, INSTR(s.text, ':=') + 2)),
                            ';\s*[-]{2}.*$',
                            ';'),
                        '[;]\s*',
                        ''),
                    '(^[''])|(['']\s*$)',
                    ''),
                'NULL')
        INTO out_value
        FROM all_source s
        WHERE s.owner   = COALESCE(in_owner, c_constants_owner, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'))
            AND s.name  = UPPER(NVL(in_package, c_constants))
            AND s.type  = 'PACKAGE' || CASE WHEN in_private IS NOT NULL THEN ' BODY' END
            AND (
                    (in_env IS NOT NULL AND REGEXP_LIKE(s.text, '^\s*' || UPPER(in_prefix || in_name || '_' || in_env) || '\s+CONSTANT\s+', 'i'))
                OR  REGEXP_LIKE(s.text, '^\s*' || UPPER(in_prefix || in_name) || '\s+CONSTANT\s+', 'i')
            )
        ORDER BY
            CASE
                WHEN in_env IS NOT NULL AND REGEXP_LIKE(s.text, '^\s*' || UPPER(in_prefix || in_name || '_' || NVL(in_env, '\?')) || '\s+CONSTANT\s+', 'i') THEN 1
                WHEN REGEXP_LIKE(s.text, '^\s*' || UPPER(in_prefix || in_name) || '\s+CONSTANT\s+', 'i') THEN 2
                END,
            s.line
        FETCH FIRST 1 ROWS ONLY;
        --
        RETURN out_value;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- check if we have a correct package
        BEGIN
            SELECT 1
            INTO v_found
            FROM all_source s
            WHERE s.owner   = COALESCE(in_owner, c_constants_owner, SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'))
                AND s.name  = UPPER(NVL(in_package, c_constants))
                AND s.type  = 'PACKAGE' || CASE WHEN in_private IS NOT NULL THEN ' BODY' END
                AND s.line  = 1;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            IF NOT in_silent THEN
                core.raise_error('CONSTANT_PACKAGE_MISSING|' || UPPER(NVL(in_package, c_constants)), in_rollback => FALSE);
            END IF;
        END;
        --
        IF NOT in_silent THEN
            core.raise_error('CONSTANT_MISSING|' || UPPER(NVL(in_package, c_constants)) || '|' || UPPER(in_prefix || in_name), in_rollback => FALSE);
        END IF;
        --
        RETURN NULL;
    END;



    FUNCTION get_constant_num (
        in_name                 VARCHAR2,
        in_package              VARCHAR2        := NULL,
        in_owner                VARCHAR2        := NULL,
        in_private              CHAR            := NULL,    -- Y = package body
        in_prefix               VARCHAR2        := NULL,
        in_env                  VARCHAR2        := NULL,
        in_silent               BOOLEAN         := FALSE
    )
    RETURN NUMBER
    RESULT_CACHE
    AS
        out_value           NUMBER;
    BEGIN
        RETURN TO_NUMBER(get_constant (
            in_package      => in_package,
            in_name         => in_name,
            in_owner        => in_owner,
            in_private      => in_private,
            in_prefix       => in_prefix,
            in_env          => in_env,
            in_silent       => in_silent
        ));
    END;



    FUNCTION is_developer (
        in_user                 VARCHAR2        := NULL,
        in_deep_check           BOOLEAN         := FALSE    -- split to make it faster
    )
    RETURN BOOLEAN
    AS
        is_valid                CHAR;
    BEGIN
        -- check if we have APEX Builder session
        IF in_user IS NULL AND NV('APP_BUILDER_SESSION') > 0 THEN
            RETURN TRUE;
        END IF;

        -- check if we have a record in APEX Developers table
        IF in_deep_check THEN
            WITH u AS (
                SELECT core.get_user_id() AS user_id    FROM DUAL UNION ALL
                SELECT in_user                          FROM DUAL
            )
            SELECT 'Y' INTO is_valid
            FROM apex_workspace_developers d
            JOIN apex_applications a
                ON a.workspace                  = d.workspace_name
            JOIN u
                ON UPPER(u.user_id)             IN (UPPER(d.user_name), UPPER(d.email))
            WHERE a.application_id              = core.get_app_id()
                AND d.is_application_developer  = 'Yes'
                AND d.account_locked            = 'No'
                AND ROWNUM                      = 1;
            --
            RETURN TRUE;
        END IF;
        --
        RETURN FALSE;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN FALSE;
    END;



    FUNCTION is_developer_y (
        in_user                 VARCHAR2        := NULL,
        in_deep_check           BOOLEAN         := FALSE
    )
    RETURN CHAR
    AS
    BEGIN
        RETURN CASE
            WHEN core.is_developer (
                in_user         => in_user,
                in_deep_check   => in_deep_check
            )
            THEN 'Y' END;
    END;



    FUNCTION is_authorized (
        in_auth_scheme          VARCHAR2
    )
    RETURN CHAR
    AS
    BEGIN
        -- check scheme and procedure
        IF (NULLIF(in_auth_scheme, '-') IS NULL OR in_auth_scheme = 'MUST_NOT_BE_PUBLIC_USER') THEN
            RETURN 'Y';  -- no authorization or public access
        END IF;

        -- return Y/NULL so we can call this in a SQL statement
        RETURN CASE
            WHEN APEX_AUTHORIZATION.IS_AUTHORIZED (
                p_authorization_name => in_auth_scheme
            )
            THEN 'Y' END;
    END;



    FUNCTION get_debug_level (
        in_session_id           NUMBER      := NULL
    )
    RETURN NUMBER
    AS
        out_level               NUMBER(1);
    BEGIN
        SELECT s.session_debug_level
        INTO out_level
        FROM apex_workspace_sessions s
        WHERE s.apex_session_id = COALESCE(in_session_id, core.get_session_id());
        --
        RETURN NULLIF(out_level, 0);
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    FUNCTION get_debug
    RETURN BOOLEAN
    AS
    BEGIN
        RETURN APEX_APPLICATION.G_DEBUG;
    END;



    PROCEDURE set_debug (
        in_level                NUMBER      := NULL,
        in_session_id           NUMBER      := NULL
    )
    AS
    BEGIN
        core.log_start (
            'level',        in_level,
            'session_id',   in_session_id
        );
        --
        --APEX_APPLICATION.G_DEBUG := in_level;
        APEX_SESSION.SET_DEBUG (
            p_session_id    => COALESCE(in_session_id, core.get_session_id()),
            p_level         => COALESCE(in_level, 4)
        );
        --
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE create_security_context (
        in_workspace            VARCHAR2    := NULL,
        in_app_id               NUMBER      := NULL
    )
    AS
        v_workspace             apex_applications.workspace%TYPE := in_workspace;
    BEGIN
        -- find workspace based on application id
        IF v_workspace IS NULL AND in_app_id IS NOT NULL THEN
            BEGIN
                SELECT a.workspace INTO v_workspace
                FROM apex_applications a
                WHERE a.application_id = in_app_id;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                core.raise_error('INVALID_APP', in_app_id, in_concat => TRUE);
            END;
        END IF;
        --
        APEX_UTIL.SET_WORKSPACE (
            p_workspace => v_workspace
        );
        APEX_UTIL.SET_SECURITY_GROUP_ID (
            p_security_group_id => APEX_UTIL.FIND_SECURITY_GROUP_ID(p_workspace => v_workspace)
        );
        --
    EXCEPTION
    WHEN core.app_exception THEN
        ROLLBACK;
        RAISE;
    WHEN OTHERS THEN
        ROLLBACK;
        core.raise_error();
    END;



    PROCEDURE create_session (
        in_user_id              VARCHAR2,
        in_app_id               NUMBER,
        in_page_id              NUMBER      := NULL,
        in_session_id           NUMBER      := NULL,
        in_workspace            VARCHAR2    := NULL,
        in_postauth             BOOLEAN     := FALSE
    )
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --
        v_user_name             apex_workspace_sessions.user_name%TYPE;
    BEGIN
        core.log_start (
            'user_id',      in_user_id,
            'app_id',       in_app_id,
            'page_id',      in_page_id,
            'session_id',   in_session_id,
            'workspace',    in_workspace,
            'postauth',     CASE WHEN in_postauth THEN 'Y' ELSE 'N' END
        );

        -- set security context
        core.create_security_context (
            in_workspace        => in_workspace,
            in_app_id           => in_app_id
        );

        -- attach to existing session
        IF in_session_id > 0 THEN
            attach_session (
                in_session_id   => in_session_id,
                in_app_id       => in_app_id,
                in_page_id      => NVL(in_page_id, 0),
                in_workspace    => in_workspace,
                in_postauth     => in_postauth
            );
        ELSE
            -- create new APEX session
            BEGIN
                APEX_SESSION.CREATE_SESSION (
                    p_app_id                    => in_app_id,
                    p_page_id                   => NVL(in_page_id, 0),
                    p_username                  => in_user_id,
                    p_call_post_authentication  => in_postauth
                );
            EXCEPTION
            WHEN OTHERS THEN
                core.raise_error('CREATE_SESSION_FAILED', in_app_id, in_page_id, in_user_id, in_concat => TRUE);
            END;

            -- set username
            IF APEX_CUSTOM_AUTH.SESSION_ID_EXISTS THEN
                APEX_UTIL.SET_USERNAME (
                    p_userid    => APEX_UTIL.GET_USER_ID(v_user_name),
                    p_username  => v_user_name
                );
            END IF;
            --
            core.print_items();
        END IF;

        -- set client identifier
        DBMS_SESSION.SET_IDENTIFIER(in_user_id);    -- SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER')

        -- enable debug so we can use debug messages
        APEX_DEBUG.ENABLE(p_level => core_custom.default_debug_level);
        --
        COMMIT;
        --
    EXCEPTION
    WHEN core.app_exception THEN
        ROLLBACK;
        RAISE;
    WHEN APEX_APPLICATION.E_STOP_APEX_ENGINE THEN
        COMMIT;
    WHEN OTHERS THEN
        ROLLBACK;
        core.raise_error();
    END;



    PROCEDURE attach_session (
        in_session_id           NUMBER,
        in_app_id               NUMBER,
        in_page_id              NUMBER      := NULL,
        in_workspace            VARCHAR2    := NULL,
        in_postauth             BOOLEAN     := FALSE
    )
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        -- set security context
        core.create_security_context (
            in_workspace        => in_workspace,
            in_app_id           => in_app_id
        );

        -- try to attach to the provided session
        BEGIN
            APEX_SESSION.ATTACH (
                p_app_id        => in_app_id,
                p_page_id       => in_page_id,
                p_session_id    => in_session_id
            );
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error('ATTACH_SESSION_FAILED', in_app_id, in_page_id, in_session_id, in_concat => TRUE);
        END;
        --
        COMMIT;
        --
        core.print_items();
        --
    EXCEPTION
    WHEN core.app_exception THEN
        ROLLBACK;
        RAISE;
    WHEN APEX_APPLICATION.E_STOP_APEX_ENGINE THEN
        COMMIT;
    WHEN OTHERS THEN
        ROLLBACK;
        core.raise_error();
    END;



    PROCEDURE exit_session
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        DBMS_SESSION.CLEAR_IDENTIFIER();
        DBMS_APPLICATION_INFO.SET_MODULE (
            module_name     => NULL,
            action_name     => NULL
        );
        --DBMS_SESSION.CLEAR_ALL_CONTEXT(namespace);
        --DBMS_SESSION.RESET_PACKAGE;  -- avoid ORA-04068 exception
        --
        --APEX_SESSION.DETACH();
        --APEX_SESSION.DELETE_SESSION();
        --
        COMMIT;
    EXCEPTION
    WHEN core.app_exception THEN
        ROLLBACK;
        RAISE;
    WHEN OTHERS THEN
        ROLLBACK;
        core.raise_error();
    END;



    PROCEDURE print_items
    AS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--');
        DBMS_OUTPUT.PUT_LINE('WORKSPACE   : ' || core.get_workspace() || ' | ' || APEX_CUSTOM_AUTH.GET_SECURITY_GROUP_ID());
        DBMS_OUTPUT.PUT_LINE('SESSION     : ' || core.get_app_id() || ' | ' || core.get_page_id() || ' | ' || core.get_session_id() || ' | ' || core.get_user_id());
        DBMS_OUTPUT.PUT_LINE('--');

        -- print app and page items
        FOR c IN (
            SELECT
                t.item_name,
                t.item_value,
                (FLOOR(MAX(LENGTH(t.item_name)) OVER () / 4) + 2) * 4 AS max_length
            FROM (
                SELECT
                    i.item_name,
                    core.get_item(i.item_name) AS item_value
                FROM apex_application_items i
                WHERE i.application_id      = core.get_app_id()
                UNION ALL
                SELECT
                    i.item_name,
                    core.get_item(i.item_name) AS item_value
                FROM apex_application_page_items i
                WHERE i.application_id      = core.get_app_id()
                    AND i.page_id           = core.get_page_id()
            ) t
            WHERE t.item_value IS NOT NULL
            ORDER BY 1
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('  ' || RPAD(c.item_name || ' ', c.max_length, '.') || ' ' || c.item_value);
        END LOOP;
        --
        DBMS_OUTPUT.PUT_LINE('--');
    END;



    PROCEDURE set_action (
        in_action_name          VARCHAR2,
        in_module_name          VARCHAR2        := NULL
    )
    AS
    BEGIN
        core.log_start (
            'action_name',  in_action_name,
            'module_name',  in_module_name
        );
        --
        IF in_module_name IS NOT NULL THEN
            DBMS_APPLICATION_INFO.SET_MODULE(in_module_name, in_action_name);   -- USERENV.MODULE, USERENV.ACTION
        END IF;
        --
        IF in_action_name IS NOT NULL THEN
            DBMS_APPLICATION_INFO.SET_ACTION(in_action_name);                   -- USERENV.ACTION
        END IF;
    END;



    FUNCTION get_session_id
    RETURN NUMBER
    AS
    BEGIN
        RETURN SYS_CONTEXT('APEX$SESSION', 'APP_SESSION');  -- APEX_APPLICATION.G_INSTANCE
    END;



    FUNCTION get_workspace
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN NULLIF(APEX_UTIL.FIND_WORKSPACE(APEX_CUSTOM_AUTH.GET_SECURITY_GROUP_ID()), 'Unknown');
    END;



    FUNCTION get_client_id (
        in_user_id              VARCHAR2        := NULL
    )
    RETURN VARCHAR2
    AS
    BEGIN
        -- mimic APEX client_id
        RETURN
            COALESCE(in_user_id, core.get_user_id()) || ':' ||
            COALESCE(core.get_session_id(), SYS_CONTEXT('USERENV', 'SESSIONID')
        );
    END;



    FUNCTION get_env
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN COALESCE (
            core_custom.get_env(),
            SYS_CONTEXT('USERENV', 'SERVER_HOST') || '/' || SYS_CONTEXT('USERENV', 'INSTANCE_NAME')
        );
    END;



    FUNCTION get_page_id
    RETURN NUMBER
    AS
    BEGIN
        RETURN APEX_APPLICATION.G_FLOW_STEP_ID;
    END;



    FUNCTION get_page_is_modal (
        in_page_id              NUMBER      := NULL,
        in_app_id               NUMBER      := NULL
    )
    RETURN CHAR
    AS
        out_flag                CHAR;
    BEGIN
        SELECT 'Y' INTO out_flag
        FROM apex_application_pages p
        WHERE p.application_id      = COALESCE(in_app_id, core.get_app_id())
            AND p.page_id           = COALESCE(in_page_id, core.get_page_id())
            AND p.page_mode         != 'Normal';
        --
        RETURN out_flag;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    FUNCTION get_page_group (
        in_page_id              NUMBER      := NULL,
        in_app_id               NUMBER      := NULL
    )
    RETURN apex_application_pages.page_group%TYPE
    AS
        out_name                apex_application_pages.page_group%TYPE;
    BEGIN
        SELECT p.page_group INTO out_name
        FROM apex_application_pages p
        WHERE p.application_id      = COALESCE(in_app_id,  core.get_app_id())
            AND p.page_id           = COALESCE(in_page_id, core.get_page_id());
        --
        RETURN out_name;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    FUNCTION get_page_name (
        in_page_id              NUMBER      := NULL,
        in_app_id               NUMBER      := NULL,
        in_name                 VARCHAR2    := NULL,
        in_replace              CHAR        := NULL
    )
    RETURN VARCHAR2
    AS
        v_name          VARCHAR2(2000)      := in_name;
        v_search        VARCHAR2(2000);
    BEGIN
        IF v_name IS NULL THEN
            BEGIN
                SELECT p.page_name INTO v_name
                FROM apex_application_pages p
                WHERE p.application_id      = COALESCE(in_app_id,   core.get_app_id())
                    AND p.page_id           = COALESCE(in_page_id,  core.get_page_id());
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN NULL;
            END;
        END IF;

        -- transform icons
        FOR i IN 1 .. NVL(REGEXP_COUNT(v_name, '(#fa-)'), 0) + 1 LOOP
            v_search  := REGEXP_SUBSTR(v_name, '(#fa-[[:alnum:]+_-]+\s*)+');
            v_name    := REPLACE (
                v_name,
                v_search,
                ' &' || 'nbsp; <span class="fa' || REPLACE(REPLACE(v_search, '#fa-', '+'), '+', ' fa-') || '"></span> &' || 'nbsp; '
            );
        END LOOP;

        -- replace page items with values
        IF in_replace IS NOT NULL THEN
            v_name := REPLACE(v_name, '&' || 'APP_NAME.', core.get_app_name(COALESCE(in_app_id, core.get_context_app())));
            v_name := APEX_PLUGIN_UTIL.REPLACE_SUBSTITUTIONS(v_name);
        END IF;
        --
        RETURN REGEXP_REPLACE(v_name, '((^\s*&' || 'nbsp;\s*)|(\s*&' || 'nbsp;\s*$))', '');  -- trim hard spaces
    END;



    FUNCTION get_page_title (
        in_page_id              NUMBER      := NULL,
        in_app_id               NUMBER      := NULL,
        in_title                VARCHAR2    := NULL
    )
    RETURN VARCHAR2
    AS
        out_title               apex_application_pages.page_title%TYPE      := in_title;
    BEGIN
        IF out_title IS NULL THEN
            SELECT p.page_title INTO out_title
            FROM apex_application_pages p
            WHERE p.application_id      = COALESCE(in_app_id, core.get_app_id())
                AND p.page_id           = COALESCE(in_page_id, core.get_page_id());
        END IF;
        --
        RETURN out_title;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    FUNCTION get_page_url (
        in_page_id              NUMBER      := NULL,
        in_app_id               NUMBER      := NULL,
        in_names                VARCHAR2    := NULL,
        in_values               VARCHAR2    := NULL,
        in_overload             VARCHAR2    := NULL,    -- JSON object to overload passed items/values
        in_session_id           NUMBER      := NULL,
        in_reset                CHAR        := 'Y',     -- reset page items
        in_plain                CHAR        := 'Y'      -- remove JS
    )
    RETURN VARCHAR2
    AS
        out_names               VARCHAR2(32767) := in_names;
        out_values              VARCHAR2(32767) := in_values;
    BEGIN
        -- autofill missing values
        IF in_names IS NOT NULL AND in_values IS NULL THEN
            FOR c IN (
                SELECT item_name
                FROM (
                    SELECT DISTINCT REGEXP_SUBSTR(in_names, '[^,]+', 1, LEVEL) AS item_name, LEVEL AS order#
                    FROM DUAL
                    CONNECT BY LEVEL <= REGEXP_COUNT(in_names, ',') + 1
                )
                ORDER BY order# DESC
            ) LOOP
                out_values := core.get_item(c.item_name) || ',' || out_values;
            END LOOP;
        END IF;

        -- generate url
        RETURN APEX_PAGE.GET_URL (
            p_application       => in_app_id,
            p_session           => COALESCE(in_session_id, core.get_session_id()),
            p_page              => COALESCE(in_page_id, core.get_page_id()),
            p_clear_cache       => CASE WHEN in_reset = 'Y' THEN COALESCE(in_page_id, core.get_page_id()) END,
            p_items             => out_names,
            p_values            => NULLIF(out_values, 'NULL'),
            /*
            p_request            IN VARCHAR2 DEFAULT NULL,
            p_debug              IN VARCHAR2 DEFAULT NULL,
            p_printer_friendly   IN VARCHAR2 DEFAULT NULL,
            p_trace              IN VARCHAR2 DEFAULT NULL,
            p_triggering_element IN VARCHAR2 DEFAULT 'this',
            p_plain_url          IN BOOLEAN DEFAULT FALSE
            */
            p_plain_url         => (in_plain = 'Y')
        );
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION get_request_url (
        in_arguments_only       BOOLEAN                     := FALSE
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN RTRIM(CASE WHEN NOT in_arguments_only
            THEN UTL_URL.UNESCAPE (
                OWA_UTIL.GET_CGI_ENV('SCRIPT_NAME') ||
                OWA_UTIL.GET_CGI_ENV('PATH_INFO')   || '?'
            ) END ||
            UTL_URL.UNESCAPE(OWA_UTIL.GET_CGI_ENV('QUERY_STRING')), '?');
    EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
    END;



    FUNCTION get_request
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN APEX_APPLICATION.G_REQUEST;
    END;



    FUNCTION get_request (
        in_name                 VARCHAR2,
        in_escape               VARCHAR2    := '\'
    )
    RETURN BOOLEAN
    AS
    BEGIN
        RETURN APEX_APPLICATION.G_REQUEST LIKE in_name ESCAPE in_escape;
    END;



    FUNCTION get_icon (
        in_name                 VARCHAR2,
        in_title                VARCHAR2    := NULL,
        in_style                VARCHAR2    := NULL
    )
    RETURN VARCHAR2
    AS
        v_icon_name             VARCHAR2(64);
    BEGIN
        IF INSTR(in_name, '#fa-') > 0 THEN
            v_icon_name := REGEXP_SUBSTR(in_name, '(#fa-[a-z0-9-]+)', 1, 1, NULL, 1);
            --
        ELSIF in_name LIKE 'fa-%' THEN
            v_icon_name := in_name;
            --
        ELSE
            RETURN in_name;
        END IF;
        --
        RETURN REPLACE(in_name, v_icon_name,
            '<span class="fa ' || REPLACE(v_icon_name, '#', '') ||
            '" style="' || in_style ||
            '" title="' || in_title || '"></span>');
    END;



    FUNCTION get_grid_action
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN APEX_UTIL.GET_SESSION_STATE('APEX$ROW_STATUS');
    END;



    FUNCTION get_grid_data (
        in_column_name          VARCHAR2
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN APEX_UTIL.GET_SESSION_STATE(in_column_name);
    END;



    PROCEDURE set_grid_data (
        in_column_name          VARCHAR2,
        in_value                VARCHAR2
    )
    AS
    BEGIN
        APEX_UTIL.SET_SESSION_STATE (
            p_name      => in_column_name,
            p_value     => in_value,
            p_commit    => FALSE
        );
    END;



    FUNCTION get_item_name (
        in_name                 apex_application_page_items.item_name%TYPE,
        in_page_id              apex_application_page_items.page_id%TYPE            := NULL,
        in_app_id               apex_application_page_items.application_id%TYPE     := NULL
    )
    RETURN VARCHAR2
    AS
        v_page_id       apex_application_page_items.page_id%TYPE;
        v_item_name     apex_application_page_items.item_name%TYPE;
    BEGIN
        v_page_id       := COALESCE(in_page_id, core.get_page_id());
        v_item_name     := REPLACE(in_name, c_page_item_wild, c_page_item_prefix || TO_CHAR(v_page_id) || '_');

        -- check if page item exists
        IF APEX_CUSTOM_AUTH.APPLICATION_PAGE_ITEM_EXISTS(v_item_name) THEN
            RETURN v_item_name;
        END IF;
        --
        RETURN v_item_name;
    END;



    FUNCTION get_item (
        in_name                 VARCHAR2
    )
    RETURN VARCHAR2
    AS
        v_item_name             apex_application_page_items.item_name%TYPE;
    BEGIN
        v_item_name := core.get_item_name(in_name);

        -- check item existence to avoid hidden errors
        IF v_item_name IS NOT NULL THEN
            RETURN APEX_UTIL.GET_SESSION_STATE(v_item_name);
        END IF;
        --
        RETURN NULL;
    END;



    FUNCTION get_number_item (
        in_name                 VARCHAR2
    )
    RETURN NUMBER
    AS
    BEGIN
        RETURN TO_NUMBER(core.get_item(in_name));
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error('INVALID_NUMBER',
            'requested',    in_name,
            'name',         core.get_item(in_name)
        );
    END;



    FUNCTION get_date_item (
        in_name                 VARCHAR2,
        in_format               VARCHAR2        := NULL
    )
    RETURN DATE
    AS
        v_value VARCHAR2(256);
    BEGIN
        v_value := core.get_item(in_name);
        --
        IF v_value IS NULL THEN
            RETURN NULL;
        END IF;
        --
        RETURN core.get_date(v_value, in_format);
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error('INVALID_DATE',
            'name',     in_name,
            'value',    v_value,
            'format',   in_format
        );
    END;



    FUNCTION get_date (
        in_value                VARCHAR2,
        in_format               VARCHAR2        := NULL
    )
    RETURN DATE
    AS
        l_value                 VARCHAR2(30)    := SUBSTR(REPLACE(in_value, 'T', ' '), 1, 30);
        out_date                DATE;
    BEGIN
        IF in_value IS NULL THEN
            RETURN NULL;
        END IF;
        --
        IF in_format IS NOT NULL THEN
            out_date := TO_DATE(l_value, in_format);
        ELSE
            -- try different formats
            out_date := COALESCE (
                TO_DATE(l_value DEFAULT NULL ON CONVERSION ERROR, c_format_date_time),
                TO_DATE(l_value DEFAULT NULL ON CONVERSION ERROR, c_format_date_short),
                TO_DATE(l_value DEFAULT NULL ON CONVERSION ERROR, c_format_date),
                TO_DATE(l_value DEFAULT NULL ON CONVERSION ERROR, V('APP_NLS_DATE_FORMAT')),
                TO_DATE(l_value DEFAULT NULL ON CONVERSION ERROR, V('APP_DATE_TIME_FORMAT')),
                TO_DATE(l_value DEFAULT NULL ON CONVERSION ERROR)
            );
        END IF;
        --
        IF out_date IS NULL THEN
            core.raise_error('INVALID_DATE',
                'value',    in_value,
                'format',   in_format,
                --
                in_rollback => FALSE
            );
        END IF;
        --
        RETURN out_date;
    END;



    FUNCTION get_date (
        in_date                 DATE            := NULL,
        in_format               VARCHAR2        := NULL
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN TO_CHAR(COALESCE(in_date, SYSDATE), NVL(in_format, c_format_date));
    END;



    FUNCTION get_date_time (
        in_date                 DATE            := NULL,
        in_format               VARCHAR2        := NULL
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN TO_CHAR(COALESCE(in_date, SYSDATE), NVL(in_format, c_format_date_time));
    END;



    FUNCTION get_time_bucket (
        in_date                 DATE,
        in_interval             NUMBER
    )
    RETURN NUMBER
    DETERMINISTIC
    AS
        PRAGMA UDF;
    BEGIN
        RETURN FLOOR((in_date - TRUNC(in_date)) * 1440 / in_interval) + 1;
    END;



    FUNCTION get_duration (
        in_interval             INTERVAL DAY TO SECOND
    )
    RETURN VARCHAR2 AS
    BEGIN
        RETURN REGEXP_SUBSTR(in_interval, '(\d{2}:\d{2}:\d{2}\.\d{3})');
    END;



    FUNCTION get_duration (
        in_interval             NUMBER
    )
    RETURN VARCHAR2 AS
    BEGIN
        RETURN TO_CHAR(TRUNC(SYSDATE) + in_interval, 'HH24:MI:SS');
    END;



    FUNCTION get_duration (
        in_start                TIMESTAMP,
        in_end                  TIMESTAMP       := NULL
    )
    RETURN VARCHAR2
    AS
        v_end                   CONSTANT TIMESTAMP := SYSTIMESTAMP;  -- to prevent timezone shift, APEX_UTIL.GET_SESSION_TIME_ZONE
    BEGIN
        RETURN SUBSTR(TO_CHAR(COALESCE(in_end, v_end) - in_start), 12, 12);     -- keep 00:00:00.000
    END;



    FUNCTION get_timer (
        in_timestamp            VARCHAR2
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN REPLACE(REPLACE(
            LTRIM(REPLACE(REGEXP_REPLACE(in_timestamp, '^[^\s]\s+', ''), '+000', '')),
            '000000 ', ''),
            '.000000', '');
    END;



    FUNCTION get_local_date (
        in_utc_timestamp        DATE,
        in_timezone             VARCHAR2
    )
    RETURN DATE
    DETERMINISTIC
    AS
    BEGIN
        RETURN FROM_TZ(in_utc_timestamp, 'UTC') AT TIME ZONE in_timezone;
    END;



    FUNCTION get_utc_date (
        in_timestamp            DATE,
        in_timezone             VARCHAR2
    )
    RETURN DATE
    DETERMINISTIC
    AS
    BEGIN
        RETURN FROM_TZ(in_timestamp, in_timezone) AT TIME ZONE 'UTC';
    END;



    PROCEDURE set_item (
        in_name                 VARCHAR2,
        in_value                VARCHAR2        := NULL,
        in_if_exists            BOOLEAN         := FALSE,   -- set only if item exists
        in_throw                BOOLEAN         := FALSE    -- throw error if not found
    )
    AS
        v_item_name             apex_application_page_items.item_name%TYPE;
        v_exists                CHAR;
    BEGIN
        v_item_name := core.get_item_name(in_name);
        --
        IF v_item_name IS NULL THEN
            RETURN;
        END IF;

        -- check if item exists
        IF in_if_exists THEN
            IF v_exists IS NULL THEN
                -- check page item presence
                SELECT MAX('Y')
                INTO v_exists
                FROM apex_application_page_items t
                WHERE t.application_id  = core.get_context_app()
                    --AND t.page_id       = core.get_page_id()
                    AND t.item_name     = v_item_name;
            END IF;
            --
            IF v_exists IS NULL THEN
                -- check application item presence
                SELECT MAX('Y')
                INTO v_exists
                FROM apex_application_items t
                WHERE t.application_id  = core.get_context_app()
                    AND t.item_name     = v_item_name;
            END IF;
            --
            IF v_exists IS NULL THEN
                -- unknown page/app item, but silent mode, so not throw any error
                --RETURN;
                NULL;
            END IF;
        END IF;

        -- check if item exists
        IF in_throw AND v_exists IS NULL THEN
            core.raise_error('ITEM_MISSING',
                'name',     v_item_name,
                'value',    in_value,
                'app_id',   core.get_context_app()
            );
        END IF;

        -- set item, you cant catch exception raised on this
        IF (v_exists IS NOT NULL OR NOT in_if_exists) THEN
            APEX_UTIL.SET_SESSION_STATE (
                p_name      => v_item_name,
                p_value     => in_value,
                p_commit    => FALSE
            );
        END IF;
    END;



    PROCEDURE set_date_item (
        in_name                 VARCHAR2,
        in_value                DATE
    )
    AS
    BEGIN
        core.set_item (
            in_name             => in_name,
            in_value            => TO_CHAR(in_value, c_format_date_time)
        );
    END;



    PROCEDURE set_page_items (
        in_query                VARCHAR2,
        in_page_id              NUMBER          := NULL
    )
    AS
        l_cursor                PLS_INTEGER;
        l_refcur                SYS_REFCURSOR;
        l_items                 t_page_items;
    BEGIN
        core.log_start();

        -- process cursor
        OPEN l_refcur FOR LTRIM(RTRIM(in_query));
        --
        l_cursor    := DBMS_SQL.TO_CURSOR_NUMBER(l_refcur);
        l_items     := set_page_items__(l_cursor , in_page_id);
        --
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION set_page_items (
        in_query                VARCHAR2,
        in_page_id              NUMBER          := NULL
    )
    RETURN t_page_items PIPELINED
    AS
        l_cursor                PLS_INTEGER;
        l_refcur                SYS_REFCURSOR;
        l_items                 t_page_items;
    BEGIN
        core.log_start();

        -- process cursor
        OPEN l_refcur FOR LTRIM(RTRIM(in_query));
        --
        l_cursor    := DBMS_SQL.TO_CURSOR_NUMBER(l_refcur);
        l_items     := set_page_items__(l_cursor , in_page_id);
        --
        FOR i IN l_items.FIRST .. l_items.LAST LOOP
            PIPE ROW (l_items(i));
        END LOOP;
        --
        RETURN;
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
        RETURN;
    END;



    PROCEDURE set_page_items (
        in_cursor               SYS_REFCURSOR,
        in_page_id              NUMBER          := NULL
    )
    AS
        l_cursor                PLS_INTEGER;
        l_cloned_curs           SYS_REFCURSOR;
        l_items                 t_page_items;
    BEGIN
        core.log_start();
        --
        l_cloned_curs   := in_cursor;
        l_cursor        := get_cursor_number(l_cloned_curs);
        l_items         := set_page_items__(l_cursor , in_page_id);
        --
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION set_page_items (
        in_cursor               SYS_REFCURSOR,
        in_page_id              NUMBER          := NULL
    )
    RETURN t_page_items PIPELINED
    AS
        l_cursor                PLS_INTEGER;
        l_cloned_curs           SYS_REFCURSOR;
        l_items                 t_page_items;
    BEGIN
        core.log_start();
        --
        l_cloned_curs   := in_cursor;
        l_cursor        := get_cursor_number(l_cloned_curs);
        l_items         := set_page_items__(l_cursor , in_page_id);
        --
        FOR i IN l_items.FIRST .. l_items.LAST LOOP
            PIPE ROW (l_items(i));
        END LOOP;
        --
        RETURN;
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
        RETURN;
    END;



    FUNCTION set_page_items__ (
        io_cursor       IN OUT  PLS_INTEGER,
        in_page_id              NUMBER          := NULL
    )
    RETURN t_page_items
    AS
        l_desc          DBMS_SQL.DESC_TAB;
        l_cols          PLS_INTEGER;
        l_number        NUMBER;
        l_date          DATE;
        l_string        VARCHAR2(4000);
        --
        out_items       t_page_items        := t_page_items();
        out_item        type_page_items;
    BEGIN
        core.log_start();
        --
        -- two scenarios:
        --     1) multiple lines with 2 columns, first = item_name, second = item_value
        --     2) single row where column_name = item_name
        --

        -- get column names
        DBMS_SQL.DESCRIBE_COLUMNS(io_cursor, l_cols, l_desc);
        --
        FOR i IN 1 .. l_cols LOOP
            IF l_desc(i).col_type = DBMS_SQL.NUMBER_TYPE THEN
                DBMS_SQL.DEFINE_COLUMN(io_cursor, i, l_number);
            ELSIF l_desc(i).col_type = DBMS_SQL.DATE_TYPE THEN
                DBMS_SQL.DEFINE_COLUMN(io_cursor, i, l_date);
            ELSE
                DBMS_SQL.DEFINE_COLUMN(io_cursor, i, l_string, 4000);
            END IF;
        END LOOP;

        -- fetch data
        WHILE DBMS_SQL.FETCH_ROWS(io_cursor) > 0 LOOP
            IF l_cols = 2 AND l_desc(1).col_name LIKE '%NAME' AND l_desc(2).col_name LIKE '%VALUE' THEN
                -- scenario 1
                DBMS_SQL.COLUMN_VALUE(io_cursor, 1, out_item.column_name);
                DBMS_SQL.COLUMN_VALUE(io_cursor, 2, out_item.item_value);
                --
                out_item.item_name := CASE WHEN in_page_id IS NOT NULL THEN 'P' || in_page_id || '_' END || out_item.column_name;
                --
                core.set_item (
                    in_name     => out_item.item_name,
                    in_value    => out_item.item_value
                );
                --
                out_items.EXTEND;
                out_items(out_items.LAST) := out_item;
            ELSE
                -- scenario 2
                FOR i IN 1 .. l_cols LOOP
                    IF l_desc(i).col_type = DBMS_SQL.NUMBER_TYPE THEN
                        DBMS_SQL.COLUMN_VALUE(io_cursor, i, l_number);
                        l_string := TO_CHAR(l_number);
                    ELSIF l_desc(i).col_type = DBMS_SQL.DATE_TYPE THEN
                        DBMS_SQL.COLUMN_VALUE(io_cursor, i, l_date);
                        l_string := TO_CHAR(l_date);
                    ELSE
                        DBMS_SQL.COLUMN_VALUE(io_cursor, i, l_string);
                    END IF;

                    -- set application/page item
                    out_item.column_name    := l_desc(i).col_name;
                    out_item.item_name      := CASE WHEN in_page_id IS NOT NULL THEN 'P' || in_page_id || '_' END || l_desc(i).col_name;
                    out_item.item_value     := l_string;
                    --
                    core.set_item (
                        in_name     => out_item.item_name,
                        in_value    => out_item.item_value
                    );
                    --
                    out_items.EXTEND;
                    out_items(out_items.LAST) := out_item;
                END LOOP;
            END IF;
        END LOOP;

        -- cleanup
        close_cursor(io_cursor);
        --
        RETURN out_items;
    EXCEPTION
    WHEN OTHERS THEN
        close_cursor(io_cursor);
        core.raise_error();
    END;



    FUNCTION get_cursor_number (
        io_cursor       IN OUT  SYS_REFCURSOR
    )
    RETURN PLS_INTEGER
    AS
    BEGIN
        RETURN DBMS_SQL.TO_CURSOR_NUMBER(io_cursor);
    END;



    PROCEDURE close_cursor (
        io_cursor       IN OUT  PLS_INTEGER
    )
    AS
    BEGIN
        DBMS_SQL.CLOSE_CURSOR(io_cursor);
    EXCEPTION
    WHEN OTHERS THEN
        NULL;
    END;



    PROCEDURE clear_items
    AS
        req VARCHAR2(32767) := core.get_request_url();
    BEGIN
        -- delete page items one by one, except items passed in url (query string)
        FOR c IN (
            SELECT i.item_name
            FROM apex_application_page_items i
            WHERE i.application_id  = core.get_app_id()
                AND i.page_id       = core.get_page_id()
                AND (
                    NOT REGEXP_LIKE(req, '[:,]' || i.item_name || '[,:]')       -- for legacy
                    AND NOT REGEXP_LIKE(req, LOWER(i.item_name) || '[=&]')      -- for friendly url
                )
        ) LOOP
            core.set_item (
                in_name     => c.item_name,
                in_value    => NULL
            );
        END LOOP;
    END;



    FUNCTION get_page_items (
        in_page_id              NUMBER      := NULL,
        in_filter               VARCHAR2    := '%'
    )
    RETURN VARCHAR2
    AS
        out_payload             VARCHAR2(32767);
    BEGIN
        SELECT JSON_OBJECTAGG(t.item_name VALUE APEX_UTIL.GET_SESSION_STATE(t.item_name) ABSENT ON NULL)
        INTO out_payload
        FROM apex_application_page_items t
        WHERE t.application_id  = core.get_app_id()
            AND t.page_id       = COALESCE(in_page_id, core.get_page_id())
            AND t.item_name     LIKE in_filter;
        --
        RETURN out_payload;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    FUNCTION get_global_items (
        in_filter               VARCHAR2    := '%'
    )
    RETURN VARCHAR2
    AS
        out_payload             VARCHAR2(32767);
    BEGIN
        SELECT JSON_OBJECTAGG(t.item_name VALUE APEX_UTIL.GET_SESSION_STATE(t.item_name) ABSENT ON NULL)
        INTO out_payload
        FROM apex_application_items t
        WHERE t.application_id  = core.get_app_id()
            AND t.item_name     LIKE in_filter;
        --
        RETURN out_payload;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    PROCEDURE apply_items (
        in_items                VARCHAR2
    )
    AS
        json_keys               JSON_KEY_LIST;
    BEGIN
        IF in_items IS NULL THEN
            RETURN;
        END IF;
        --
        json_keys := JSON_OBJECT_T(in_items).get_keys();
        --
        FOR i IN 1 .. json_keys.COUNT LOOP
            BEGIN
                core.set_item(json_keys(i), JSON_VALUE(in_items, '$.' || json_keys(i)));
            EXCEPTION
            WHEN OTHERS THEN
                NULL;
            END;
        END LOOP;
    END;



    PROCEDURE create_job (
        in_job_name             VARCHAR2,
        in_statement            VARCHAR2,
        in_user_id              VARCHAR2        := NULL,
        in_app_id               NUMBER          := NULL,
        in_session_id           NUMBER          := NULL,
        in_priority             PLS_INTEGER     := NULL,
        in_schedule_name        VARCHAR2        := NULL,
        in_start_date           DATE            := NULL,
        in_enabled              BOOLEAN         := TRUE,
        in_autodrop             BOOLEAN         := TRUE,
        in_force_replace        BOOLEAN         := FALSE,
        in_context_id           NUMBER          := NULL,
        in_comments             VARCHAR2        := NULL,
        in_job_class            VARCHAR2        := NULL,
        in_job_type             VARCHAR2        := NULL
    )
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --
        v_job_name              user_scheduler_jobs.job_name%TYPE := '"' || in_job_name || '"';
        v_statement             VARCHAR2(32767);
        v_query                 VARCHAR2(32767);
    BEGIN
        -- create unique name, if there is "?" in the job name
        IF INSTR(v_job_name, '?') > 0 THEN
            v_job_name := DBMS_SCHEDULER.GENERATE_JOB_NAME(REPLACE(v_job_name, '?', ''));
        END IF;
        --
        v_statement := RTRIM(APEX_STRING.FORMAT (
            -- point of the first comment is that it will be visible in scheduler additional info
            q'!DECLARE
              !    v_id PLS_INTEGER;
              !BEGIN
              !    -- keep comment here, so it is visible in user_scheduler_job_run_details.output column
              !    DBMS_OUTPUT.PUT_LINE('#%5 | %6');
              !    --
              !    v_id := core.log_start (
              !        'job_name',   '%1',
              !        'user_id',    '%3',
              !        'app_id',     '%2',
              !        'session_id', '%4',
              !        'comment',    '%6',
              !        in_context_id => %5
              !    );
              !
              !    -- we need a valid APEX session to handle collections and other context sensitive things
              !    IF '%3' IS NOT NULL AND %2 IS NOT NULL THEN
              !        core.create_session (
              !            in_user_id      => '%3',
              !            in_app_id       => %2,
              !            in_session_id   => %4
              !        );
              !    END IF;
              !
              !    -- finally execute the requested statement
              !    %7;
              !
              !    -- mark it as finished in the log
              !    core.log_end (in_context_id => v_id);
              !EXCEPTION
              !WHEN OTHERS THEN
              !    core.raise_error();
              !END;
              !',
            --
            p1  => v_job_name,                                                      -- job_name
            p2  => NVL(TO_CHAR(COALESCE(in_app_id, core.get_app_id())), 'NULL'),    -- app_id
            p3  => in_user_id,                                                      -- user_id
            p4  => NVL(TO_CHAR(in_session_id), 'NULL'),                             -- session_id
            p5  => NVL(TO_CHAR(in_context_id), 'NULL'),                             -- context_id
            p6  => in_comments,                                                     -- comments
            p7  => REGEXP_REPLACE(in_statement, '(\s*;\s*)$', ''),                  -- statement
            --
            p_max_length    => 32767,
            p_prefix        => '!'
        ));
        --
        core.log_start (
            'job_name',     v_job_name,
            'comments',     in_comments,
            'statement',    REGEXP_REPLACE(in_statement, '(\s*;\s*)$', '') || ';',
            --
            in_context_id   => in_context_id,
            in_payload      => v_statement
        );

        -- if we are going to use the same name, kill and drop previous job
        IF in_force_replace THEN
            stop_job (
                in_job_name => v_job_name
            );
            --
            drop_job (
                in_job_name => v_job_name
            );
        END IF;

        -- either run on schedule or at specified date
        -- https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_SCHEDULER.html#GUID-7E744D62-13F6-40E9-91F0-1569E6C38BBC
        BEGIN
            v_query := APEX_STRING.FORMAT(
                q'!BEGIN DBMS_SCHEDULER.CREATE_JOB (
                  !  job_name      => '%1',
                  !  job_type      => '%2',
                  !  job_action    => '%3',
                  !  job_class     => '%4',
                  !  %5            => %6,
                  !  enabled       => FALSE,
                  !  auto_drop     => %8,
                  !  comments      => '%9'
                  !);
                  !END;
                  !',
                p1  => v_job_name,
                p2  => NVL(in_job_type, 'PLSQL_BLOCK'),
                p3  => REPLACE(v_statement, '''', ''''''),
                p4  => NVL(in_job_class, 'DEFAULT_JOB_CLASS'),
                p5  => CASE WHEN in_schedule_name IS NOT NULL THEN 'schedule_name' ELSE 'start_date' END,
                p6  => CASE
                            WHEN in_schedule_name IS NOT NULL
                                THEN '''' || in_schedule_name || ''''
                            WHEN in_start_date IS NOT NULL
                                THEN 'TO_DATE(''' || TO_CHAR(in_start_date, 'YYYY-MM-DD HH24:MI:SS') || ''', ''YYYY-MM-DD HH24:MI:SS'')'
                            ELSE 'NULL' END,
                p8  => CASE WHEN in_autodrop THEN 'TRUE' ELSE 'FALSE' END,
                p9  => in_comments,
                --
                p_prefix        => '!',
                p_max_length    => 32767
            );
            --
            EXECUTE IMMEDIATE v_query;
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error (
                'CREATE_JOB_FAILED|' || v_job_name,
                'statement',    v_statement,
                'query',        v_query,
                'reason',       SQLERRM
            );
        END;
        --
        IF in_priority IS NOT NULL THEN
            DBMS_SCHEDULER.SET_ATTRIBUTE(v_job_name, 'JOB_PRIORITY', in_priority);
        END IF;
        --
        IF in_enabled THEN
            DBMS_SCHEDULER.ENABLE(v_job_name);
        END IF;
        --
        COMMIT;

        -- grant to APEX so we can drop it from APEX
        BEGIN
            EXECUTE IMMEDIATE
                'GRANT ALTER ON ' || v_job_name || ' TO APEX_PUBLIC_USER';
        EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                EXECUTE IMMEDIATE
                    'GRANT ALTER ON ' || v_job_name || ' TO ORDS_PUBLIC_USER';
            EXCEPTION
            WHEN OTHERS THEN
                core.raise_error('GRANT_FAILED');
            END;
        END;
        --
        core.log_end();
        --
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        ROLLBACK;
        core.raise_error();
    END;



    PROCEDURE stop_job (
        in_job_name             VARCHAR2,
        in_app_id               NUMBER      := NULL
    )
    AS
        v_job_name              VARCHAR2(256);
    BEGIN
        v_job_name := CASE
            WHEN INSTR(in_job_name, '.') = 0 AND in_app_id > 0
                THEN get_app_owner() || '.'
                END || in_job_name;
        --
        DBMS_SCHEDULER.STOP_JOB (
            job_name    => v_job_name,
            force       => TRUE
        );
        --
    EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE NOT IN (
            -27475      -- ORA-27475 uknown job
        ) THEN
            NULL;--core.raise_error('STOP_JOB', v_job_name, in_concat => TRUE);
        END IF;
    END;



    PROCEDURE drop_job (
        in_job_name             VARCHAR2,
        in_app_id               NUMBER      := NULL
    )
    AS
        v_job_name              VARCHAR2(256);
    BEGIN
        v_job_name := CASE
            WHEN INSTR(in_job_name, '.') = 0 AND in_app_id > 0
                THEN get_app_owner() || '.'
                END || in_job_name;
        --
        DBMS_SCHEDULER.DROP_JOB (
            job_name    => v_job_name,
            force       => TRUE
        );
        --
    EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE NOT IN (
            -27475      -- ORA-27475 uknown job
        ) THEN
            NULL;--core.raise_error('DROP_JOB', v_job_name, in_concat => TRUE);
        END IF;
    END;



    PROCEDURE run_job (
        in_job_name             VARCHAR2,
        in_app_id               NUMBER      := NULL
    )
    AS
        v_job_name              VARCHAR2(256);
    BEGIN
        v_job_name := CASE
            WHEN INSTR(in_job_name, '.') = 0 AND in_app_id > 0
                THEN get_app_owner() || '.'
                END || in_job_name;
        --
        DBMS_SCHEDULER.RUN_JOB (
            job_name            => v_job_name,
            use_current_session => FALSE
        );
        --
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error('RUN_JOB', v_job_name, in_concat => TRUE);
    END;



    FUNCTION get_arguments (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_as_list              BOOLEAN     := FALSE
    )
    RETURN VARCHAR2
    AS
        v_obj                   JSON_OBJECT_T;
    BEGIN
        -- construct a list of arguments
        IF in_as_list THEN
            RETURN NULLIF(REGEXP_REPLACE(
                REGEXP_REPLACE(
                    NULLIF(JSON_ARRAY(
                        in_name01, in_value01,
                        in_name02, in_value02,
                        in_name03, in_value03,
                        in_name04, in_value04,
                        in_name05, in_value05,
                        in_name06, in_value06,
                        in_name07, in_value07,
                        in_name08, in_value08,
                        in_name09, in_value09,
                        in_name10, in_value10,
                        in_name11, in_value11,
                        in_name12, in_value12,
                        in_name13, in_value13,
                        in_name14, in_value14,
                        in_name15, in_value15,
                        in_name16, in_value16,
                        in_name17, in_value17,
                        in_name18, in_value18,
                        in_name19, in_value19,
                        in_name20, in_value20
                        NULL ON NULL),
                        '[]'),
                    '"(\d+)([.,]\d+)?"', '\1\2'  -- convert to numbers if possible
                ),
                '(,null)+\]$', ']'),  -- strip NULLs from the right side
                '[null]');
        END IF;

        -- construct a key-value pairs
        v_obj := JSON_OBJECT_T(JSON_OBJECT (
            NVL(in_name01, '__') VALUE in_value01,
            NVL(in_name02, '__') VALUE in_value02,
            NVL(in_name03, '__') VALUE in_value03,
            NVL(in_name04, '__') VALUE in_value04,
            NVL(in_name05, '__') VALUE in_value05,
            NVL(in_name06, '__') VALUE in_value06,
            NVL(in_name07, '__') VALUE in_value07,
            NVL(in_name08, '__') VALUE in_value08,
            NVL(in_name09, '__') VALUE in_value09,
            NVL(in_name10, '__') VALUE in_value10,
            NVL(in_name11, '__') VALUE in_value11,
            NVL(in_name12, '__') VALUE in_value12,
            NVL(in_name13, '__') VALUE in_value13,
            NVL(in_name14, '__') VALUE in_value14,
            NVL(in_name15, '__') VALUE in_value15,
            NVL(in_name16, '__') VALUE in_value16,
            NVL(in_name17, '__') VALUE in_value17,
            NVL(in_name18, '__') VALUE in_value18,
            NVL(in_name19, '__') VALUE in_value19,
            NVL(in_name20, '__') VALUE in_value20 NULL ON NULL  -- keep NULL values
        ));
        --
        v_obj.REMOVE('__');     -- remove empty pairs
        --
        RETURN REGEXP_REPLACE(
            NULLIF(v_obj.STRINGIFY, '{}'),
            '"(\d+)([.,]\d+)?"', '\1\2'  -- convert to numbers if possible
        );
    END;



    PROCEDURE raise_error (
        in_message              VARCHAR2    := NULL,            -- message for user, translatable
        --
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,
        in_payload              CLOB        := NULL,
        in_rollback             BOOLEAN     := FALSE,
        in_as_list              BOOLEAN     := FALSE,
        in_concat               BOOLEAN     := FALSE
    )
    AS
        v_caller                VARCHAR2(256);
        v_id                    NUMBER;
        v_arguments             VARCHAR2(32767);
        v_message               VARCHAR2(32767);
        v_backtrace             VARCHAR2(32767);
    BEGIN
        -- rollback transaction if requested (cant do this from trigger)
        IF in_rollback THEN
            ROLLBACK;
        END IF;

        -- construct message for user: source_procedure|message_or_source_line
        v_caller := core.get_caller_name(3, TRUE);
        --
        IF v_caller LIKE '__anonymous_block%' THEN
            v_caller := SUBSTR(''
                || 'BLOCK_P' || REGEXP_SUBSTR(SYS_CONTEXT('USERENV', 'MODULE'), ':(\d+)$', 1, 1, NULL, 1)
                || '_' || RTRIM(REGEXP_SUBSTR(SYS_CONTEXT('USERENV', 'ACTION'), ':\s*([^:]+)$', 1, 1, NULL, 1), ',')
                || ' ' || REGEXP_SUBSTR(v_caller, '(\[.*)$', 1, 1, NULL, 1), 1, 128);
        END IF;
        --
        v_message := v_caller || '|' || in_message;

        -- convert passed arguments
        IF in_concat THEN
            -- keep args concatenated in the message
            v_message := SUBSTR(v_message || '|' || in_name01,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value01, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name02,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value02, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name03,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value03, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name04,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value04, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name05,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value05, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name06,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value06, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name07,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value07, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name08,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value08, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name09,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value09, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name10,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value10, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name11,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value11, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name12,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value12, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name13,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value13, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name14,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value14, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name15,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value15, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name16,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value16, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name17,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value17, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name18,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value18, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name19,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value19, 1, 32767);
            v_message := SUBSTR(v_message || '|' || in_name20,  1, 32767);      v_message := SUBSTR(v_message || '|' || in_value20, 1, 32767);
            --
            v_message := RTRIM(v_message, '|');
        ELSE
            -- pass arguments either as JSON object or JSON array
            v_arguments := core.get_arguments (
                in_name01       => in_name01,       in_value01  => in_value01,
                in_name02       => in_name02,       in_value02  => in_value02,
                in_name03       => in_name03,       in_value03  => in_value03,
                in_name04       => in_name04,       in_value04  => in_value04,
                in_name05       => in_name05,       in_value05  => in_value05,
                in_name06       => in_name06,       in_value06  => in_value06,
                in_name07       => in_name07,       in_value07  => in_value07,
                in_name08       => in_name08,       in_value08  => in_value08,
                in_name09       => in_name09,       in_value09  => in_value09,
                in_name10       => in_name10,       in_value10  => in_value10,
                in_name11       => in_name11,       in_value11  => in_value11,
                in_name12       => in_name12,       in_value12  => in_value12,
                in_name13       => in_name13,       in_value13  => in_value13,
                in_name14       => in_name14,       in_value14  => in_value14,
                in_name15       => in_name15,       in_value15  => in_value15,
                in_name16       => in_name16,       in_value16  => in_value16,
                in_name17       => in_name17,       in_value17  => in_value17,
                in_name18       => in_name18,       in_value18  => in_value18,
                in_name19       => in_name19,       in_value19  => in_value19,
                in_name20       => in_name20,       in_value20  => in_value20,
                in_as_list      => in_as_list
            );
        END IF;

        -- log raised error
        v_id := core.log__ (
            in_type             => core.flag_error,
            in_message          => v_message,
            in_arguments        => v_arguments,
            in_payload          => in_payload,
            in_context_id       => in_context_id,
            in_caller           => v_caller
        );

        -- append #log_id, args and error message
        v_message := SUBSTR(v_message
            || NULLIF(' #' || TO_CHAR(v_id) || '', ' #')
            || CASE WHEN NULLIF(v_arguments, '{}') IS NOT NULL THEN CHR(10) || '^ARGS: ' || v_arguments END
            || CASE WHEN SQLERRM NOT LIKE 'ORA-0000:%'         THEN CHR(10) || '^ERR: '  || SQLERRM END
            || CHR(10) || '-- ',
            1, 32767);

        -- add backtrace to the message (in debug mode) to quickly find the problem
        IF core.is_developer() THEN
            v_backtrace := get_shorter_stack(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            IF v_backtrace IS NOT NULL THEN
                v_backtrace := SUBSTR(CHR(10) || '^BACKTRACE: ' || v_backtrace, 1, 32767);
            END IF;
        END IF;
        --
        RAISE_APPLICATION_ERROR (
            core.app_exception_code,
            REPLACE(v_message || REPLACE(v_backtrace, '"', ''), '&' || 'quot;', ''),
            TRUE
        );
    END;



    FUNCTION log__ (
        in_type                 CHAR,
        in_message              VARCHAR2,
        in_arguments            VARCHAR2,
        in_payload              CLOB        := NULL,
        in_context_id           NUMBER      := NULL,
        in_caller               VARCHAR2    := NULL
    )
    RETURN NUMBER
    AS
        v_caller                VARCHAR2(256);
        v_message               VARCHAR2(32767);
    BEGIN
        -- construct message for user: source_procedure|message_or_source_line
        v_caller    := COALESCE(in_caller, core.get_caller_name(5, TRUE));
        v_message   := COALESCE(in_message, REGEXP_REPLACE(v_caller, '\[\d+\]', '') || '|' || REGEXP_SUBSTR(v_caller, '\[(\d+)\]', 1, 1, NULL, 1));
        --
        RETURN core_custom.log__ (
            in_type         => in_type,
            in_message      => v_message,
            in_arguments    => in_arguments,
            in_payload      => in_payload,
            in_context_id   => in_context_id,
            --
            in_app_id       => core.get_app_id(),
            in_page_id      => core.get_page_id(),
            in_user_id      => core.get_user_id(),
            in_session_id   => core.get_session_id(),
            --
            in_caller       => v_caller,
            in_backtrace    => CASE WHEN SQLCODE != 0 THEN core.get_shorter_stack(core.get_error_stack()) END,
            in_callstack    => CASE WHEN (SQLCODE != 0 OR in_type IN (flag_error, flag_warning)) THEN core.get_shorter_stack(core.get_call_stack()) END
        );
        --
    EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('-- NOT LOGGED ERROR:');
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_STACK);
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_CALL_STACK);
        DBMS_OUTPUT.PUT_LINE('-- ^');
        --
        RAISE_APPLICATION_ERROR(core.app_exception_code, 'LOG_FAILED|' || SQLERRM, TRUE);
    END;



    FUNCTION log_error (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,
        in_payload              CLOB        := NULL,
        in_as_list              BOOLEAN     := FALSE
    )
    RETURN NUMBER
    AS
        v_arguments             VARCHAR2(32767);
    BEGIN
        -- convert passed arguments
        v_arguments := core.get_arguments (
            in_name01       => in_name01,       in_value01  => in_value01,
            in_name02       => in_name02,       in_value02  => in_value02,
            in_name03       => in_name03,       in_value03  => in_value03,
            in_name04       => in_name04,       in_value04  => in_value04,
            in_name05       => in_name05,       in_value05  => in_value05,
            in_name06       => in_name06,       in_value06  => in_value06,
            in_name07       => in_name07,       in_value07  => in_value07,
            in_name08       => in_name08,       in_value08  => in_value08,
            in_name09       => in_name09,       in_value09  => in_value09,
            in_name10       => in_name10,       in_value10  => in_value10,
            in_name11       => in_name11,       in_value11  => in_value11,
            in_name12       => in_name12,       in_value12  => in_value12,
            in_name13       => in_name13,       in_value13  => in_value13,
            in_name14       => in_name14,       in_value14  => in_value14,
            in_name15       => in_name15,       in_value15  => in_value15,
            in_name16       => in_name16,       in_value16  => in_value16,
            in_name17       => in_name17,       in_value17  => in_value17,
            in_name18       => in_name18,       in_value18  => in_value18,
            in_name19       => in_name19,       in_value19  => in_value19,
            in_name20       => in_name20,       in_value20  => in_value20,
            in_as_list      => in_as_list
        );
        --
        RETURN core.log__ (
            in_type         => core.flag_error,
            in_message      => NULL,
            in_arguments    => v_arguments,
            in_payload      => in_payload,
            in_context_id   => in_context_id
        );
    END;



    PROCEDURE log_error (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,
        in_payload              CLOB        := NULL,
        in_as_list              BOOLEAN     := FALSE
    )
    AS
        v_id NUMBER;
    BEGIN
        v_id := core.log_error (
            in_name01       => in_name01,       in_value01  => in_value01,
            in_name02       => in_name02,       in_value02  => in_value02,
            in_name03       => in_name03,       in_value03  => in_value03,
            in_name04       => in_name04,       in_value04  => in_value04,
            in_name05       => in_name05,       in_value05  => in_value05,
            in_name06       => in_name06,       in_value06  => in_value06,
            in_name07       => in_name07,       in_value07  => in_value07,
            in_name08       => in_name08,       in_value08  => in_value08,
            in_name09       => in_name09,       in_value09  => in_value09,
            in_name10       => in_name10,       in_value10  => in_value10,
            in_name11       => in_name11,       in_value11  => in_value11,
            in_name12       => in_name12,       in_value12  => in_value12,
            in_name13       => in_name13,       in_value13  => in_value13,
            in_name14       => in_name14,       in_value14  => in_value14,
            in_name15       => in_name15,       in_value15  => in_value15,
            in_name16       => in_name16,       in_value16  => in_value16,
            in_name17       => in_name17,       in_value17  => in_value17,
            in_name18       => in_name18,       in_value18  => in_value18,
            in_name19       => in_name19,       in_value19  => in_value19,
            in_name20       => in_name20,       in_value20  => in_value20,
            --
            in_context_id   => in_context_id,
            in_payload      => in_payload,
            in_as_list      => in_as_list
        );
    END;



    FUNCTION log_warning (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,
        in_payload              CLOB        := NULL,
        in_as_list              BOOLEAN     := FALSE
    )
    RETURN NUMBER
    AS
        v_arguments             VARCHAR2(32767);
    BEGIN
        -- convert passed arguments
        v_arguments := core.get_arguments (
            in_name01       => in_name01,       in_value01  => in_value01,
            in_name02       => in_name02,       in_value02  => in_value02,
            in_name03       => in_name03,       in_value03  => in_value03,
            in_name04       => in_name04,       in_value04  => in_value04,
            in_name05       => in_name05,       in_value05  => in_value05,
            in_name06       => in_name06,       in_value06  => in_value06,
            in_name07       => in_name07,       in_value07  => in_value07,
            in_name08       => in_name08,       in_value08  => in_value08,
            in_name09       => in_name09,       in_value09  => in_value09,
            in_name10       => in_name10,       in_value10  => in_value10,
            in_name11       => in_name11,       in_value11  => in_value11,
            in_name12       => in_name12,       in_value12  => in_value12,
            in_name13       => in_name13,       in_value13  => in_value13,
            in_name14       => in_name14,       in_value14  => in_value14,
            in_name15       => in_name15,       in_value15  => in_value15,
            in_name16       => in_name16,       in_value16  => in_value16,
            in_name17       => in_name17,       in_value17  => in_value17,
            in_name18       => in_name18,       in_value18  => in_value18,
            in_name19       => in_name19,       in_value19  => in_value19,
            in_name20       => in_name20,       in_value20  => in_value20,
            in_as_list      => in_as_list
        );
        --
        RETURN core.log__ (
            in_type         => core.flag_warning,
            in_message      => NULL,
            in_arguments    => v_arguments,
            in_payload      => in_payload,
            in_context_id   => in_context_id
        );
    END;



    PROCEDURE log_warning (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,
        in_payload              CLOB        := NULL,
        in_as_list              BOOLEAN     := FALSE
    )
    AS
        v_id NUMBER;
    BEGIN
        v_id := core.log_warning (
            in_name01       => in_name01,       in_value01  => in_value01,
            in_name02       => in_name02,       in_value02  => in_value02,
            in_name03       => in_name03,       in_value03  => in_value03,
            in_name04       => in_name04,       in_value04  => in_value04,
            in_name05       => in_name05,       in_value05  => in_value05,
            in_name06       => in_name06,       in_value06  => in_value06,
            in_name07       => in_name07,       in_value07  => in_value07,
            in_name08       => in_name08,       in_value08  => in_value08,
            in_name09       => in_name09,       in_value09  => in_value09,
            in_name10       => in_name10,       in_value10  => in_value10,
            in_name11       => in_name11,       in_value11  => in_value11,
            in_name12       => in_name12,       in_value12  => in_value12,
            in_name13       => in_name13,       in_value13  => in_value13,
            in_name14       => in_name14,       in_value14  => in_value14,
            in_name15       => in_name15,       in_value15  => in_value15,
            in_name16       => in_name16,       in_value16  => in_value16,
            in_name17       => in_name17,       in_value17  => in_value17,
            in_name18       => in_name18,       in_value18  => in_value18,
            in_name19       => in_name19,       in_value19  => in_value19,
            in_name20       => in_name20,       in_value20  => in_value20,
            --
            in_context_id   => in_context_id,
            in_payload      => in_payload,
            in_as_list      => in_as_list
        );
    END;



    FUNCTION log_debug (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,
        in_payload              CLOB        := NULL,
        in_as_list              BOOLEAN     := FALSE
    )
    RETURN NUMBER
    AS
        v_arguments             VARCHAR2(32767);
    BEGIN
        -- convert passed arguments
        v_arguments := core.get_arguments (
            in_name01       => in_name01,       in_value01  => in_value01,
            in_name02       => in_name02,       in_value02  => in_value02,
            in_name03       => in_name03,       in_value03  => in_value03,
            in_name04       => in_name04,       in_value04  => in_value04,
            in_name05       => in_name05,       in_value05  => in_value05,
            in_name06       => in_name06,       in_value06  => in_value06,
            in_name07       => in_name07,       in_value07  => in_value07,
            in_name08       => in_name08,       in_value08  => in_value08,
            in_name09       => in_name09,       in_value09  => in_value09,
            in_name10       => in_name10,       in_value10  => in_value10,
            in_name11       => in_name11,       in_value11  => in_value11,
            in_name12       => in_name12,       in_value12  => in_value12,
            in_name13       => in_name13,       in_value13  => in_value13,
            in_name14       => in_name14,       in_value14  => in_value14,
            in_name15       => in_name15,       in_value15  => in_value15,
            in_name16       => in_name16,       in_value16  => in_value16,
            in_name17       => in_name17,       in_value17  => in_value17,
            in_name18       => in_name18,       in_value18  => in_value18,
            in_name19       => in_name19,       in_value19  => in_value19,
            in_name20       => in_name20,       in_value20  => in_value20,
            in_as_list      => in_as_list
        );
        --
        RETURN core.log__ (
            in_type         => core.flag_debug,
            in_message      => NULL,
            in_arguments    => v_arguments,
            in_payload      => in_payload,
            in_context_id   => in_context_id
        );
    END;



    PROCEDURE log_debug (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,
        in_payload              CLOB        := NULL,
        in_as_list              BOOLEAN     := FALSE
    )
    AS
        v_id NUMBER;
    BEGIN
        v_id := core.log_debug (
            in_name01       => in_name01,       in_value01  => in_value01,
            in_name02       => in_name02,       in_value02  => in_value02,
            in_name03       => in_name03,       in_value03  => in_value03,
            in_name04       => in_name04,       in_value04  => in_value04,
            in_name05       => in_name05,       in_value05  => in_value05,
            in_name06       => in_name06,       in_value06  => in_value06,
            in_name07       => in_name07,       in_value07  => in_value07,
            in_name08       => in_name08,       in_value08  => in_value08,
            in_name09       => in_name09,       in_value09  => in_value09,
            in_name10       => in_name10,       in_value10  => in_value10,
            in_name11       => in_name11,       in_value11  => in_value11,
            in_name12       => in_name12,       in_value12  => in_value12,
            in_name13       => in_name13,       in_value13  => in_value13,
            in_name14       => in_name14,       in_value14  => in_value14,
            in_name15       => in_name15,       in_value15  => in_value15,
            in_name16       => in_name16,       in_value16  => in_value16,
            in_name17       => in_name17,       in_value17  => in_value17,
            in_name18       => in_name18,       in_value18  => in_value18,
            in_name19       => in_name19,       in_value19  => in_value19,
            in_name20       => in_name20,       in_value20  => in_value20,
            --
            in_context_id   => in_context_id,
            in_payload      => in_payload,
            in_as_list      => in_as_list
        );
    END;



    FUNCTION log_start (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,
        in_payload              CLOB        := NULL,
        in_as_list              BOOLEAN     := FALSE
    )
    RETURN NUMBER
    AS
        v_arguments             VARCHAR2(32767);
    BEGIN
        -- convert passed arguments
        v_arguments := core.get_arguments (
            in_name01       => in_name01,       in_value01  => in_value01,
            in_name02       => in_name02,       in_value02  => in_value02,
            in_name03       => in_name03,       in_value03  => in_value03,
            in_name04       => in_name04,       in_value04  => in_value04,
            in_name05       => in_name05,       in_value05  => in_value05,
            in_name06       => in_name06,       in_value06  => in_value06,
            in_name07       => in_name07,       in_value07  => in_value07,
            in_name08       => in_name08,       in_value08  => in_value08,
            in_name09       => in_name09,       in_value09  => in_value09,
            in_name10       => in_name10,       in_value10  => in_value10,
            in_name11       => in_name11,       in_value11  => in_value11,
            in_name12       => in_name12,       in_value12  => in_value12,
            in_name13       => in_name13,       in_value13  => in_value13,
            in_name14       => in_name14,       in_value14  => in_value14,
            in_name15       => in_name15,       in_value15  => in_value15,
            in_name16       => in_name16,       in_value16  => in_value16,
            in_name17       => in_name17,       in_value17  => in_value17,
            in_name18       => in_name18,       in_value18  => in_value18,
            in_name19       => in_name19,       in_value19  => in_value19,
            in_name20       => in_name20,       in_value20  => in_value20,
            in_as_list      => in_as_list
        );
        --
        RETURN core.log__ (
            in_type         => core.flag_start,
            in_message      => NULL,
            in_arguments    => v_arguments,
            in_payload      => in_payload,
            in_context_id   => in_context_id
        );
    END;



    PROCEDURE log_start (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,
        in_payload              CLOB        := NULL,
        in_as_list              BOOLEAN     := FALSE
    )
    AS
        v_id NUMBER;
    BEGIN
        v_id := core.log_start (
            in_name01       => in_name01,       in_value01  => in_value01,
            in_name02       => in_name02,       in_value02  => in_value02,
            in_name03       => in_name03,       in_value03  => in_value03,
            in_name04       => in_name04,       in_value04  => in_value04,
            in_name05       => in_name05,       in_value05  => in_value05,
            in_name06       => in_name06,       in_value06  => in_value06,
            in_name07       => in_name07,       in_value07  => in_value07,
            in_name08       => in_name08,       in_value08  => in_value08,
            in_name09       => in_name09,       in_value09  => in_value09,
            in_name10       => in_name10,       in_value10  => in_value10,
            in_name11       => in_name11,       in_value11  => in_value11,
            in_name12       => in_name12,       in_value12  => in_value12,
            in_name13       => in_name13,       in_value13  => in_value13,
            in_name14       => in_name14,       in_value14  => in_value14,
            in_name15       => in_name15,       in_value15  => in_value15,
            in_name16       => in_name16,       in_value16  => in_value16,
            in_name17       => in_name17,       in_value17  => in_value17,
            in_name18       => in_name18,       in_value18  => in_value18,
            in_name19       => in_name19,       in_value19  => in_value19,
            in_name20       => in_name20,       in_value20  => in_value20,
            --
            in_context_id   => in_context_id,
            in_payload      => in_payload,
            in_as_list      => in_as_list
        );
    END;



    FUNCTION log_end (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,
        in_payload              CLOB        := NULL,
        in_as_list              BOOLEAN     := FALSE
    )
    RETURN NUMBER
    AS
        v_arguments             VARCHAR2(32767);
    BEGIN
        -- convert passed arguments
        v_arguments := core.get_arguments (
            in_name01       => in_name01,       in_value01  => in_value01,
            in_name02       => in_name02,       in_value02  => in_value02,
            in_name03       => in_name03,       in_value03  => in_value03,
            in_name04       => in_name04,       in_value04  => in_value04,
            in_name05       => in_name05,       in_value05  => in_value05,
            in_name06       => in_name06,       in_value06  => in_value06,
            in_name07       => in_name07,       in_value07  => in_value07,
            in_name08       => in_name08,       in_value08  => in_value08,
            in_name09       => in_name09,       in_value09  => in_value09,
            in_name10       => in_name10,       in_value10  => in_value10,
            in_name11       => in_name11,       in_value11  => in_value11,
            in_name12       => in_name12,       in_value12  => in_value12,
            in_name13       => in_name13,       in_value13  => in_value13,
            in_name14       => in_name14,       in_value14  => in_value14,
            in_name15       => in_name15,       in_value15  => in_value15,
            in_name16       => in_name16,       in_value16  => in_value16,
            in_name17       => in_name17,       in_value17  => in_value17,
            in_name18       => in_name18,       in_value18  => in_value18,
            in_name19       => in_name19,       in_value19  => in_value19,
            in_name20       => in_name20,       in_value20  => in_value20,
            in_as_list      => in_as_list
        );
        --
        RETURN core.log__ (
            in_type         => core.flag_end,
            in_message      => NULL,
            in_arguments    => v_arguments,
            in_payload      => in_payload,
            in_context_id   => in_context_id
        );
    END;



    PROCEDURE log_end (
        in_name01               VARCHAR2    := NULL,            in_value01  VARCHAR2 := NULL,
        in_name02               VARCHAR2    := NULL,            in_value02  VARCHAR2 := NULL,
        in_name03               VARCHAR2    := NULL,            in_value03  VARCHAR2 := NULL,
        in_name04               VARCHAR2    := NULL,            in_value04  VARCHAR2 := NULL,
        in_name05               VARCHAR2    := NULL,            in_value05  VARCHAR2 := NULL,
        in_name06               VARCHAR2    := NULL,            in_value06  VARCHAR2 := NULL,
        in_name07               VARCHAR2    := NULL,            in_value07  VARCHAR2 := NULL,
        in_name08               VARCHAR2    := NULL,            in_value08  VARCHAR2 := NULL,
        in_name09               VARCHAR2    := NULL,            in_value09  VARCHAR2 := NULL,
        in_name10               VARCHAR2    := NULL,            in_value10  VARCHAR2 := NULL,
        in_name11               VARCHAR2    := NULL,            in_value11  VARCHAR2 := NULL,
        in_name12               VARCHAR2    := NULL,            in_value12  VARCHAR2 := NULL,
        in_name13               VARCHAR2    := NULL,            in_value13  VARCHAR2 := NULL,
        in_name14               VARCHAR2    := NULL,            in_value14  VARCHAR2 := NULL,
        in_name15               VARCHAR2    := NULL,            in_value15  VARCHAR2 := NULL,
        in_name16               VARCHAR2    := NULL,            in_value16  VARCHAR2 := NULL,
        in_name17               VARCHAR2    := NULL,            in_value17  VARCHAR2 := NULL,
        in_name18               VARCHAR2    := NULL,            in_value18  VARCHAR2 := NULL,
        in_name19               VARCHAR2    := NULL,            in_value19  VARCHAR2 := NULL,
        in_name20               VARCHAR2    := NULL,            in_value20  VARCHAR2 := NULL,
        --
        in_context_id           NUMBER      := NULL,
        in_payload              CLOB        := NULL,
        in_as_list              BOOLEAN     := FALSE
    )
    AS
        v_id NUMBER;
    BEGIN
        v_id := core.log_end (
            in_name01       => in_name01,       in_value01  => in_value01,
            in_name02       => in_name02,       in_value02  => in_value02,
            in_name03       => in_name03,       in_value03  => in_value03,
            in_name04       => in_name04,       in_value04  => in_value04,
            in_name05       => in_name05,       in_value05  => in_value05,
            in_name06       => in_name06,       in_value06  => in_value06,
            in_name07       => in_name07,       in_value07  => in_value07,
            in_name08       => in_name08,       in_value08  => in_value08,
            in_name09       => in_name09,       in_value09  => in_value09,
            in_name10       => in_name10,       in_value10  => in_value10,
            in_name11       => in_name11,       in_value11  => in_value11,
            in_name12       => in_name12,       in_value12  => in_value12,
            in_name13       => in_name13,       in_value13  => in_value13,
            in_name14       => in_name14,       in_value14  => in_value14,
            in_name15       => in_name15,       in_value15  => in_value15,
            in_name16       => in_name16,       in_value16  => in_value16,
            in_name17       => in_name17,       in_value17  => in_value17,
            in_name18       => in_name18,       in_value18  => in_value18,
            in_name19       => in_name19,       in_value19  => in_value19,
            in_name20       => in_name20,       in_value20  => in_value20,
            --
            in_context_id   => in_context_id,
            in_payload      => in_payload,
            in_as_list      => in_as_list
        );
    END;



    FUNCTION handle_apex_error (
        p_error                 APEX_ERROR.T_ERROR
    )
    RETURN APEX_ERROR.T_ERROR_RESULT
    AS
        out_result              APEX_ERROR.T_ERROR_RESULT;
        --
        --  message             varchar2(32767),            -- Displayed error message
        --  additional_info     varchar2(32767),            -- Only used for display_location ON_ERROR_PAGE to display additional error information
        --  display_location    varchar2(40),               -- Use constants "used for display_location" below
        --  page_item_name      varchar2(255),              -- Associated page item name
        --  column_alias        varchar2(255)               -- Associated tabular form column alias
        --
        v_log_id                NUMBER;                     -- log_id from your log_error function (returning most likely sequence)
        v_constraint_code       PLS_INTEGER;
        v_message               VARCHAR2(32767);
    BEGIN
        out_result := APEX_ERROR.INIT_ERROR_RESULT(p_error => p_error);
        --
        out_result.message := REPLACE(out_result.message, '&' || 'quot;', '"');  -- replace some HTML entities
        out_result.display_location := APEX_ERROR.C_INLINE_IN_NOTIFICATION;  -- also removes HTML entities

        -- get error code thown before app exception to translate constraint names
        IF p_error.ora_sqlcode = app_exception_code THEN
            v_constraint_code := 0 - TO_NUMBER(REGEXP_SUBSTR(
                REPLACE(p_error.ora_sqlerrm, 'ORA' || app_exception_code || ': ', ''),
                '^ORA-(\d+)',
                1, 1, NULL, 1));
        END IF;

        -- assign log_id sequence (app specific, probably from sequence)
        IF NVL(v_constraint_code, p_error.ora_sqlcode) IN (
            -1,     -- ORA-00001: unique constraint violated
            -2091,  -- ORA-02091: transaction rolled back (can hide a deferred constraint)
            -2290,  -- ORA-02290: check constraint violated
            -2291,  -- ORA-02291: integrity constraint violated - parent key not found
            -2292   -- ORA-02292: integrity constraint violated - child record found
        ) THEN
            -- handle constraint violations
            out_result.message := c_constraint_prefix || APEX_ERROR.EXTRACT_CONSTRAINT_NAME (
                p_error             => p_error,
                p_include_schema    => FALSE
            );
            out_result.display_location := APEX_ERROR.C_INLINE_IN_NOTIFICATION;
            --
        ELSIF NVL(v_constraint_code, p_error.ora_sqlcode) IN (
            -1400   -- ORA-01400: cannot insert NULL into...
        ) THEN
            out_result.message := c_not_null_prefix || REGEXP_SUBSTR(out_result.message, '\.["]([^"]+)["]\)', 1, 1, NULL, 1);
            --
        END IF;

        -- store incident in your log
        IF p_error.is_internal_error AND p_error.apex_error_code IN ('APEX.SESSION.EXPIRED') THEN
            -- dont log session errors
            NULL;
        ELSE
            v_log_id := core.log_error (
                'message',          out_result.message,
                'page',             TO_CHAR(APEX_APPLICATION.G_FLOW_STEP_ID),
                'component_type',   REPLACE(p_error.component.type, 'APEX_APPLICATION_', ''),
                'component_name',   p_error.component.name,
                'process_point',    RTRIM(REPLACE(SYS_CONTEXT('USERENV', 'ACTION'), 'Processes - point: ', ''), ','),
                'page_item',        out_result.page_item_name,
                'column_alias',     out_result.column_alias,
                'error',            APEX_ERROR.GET_FIRST_ORA_ERROR_TEXT(p_error => p_error),
                --
                in_payload => ''
                    || CHR(10) || '^DESCRIPTION: ' || core.get_shorter_stack(p_error.ora_sqlerrm)
                    || CHR(10) || '^STATEMENT: '   || core.get_shorter_stack(p_error.error_statement)
                    || CHR(10) || '^BACKTRACE: '   || core.get_shorter_stack(p_error.error_backtrace)
            );
        END IF;

        -- mark associated page item (when possible)
        IF out_result.page_item_name IS NULL AND out_result.column_alias IS NULL THEN
            APEX_ERROR.AUTO_SET_ASSOCIATED_ITEM (
                p_error         => p_error,
                p_error_result  => out_result
            );
        END IF;

        --
        /*
        IF p_error.ora_sqlcode = app_exception_code THEN-- AND out_result.message LIKE '%{"%' THEN
            out_result.message := NVL(REGEXP_SUBSTR(out_result.message, '({[^}]+})', 1 ,1, NULL, 1), out_result.message);
            RETURN out_result;
        END IF;
        */

        -- translate message (custom) just for user (not for the log)
        -- with APEX globalization - text messages - we can also auto add new messages there through APEX_LANG.CREATE_MESSAGE
        -- for custom table out_result.message := NVL(core.get_translated(out_result.message), out_result.message);

        -- remove error numbers
        out_result.message := RTRIM(REGEXP_REPLACE(out_result.message, '(#\d{8,}+)\s*(<br>)?(--)?\s*', ' '));

        -- translate message without the app main error code
        v_message := core.get_translated(REGEXP_REPLACE(out_result.message, '^(ORA' || TO_CHAR(app_exception_code) || ':\s*)\s*', ''));

        -- detect if message was not translated
        --IF v_message = UPPER(REGEXP_REPLACE(out_result.message, '^(ORA' || TO_CHAR(app_exception_code) || ':\s*)\s*', '')) THEN
        --    v_message := out_result.message;    -- restore original message
        --END IF;

        IF core.is_developer() THEN
            v_message := v_message
                || '<br>^APEX: {'
                || '"name":"' || p_error.component.name || '",'
                || '"type":"' || REPLACE(p_error.component.type, 'APEX_APPLICATION_', '') || '",'
                || CASE
                    WHEN out_result.page_item_name IS NOT NULL
                        THEN '"page_item":"' || out_result.page_item_name || '",'
                    END
                || CASE
                    WHEN out_result.column_alias IS NOT NULL
                        THEN '"column":"' || out_result.column_alias || '",'
                    END
                || '"point":"'  || RTRIM(REPLACE(SYS_CONTEXT('USERENV', 'ACTION'), 'Processes - point: ', ''), ',') || '"'
                || '}';
        END IF;

        -- replace some parts to make it readable
        v_message := REPLACE(REPLACE(REPLACE(v_message,
            '| ', '<br />'),
            '|', ' | '),
            '[', ' [');

        -- show only the latest error message prepended with log_id for support
        out_result.message := CASE WHEN v_log_id IS NOT NULL THEN '#' || TO_CHAR(v_log_id) || '<br>' END || v_message;
        --out_result.message := REPLACE(out_result.message, '&' || '#X27;', '');
        --
        RETURN out_result;
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error (
            in_name01       => APEX_ERROR.GET_FIRST_ORA_ERROR_TEXT(p_error => p_error)
        );
    END;



    FUNCTION get_translated (
        in_message              VARCHAR2
    )
    RETURN VARCHAR2
    AS
        v_message               VARCHAR2(32767) := in_message;
    BEGIN
        -- dont translate unexpected app errors
        IF in_message LIKE 'ORA-%' THEN
            RETURN in_message;
        END IF;

        -- whole message must match the translation
        IF REGEXP_LIKE(in_message, '^[A-Z][A-Z0-9_\.\|]+$') THEN
            v_message := APEX_LANG.MESSAGE(REGEXP_SUBSTR(in_message, '^[A-Z][A-Z0-9_\.\|]+$'));
        END IF;
        --
        IF (v_message IS NULL OR v_message = UPPER(in_message)) THEN
            RETURN in_message;
        END IF;
        --
        RETURN v_message;
    END;



    PROCEDURE set_json_message (
        in_message              VARCHAR2,
        in_type                 VARCHAR2        := NULL
    )
    AS
    BEGIN
        APEX_JSON.OPEN_OBJECT();
        APEX_JSON.WRITE('message',  in_message);
        APEX_JSON.WRITE('status',   NVL(in_type, 'SUCCESS'));   -- SUCCESS, ERROR, WARNING
        APEX_JSON.CLOSE_OBJECT();
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE refresh_mviews (
        in_name_like            VARCHAR2        := NULL,
        in_percent              NUMBER          := NULL,
        in_method               CHAR            := NULL,
        in_parallelism          NUMBER          := NULL,
        in_atomic               BOOLEAN         := FALSE
    )
    AS
    BEGIN
        FOR c IN (
            SELECT
                m.owner,
                m.mview_name
            FROM all_mviews m
            WHERE m.owner           = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
                AND (m.mview_name   LIKE in_name_like ESCAPE '\' OR in_name_like IS NULL)
            ORDER BY 1, 2
        ) LOOP
            core.log_debug (
                'owner',        c.owner,
                'name',         c.mview_name
            );
            --
            BEGIN
                DBMS_MVIEW.REFRESH (
                    list            => c.owner || '.' || c.mview_name,
                    method          => NVL(in_method, 'C'),
                    parallelism     => NVL(in_parallelism, 1),
                    atomic_refresh  => in_atomic
                );
            EXCEPTION
            WHEN OTHERS THEN
                core.raise_error('MVIEW_REFRESH_FAILED',
                    'owner',        c.owner,
                    'name',         c.mview_name
                );
            END;
            --
            IF in_percent > 0 THEN
                recalc_table_stats (
                    in_owner        => c.owner,
                    in_table_name   => c.mview_name,
                    in_percent      => in_percent
                );
            END IF;
        END LOOP;
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE recalc_table_stats (
        in_owner            VARCHAR2,
        in_table_name       VARCHAR2,
        in_percent          NUMBER
    )
    AS
    BEGIN
        core.log_debug (
            'owner',        in_owner,
            'table_name',   in_table_name,
            'percent',      in_percent
        );
        --
        IF in_percent > 0 THEN
            DBMS_STATS.GATHER_TABLE_STATS (
                ownname             => in_owner,
                tabname             => in_table_name,
                estimate_percent    => in_percent,
                granularity         => 'ALL'
            );
        END IF;
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE shrink_table (
        in_owner                VARCHAR2,
        in_table_name           VARCHAR2,
        in_drop_indexes         BOOLEAN := FALSE,
        in_row_movement         BOOLEAN := FALSE
    )
    AS
        v_indexes               VARCHAR2(32767);    -- to backup indexes
    BEGIN
        core.log_debug (
            'owner',            in_owner,
            'table_name',       in_table_name,
            'row_movement',     core.get_yn(in_row_movement),
            'drop_indexes',     core.get_yn(in_drop_indexes)
        );

        -- to shrink tables with function based indexes we have to drop them first
        IF in_drop_indexes THEN
            FOR c IN (
                SELECT i.table_name, i.index_name, DBMS_METADATA.GET_DDL('INDEX', i.index_name, in_owner) AS content
                FROM user_indexes i
                WHERE i.index_type      LIKE 'FUNCTION%'
                    AND i.table_name    = in_table_name
            ) LOOP
                -- create backup
                v_indexes := v_indexes || c.content || ';';
            END LOOP;
            --
            FOR c IN (
                SELECT i.table_name, i.index_name
                FROM user_indexes i
                WHERE i.index_type      LIKE 'FUNCTION%'
                    AND i.table_name    = in_table_name
            ) LOOP
                EXECUTE IMMEDIATE
                    'DROP INDEX ' || in_owner || '.' || c.index_name;
            END LOOP;
        END IF;

        -- we also need to enable row movement
        -- we should check if it is already enabled...
        EXECUTE IMMEDIATE 'ALTER TABLE ' || in_table_name || ' ENABLE ROW MOVEMENT';
        EXECUTE IMMEDIATE 'ALTER TABLE ' || in_table_name || ' SHRINK SPACE';
        --
        IF NOT in_row_movement THEN
            EXECUTE IMMEDIATE
                'ALTER TABLE ' || in_table_name || ' DISABLE ROW MOVEMENT';
        END IF;

        -- recreate indexes
        IF v_indexes IS NOT NULL THEN
            FOR c IN (
                WITH t AS (
                    SELECT v_indexes AS src FROM DUAL
                )
                SELECT REGEXP_SUBSTR(src, '([^;]+)', 1, LEVEL) AS col
                FROM t
                CONNECT BY REGEXP_INSTR(src, '([^;]+)', 1, LEVEL) > 0
                ORDER BY LEVEL ASC
            ) LOOP
                DBMS_OUTPUT.PUT_LINE(c.col);
                EXECUTE IMMEDIATE c.col;
            END LOOP;
        END IF;

        -- recalc stats after shrink
        --DBMS_STATS.GATHER_TABLE_STATS('' || in_owner || '', in_table_name);
        EXECUTE IMMEDIATE
            'ANALYZE TABLE ' || in_owner || '.' || in_table_name ||
            ' COMPUTE STATISTICS FOR TABLE';
        --
    EXCEPTION
    WHEN OTHERS THEN
        IF NOT in_row_movement THEN
            EXECUTE IMMEDIATE
                'ALTER TABLE ' || in_table_name || ' DISABLE ROW MOVEMENT';
        END IF;
        --
        core.raise_error();
    END;



    FUNCTION get_caller_name (
        in_offset               PLS_INTEGER     := NULL,
        in_add_line             BOOLEAN         := FALSE
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN
            UTL_CALL_STACK.CONCATENATE_SUBPROGRAM(UTL_CALL_STACK.SUBPROGRAM(NVL(in_offset, 2))) ||
            CASE WHEN in_add_line THEN '[' || UTL_CALL_STACK.UNIT_LINE( NVL(in_offset, 2)) || ']' END;
    EXCEPTION
    WHEN BAD_DEPTH THEN
        RETURN NULL;
    END;



    FUNCTION get_caller_line (
        in_offset               PLS_INTEGER     := NULL
    )
    RETURN NUMBER
    AS
    BEGIN
        RETURN UTL_CALL_STACK.UNIT_LINE(NVL(in_offset, 2));
    EXCEPTION
    WHEN BAD_DEPTH THEN
        RETURN NULL;
    END;



    FUNCTION get_hash (
        in_payload              VARCHAR2
    )
    RETURN VARCHAR2
    DETERMINISTIC
    AS
        out_ VARCHAR2(40);
    BEGIN
        -- quick hash alg, shame we need a context switch, compensate with result cache
        SELECT STANDARD_HASH(in_payload) INTO out_
        FROM DUAL;
        --
        RETURN out_;
    END;



    FUNCTION get_call_stack (
        in_offset               PLS_INTEGER     := NULL,
        in_skip_others          BOOLEAN         := FALSE,
        in_line_numbers         BOOLEAN         := TRUE,
        in_splitter             VARCHAR2        := CHR(10)
    )
    RETURN VARCHAR2
    AS
        out_stack       VARCHAR2(32767);
        out_module      VARCHAR2(2000);
    BEGIN
        -- better version of DBMS_UTILITY.FORMAT_CALL_STACK
        FOR i IN REVERSE NVL(in_offset, 2) .. UTL_CALL_STACK.DYNAMIC_DEPTH LOOP  -- 2 = ignore this function, 3 = ignore caller
            CONTINUE WHEN in_skip_others AND NVL(UTL_CALL_STACK.OWNER(i), '-') NOT IN (core.get_app_owner());
            --
            out_module  := UTL_CALL_STACK.CONCATENATE_SUBPROGRAM(UTL_CALL_STACK.SUBPROGRAM(i));
            out_stack   := out_stack || out_module || CASE WHEN in_line_numbers THEN ' [' || TO_CHAR(UTL_CALL_STACK.UNIT_LINE(i)) || ']' END || in_splitter;
        END LOOP;
        --
        RETURN out_stack;
    EXCEPTION
    WHEN BAD_DEPTH THEN
        RETURN NULL;
    END;



    FUNCTION get_error_stack
    RETURN VARCHAR2
    AS
        out_stack       VARCHAR2(32767);
    BEGIN
        -- switch NLS to get error message in english
        BEGIN
            DBMS_SESSION.SET_NLS('NLS_LANGUAGE', '''ENGLISH''');
        EXCEPTION
        WHEN OTHERS THEN    -- cant set NLS in triggers
            NULL;
        END;

        -- better version of DBMS_UTILITY.FORMAT_ERROR_STACK, FORMAT_ERROR_BACKTRACE
        FOR i IN REVERSE 1 .. UTL_CALL_STACK.ERROR_DEPTH LOOP
            BEGIN
                out_stack := out_stack ||
                    UTL_CALL_STACK.BACKTRACE_UNIT(i) || ' [' || UTL_CALL_STACK.BACKTRACE_LINE(i) || '] ' ||
                    'ORA-' || LPAD(UTL_CALL_STACK.ERROR_NUMBER(i), 5, '0') || ' ' ||
                    UTL_CALL_STACK.ERROR_MSG(i) || CHR(10);
            EXCEPTION
            WHEN BAD_DEPTH THEN
                NULL;
            END;
        END LOOP;
        --
        RETURN out_stack;
    END;



    FUNCTION get_shorter_stack (
        in_stack                VARCHAR2
    )
    RETURN VARCHAR2
    AS
        out_stack               VARCHAR2(32767);
    BEGIN
        out_stack := REPLACE(in_stack, 'WWV_FLOW', '%');
        out_stack := REGEXP_REPLACE(out_stack, 'APEX_\d{6}', '%');
        --
        out_stack := REGEXP_REPLACE(out_stack, '\s.*SQL.*\.EXEC.*\]',   '.');
        out_stack := REGEXP_REPLACE(out_stack, '\s%.*EXEC.*\]',         '.');
        out_stack := REGEXP_REPLACE(out_stack, '\s%_PROCESS.*\]',       '.');
        out_stack := REGEXP_REPLACE(out_stack, '\s%_ERROR.*\]',         '.');
        out_stack := REGEXP_REPLACE(out_stack, '\s%_SECURITY.*\]',      '.');
        out_stack := REGEXP_REPLACE(out_stack, '\sHTMLDB*\]',           '.');
        out_stack := REGEXP_REPLACE(out_stack, '\s\d+\s\[\]',           '.');
        --
        out_stack := REGEXP_REPLACE(out_stack, '\sORA-\d+.*%\.%.*EXEC.*, line \d+',             '.');
        out_stack := REGEXP_REPLACE(out_stack, '\sORA-\d+.*%\.%.*PROCESS_NATIVE.*, line \d+',   '.');
        out_stack := REGEXP_REPLACE(out_stack, '\sORA-\d+.*DBMS_(SYS_)?SQL.*, line \d+',        '.');
        --
        RETURN out_stack;
    END;



    PROCEDURE send_push_notification (
        in_title                VARCHAR2,
        in_message              VARCHAR2,
        in_user_id              VARCHAR2    := NULL,
        in_app_id               NUMBER      := NULL,
        in_target_url           VARCHAR2    := NULL,
        in_icon_url             VARCHAR2    := NULL,
        in_asap                 BOOLEAN     := TRUE
    )
    AS
        v_app_id                CONSTANT NUMBER         := COALESCE(in_app_id,  core.get_context_app());
        v_user_id               CONSTANT VARCHAR2(128)  := COALESCE(in_user_id, core.get_user_id());
    BEGIN
        -- https://docs.oracle.com/en/database/oracle/apex/23.1/aeapi/APEX_PWA.SEND_PUSH_NOTIFICATION-Procedure.html
        IF APEX_PWA.HAS_PUSH_SUBSCRIPTION (
            p_application_id    => v_app_id,
            p_user_name         => v_user_id
        ) THEN
            APEX_PWA.SEND_PUSH_NOTIFICATION (
                p_application_id    => v_app_id,
                p_user_name         => v_user_id,
                p_title             => in_title,
                p_body              => in_message,
                p_icon_url          => in_icon_url,
                p_target_url        => in_target_url
            );
            --
            IF in_asap THEN
                APEX_PWA.PUSH_QUEUE();
            END IF;
        END IF;
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE send_mail (
        in_to                   VARCHAR2,
        in_subject              VARCHAR2,
        in_body                 CLOB,
        in_cc                   VARCHAR2        := NULL,
        in_bcc                  VARCHAR2        := NULL,
        in_from                 VARCHAR2        := NULL,
        in_attach_name          VARCHAR2        := NULL,
        in_attach_mime          VARCHAR2        := NULL,
        in_attach_data          CLOB            := NULL,
        in_compress             BOOLEAN         := FALSE
    )
    AS
        smtp_from               VARCHAR2(256);
        smtp_username           VARCHAR2(256);
        smtp_password           VARCHAR2(256);
        smtp_host               VARCHAR2(256);
        smtp_port               NUMBER(4);
        smtp_timeout            NUMBER(2);
        --
        boundary                CONSTANT VARCHAR2(128)      := '-----5b9d8059445a8eb8c025f159131f02d94969a12c16363d4dec42e893b374cb85-----';
        --
        reply                   UTL_SMTP.REPLY;
        conn                    UTL_SMTP.CONNECTION;
        --
        blob_content            BLOB;
        blob_gzipped            BLOB;
        blob_amount             BINARY_INTEGER              := 6000;
        blob_offset             PLS_INTEGER                 := 1;
        buffer                  VARCHAR2(32767);
        buffer_raw              RAW(6000);                  -- must match blob_amount^
        --
        FUNCTION quote_encoding (
            in_text VARCHAR2
        )
        RETURN VARCHAR2 AS
        BEGIN
            RETURN '=?UTF-8?Q?' || REPLACE(
                UTL_RAW.CAST_TO_VARCHAR2(UTL_ENCODE.QUOTED_PRINTABLE_ENCODE(
                    UTL_RAW.CAST_TO_RAW(in_text))), '=' || UTL_TCP.CRLF, '') || '?=';
        END;
        --
        FUNCTION quote_address (
            in_address      VARCHAR2,
            in_strip_name   BOOLEAN := FALSE
        )
        RETURN VARCHAR2 AS
            in_found PLS_INTEGER;
        BEGIN
            IF in_strip_name THEN
                RETURN REGEXP_REPLACE(in_address, '.*\s?<(\S+)>$', '\1');
            ELSE
                in_found := REGEXP_INSTR(in_address, '\s?<\S+@\S+\.\S{2,6}>$');
                IF in_found > 1 THEN
                    RETURN quote_encoding(RTRIM(SUBSTR(in_address, 1, in_found))) || SUBSTR(in_address, in_found);
                ELSE
                    RETURN in_address;
                END IF;
            END IF;
        END;
        --
        PROCEDURE split_addresses (
            in_out_conn     IN OUT NOCOPY   UTL_SMTP.CONNECTION,
            in_to           IN              VARCHAR2
        )
        AS
        BEGIN
            FOR i IN (
                SELECT LTRIM(RTRIM(REGEXP_SUBSTR(in_to, '[^;,]+', 1, LEVEL))) AS address
                FROM DUAL
                CONNECT BY REGEXP_SUBSTR(in_to, '[^;,]+', 1, LEVEL) IS NOT NULL)
            LOOP
                UTL_SMTP.RCPT(in_out_conn, quote_address(i.address, TRUE));
            END LOOP;
        END;
    BEGIN
        IF (c_smtp_host IS NULL OR c_smtp_port IS NULL OR c_smtp_from IS NULL) THEN
            core.raise_error('SMTP_SETUP_MISSING');
        END IF;

        -- connect to SMTP server
        BEGIN
            reply := UTL_SMTP.OPEN_CONNECTION(c_smtp_host, NVL(c_smtp_port, 25), conn, NVL(c_smtp_timeout, 10));
        EXCEPTION
        WHEN OTHERS THEN
            core.raise_error('CONNECTION_FAILED');
            RETURN;
        END;
        --
        UTL_SMTP.HELO(conn, c_smtp_host);
        IF c_smtp_username IS NOT NULL THEN
            UTL_SMTP.COMMAND(conn, 'AUTH LOGIN');
            UTL_SMTP.COMMAND(conn, UTL_ENCODE.BASE64_ENCODE(UTL_RAW.CAST_TO_RAW(c_smtp_username)));
            IF c_smtp_password IS NOT NULL THEN
                UTL_SMTP.COMMAND(conn, UTL_ENCODE.BASE64_ENCODE(UTL_RAW.CAST_TO_RAW(c_smtp_password)));
            END IF;
        END IF;

        -- prepare headers
        UTL_SMTP.MAIL(conn, quote_address(COALESCE(c_smtp_from, core_custom.get_sender()), TRUE));

        -- handle multiple recipients
        split_addresses(conn, in_to);
        --
        IF in_cc IS NOT NULL THEN
            split_addresses(conn, in_cc);
        END IF;
        --
        IF in_bcc IS NOT NULL THEN
            split_addresses(conn, in_bcc);
        END IF;

        -- continue with headers
        UTL_SMTP.OPEN_DATA(conn);
        --
        UTL_SMTP.WRITE_DATA(conn, 'Date: '      || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || UTL_TCP.CRLF);
        UTL_SMTP.WRITE_DATA(conn, 'From: '      || quote_address(c_smtp_from) || UTL_TCP.CRLF);
        UTL_SMTP.WRITE_DATA(conn, 'To: '        || quote_address(in_to) || UTL_TCP.CRLF);
        UTL_SMTP.WRITE_DATA(conn, 'Subject: '   || quote_encoding(in_subject) || UTL_TCP.CRLF);
        UTL_SMTP.WRITE_DATA(conn, 'Reply-To: '  || quote_address(c_smtp_from) || UTL_TCP.CRLF);
        UTL_SMTP.WRITE_DATA(conn, 'MIME-Version: 1.0' || UTL_TCP.CRLF);
        UTL_SMTP.WRITE_DATA(conn, 'Content-Type: multipart/mixed; boundary="' || boundary || '"' || UTL_TCP.CRLF || UTL_TCP.CRLF);

        -- prepare body content
        IF in_body IS NOT NULL THEN
            UTL_SMTP.WRITE_DATA(conn, '--' || boundary || UTL_TCP.CRLF);
            UTL_SMTP.WRITE_DATA(conn, 'Content-Type: ' || 'text/html' || '; charset="utf-8"' || UTL_TCP.CRLF);
            UTL_SMTP.WRITE_DATA(conn, 'Content-Transfer-Encoding: base64' || UTL_TCP.CRLF || UTL_TCP.CRLF);
            --
            FOR i IN 0 .. TRUNC((DBMS_LOB.GETLENGTH(in_body) - 1) / 12000) LOOP
                UTL_SMTP.WRITE_RAW_DATA(conn, UTL_ENCODE.BASE64_ENCODE(UTL_RAW.CAST_TO_RAW(DBMS_LOB.SUBSTR(in_body, 12000, i * 12000 + 1))));
            END LOOP;
            --
            UTL_SMTP.WRITE_DATA(conn, UTL_TCP.CRLF || UTL_TCP.CRLF);
        END IF;

        -- prepare attachment
        IF in_attach_name IS NOT NULL AND in_compress THEN
            -- compress attachment
            UTL_SMTP.WRITE_DATA(conn, '--' || boundary || UTL_TCP.CRLF);
            UTL_SMTP.WRITE_DATA(conn, 'Content-Transfer-Encoding: base64' || UTL_TCP.CRLF);
            UTL_SMTP.WRITE_DATA(conn, 'Content-Type: ' || 'application/octet-stream' || UTL_TCP.CRLF);
            UTL_SMTP.WRITE_DATA(conn, 'Content-Disposition: attachment; filename="' || in_attach_name || '.gz"' || UTL_TCP.CRLF || UTL_TCP.CRLF);
            --
            blob_content := core.clob_to_blob(in_attach_data);
            DBMS_LOB.CREATETEMPORARY(blob_gzipped, TRUE, DBMS_LOB.CALL);
            DBMS_LOB.OPEN(blob_gzipped, DBMS_LOB.LOB_READWRITE);
            --
            UTL_COMPRESS.LZ_COMPRESS(blob_content, blob_gzipped, quality => 8);
            --
            WHILE blob_offset <= DBMS_LOB.GETLENGTH(blob_gzipped) LOOP
                DBMS_LOB.READ(blob_gzipped, blob_amount, blob_offset, buffer_raw);
                UTL_SMTP.WRITE_RAW_DATA(conn, UTL_ENCODE.BASE64_ENCODE(buffer_raw));
                blob_offset := blob_offset + blob_amount;
            END LOOP;
            DBMS_LOB.FREETEMPORARY(blob_gzipped);
            --
            UTL_SMTP.WRITE_DATA(conn, UTL_TCP.CRLF || UTL_TCP.CRLF);
        ELSIF in_attach_name IS NOT NULL THEN
            -- regular attachment
            UTL_SMTP.WRITE_DATA(conn, '--' || boundary || UTL_TCP.CRLF);
            UTL_SMTP.WRITE_DATA(conn, 'Content-Transfer-Encoding: base64' || UTL_TCP.CRLF);
            UTL_SMTP.WRITE_DATA(conn, 'Content-Type: ' || in_attach_mime || '; name="' || in_attach_name || '"' || UTL_TCP.CRLF);
            UTL_SMTP.WRITE_DATA(conn, 'Content-Disposition: attachment; filename="' || in_attach_name || '"' || UTL_TCP.CRLF || UTL_TCP.CRLF);
            --
            FOR i IN 0 .. TRUNC((DBMS_LOB.GETLENGTH(in_attach_data) - 1) / 12000) LOOP
                UTL_SMTP.WRITE_RAW_DATA(conn, UTL_ENCODE.BASE64_ENCODE(UTL_RAW.CAST_TO_RAW(DBMS_LOB.SUBSTR(in_attach_data, 12000, i * 12000 + 1))));
            END LOOP;
            --
            UTL_SMTP.WRITE_DATA(conn, UTL_TCP.CRLF || UTL_TCP.CRLF);
        END IF;

        -- close
        UTL_SMTP.WRITE_DATA(conn, '--' || boundary || '--' || UTL_TCP.CRLF);
        UTL_SMTP.CLOSE_DATA(conn);
        UTL_SMTP.QUIT(conn);
    EXCEPTION
    WHEN UTL_SMTP.TRANSIENT_ERROR OR UTL_SMTP.PERMANENT_ERROR THEN
        BEGIN
            UTL_SMTP.QUIT(conn);
        EXCEPTION
        WHEN UTL_SMTP.TRANSIENT_ERROR OR UTL_SMTP.PERMANENT_ERROR THEN
            NULL;
        END;
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION send_request (
        in_url                  VARCHAR2,
        in_method               VARCHAR2    := NULL,
        in_content_type         VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL
    )
    RETURN VARCHAR2
    AS
        http_req        UTL_HTTP.REQ;
        http_resp       UTL_HTTP.RESP;
        --
        out_content     VARCHAR2(32767);    -- could be CLOB
        v_buffer        VARCHAR2(32767);
    BEGIN
        IF c_app_proxy IS NOT NULL THEN
            UTL_HTTP.SET_PROXY(c_app_proxy);
        END IF;
        --
        IF c_app_wallet IS NOT NULL THEN
            UTL_HTTP.SET_WALLET(c_app_wallet);
        END IF;

        -- send headers
        BEGIN
            http_req := UTL_HTTP.BEGIN_REQUEST(in_url, NVL(UPPER(in_method), 'GET'), 'HTTP/1.1');
            --APEX_WEB_SERVICE.MAKE_REST_REQUEST
        EXCEPTION
        WHEN OTHERS THEN
            --
            -- parse callstack
            --
            core.raise_error (
                CASE SQLCODE
                    WHEN -24247 THEN 'MISSING_ACL_ISSUE'    -- ORA-24247: network access denied by access control list (ACL)
                    WHEN -29024 THEN 'CERTIFICATE_ISSUE'    -- ORA-29024: Certificate validation failure
                    ELSE 'CONNECTION_ERROR'
                    END,
                APEX_STRING_UTIL.GET_DOMAIN(in_url)
            );
        END;
        --
        UTL_HTTP.SET_BODY_CHARSET(http_req, 'UTF-8');

        -- extra headers for SOAP request
        UTL_HTTP.SET_HEADER(http_req, 'Accept',             '*/*');
        UTL_HTTP.SET_HEADER(http_req, 'Accept-Encoding',    'gzip, deflate');
        UTL_HTTP.SET_HEADER(http_req, 'Cache-Control',      'no-cache');
        UTL_HTTP.SET_HEADER(http_req, 'Content-Type',       NVL(in_content_type, 'application/x-www-form-urlencoded'));
        UTL_HTTP.SET_HEADER(http_req, 'Content-Length',     LENGTH(in_payload));
        UTL_HTTP.SET_HEADER(http_req, 'Connection',         'keep-alive');
        UTL_HTTP.SET_HEADER(http_req, 'User-Agent',         'Godzilla');

        -- send payload
        IF in_payload IS NOT NULL THEN
            UTL_HTTP.WRITE_TEXT(http_req, in_payload);
        END IF;

        -- get response
        http_resp := UTL_HTTP.GET_RESPONSE(http_req);
        DBMS_OUTPUT.PUT_LINE(http_resp.status_code);
        --
        IF http_resp.status_code >= 300 THEN
            core.raise_error('WRONG_RESPONSE_CODE', http_resp.status_code, in_concat => TRUE);
        END IF;

        -- get response
        --DBMS_LOB.CREATETEMPORARY(out_content, TRUE);
        BEGIN
            v_buffer := NULL;
            LOOP
                UTL_HTTP.READ_TEXT(http_resp, v_buffer, 32767);
                --IF v_buffer IS NOT NULL AND LENGTH(v_buffer) > 0 THEN
                    --DBMS_LOB.WRITEAPPEND(out_content, LENGTH(v_buffer), v_buffer);
                    out_content := v_buffer; EXIT;
                --END IF;
            END LOOP;
        EXCEPTION
        WHEN UTL_HTTP.END_OF_BODY THEN
            UTL_HTTP.END_RESPONSE(http_resp);
        END;

        -- quit
        UTL_HTTP.END_RESPONSE(http_resp);
        --
        RETURN out_content;
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        BEGIN
            UTL_HTTP.END_RESPONSE(http_resp);
            --
            RETURN out_content;
        EXCEPTION
        WHEN OTHERS THEN
            NULL;
        END;
        --
        core.raise_error();
    END;



    FUNCTION clob_to_blob (
        in_clob CLOB
    )
    RETURN BLOB
    AS
        out_blob        BLOB;
        --
        v_file_size     INTEGER     := DBMS_LOB.LOBMAXSIZE;
        v_dest_offset   INTEGER     := 1;
        v_src_offset    INTEGER     := 1;
        v_blob_csid     NUMBER      := DBMS_LOB.DEFAULT_CSID;
        v_lang_context  NUMBER      := DBMS_LOB.DEFAULT_LANG_CTX;
        v_warning       INTEGER;
        v_length        NUMBER;
    BEGIN
        DBMS_LOB.CREATETEMPORARY(out_blob, TRUE);
        DBMS_LOB.CONVERTTOBLOB(out_blob, in_clob, v_file_size, v_dest_offset, v_src_offset, v_blob_csid, v_lang_context, v_warning);
        RETURN out_blob;
    END;



    PROCEDURE clob_append (
        io_clob             IN OUT NOCOPY   CLOB,
        in_content                          VARCHAR2
    )
    AS
    BEGIN
        IF LENGTH(in_content) > 0 THEN
            DBMS_LOB.WRITEAPPEND(io_clob, LENGTH(in_content), in_content);
        END IF;
    END;



    FUNCTION get_long_string (
        in_table_name           VARCHAR2,
        in_column_name          VARCHAR2,
        in_where_col1_name      VARCHAR2,
        in_where_val1           VARCHAR2,
        in_where_col2_name      VARCHAR2    := NULL,
        in_where_val2           VARCHAR2    := NULL,
        in_owner                VARCHAR2    := NULL
    )
    RETURN VARCHAR2 AS
        l_query                 VARCHAR2(4000);
        l_cursor                INTEGER         := DBMS_SQL.OPEN_CURSOR;
        l_buflen                PLS_INTEGER     := 4000;
        l_result                PLS_INTEGER;
        --
        out_value               VARCHAR2(4000);
        out_value_len           PLS_INTEGER;
    BEGIN
        l_query :=
            'SELECT ' || in_column_name ||
            ' FROM '  || in_table_name ||
            ' WHERE ' || in_where_col1_name || ' = :val1';
        --
        IF in_where_col2_name IS NOT NULL THEN
            l_query := l_query || ' AND ' || in_where_col2_name || ' = :val2';
        END IF;
        --
        IF in_owner IS NOT NULL THEN
            l_query := l_query || ' AND owner = :owner';
        END IF;
        --
        DBMS_SQL.PARSE(l_cursor, l_query, DBMS_SQL.NATIVE);
        DBMS_SQL.BIND_VARIABLE(l_cursor, ':val1', in_where_val1);
        --
        IF in_where_col2_name IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(l_cursor, ':val2', in_where_val2);
        END IF;
        --
        IF in_owner IS NOT NULL THEN
            DBMS_SQL.BIND_VARIABLE(l_cursor, ':owner', in_owner);
        END IF;
        --
        DBMS_SQL.DEFINE_COLUMN_LONG(l_cursor, 1);
        --
        l_result := DBMS_SQL.EXECUTE(l_cursor);
        IF DBMS_SQL.FETCH_ROWS(l_cursor) > 0 THEN
            DBMS_SQL.COLUMN_VALUE_LONG(l_cursor, 1, l_buflen, 0, out_value, out_value_len);
        END IF;
        DBMS_SQL.CLOSE_CURSOR(l_cursor);
        --
        RETURN out_value;
    END;



    PROCEDURE download_file (
        in_file_name                        VARCHAR2,
        in_file_payload     IN OUT NOCOPY   BLOB
    )
    AS
    BEGIN
        HTP.INIT;
        --OWA_UTIL.MIME_HEADER(in_file_mime, FALSE);
        --
        HTP.P('Content-Type: application/octet-stream');
        HTP.P('Content-Length: ' || DBMS_LOB.GETLENGTH(in_file_payload));
        HTP.P('Content-Disposition: attachment; filename="' || REGEXP_SUBSTR(in_file_name, '([^/]*)$') || '"');
        HTP.P('Cache-Control: max-age=0');
        --
        OWA_UTIL.HTTP_HEADER_CLOSE;
        WPG_DOCLOAD.DOWNLOAD_FILE(in_file_payload);
        APEX_APPLICATION.STOP_APEX_ENGINE;              -- throws ORA-20876 Stop APEX Engine
    EXCEPTION
    WHEN APEX_APPLICATION.E_STOP_APEX_ENGINE THEN
        NULL;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE redirect (
        in_page_id              NUMBER          := NULL,
        in_names                VARCHAR2        := NULL,
        in_values               VARCHAR2        := NULL,
        in_overload             VARCHAR2        := NULL,    -- JSON object to overload passed items/values
        in_transform            BOOLEAN         := FALSE,   -- to pass all page items to new page
        in_reset                CHAR            := NULL
    )
    AS
        out_target              VARCHAR2(32767);
        in_app_id               CONSTANT PLS_INTEGER := get_app_id();
    BEGIN
        -- commit otherwise anything before redirect will be rolled back
        COMMIT;

        -- check if we are in APEX or not
        HTP.INIT;
        out_target := core.get_page_url (
            in_page_id          => in_page_id,
            in_names            => in_names,
            in_values           => in_values,
            in_overload         => in_overload,
            in_reset            => in_reset
        );

        -- fix address
        IF out_target LIKE '%/authentication-scheme-login/%' THEN
            FOR c IN (
                SELECT a.alias
                FROM apex_applications a
                WHERE a.application_id  = in_app_id
                    AND ROWNUM          = 1
            ) LOOP
                out_target := REPLACE(out_target, '/authentication-scheme-login/', '/' || LOWER(c.alias) || '/');
            END LOOP;
        END IF;
        --
        APEX_UTIL.REDIRECT_URL(out_target);  -- OWA_UTIL not working on Cloud
        --
        APEX_APPLICATION.STOP_APEX_ENGINE;
        --
        -- EXCEPTION
        -- WHEN APEX_APPLICATION.E_STOP_APEX_ENGINE THEN
        --
    EXCEPTION
    WHEN APEX_APPLICATION.E_STOP_APEX_ENGINE THEN
        NULL;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE assert_true (
        in_error_message        VARCHAR2,
        in_bool_expression      BOOLEAN
    )
    AS
    BEGIN
        IF in_bool_expression THEN
            RAISE_APPLICATION_ERROR(assert_exception_code, c_assert_message || in_error_message);
        END IF;
    END;



    PROCEDURE assert_false (
        in_error_message        VARCHAR2,
        in_bool_expression      BOOLEAN
    )
    AS
    BEGIN
        IF NOT in_bool_expression THEN
            RAISE_APPLICATION_ERROR(assert_exception_code, c_assert_message || in_error_message);
        END IF;
    END;



    PROCEDURE assert_not_null (
        in_error_message        VARCHAR2,
        in_value                VARCHAR2
    )
    AS
    BEGIN
        IF in_value IS NULL THEN
            RAISE_APPLICATION_ERROR(assert_exception_code, c_assert_message || in_error_message);
        END IF;
    END;



    PROCEDURE add_grid_filter (
        in_static_id            VARCHAR2,
        in_column_name          VARCHAR2,
        in_filter_value         VARCHAR2        := NULL,
        in_operator             VARCHAR2        := 'EQ',
        in_region_id            VARCHAR2        := NULL
    )
    AS
        v_region_id             apex_application_page_regions.region_id%TYPE;
        v_filter_value          VARCHAR2(2000);
    BEGIN
        v_region_id             := in_region_id;
        v_filter_value          := COALESCE(in_filter_value, core.get_item('$' || in_column_name));

        -- convert static_id to region_id
        IF in_region_id IS NULL THEN
            BEGIN
                SELECT a.region_id
                INTO v_region_id
                FROM apex_application_page_regions a
                WHERE a.application_id  = core.get_app_id()
                    AND a.page_id       = core.get_page_id()
                    AND a.static_id     = in_static_id;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                core.raise_error('REGION_NOT_FOUND', in_static_id, in_concat => TRUE);
            END;
        END IF;
        --
        APEX_IG.RESET_REPORT (
            p_page_id           => core.get_page_id(),
            p_region_id         => v_region_id,
            p_report_id         => NULL
        );
        --
        IF v_filter_value IS NOT NULL THEN
            APEX_IG.ADD_FILTER (
                p_page_id           => core.get_page_id(),
                p_region_id         => v_region_id,
                p_column_name       => in_column_name,
                p_filter_value      => v_filter_value,
                p_operator_abbr     => in_operator,
                p_is_case_sensitive => FALSE,
                p_report_id         => NULL
            );
        END IF;
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION get_view_source (
        in_view_name            VARCHAR2,
        in_owner                VARCHAR2    := NULL,
        in_trim                 CHAR        := NULL
    )
    RETURN VARCHAR2
    AS
        v_owner     apex_applications.owner%TYPE;
        v_source    user_views.text%TYPE;
    BEGIN
        IF in_owner IS NULL THEN
            SELECT ORA_INVOKING_USER INTO v_owner
            FROM DUAL;
        END IF;
        --
        IF in_owner IS NULL THEN
            SELECT MAX(a.owner) INTO v_owner
            FROM apex_applications a
            WHERE a.application_id = core.get_app_id();
        END IF;
        --
        v_owner := COALESCE(in_owner, v_owner, USER);
        --
        SELECT v.text
        INTO v_source
        FROM all_views v
        WHERE v.owner       = v_owner
            AND v.view_name = UPPER(in_view_name);
        --
        IF in_trim IS NOT NULL THEN
            v_source := REGEXP_REPLACE(v_source, '[ ]{2,}', ' ');
            v_source := REGEXP_REPLACE(v_source, CHR(10) || '[ ]*', CHR(10));
        END IF;
        --
        RETURN v_source;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        core.raise_error('VIEW_SOURCE_MISSING', v_owner || '.' || in_view_name, in_concat => TRUE);
    END;



    FUNCTION search_clob (
        in_payload              CLOB,
        in_search_start         VARCHAR2,
        in_search_stop          VARCHAR2,
        in_occurence            PLS_INTEGER     := 1,
        in_overlap              PLS_INTEGER     := NULL,
        in_new_line             VARCHAR2        := NULL
    )
    RETURN VARCHAR2
    AS
        v_length        PLS_INTEGER;                    -- length of the input CLOB
        v_counter       PLS_INTEGER     := 0;           -- number of found strings
        v_chunk_size    PLS_INTEGER     := 2000;        -- chunk size
        v_chunk         VARCHAR2(32767);                -- chunk extracted from the CLOB
        v_position      PLS_INTEGER     := 1;           -- starting position for next chunk
        v_pos2          PLS_INTEGER;
    BEGIN
        -- search CLOB in chunks
        v_length := DBMS_LOB.GETLENGTH(in_payload);
        --
        WHILE v_position <= v_length LOOP
            v_position  := GREATEST(1, v_position - NVL(in_overlap, LENGTH(in_search_start) - 1));
            v_chunk     := DBMS_LOB.SUBSTR(in_payload, v_chunk_size, v_position);

            -- modify CLOB to remove new lines for easier multiline searching
            IF in_new_line IS NOT NULL THEN
                v_chunk := REPLACE(v_chunk, CHR(10), in_new_line);  -- to search multilines
            END IF;

            -- we can have multiple occurences in the same chunk
            FOR i IN 1 .. REGEXP_COUNT(v_chunk, in_search_start) LOOP
                v_counter   := v_counter + 1;
                v_pos2      := REGEXP_INSTR(v_chunk, in_search_start, 1, i) + LENGTH(in_search_start);
                --
                IF v_counter = in_occurence THEN
                    -- retrieve whole bucket from the starting point
                    v_chunk := DBMS_LOB.SUBSTR(in_payload, v_chunk_size, v_position + v_pos2 - 1);
                    IF in_new_line IS NOT NULL THEN
                        v_chunk := REPLACE(v_chunk, CHR(10), in_new_line);  -- to search multilines
                    END IF;
                    --
                    RETURN SUBSTR(v_chunk, 1, NVL(INSTR(v_chunk, in_search_stop) - 1, v_chunk_size));
                END IF;
            END LOOP;

            -- process next chunk
            v_position := v_position + v_chunk_size;
        END LOOP;
        --
        RETURN '';
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION search_clob_count (
        in_payload              CLOB,
        in_search_start         VARCHAR2,
        in_overlap              PLS_INTEGER     := NULL,
        in_new_line             VARCHAR2        := NULL
    )
    RETURN PLS_INTEGER
    AS
        v_length        PLS_INTEGER;                    -- length of the input CLOB
        v_counter       PLS_INTEGER     := 0;           -- number of found strings
        v_chunk_size    PLS_INTEGER     := 2000;        -- chunk size
        v_chunk         VARCHAR2(32767);                -- chunk extracted from the CLOB
        v_position      PLS_INTEGER     := 1;           -- starting position for next chunk
    BEGIN
        -- search CLOB in chunks
        v_length := DBMS_LOB.GETLENGTH(in_payload);
        --
        WHILE v_position <= v_length LOOP
            v_position  := GREATEST(1, v_position - NVL(in_overlap, LENGTH(in_search_start) - 1));
            v_chunk     := DBMS_LOB.SUBSTR(in_payload, v_chunk_size, v_position);

            -- modify CLOB to remove new lines for easier multiline searching
            IF in_new_line IS NOT NULL THEN
                v_chunk := REPLACE(v_chunk, CHR(10), in_new_line);  -- to search multilines
            END IF;
            --
            v_counter   := v_counter + REGEXP_COUNT(v_chunk, in_search_start);
            v_position  := v_position + v_chunk_size;
        END LOOP;
        --
        RETURN v_counter;
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    FUNCTION call_procedure (
        in_package_name         VARCHAR2,
        in_procedure_name       VARCHAR2,
        in_owner                VARCHAR2    := NULL,
        in_prefix               VARCHAR2    := NULL
    )
    RETURN BOOLEAN
    AS
        v_id NUMBER;
    BEGIN
        FOR c IN (
            SELECT
                p.object_name || '.' || p.procedure_name AS procedure_name,
                p.owner
            FROM all_procedures p
            WHERE 1 = 1
                AND p.owner             = COALESCE(in_owner, core.get_app_owner())
                AND p.object_name       = in_prefix || in_package_name
                AND p.procedure_name    = in_procedure_name
            ORDER BY 1
            FETCH FIRST 1 ROWS ONLY
        ) LOOP
            v_id := core.log_start (
                'owner',            c.owner,
                'procedure_name',   c.procedure_name
            );
            --
            EXECUTE IMMEDIATE
                'BEGIN ' || c.owner || '.' || c.procedure_name || '(); END;';
            --
            core.log_end(in_context_id => v_id);
            --
            RETURN TRUE;
        END LOOP;
        --
        RETURN FALSE;
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE call_procedure (
        in_package_name         VARCHAR2,
        in_procedure_name       VARCHAR2,
        in_owner                VARCHAR2    := NULL,
        in_prefix               VARCHAR2    := NULL
    )
    AS
        v_result BOOLEAN;
    BEGIN
        v_result := call_procedure (
            in_package_name    => in_package_name,
            in_procedure_name  => in_procedure_name,
            in_owner           => in_owner,
            in_prefix          => in_prefix
        );
    EXCEPTION
    WHEN core.app_exception THEN
        RAISE;
    WHEN OTHERS THEN
        core.raise_error();
    END;



    PROCEDURE update_app_version (
        in_app_id           PLS_INTEGER     := NULL,
        in_version          VARCHAR2        := NULL,
        in_proceed          BOOLEAN         := TRUE,
        in_skip_main        BOOLEAN         := FALSE,
        in_keep_older       BOOLEAN         := FALSE
    )
    AS
        v_apps              apex_t_varchar2;
        --
        FUNCTION get_sortable_version (
            in_version      VARCHAR2
        )
        RETURN VARCHAR2
        AS
        BEGIN
            RETURN REGEXP_REPLACE(REGEXP_REPLACE(in_version, '\.(\d+)', '.0\1'), '\.\d?(\d{2})', '.\1');
        END;
    BEGIN
        -- prepare apps list
        IF in_app_id IS NOT NULL THEN
            v_apps := apex_t_varchar2(in_app_id);
        ELSE
            v_apps := core_custom.g_apps;
        END IF;

        -- proceed with apps
        IF core_custom.master_id IS NOT NULL THEN
            core.create_session(USER, core_custom.master_id);
        END IF;
        --
        FOR c IN (
            SELECT
                t.application_id        AS app_id,
                t.application_name      AS app_name,
                t.version               AS version_old,
                TO_CHAR(in_version)     AS version_new,
                LPAD('0', 18, '0')      AS version_tmp
            FROM apex_applications t
            JOIN TABLE(v_apps) f
                ON TO_NUMBER(f.column_value) = t.application_id
            ORDER BY 1
        ) LOOP
            IF (core_custom.master_id IS NULL OR in_app_id IS NOT NULL) THEN
                core.create_session(USER, c.app_id);
            END IF;
            --
            DBMS_OUTPUT.PUT_LINE('--');
            DBMS_OUTPUT.PUT_LINE('APP ' || c.app_id || ' - ' || c.app_name);

            -- loop over all views with app_id and date column, find the maximum
            IF c.version_new IS NULL THEN
                FOR d IN (
                    SELECT
                        c.owner,
                        c.table_name,
                        c.column_name
                    FROM all_views t
                    JOIN all_tab_cols c
                        ON c.table_name     = t.view_name
                        AND c.data_type     = 'DATE'
                        AND c.column_name   IN ('CREATED_ON', 'LAST_UPDATED_ON', 'UPDATED_ON')
                    JOIN all_tab_cols a
                        ON a.table_name     = t.view_name
                        AND a.column_name   = 'APPLICATION_ID'
                    WHERE t.owner           LIKE 'APEX_2%'
                        AND t.view_name     LIKE 'APEX_APPL%'
                    ORDER BY
                        1, 2, 3
                ) LOOP
                    CONTINUE WHEN in_skip_main AND d.table_name IN ('APEX_APPLICATIONS', 'APEX_APPL_USER_INTERFACES');
                    --
                    EXECUTE IMMEDIATE
                        APEX_STRING.FORMAT (
                            q'!SELECT
                              !    MAX(TO_CHAR(t.%3, 'YYYY-MM-DD HH24:MI:SS'))
                              !FROM %1.%2 t
                              !WHERE t.application_id = %4
                              !',
                            --
                            p1 => d.owner,
                            p2 => d.table_name,
                            p3 => d.column_name,
                            p4 => c.app_id,
                            --
                            p_prefix        => '!',
                            p_max_length    => 32767
                        )
                        INTO c.version_tmp;
                    --
                    IF c.version_tmp IS NOT NULL THEN
                        c.version_new := GREATEST(NVL(c.version_new, c.version_old), c.version_tmp);
                        --
                        IF get_sortable_version(c.version_tmp) > get_sortable_version(c.version_old) THEN
                            DBMS_OUTPUT.PUT_LINE('    ' || RPAD(d.table_name || ' ', 48, '.') || ' ' || c.version_tmp);
                        END IF;
                    END IF;
                END LOOP;
            END IF;

            -- update version number for the app
            BEGIN
                IF in_version IS NULL THEN
                    c.version_new := REPLACE(TO_CHAR(TO_DATE(c.version_new, 'YYYY-MM-DD HH24:MI:SS'), 'YYYY-MM-DD fmHH24.MI'), ' ', ' 1.');
                END IF;
                --
                IF (
                    (NOT in_keep_older AND get_sortable_version(c.version_new) >  get_sortable_version(c.version_old))
                    OR  (in_keep_older AND get_sortable_version(c.version_new) != get_sortable_version(c.version_old))
                ) THEN
                    DBMS_OUTPUT.PUT_LINE('    --');
                    DBMS_OUTPUT.PUT_LINE('    UPDATING ' || c.version_old);
                    DBMS_OUTPUT.PUT_LINE('          TO ' || c.version_new);
                    DBMS_OUTPUT.PUT_LINE('');
                    --
                    IF in_proceed THEN
                        APEX_APPLICATION_ADMIN.SET_APPLICATION_VERSION (
                            p_application_id    => c.app_id,
                            p_version           => c.version_new
                        );
                    END IF;
                END IF;
            EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -20987 THEN
                    DBMS_OUTPUT.PUT_LINE('    --> ENABLE RUNTIME_API_USAGE');
                END IF;
            END;
        END LOOP;
    END;

END;
/

