CREATE OR REPLACE PACKAGE BODY core AS

    FUNCTION get_id
    RETURN NUMBER
    AS
    BEGIN
        RETURN TO_NUMBER(SYS_GUID(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');
    END;



    FUNCTION generate_token (
        in_size                 NUMBER := 6
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN LPAD(TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(1, TO_CHAR(POWER(10, in_size) - 1)))), in_size, '0');
    END;



    FUNCTION get_context_id (
        in_context_name         VARCHAR2 := NULL
    )
    RETURN NUMBER
    AS
    BEGIN
        RETURN COALESCE (
            CASE WHEN in_context_name IS NOT NULL
                THEN TO_NUMBER(APEX_UTIL.GET_SESSION_STATE(in_context_name))
                END,
            TO_NUMBER(APEX_UTIL.GET_SESSION_STATE('G_CONTEXT_ID')),
            TO_NUMBER(APEX_UTIL.GET_SESSION_STATE('G_APP_ID')),
            APEX_APPLICATION.G_FLOW_ID
        );
    EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
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
        WHERE a.application_id = COALESCE(in_app_id, core.get_app_id());
        --
        RETURN COALESCE(out_owner, APEX_UTIL.GET_DEFAULT_SCHEMA, USER);
    END;



    FUNCTION get_app_prefix (
        in_app_id               NUMBER      := NULL
    )
    RETURN VARCHAR2
    AS
        out_prefix              VARCHAR2(30);
    BEGIN
        SELECT NVL(s.value, b.substitution_value)
        INTO out_prefix
        FROM apex_applications a
        LEFT JOIN apex_application_settings s
            ON s.application_id         = a.application_id
            AND s.name                  = 'APP_PREFIX'
        LEFT JOIN apex_application_substitutions b
            ON b.application_id         = a.application_id
            AND b.substitution_string   = 'APP_PREFIX'
        WHERE a.application_id = COALESCE(in_app_id, core.get_app_id());
        --
        RETURN out_prefix;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
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
        WHERE a.application_id = COALESCE(in_app_id, core.get_app_id());
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
        WHERE a.application_id = COALESCE(in_app_id, core.get_app_id());
        --
        RETURN out_name;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    FUNCTION get_app_homepage (
        in_app_id               NUMBER
    )
    RETURN NUMBER
    DETERMINISTIC
    AS
        out_page_id             apex_application_pages.page_id%TYPE;
    BEGIN
        BEGIN
            SELECT p.page_id
            INTO out_page_id
            FROM apex_applications a
            JOIN apex_application_pages p
                ON p.application_id     = a.application_id
                AND p.page_alias        = REGEXP_SUBSTR(a.home_link, ':([^:]+)', 1, 1, NULL, 1)
            WHERE a.application_id      = in_app_id;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            BEGIN
                SELECT TO_NUMBER(REGEXP_SUBSTR(a.home_link, ':([^:]+)', 1, 1, NULL, 1))
                INTO out_page_id
                FROM apex_applications a
                WHERE a.application_id  = in_app_id;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
            END;
        END;
        --
        RETURN out_page_id;
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error('GET_HOMEPAGE_FAILED', COALESCE(in_app_id, core.get_app_id()));
    END;



    FUNCTION get_app_login_url (
        in_app_id               NUMBER
    )
    RETURN VARCHAR2
    DETERMINISTIC
    AS
        out_url                 apex_applications.login_url%TYPE;
    BEGIN
        BEGIN
            SELECT a.login_url
            INTO out_url
            FROM apex_applications a
            WHERE a.application_id = in_app_id;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
        END;
        --
        RETURN out_url;
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error('GET_LOGIN_FAILED', COALESCE(in_app_id, core.get_app_id()));
    END;



    FUNCTION get_user_id
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN COALESCE (
            APEX_APPLICATION.G_USER,
            SYS_CONTEXT('USERENV', 'PROXY_USER'),
            SYS_CONTEXT('USERENV', 'SESSION_USER'),
            USER
        );
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
        WHERE s.application_id          = COALESCE(in_app_id, core.get_context_id())
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
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    PROCEDURE set_preference (
        in_name                 VARCHAR2,
        in_value                VARCHAR2
    )
    AS
    BEGIN
        APEX_UTIL.SET_PREFERENCE (
            p_preference    => in_name,
            p_value         => in_value
        );
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
        APEX_APP_SETTING.SET_VALUE (
            p_name          => in_name,
            p_value         => in_value,
            p_raise_error   => TRUE
        );
    END;



    FUNCTION get_constant (
        in_package              VARCHAR2,
        in_name                 VARCHAR2,
        in_prefix               VARCHAR2        := NULL,
        in_private              CHAR            := NULL
    )
    RETURN VARCHAR2
    RESULT_CACHE
    AS
        out_value               VARCHAR2(4000);
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
        FROM user_identifiers t
        JOIN user_source s
            ON s.name               = t.object_name
            AND s.type              = t.object_type
            AND s.line              = t.line
        WHERE t.object_name         = UPPER(in_package)
            AND t.object_type       = 'PACKAGE' || CASE WHEN in_private IS NOT NULL THEN ' BODY' END
            AND t.name              = UPPER(in_prefix || in_name)
            AND t.type              = 'CONSTANT'
            AND t.usage             = 'DECLARATION'
            AND t.usage_context_id  = 1;
        --
        RETURN out_value;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
    END;



    FUNCTION get_constant_num (
        in_package              VARCHAR2,
        in_name                 VARCHAR2,
        in_prefix               VARCHAR2        := NULL,
        in_private              CHAR            := NULL
    )
    RETURN NUMBER
    RESULT_CACHE
    AS
        out_value           NUMBER;
    BEGIN
        RETURN TO_NUMBER(get_constant (
            in_package      => in_package,
            in_name         => in_name,
            in_prefix       => in_prefix,
            in_private      => in_private
        ));
    END;



    FUNCTION is_developer (
        in_user                 VARCHAR2        := NULL
    )
    RETURN BOOLEAN
    AS
        is_valid                CHAR;
    BEGIN
        IF NV('APP_BUILDER_SESSION') > 0 THEN
            RETURN TRUE;
        END IF;
        --
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
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN FALSE;
    END;



    FUNCTION is_developer_y (
        in_user                 VARCHAR2        := NULL
    )
    RETURN CHAR
    AS
    BEGIN
        RETURN CASE WHEN core.is_developer(in_user) THEN 'Y' END;
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



    FUNCTION is_debug_on
    RETURN BOOLEAN
    AS
    BEGIN
        RETURN APEX_APPLICATION.G_DEBUG;
    END;



    PROCEDURE set_debug (
        in_status               BOOLEAN     := TRUE
    )
    AS
    BEGIN
        APEX_APPLICATION.G_DEBUG := in_status;
        DBMS_OUTPUT.PUT_LINE('DEBUG: ' || CASE WHEN core.is_debug_on() THEN 'ON' ELSE 'OFF' END);
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
                core.raise_error('INVALID_APP', in_app_id);
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
        -- set security context
        core.create_security_context (
            in_workspace        => in_workspace,
            in_app_id           => in_app_id
        );

        -- attach to existing session
        IF in_session_id IS NOT NULL THEN
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
                core.raise_error('CREATE_SESSION_FAILED', in_app_id, in_page_id, in_user_id);
            END;

            -- set username
            IF APEX_CUSTOM_AUTH.SESSION_ID_EXISTS THEN
                APEX_UTIL.SET_USERNAME (
                    p_userid    => APEX_UTIL.GET_USER_ID(v_user_name),
                    p_username  => v_user_name
                );
            END IF;
        END IF;
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
            core.raise_error('ATTACH_SESSION_FAILED', in_app_id, in_page_id, in_session_id);
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
        RETURN APEX_UTIL.FIND_WORKSPACE(APEX_CUSTOM_AUTH.GET_SECURITY_GROUP_ID());
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
            core_customized.get_env(),
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
        WHERE p.application_id      = COALESCE(in_app_id, core.get_app_id())
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
        in_name                 VARCHAR2    := NULL
    )
    RETURN VARCHAR2
    AS
        out_name                apex_application_pages.page_name%TYPE       := in_name;
        out_search              apex_application_pages.page_name%TYPE;
    BEGIN
        IF out_name IS NULL THEN
            SELECT p.page_name INTO out_name
            FROM apex_application_pages p
            WHERE p.application_id      = COALESCE(in_app_id,   core.get_app_id())
                AND p.page_id           = COALESCE(in_page_id,  core.get_page_id());
        END IF;

        -- transform icons
        FOR i IN 1 .. NVL(REGEXP_COUNT(out_name, '(#fa-)'), 0) + 1 LOOP
            out_search  := REGEXP_SUBSTR(out_name, '(#fa-[[:alnum:]+_-]+\s*)+');
            out_name    := REPLACE (
                out_name,
                out_search,
                ' &' || 'nbsp; <span class="fa' || REPLACE(REPLACE(out_search, '#fa-', '+'), '+', ' fa-') || '"></span> &' || 'nbsp; '
            );
        END LOOP;
        --
        RETURN REGEXP_REPLACE(out_name, '((^\s*&' || 'nbsp;\s*)|(\s*&' || 'nbsp;\s*$))', '');  -- trim hard spaces
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
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



    FUNCTION get_icon (
        in_name                 VARCHAR2,
        in_title                VARCHAR2    := NULL,
        in_style                VARCHAR2    := NULL
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN '<span class="fa ' || in_name || '" style="' || in_style || '" title="' || in_title || '"></span>';
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
        v_item_name             apex_application_page_items.item_name%TYPE;
        v_page_id               apex_application_page_items.page_id%TYPE;
        v_app_id                apex_application_page_items.application_id%TYPE;
        is_valid                CHAR;
    BEGIN
        v_app_id        := NVL(in_app_id,   core.get_context_id());
        v_page_id       := NVL(in_page_id,  core.get_page_id());
        v_item_name     := REPLACE(in_name, c_page_item_wild, c_page_item_prefix || v_page_id || '_');

        -- check if item exists
        BEGIN
            SELECT 'Y' INTO is_valid
            FROM apex_application_page_items p
            WHERE p.application_id      = v_app_id
                AND p.page_id           IN (0, v_page_id)
                AND p.item_name         = v_item_name;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            BEGIN
                SELECT 'Y' INTO is_valid
                FROM apex_application_items g
                WHERE g.application_id      = v_app_id
                    AND g.item_name         = in_name;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN NULL;
            END;
        END;
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
        core.raise_error('INVALID_NUMBER', in_name, core.get_item(in_name));
    END;



    FUNCTION get_date_item (
        in_name                 VARCHAR2,
        in_format               VARCHAR2        := NULL
    )
    RETURN DATE
    AS
    BEGIN
        RETURN core.get_date(core.get_item(in_name), in_format);
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error('INVALID_DATE', in_name, core.get_item(in_name), in_format);
    END;



    FUNCTION get_date (
        in_value                VARCHAR2,
        in_format               VARCHAR2        := NULL
    )
    RETURN DATE
    AS
        l_value                 VARCHAR2(30)    := SUBSTR(REPLACE(in_value, 'T', ' '), 1, 30);
    BEGIN
        IF in_format IS NOT NULL THEN
            BEGIN
                RETURN TO_DATE(l_value, in_format);
            EXCEPTION
            WHEN OTHERS THEN
                core.raise_error('INVALID_DATE', in_value, in_format);
            END;
        END IF;

        -- try different formats
        BEGIN
            RETURN TO_DATE(l_value, c_format_date_time);                        -- YYYY-MM-DD HH24:MI:SS
        EXCEPTION
        WHEN OTHERS THEN
            BEGIN
                RETURN TO_DATE(l_value, c_format_date_short);                   -- YYYY-MM-DD HH24:MI
            EXCEPTION
            WHEN OTHERS THEN
                BEGIN
                    RETURN TO_DATE(SUBSTR(l_value, 1, 10), c_format_date);      -- YYYY-MM-DD
                EXCEPTION
                WHEN OTHERS THEN
                    BEGIN
                        RETURN TO_DATE(l_value, V('APP_NLS_DATE_FORMAT'));
                    EXCEPTION
                    WHEN OTHERS THEN
                        BEGIN
                            RETURN TO_DATE(l_value);
                        EXCEPTION
                        WHEN OTHERS THEN
                            core.raise_error('INVALID_DATE', in_value, in_format);
                        END;
                    END;
                END;
            END;
        END;
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
    RESULT_CACHE
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
        in_value                VARCHAR2        := NULL
    )
    AS
        v_item_name             apex_application_page_items.item_name%TYPE;
    BEGIN
        v_item_name := core.get_item_name(in_name);
        --
        IF v_item_name IS NOT NULL THEN
            BEGIN
                APEX_UTIL.SET_SESSION_STATE (
                    p_name      => v_item_name,
                    p_value     => core.get_translated(in_value),
                    p_commit    => FALSE
                );
            EXCEPTION
            WHEN OTHERS THEN
                core.raise_error('ITEM_MISSING', v_item_name, in_name);
            END;
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
        -- process cursor
        OPEN l_refcur FOR LTRIM(RTRIM(in_query));
        --
        l_cursor    := DBMS_SQL.TO_CURSOR_NUMBER(l_refcur);
        l_items     := set_page_item_values(l_cursor , in_page_id);
    EXCEPTION
    WHEN OTHERS THEN
        RAISE;
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
        -- process cursor
        OPEN l_refcur FOR LTRIM(RTRIM(in_query));
        --
        l_cursor    := DBMS_SQL.TO_CURSOR_NUMBER(l_refcur);
        l_items     := set_page_item_values(l_cursor , in_page_id);
        --
        FOR i IN l_items.FIRST .. l_items.LAST LOOP
            PIPE ROW (l_items(i));
        END LOOP;
        --
        RETURN;
    EXCEPTION
    WHEN OTHERS THEN
        RAISE;
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
        l_cloned_curs   := in_cursor;
        l_cursor        := get_cursor_number(l_cloned_curs);
        l_items         := set_page_item_values(l_cursor , in_page_id);
    EXCEPTION
    WHEN OTHERS THEN
        RAISE;
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
        l_cloned_curs   := in_cursor;
        l_cursor        := get_cursor_number(l_cloned_curs);
        l_items         := set_page_item_values(l_cursor , in_page_id);
        --
        FOR i IN l_items.FIRST .. l_items.LAST LOOP
            PIPE ROW (l_items(i));
        END LOOP;
        --
        RETURN;
    EXCEPTION
    WHEN OTHERS THEN
        RAISE;
        RETURN;
    END;



    FUNCTION set_page_item_values (
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
        RAISE;
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



    FUNCTION get_json_list (
        in_arg1                 VARCHAR2    := NULL,
        in_arg2                 VARCHAR2    := NULL,
        in_arg3                 VARCHAR2    := NULL,
        in_arg4                 VARCHAR2    := NULL,
        in_arg5                 VARCHAR2    := NULL,
        in_arg6                 VARCHAR2    := NULL,
        in_arg7                 VARCHAR2    := NULL,
        in_arg8                 VARCHAR2    := NULL,
        in_arg9                 VARCHAR2    := NULL,
        in_arg10                VARCHAR2    := NULL,
        in_arg11                VARCHAR2    := NULL,
        in_arg12                VARCHAR2    := NULL,
        in_arg13                VARCHAR2    := NULL,
        in_arg14                VARCHAR2    := NULL,
        in_arg15                VARCHAR2    := NULL,
        in_arg16                VARCHAR2    := NULL,
        in_arg17                VARCHAR2    := NULL,
        in_arg18                VARCHAR2    := NULL,
        in_arg19                VARCHAR2    := NULL,
        in_arg20                VARCHAR2    := NULL
    )
    RETURN VARCHAR2
    AS
    BEGIN
        RETURN NULLIF(REGEXP_REPLACE(
            REGEXP_REPLACE(
                NULLIF(JSON_ARRAY(
                    in_arg1,    in_arg2,    in_arg3,    in_arg4,    in_arg5,    in_arg6,    in_arg7,    in_arg8,    in_arg9,    in_arg10,
                    in_arg11,   in_arg12,   in_arg13,   in_arg14,   in_arg15,   in_arg16,   in_arg17,   in_arg18,   in_arg19,   in_arg20
                    NULL ON NULL),
                    '[]'),
                '"(\d+)([.,]\d+)?"', '\1\2'  -- convert to numbers if possible
            ),
            '(,null)+\]$', ']'),  -- strip NULLs from the right side
            '[null]');
    END;



    FUNCTION get_json_object (
        in_name01   VARCHAR2 := NULL,           in_value01  VARCHAR2 := NULL,
        in_name02   VARCHAR2 := NULL,           in_value02  VARCHAR2 := NULL,
        in_name03   VARCHAR2 := NULL,           in_value03  VARCHAR2 := NULL,
        in_name04   VARCHAR2 := NULL,           in_value04  VARCHAR2 := NULL,
        in_name05   VARCHAR2 := NULL,           in_value05  VARCHAR2 := NULL,
        in_name06   VARCHAR2 := NULL,           in_value06  VARCHAR2 := NULL,
        in_name07   VARCHAR2 := NULL,           in_value07  VARCHAR2 := NULL,
        in_name08   VARCHAR2 := NULL,           in_value08  VARCHAR2 := NULL,
        in_name09   VARCHAR2 := NULL,           in_value09  VARCHAR2 := NULL,
        in_name10   VARCHAR2 := NULL,           in_value10  VARCHAR2 := NULL,
        in_name11   VARCHAR2 := NULL,           in_value11  VARCHAR2 := NULL,
        in_name12   VARCHAR2 := NULL,           in_value12  VARCHAR2 := NULL,
        in_name13   VARCHAR2 := NULL,           in_value13  VARCHAR2 := NULL,
        in_name14   VARCHAR2 := NULL,           in_value14  VARCHAR2 := NULL,
        in_name15   VARCHAR2 := NULL,           in_value15  VARCHAR2 := NULL,
        in_name16   VARCHAR2 := NULL,           in_value16  VARCHAR2 := NULL,
        in_name17   VARCHAR2 := NULL,           in_value17  VARCHAR2 := NULL,
        in_name18   VARCHAR2 := NULL,           in_value18  VARCHAR2 := NULL,
        in_name19   VARCHAR2 := NULL,           in_value19  VARCHAR2 := NULL,
        in_name20   VARCHAR2 := NULL,           in_value20  VARCHAR2 := NULL
    )
    RETURN VARCHAR2
    AS
        v_obj                   JSON_OBJECT_T;
    BEGIN
        -- construct a key-value pairs
        v_obj := JSON_OBJECT_T(JSON_OBJECT (
            CASE WHEN (in_name01 IS NULL OR in_value01 IS NULL) THEN '__' ELSE in_name01 END VALUE in_value01,
            CASE WHEN (in_name02 IS NULL OR in_value02 IS NULL) THEN '__' ELSE in_name02 END VALUE in_value02,
            CASE WHEN (in_name03 IS NULL OR in_value03 IS NULL) THEN '__' ELSE in_name03 END VALUE in_value03,
            CASE WHEN (in_name04 IS NULL OR in_value04 IS NULL) THEN '__' ELSE in_name04 END VALUE in_value04,
            CASE WHEN (in_name05 IS NULL OR in_value05 IS NULL) THEN '__' ELSE in_name05 END VALUE in_value05,
            CASE WHEN (in_name06 IS NULL OR in_value06 IS NULL) THEN '__' ELSE in_name06 END VALUE in_value06,
            CASE WHEN (in_name07 IS NULL OR in_value07 IS NULL) THEN '__' ELSE in_name07 END VALUE in_value07,
            CASE WHEN (in_name08 IS NULL OR in_value08 IS NULL) THEN '__' ELSE in_name08 END VALUE in_value08,
            CASE WHEN (in_name09 IS NULL OR in_value09 IS NULL) THEN '__' ELSE in_name09 END VALUE in_value09,
            CASE WHEN (in_name10 IS NULL OR in_value10 IS NULL) THEN '__' ELSE in_name10 END VALUE in_value10,
            CASE WHEN (in_name11 IS NULL OR in_value11 IS NULL) THEN '__' ELSE in_name11 END VALUE in_value11,
            CASE WHEN (in_name12 IS NULL OR in_value12 IS NULL) THEN '__' ELSE in_name12 END VALUE in_value12,
            CASE WHEN (in_name13 IS NULL OR in_value13 IS NULL) THEN '__' ELSE in_name13 END VALUE in_value13,
            CASE WHEN (in_name14 IS NULL OR in_value14 IS NULL) THEN '__' ELSE in_name14 END VALUE in_value14,
            CASE WHEN (in_name15 IS NULL OR in_value15 IS NULL) THEN '__' ELSE in_name15 END VALUE in_value15,
            CASE WHEN (in_name16 IS NULL OR in_value16 IS NULL) THEN '__' ELSE in_name16 END VALUE in_value16,
            CASE WHEN (in_name17 IS NULL OR in_value17 IS NULL) THEN '__' ELSE in_name17 END VALUE in_value17,
            CASE WHEN (in_name18 IS NULL OR in_value18 IS NULL) THEN '__' ELSE in_name18 END VALUE in_value18,
            CASE WHEN (in_name19 IS NULL OR in_value19 IS NULL) THEN '__' ELSE in_name19 END VALUE in_value19,
            CASE WHEN (in_name20 IS NULL OR in_value20 IS NULL) THEN '__' ELSE in_name20 END VALUE in_value20
        ));
        v_obj.REMOVE('__');     -- remove empty pairs
        --
        RETURN NULLIF(v_obj.STRINGIFY, '{}');
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
        in_comments             VARCHAR2        := NULL
    )
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --
        v_job_name              user_scheduler_jobs.job_name%TYPE;
        v_action                VARCHAR2(32767);
    BEGIN
        v_job_name := '"' || in_job_name || '"';
        --
        IF INSTR(v_job_name, '?') > 0 THEN
            v_job_name := DBMS_SCHEDULER.GENERATE_JOB_NAME(REPLACE(v_job_name, '?', ''));  -- create unique name
        END IF;
        --
        v_action := RTRIM(APEX_STRING.FORMAT (
            -- point of the first comment is that it will be visible in scheduler additional info
            q'!BEGIN
              !    DBMS_OUTPUT.PUT_LINE('%4');
              !    --
              !    core.log_module('JOB_EXECUTED|%6',
              !        'user_id',    '%1',
              !        'app_id',     '%2',
              !        'session_id', '%5',
              !        'comment',    '%4'
              !    );
              !    --
              !    IF '%1' IS NOT NULL AND %2 IS NOT NULL THEN
              !        core.create_session (
              !            in_user_id      => '%1',
              !            in_app_id       => %2,
              !            in_session_id   => %5
              !        );
              !    END IF;
              !    %3
              !EXCEPTION
              !WHEN OTHERS THEN
              !    core.raise_error();
              !END;
              !',
            p1          => in_user_id,
            p2          => NVL(TO_CHAR(COALESCE(in_app_id, core.get_app_id())), 'NULL'),
            p3          => REGEXP_REPLACE(in_statement, '(\s*;\s*)$', '') || ';',
            p4          => in_comments,
            p5          => NVL(TO_CHAR(in_session_id), 'NULL'),
            p6          => v_job_name,
            p_prefix    => '!'
        ));
        --
        core.log_debug('JOB_REQUESTED|' || v_job_name,
            in_comments,
            REGEXP_REPLACE(in_statement, '(\s*;\s*)$', '') || ';',              -- statement
            in_payload => v_action
        );

        -- either run on schedule or at specified date
        IF in_schedule_name IS NOT NULL THEN
            DBMS_SCHEDULER.CREATE_JOB (
                job_name        => v_job_name,
                schedule_name   => in_schedule_name,
                job_type        => 'PLSQL_BLOCK',
                job_action      => v_action,
                enabled         => FALSE,
                auto_drop       => in_autodrop,
                comments        => in_comments
            );
        ELSE
            DBMS_SCHEDULER.CREATE_JOB (
                job_name        => v_job_name,
                job_type        => 'PLSQL_BLOCK',
                job_action      => v_action,
                start_date      => in_start_date,
                enabled         => FALSE,
                auto_drop       => in_autodrop,
                comments        => in_comments
            );
        END IF;
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
            core.raise_error('GRANT_FAILED');
        END;
        --
        core.log_debug('JOB_CREATED|' || v_job_name);
        --
    EXCEPTION
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
        core.raise_error('STOP_JOB|' || v_job_name);
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
        core.raise_error('DROP_JOB|' || v_job_name);
    END;



    PROCEDURE raise_error (
        in_action_name          VARCHAR2    := NULL,
        in_arg1                 VARCHAR2    := NULL,
        in_arg2                 VARCHAR2    := NULL,
        in_arg3                 VARCHAR2    := NULL,
        in_arg4                 VARCHAR2    := NULL,
        in_arg5                 VARCHAR2    := NULL,
        in_arg6                 VARCHAR2    := NULL,
        in_arg7                 VARCHAR2    := NULL,
        in_arg8                 VARCHAR2    := NULL,
        in_arg9                 VARCHAR2    := NULL,
        in_arg10                VARCHAR2    := NULL,
        in_arg11                VARCHAR2    := NULL,
        in_arg12                VARCHAR2    := NULL,
        in_arg13                VARCHAR2    := NULL,
        in_arg14                VARCHAR2    := NULL,
        in_arg15                VARCHAR2    := NULL,
        in_arg16                VARCHAR2    := NULL,
        in_arg17                VARCHAR2    := NULL,
        in_arg18                VARCHAR2    := NULL,
        in_arg19                VARCHAR2    := NULL,
        in_arg20                VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL,
        in_json_object          BOOLEAN     := FALSE,
        in_rollback             BOOLEAN     := FALSE,
        in_traceback            BOOLEAN     := FALSE
    )
    AS
        v_message               VARCHAR2(4000);
        v_backtrace             VARCHAR2(4000);
    BEGIN
        -- rollback transaction if requested (cant do this from trigger)
        IF in_rollback THEN
            ROLLBACK;
        END IF;

        -- always log raised error
        core.log_error (
            in_action_name      => in_action_name,
            in_arg1             => in_arg1,
            in_arg2             => in_arg2,
            in_arg3             => in_arg3,
            in_arg4             => in_arg4,
            in_arg5             => in_arg5,
            in_arg6             => in_arg6,
            in_arg7             => in_arg7,
            in_arg8             => in_arg8,
            in_arg9             => in_arg9,
            in_arg10            => in_arg10,
            in_arg11            => in_arg11,
            in_arg12            => in_arg12,
            in_arg13            => in_arg13,
            in_arg14            => in_arg14,
            in_arg15            => in_arg15,
            in_arg16            => in_arg16,
            in_arg17            => in_arg17,
            in_arg18            => in_arg18,
            in_arg19            => in_arg19,
            in_arg20            => in_arg20,
            in_payload          => in_payload,
            in_json_object      => in_json_object
        );

        -- construct message for user
        v_message := SUBSTR(REPLACE(REPLACE(
            COALESCE(in_action_name, SQLERRM) ||
            RTRIM(
                '|' || in_arg1 || '|' || in_arg2 || '|' || in_arg3 || '|' || in_arg4 ||
                '|' || in_arg5 || '|' || in_arg6 || '|' || in_arg7 || '|' || in_arg8,
                '|'
            ) || CASE WHEN UPPER(core.get_user_id()) NOT IN ('NOBODY') THEN '| ' || core.get_caller_name(3, TRUE) END,
            '"', ''), '&' || 'quot;', ''),
            1, 4000);

        -- add backtrace for developers (or on demand) to quickly find the problem
        IF (in_traceback OR core.is_developer()) AND UPPER(core.get_user_id()) NOT IN ('NOBODY') THEN
            v_backtrace := SUBSTR('|' || REPLACE(REPLACE(get_shorter_stack(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE), '"', ''), '&' || 'quot;', ''), 1, 4000);
        END IF;
        --
        RAISE_APPLICATION_ERROR(core.app_exception_code, v_message || RTRIM(v_backtrace, '|'), TRUE);
    END;



    PROCEDURE log__ (
        in_action_type          CHAR,
        in_action_name          VARCHAR2,
        in_arg1                 VARCHAR2    := NULL,
        in_arg2                 VARCHAR2    := NULL,
        in_arg3                 VARCHAR2    := NULL,
        in_arg4                 VARCHAR2    := NULL,
        in_arg5                 VARCHAR2    := NULL,
        in_arg6                 VARCHAR2    := NULL,
        in_arg7                 VARCHAR2    := NULL,
        in_arg8                 VARCHAR2    := NULL,
        in_arg9                 VARCHAR2    := NULL,
        in_arg10                VARCHAR2    := NULL,
        in_arg11                VARCHAR2    := NULL,
        in_arg12                VARCHAR2    := NULL,
        in_arg13                VARCHAR2    := NULL,
        in_arg14                VARCHAR2    := NULL,
        in_arg15                VARCHAR2    := NULL,
        in_arg16                VARCHAR2    := NULL,
        in_arg17                VARCHAR2    := NULL,
        in_arg18                VARCHAR2    := NULL,
        in_arg19                VARCHAR2    := NULL,
        in_arg20                VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL,
        in_json_object          BOOLEAN     := FALSE
    )
    AS
        v_log_id                NUMBER;
    BEGIN
        v_log_id := core.log__ (
            in_action_type      => in_action_type,
            in_action_name      => in_action_name,
            in_arg1             => in_arg1,
            in_arg2             => in_arg2,
            in_arg3             => in_arg3,
            in_arg4             => in_arg4,
            in_arg5             => in_arg5,
            in_arg6             => in_arg6,
            in_arg7             => in_arg7,
            in_arg8             => in_arg8,
            in_arg9             => in_arg9,
            in_arg10            => in_arg10,
            in_arg11            => in_arg11,
            in_arg12            => in_arg12,
            in_arg13            => in_arg13,
            in_arg14            => in_arg14,
            in_arg15            => in_arg15,
            in_arg16            => in_arg16,
            in_arg17            => in_arg17,
            in_arg18            => in_arg18,
            in_arg19            => in_arg19,
            in_arg20            => in_arg20,
            in_payload          => in_payload,
            in_json_object      => in_json_object
        );
    END;



    FUNCTION log__ (
        in_action_type          CHAR,
        in_action_name          VARCHAR2,
        in_arg1                 VARCHAR2    := NULL,
        in_arg2                 VARCHAR2    := NULL,
        in_arg3                 VARCHAR2    := NULL,
        in_arg4                 VARCHAR2    := NULL,
        in_arg5                 VARCHAR2    := NULL,
        in_arg6                 VARCHAR2    := NULL,
        in_arg7                 VARCHAR2    := NULL,
        in_arg8                 VARCHAR2    := NULL,
        in_arg9                 VARCHAR2    := NULL,
        in_arg10                VARCHAR2    := NULL,
        in_arg11                VARCHAR2    := NULL,
        in_arg12                VARCHAR2    := NULL,
        in_arg13                VARCHAR2    := NULL,
        in_arg14                VARCHAR2    := NULL,
        in_arg15                VARCHAR2    := NULL,
        in_arg16                VARCHAR2    := NULL,
        in_arg17                VARCHAR2    := NULL,
        in_arg18                VARCHAR2    := NULL,
        in_arg19                VARCHAR2    := NULL,
        in_arg20                VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL,
        in_json_object          BOOLEAN     := FALSE
    )
    RETURN NUMBER
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --
        out_log_id              NUMBER;
        --
        v_message               VARCHAR2(32767);
        v_arguments             VARCHAR2(32767);
        v_callstack             VARCHAR2(32767);
        v_backtrace             VARCHAR2(32767);
    BEGIN
        -- gather usefull info:
        --      app, page, user, session    | these should be covered by default
        --      action_name                 | short and unique error message
        --      module_name + line          | source of the error
        --      arguments + payload         | arguments passed
        --      error_backtrace             | cleaned error backtrace
        --      callback                    | cleaned callstack
        --
        -- in custom logger we would have multiple columns in log table
        -- but to be able to use Logger or APEX logs, we have to concat these
        --
        v_message := COALESCE(in_action_name, SQLERRM) || '|' || core.get_caller_name(3, TRUE);

        -- convert arguments to JSON list or object
        v_arguments := CASE
            WHEN in_json_object THEN
                core.get_json_object (
                    in_name01   => in_arg1,     in_value01  => in_arg2,
                    in_name02   => in_arg3,     in_value02  => in_arg4,
                    in_name03   => in_arg5,     in_value03  => in_arg6,
                    in_name04   => in_arg7,     in_value04  => in_arg8,
                    in_name05   => in_arg9,     in_value05  => in_arg10,
                    in_name06   => in_arg11,    in_value06  => in_arg12,
                    in_name07   => in_arg13,    in_value07  => in_arg14,
                    in_name08   => in_arg15,    in_value08  => in_arg16,
                    in_name09   => in_arg17,    in_value09  => in_arg18,
                    in_name10   => in_arg19,    in_value10  => in_arg20
                )
            ELSE
                core.get_json_list (
                    in_arg1     => in_arg1,
                    in_arg2     => in_arg2,
                    in_arg3     => in_arg3,
                    in_arg4     => in_arg4,
                    in_arg5     => in_arg5,
                    in_arg6     => in_arg6,
                    in_arg7     => in_arg7,
                    in_arg8     => in_arg8,
                    in_arg9     => in_arg9,
                    in_arg10    => in_arg10,
                    in_arg11    => in_arg11,
                    in_arg12    => in_arg12,
                    in_arg13    => in_arg13,
                    in_arg14    => in_arg14,
                    in_arg15    => in_arg15,
                    in_arg16    => in_arg16,
                    in_arg17    => in_arg17,
                    in_arg18    => in_arg18,
                    in_arg19    => in_arg19,
                    in_arg20    => in_arg20
                )
            END;

        -- add error stack
        IF SQLCODE != 0 THEN
            v_backtrace := CHR(10) || '-- BACKTRACE:' || CHR(10) || core.get_shorter_stack(core.get_error_stack());
        END IF;

        -- add call stack
        IF (SQLCODE != 0 OR in_action_type IN (flag_error, flag_warning, flag_module)) THEN
            v_callstack := CHR(10) || '-- CALLSTACK:' || CHR(10) || core.get_shorter_stack(core.get_call_stack());
        END IF;

        -- finally store the log
        CASE in_action_type
            --
            -- @TODO: need a switch for APEX log, logger or custom logger
            --
            WHEN flag_error THEN
                core_customized.log_error (
                    in_message      => v_message,
                    in_arguments    => v_arguments,
                    in_payload      => in_payload,
                    in_backtrace    => v_backtrace,
                    in_callstack    => v_callstack
                );
                --
            WHEN flag_warning THEN
                core_customized.log_warning (
                    in_message      => v_message,
                    in_arguments    => v_arguments,
                    in_payload      => in_payload,
                    in_backtrace    => v_backtrace,
                    in_callstack    => v_callstack
                );
                --
            WHEN flag_debug THEN
                core_customized.log_debug (
                    in_message      => v_message,
                    in_arguments    => v_arguments,
                    in_payload      => in_payload,
                    in_backtrace    => v_backtrace,
                    in_callstack    => v_callstack
                );
                --
            WHEN flag_module THEN
                core_customized.log_module (
                    in_message      => v_message,
                    in_arguments    => v_arguments,
                    in_payload      => in_payload,
                    in_backtrace    => v_backtrace,
                    in_callstack    => v_callstack
                );
            ELSE
                NULL;
            END CASE;
        --
        COMMIT;
        --
        --out_log_id := APEX_DEBUG.GET_LAST_MESSAGE_ID();
        --
        RETURN out_log_id;
    EXCEPTION
    WHEN OTHERS THEN
        COMMIT;         -- just this log call
        --
        DBMS_OUTPUT.PUT_LINE('-- NOT LOGGED ERROR:');
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_STACK);
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_CALL_STACK);
        DBMS_OUTPUT.PUT_LINE('-- ^');
        --
        RAISE_APPLICATION_ERROR(core.app_exception_code, 'LOG_FAILED|' || SQLERRM, TRUE);
    END;



    PROCEDURE log_error (
        in_action_name          VARCHAR2    := NULL,
        in_arg1                 VARCHAR2    := NULL,
        in_arg2                 VARCHAR2    := NULL,
        in_arg3                 VARCHAR2    := NULL,
        in_arg4                 VARCHAR2    := NULL,
        in_arg5                 VARCHAR2    := NULL,
        in_arg6                 VARCHAR2    := NULL,
        in_arg7                 VARCHAR2    := NULL,
        in_arg8                 VARCHAR2    := NULL,
        in_arg9                 VARCHAR2    := NULL,
        in_arg10                VARCHAR2    := NULL,
        in_arg11                VARCHAR2    := NULL,
        in_arg12                VARCHAR2    := NULL,
        in_arg13                VARCHAR2    := NULL,
        in_arg14                VARCHAR2    := NULL,
        in_arg15                VARCHAR2    := NULL,
        in_arg16                VARCHAR2    := NULL,
        in_arg17                VARCHAR2    := NULL,
        in_arg18                VARCHAR2    := NULL,
        in_arg19                VARCHAR2    := NULL,
        in_arg20                VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL,
        in_json_object          BOOLEAN     := FALSE
    )
    AS
    BEGIN
        core.log__ (
            in_action_type      => core.flag_error,
            in_action_name      => in_action_name,
            in_arg1             => in_arg1,
            in_arg2             => in_arg2,
            in_arg3             => in_arg3,
            in_arg4             => in_arg4,
            in_arg5             => in_arg5,
            in_arg6             => in_arg6,
            in_arg7             => in_arg7,
            in_arg8             => in_arg8,
            in_arg9             => in_arg9,
            in_arg10            => in_arg10,
            in_arg11            => in_arg11,
            in_arg12            => in_arg12,
            in_arg13            => in_arg13,
            in_arg14            => in_arg14,
            in_arg15            => in_arg15,
            in_arg16            => in_arg16,
            in_arg17            => in_arg17,
            in_arg18            => in_arg18,
            in_arg19            => in_arg19,
            in_arg20            => in_arg20,
            in_payload          => in_payload,
            in_json_object      => in_json_object
        );
    END;



    FUNCTION log_error (
        in_action_name          VARCHAR2    := NULL,
        in_arg1                 VARCHAR2    := NULL,
        in_arg2                 VARCHAR2    := NULL,
        in_arg3                 VARCHAR2    := NULL,
        in_arg4                 VARCHAR2    := NULL,
        in_arg5                 VARCHAR2    := NULL,
        in_arg6                 VARCHAR2    := NULL,
        in_arg7                 VARCHAR2    := NULL,
        in_arg8                 VARCHAR2    := NULL,
        in_arg9                 VARCHAR2    := NULL,
        in_arg10                VARCHAR2    := NULL,
        in_arg11                VARCHAR2    := NULL,
        in_arg12                VARCHAR2    := NULL,
        in_arg13                VARCHAR2    := NULL,
        in_arg14                VARCHAR2    := NULL,
        in_arg15                VARCHAR2    := NULL,
        in_arg16                VARCHAR2    := NULL,
        in_arg17                VARCHAR2    := NULL,
        in_arg18                VARCHAR2    := NULL,
        in_arg19                VARCHAR2    := NULL,
        in_arg20                VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL,
        in_json_object          BOOLEAN     := FALSE
    )
    RETURN NUMBER
    AS
    BEGIN
        RETURN core.log__ (
            in_action_type      => core.flag_error,
            in_action_name      => in_action_name,
            in_arg1             => in_arg1,
            in_arg2             => in_arg2,
            in_arg3             => in_arg3,
            in_arg4             => in_arg4,
            in_arg5             => in_arg5,
            in_arg6             => in_arg6,
            in_arg7             => in_arg7,
            in_arg8             => in_arg8,
            in_arg9             => in_arg9,
            in_arg10            => in_arg10,
            in_arg11            => in_arg11,
            in_arg12            => in_arg12,
            in_arg13            => in_arg13,
            in_arg14            => in_arg14,
            in_arg15            => in_arg15,
            in_arg16            => in_arg16,
            in_arg17            => in_arg17,
            in_arg18            => in_arg18,
            in_arg19            => in_arg19,
            in_arg20            => in_arg20,
            in_payload          => in_payload,
            in_json_object      => in_json_object
        );
    END;



    PROCEDURE log_warning (
        in_action_name          VARCHAR2    := NULL,
        in_arg1                 VARCHAR2    := NULL,
        in_arg2                 VARCHAR2    := NULL,
        in_arg3                 VARCHAR2    := NULL,
        in_arg4                 VARCHAR2    := NULL,
        in_arg5                 VARCHAR2    := NULL,
        in_arg6                 VARCHAR2    := NULL,
        in_arg7                 VARCHAR2    := NULL,
        in_arg8                 VARCHAR2    := NULL,
        in_arg9                 VARCHAR2    := NULL,
        in_arg10                VARCHAR2    := NULL,
        in_arg11                VARCHAR2    := NULL,
        in_arg12                VARCHAR2    := NULL,
        in_arg13                VARCHAR2    := NULL,
        in_arg14                VARCHAR2    := NULL,
        in_arg15                VARCHAR2    := NULL,
        in_arg16                VARCHAR2    := NULL,
        in_arg17                VARCHAR2    := NULL,
        in_arg18                VARCHAR2    := NULL,
        in_arg19                VARCHAR2    := NULL,
        in_arg20                VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL,
        in_json_object          BOOLEAN     := FALSE
    )
    AS
    BEGIN
        core.log__ (
            in_action_type      => core.flag_warning,
            in_action_name      => in_action_name,
            in_arg1             => in_arg1,
            in_arg2             => in_arg2,
            in_arg3             => in_arg3,
            in_arg4             => in_arg4,
            in_arg5             => in_arg5,
            in_arg6             => in_arg6,
            in_arg7             => in_arg7,
            in_arg8             => in_arg8,
            in_arg9             => in_arg9,
            in_arg10            => in_arg10,
            in_arg11            => in_arg11,
            in_arg12            => in_arg12,
            in_arg13            => in_arg13,
            in_arg14            => in_arg14,
            in_arg15            => in_arg15,
            in_arg16            => in_arg16,
            in_arg17            => in_arg17,
            in_arg18            => in_arg18,
            in_arg19            => in_arg19,
            in_arg20            => in_arg20,
            in_payload          => in_payload,
            in_json_object      => in_json_object
        );
    END;



    FUNCTION log_warning (
        in_action_name          VARCHAR2    := NULL,
        in_arg1                 VARCHAR2    := NULL,
        in_arg2                 VARCHAR2    := NULL,
        in_arg3                 VARCHAR2    := NULL,
        in_arg4                 VARCHAR2    := NULL,
        in_arg5                 VARCHAR2    := NULL,
        in_arg6                 VARCHAR2    := NULL,
        in_arg7                 VARCHAR2    := NULL,
        in_arg8                 VARCHAR2    := NULL,
        in_arg9                 VARCHAR2    := NULL,
        in_arg10                VARCHAR2    := NULL,
        in_arg11                VARCHAR2    := NULL,
        in_arg12                VARCHAR2    := NULL,
        in_arg13                VARCHAR2    := NULL,
        in_arg14                VARCHAR2    := NULL,
        in_arg15                VARCHAR2    := NULL,
        in_arg16                VARCHAR2    := NULL,
        in_arg17                VARCHAR2    := NULL,
        in_arg18                VARCHAR2    := NULL,
        in_arg19                VARCHAR2    := NULL,
        in_arg20                VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL,
        in_json_object          BOOLEAN     := FALSE
    )
    RETURN NUMBER
    AS
    BEGIN
        RETURN core.log__ (
            in_action_type      => core.flag_warning,
            in_action_name      => in_action_name,
            in_arg1             => in_arg1,
            in_arg2             => in_arg2,
            in_arg3             => in_arg3,
            in_arg4             => in_arg4,
            in_arg5             => in_arg5,
            in_arg6             => in_arg6,
            in_arg7             => in_arg7,
            in_arg8             => in_arg8,
            in_arg9             => in_arg9,
            in_arg10            => in_arg10,
            in_arg11            => in_arg11,
            in_arg12            => in_arg12,
            in_arg13            => in_arg13,
            in_arg14            => in_arg14,
            in_arg15            => in_arg15,
            in_arg16            => in_arg16,
            in_arg17            => in_arg17,
            in_arg18            => in_arg18,
            in_arg19            => in_arg19,
            in_arg20            => in_arg20,
            in_payload          => in_payload,
            in_json_object      => in_json_object
        );
    END;



    PROCEDURE log_debug (
        in_action_name          VARCHAR2    := NULL,
        in_arg1                 VARCHAR2    := NULL,
        in_arg2                 VARCHAR2    := NULL,
        in_arg3                 VARCHAR2    := NULL,
        in_arg4                 VARCHAR2    := NULL,
        in_arg5                 VARCHAR2    := NULL,
        in_arg6                 VARCHAR2    := NULL,
        in_arg7                 VARCHAR2    := NULL,
        in_arg8                 VARCHAR2    := NULL,
        in_arg9                 VARCHAR2    := NULL,
        in_arg10                VARCHAR2    := NULL,
        in_arg11                VARCHAR2    := NULL,
        in_arg12                VARCHAR2    := NULL,
        in_arg13                VARCHAR2    := NULL,
        in_arg14                VARCHAR2    := NULL,
        in_arg15                VARCHAR2    := NULL,
        in_arg16                VARCHAR2    := NULL,
        in_arg17                VARCHAR2    := NULL,
        in_arg18                VARCHAR2    := NULL,
        in_arg19                VARCHAR2    := NULL,
        in_arg20                VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL,
        in_json_object          BOOLEAN     := FALSE
    )
    AS
    BEGIN
        core.log__ (
            in_action_type      => core.flag_debug,
            in_action_name      => in_action_name,
            in_arg1             => in_arg1,
            in_arg2             => in_arg2,
            in_arg3             => in_arg3,
            in_arg4             => in_arg4,
            in_arg5             => in_arg5,
            in_arg6             => in_arg6,
            in_arg7             => in_arg7,
            in_arg8             => in_arg8,
            in_arg9             => in_arg9,
            in_arg10            => in_arg10,
            in_arg11            => in_arg11,
            in_arg12            => in_arg12,
            in_arg13            => in_arg13,
            in_arg14            => in_arg14,
            in_arg15            => in_arg15,
            in_arg16            => in_arg16,
            in_arg17            => in_arg17,
            in_arg18            => in_arg18,
            in_arg19            => in_arg19,
            in_arg20            => in_arg20,
            in_payload          => in_payload,
            in_json_object      => in_json_object
        );
    END;



    FUNCTION log_debug (
        in_action_name          VARCHAR2    := NULL,
        in_arg1                 VARCHAR2    := NULL,
        in_arg2                 VARCHAR2    := NULL,
        in_arg3                 VARCHAR2    := NULL,
        in_arg4                 VARCHAR2    := NULL,
        in_arg5                 VARCHAR2    := NULL,
        in_arg6                 VARCHAR2    := NULL,
        in_arg7                 VARCHAR2    := NULL,
        in_arg8                 VARCHAR2    := NULL,
        in_arg9                 VARCHAR2    := NULL,
        in_arg10                VARCHAR2    := NULL,
        in_arg11                VARCHAR2    := NULL,
        in_arg12                VARCHAR2    := NULL,
        in_arg13                VARCHAR2    := NULL,
        in_arg14                VARCHAR2    := NULL,
        in_arg15                VARCHAR2    := NULL,
        in_arg16                VARCHAR2    := NULL,
        in_arg17                VARCHAR2    := NULL,
        in_arg18                VARCHAR2    := NULL,
        in_arg19                VARCHAR2    := NULL,
        in_arg20                VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL,
        in_json_object          BOOLEAN     := FALSE
    )
    RETURN NUMBER
    AS
    BEGIN
        RETURN core.log__ (
            in_action_type      => core.flag_debug,
            in_action_name      => in_action_name,
            in_arg1             => in_arg1,
            in_arg2             => in_arg2,
            in_arg3             => in_arg3,
            in_arg4             => in_arg4,
            in_arg5             => in_arg5,
            in_arg6             => in_arg6,
            in_arg7             => in_arg7,
            in_arg8             => in_arg8,
            in_arg9             => in_arg9,
            in_arg10            => in_arg10,
            in_arg11            => in_arg11,
            in_arg12            => in_arg12,
            in_arg13            => in_arg13,
            in_arg14            => in_arg14,
            in_arg15            => in_arg15,
            in_arg16            => in_arg16,
            in_arg17            => in_arg17,
            in_arg18            => in_arg18,
            in_arg19            => in_arg19,
            in_arg20            => in_arg20,
            in_payload          => in_payload,
            in_json_object      => in_json_object
        );
    END;



    PROCEDURE log_request
    AS
        v_args                  VARCHAR2(32767);
    BEGIN
        -- parse arguments
        v_args := core.get_request_url(in_arguments_only => TRUE);
        --
        IF v_args IS NOT NULL THEN
            BEGIN
                SELECT JSON_OBJECTAGG (
                    REGEXP_REPLACE(REGEXP_SUBSTR(v_args, '[^&]+', 1, LEVEL), '[=].*$', '')
                    VALUE REGEXP_REPLACE(REGEXP_SUBSTR(v_args, '[^&]+', 1, LEVEL), '^[^=]+[=]', '')
                )
                INTO v_args
                FROM DUAL
                CONNECT BY LEVEL <= REGEXP_COUNT(v_args, '&') + 1
                ORDER BY LEVEL;
            EXCEPTION
            WHEN OTHERS THEN
                core.log_error('JSON_ERROR', v_args);
            END;
        END IF;
        --
        core.log_debug (
            in_action_name      => 'REQUEST',
            in_arg1             => v_args,
            in_arg2             => core.get_request()
        );
    END;



    PROCEDURE log_module (
        in_action_name          VARCHAR2    := NULL,
        in_arg1                 VARCHAR2    := NULL,
        in_arg2                 VARCHAR2    := NULL,
        in_arg3                 VARCHAR2    := NULL,
        in_arg4                 VARCHAR2    := NULL,
        in_arg5                 VARCHAR2    := NULL,
        in_arg6                 VARCHAR2    := NULL,
        in_arg7                 VARCHAR2    := NULL,
        in_arg8                 VARCHAR2    := NULL,
        in_arg9                 VARCHAR2    := NULL,
        in_arg10                VARCHAR2    := NULL,
        in_arg11                VARCHAR2    := NULL,
        in_arg12                VARCHAR2    := NULL,
        in_arg13                VARCHAR2    := NULL,
        in_arg14                VARCHAR2    := NULL,
        in_arg15                VARCHAR2    := NULL,
        in_arg16                VARCHAR2    := NULL,
        in_arg17                VARCHAR2    := NULL,
        in_arg18                VARCHAR2    := NULL,
        in_arg19                VARCHAR2    := NULL,
        in_arg20                VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL,
        in_json_object          BOOLEAN     := FALSE
    )
    AS
    BEGIN
        core.log__ (
            in_action_type      => core.flag_module,
            in_action_name      => in_action_name,
            in_arg1             => in_arg1,
            in_arg2             => in_arg2,
            in_arg3             => in_arg3,
            in_arg4             => in_arg4,
            in_arg5             => in_arg5,
            in_arg6             => in_arg6,
            in_arg7             => in_arg7,
            in_arg8             => in_arg8,
            in_arg9             => in_arg9,
            in_arg10            => in_arg10,
            in_arg11            => in_arg11,
            in_arg12            => in_arg12,
            in_arg13            => in_arg13,
            in_arg14            => in_arg14,
            in_arg15            => in_arg15,
            in_arg16            => in_arg16,
            in_arg17            => in_arg17,
            in_arg18            => in_arg18,
            in_arg19            => in_arg19,
            in_arg20            => in_arg20,
            in_payload          => in_payload,
            in_json_object      => in_json_object
        );
    END;



    FUNCTION log_module (
        in_action_name          VARCHAR2    := NULL,
        in_arg1                 VARCHAR2    := NULL,
        in_arg2                 VARCHAR2    := NULL,
        in_arg3                 VARCHAR2    := NULL,
        in_arg4                 VARCHAR2    := NULL,
        in_arg5                 VARCHAR2    := NULL,
        in_arg6                 VARCHAR2    := NULL,
        in_arg7                 VARCHAR2    := NULL,
        in_arg8                 VARCHAR2    := NULL,
        in_arg9                 VARCHAR2    := NULL,
        in_arg10                VARCHAR2    := NULL,
        in_arg11                VARCHAR2    := NULL,
        in_arg12                VARCHAR2    := NULL,
        in_arg13                VARCHAR2    := NULL,
        in_arg14                VARCHAR2    := NULL,
        in_arg15                VARCHAR2    := NULL,
        in_arg16                VARCHAR2    := NULL,
        in_arg17                VARCHAR2    := NULL,
        in_arg18                VARCHAR2    := NULL,
        in_arg19                VARCHAR2    := NULL,
        in_arg20                VARCHAR2    := NULL,
        in_payload              VARCHAR2    := NULL,
        in_json_object          BOOLEAN     := FALSE
    )
    RETURN NUMBER
    AS
    BEGIN
        RETURN core.log__ (
            in_action_type      => core.flag_module,
            in_action_name      => in_action_name,
            in_arg1             => in_arg1,
            in_arg2             => in_arg2,
            in_arg3             => in_arg3,
            in_arg4             => in_arg4,
            in_arg5             => in_arg5,
            in_arg6             => in_arg6,
            in_arg7             => in_arg7,
            in_arg8             => in_arg8,
            in_arg9             => in_arg9,
            in_arg10            => in_arg10,
            in_arg11            => in_arg11,
            in_arg12            => in_arg12,
            in_arg13            => in_arg13,
            in_arg14            => in_arg14,
            in_arg15            => in_arg15,
            in_arg16            => in_arg16,
            in_arg17            => in_arg17,
            in_arg18            => in_arg18,
            in_arg19            => in_arg19,
            in_arg20            => in_arg20,
            in_payload          => in_payload,
            in_json_object      => in_json_object
        );
    END;



    PROCEDURE log_success (
        in_log_id               NUMBER
    )
    AS
    BEGIN
        --
        -- @TODO: IMPLEMENT
        --
        NULL;
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
        v_action_name           VARCHAR2(128);              -- short error type visible to user
        v_log                   BOOLEAN         := TRUE;
        v_constraint_code       PLS_INTEGER;
    BEGIN
        out_result := APEX_ERROR.INIT_ERROR_RESULT(p_error => p_error);
        --
        out_result.message := REPLACE(out_result.message, '&' || 'quot;', '"');  -- replace some HTML entities

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
            v_action_name := APEX_ERROR.EXTRACT_CONSTRAINT_NAME (
                p_error             => p_error,
                p_include_schema    => FALSE
            );
            --
            out_result.message          := c_constraint_prefix || v_action_name;
            out_result.display_location := APEX_ERROR.C_INLINE_IN_NOTIFICATION;
            --
        ELSIF NVL(v_constraint_code, p_error.ora_sqlcode) IN (
            -1400   -- ORA-01400: cannot insert NULL into...
        ) THEN
            out_result.message          := c_not_null_prefix || REGEXP_SUBSTR(out_result.message, '\.["]([^"]+)["]\)', 1, 1, NULL, 1);
            --
        ELSIF p_error.is_internal_error THEN
            v_action_name := 'INTERNAL_ERROR';
        ELSE
            v_action_name := 'UNKNOWN_ERROR';
        END IF;

        -- dont log session errors
        IF p_error.is_internal_error AND p_error.ora_sqlcode IS NULL THEN
            IF p_error.apex_error_code NOT IN ('APEX.SESSION.EXPIRED') THEN
                v_log := FALSE;
            END IF;
        END IF;

        -- store incident in your log
        IF v_log THEN
            v_log_id := core.log_error (
                in_action_name  => v_action_name,
                in_arg1         => 'message',           in_arg2     => out_result.message,
                in_arg3         => 'page',              in_arg4     => TO_CHAR(APEX_APPLICATION.G_FLOW_STEP_ID),
                in_arg5         => 'component_type',    in_arg6     => REPLACE(p_error.component.type, 'APEX_APPLICATION_', ''),
                in_arg7         => 'component_name',    in_arg8     => p_error.component.name,
                in_arg9         => 'process_point',     in_arg10    => REPLACE(SYS_CONTEXT('USERENV', 'ACTION'), 'Processes - point: ', ''),
                in_arg11        => 'page_item',         in_arg12    => out_result.page_item_name,
                in_arg13        => 'column_alias',      in_arg14    => out_result.column_alias,
                in_arg15        => 'error',             in_arg16    => APEX_ERROR.GET_FIRST_ORA_ERROR_TEXT(p_error => p_error),
                in_payload      =>
                    CHR(10) || '-- DESCRIPTION:' || CHR(10) || core.get_shorter_stack(p_error.ora_sqlerrm)      ||
                    CHR(10) || '-- STATEMENT:'   || CHR(10) || core.get_shorter_stack(p_error.error_statement)  ||
                    CHR(10) || '-- BACKTRACE:'   || CHR(10) || core.get_shorter_stack(p_error.error_backtrace),
                in_json_object  => TRUE
            );
        END IF;

        -- mark associated page item (when possible)
        IF out_result.page_item_name IS NULL AND out_result.column_alias IS NULL THEN
            APEX_ERROR.AUTO_SET_ASSOCIATED_ITEM (
                p_error         => p_error,
                p_error_result  => out_result
            );
        END IF;

        -- translate message (custom) just for user (not for the log)
        -- with APEX globalization - text messages - we can also auto add new messages there through APEX_LANG.CREATE_MESSAGE
        -- for custom table out_result.message := NVL(core.get_translated(out_result.message), out_result.message);

        -- show only the latest error message to common users
        out_result.message := CASE WHEN v_log_id IS NOT NULL THEN '#' || TO_CHAR(v_log_id) || '<br />' END
            || core.get_translated(REGEXP_REPLACE(out_result.message, '^(ORA' || TO_CHAR(app_exception_code) || ':\s*)\s*', ''));
        --out_result.message := REPLACE(out_result.message, '&' || '#X27;', '');
        --
        out_result.display_location := APEX_ERROR.C_INLINE_IN_NOTIFICATION;  -- also removes HTML entities
        --
        RETURN out_result;
    EXCEPTION
    WHEN OTHERS THEN
        core.raise_error (
            in_action_name  => v_action_name,
            in_arg1         => APEX_ERROR.GET_FIRST_ORA_ERROR_TEXT(p_error => p_error)
        );
    END;



    FUNCTION get_translated (
        in_message              VARCHAR2
    )
    RETURN VARCHAR2
    AS
        v_message               VARCHAR2(32767) := in_message;
    BEGIN
        IF REGEXP_LIKE(in_message, '^[A-Za-z][A-Za-z0-9_\|]*$') THEN
            v_message := NVL(NULLIF(APEX_LANG.MESSAGE(in_message), UPPER(in_message)), v_message);
        END IF;
        --
        RETURN REPLACE(REPLACE(REPLACE(
            v_message,
            '| ', '<br />'),
            '|', ' | '),
            '[', ' [');
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
        in_method               CHAR            := NULL
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
            DBMS_MVIEW.REFRESH (
                list            => c.owner || '.' || c.mview_name,
                method          => NVL(in_method, 'C'),
                parallelism     => 1,
                atomic_refresh  => FALSE
            );
            --
            IF in_percent > 0 THEN
                DBMS_STATS.GATHER_TABLE_STATS (
                    ownname             => c.owner,
                    tabname             => c.mview_name,
                    estimate_percent    => in_percent,
                    granularity         => 'ALL'
                );
            END IF;
        END LOOP;
    EXCEPTION
    WHEN OTHERS THEN
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
    RESULT_CACHE
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
        v_app_id                CONSTANT NUMBER         := COALESCE(in_app_id,  core.get_context_id());
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
        UTL_SMTP.MAIL(conn, quote_address(c_smtp_from, TRUE));
        --
        -- @TODO: apex_applications.email_from
        --

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
            core.raise_error('WRONG_RESPONSE_CODE', http_resp.status_code);
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
        in_file_mime                        VARCHAR2,
        in_file_payload     IN OUT NOCOPY   BLOB
    )
    AS
    BEGIN
        HTP.INIT;
        OWA_UTIL.MIME_HEADER(in_file_mime, FALSE);
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
            RAISE_APPLICATION_ERROR(c_assert_exception_code, c_assert_message || in_error_message);
        END IF;
    END;



    PROCEDURE assert_false (
        in_error_message        VARCHAR2,
        in_bool_expression      BOOLEAN
    )
    AS
    BEGIN
        IF NOT in_bool_expression THEN
            RAISE_APPLICATION_ERROR(c_assert_exception_code, c_assert_message || in_error_message);
        END IF;
    END;



    PROCEDURE assert_not_null (
        in_error_message        VARCHAR2,
        in_value                VARCHAR2
    )
    AS
    BEGIN
        IF in_value IS NULL THEN
            RAISE_APPLICATION_ERROR(c_assert_exception_code, c_assert_message || in_error_message);
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
                core.raise_error('REGION_NOT_FOUND', in_static_id);
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

END;
/

