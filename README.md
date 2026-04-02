# CORE23

**Simplified CORE for Oracle APEX applications**

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Prerequisites & Requirements](#2-prerequisites--requirements)
3. [Installation & Setup](#3-installation--setup)
4. [Architecture & Structure](#4-architecture--structure)
5. [API Reference](#5-api-reference)
   - [Application Context Functions](#51-application-context-functions)
   - [Error Handling](#52-error-handling)
   - [Session State Management](#53-session-state-management)
   - [Email / SMTP](#54-email--smtp)
   - [Logging & Debugging](#55-logging--debugging)
   - [Translations & Globalization](#56-translations--globalization)
   - [Performance & Time Tracking](#57-performance--time-tracking)
   - [JSON Utilities](#58-json-utilities)

---

## 1. Project Overview

**CORE23** is a lightweight PL/SQL utility package for [Oracle APEX](https://apex.oracle.com) application development. It is a deliberately simplified successor to the author's original [CORE](https://github.com/jkvetina/CORE) framework — designed to provide essential helper utilities **without requiring any additional database tables**.

### Why CORE23?

The original CORE framework offered a rich set of features but came with a set of database tables (for logging, translations, etc.). CORE23 strips this down to the essentials — a single, self-contained PL/SQL package that can be dropped into any Oracle schema and immediately used in APEX applications.

**Key characteristics:**

- **No tables required** — zero schema footprint beyond the package itself
- **Single package** — one SQL file, easy to review and maintain
- **APEX-native** — built around Oracle APEX APIs (`APEX_APPLICATION`, `APEX_ERROR`, `APEX_DEBUG`, `UTL_SMTP`, etc.)
- **Lightweight** — minimal dependencies, no configuration tables or sequences

---

## 2. Prerequisites & Requirements

| Requirement | Details |
|---|---|
| Oracle Database | 12c Release 2 or later (19c+ recommended) |
| Oracle APEX | 5.1 or later (APEX 22.x / 23.x recommended) |
| Database Privileges | `CREATE SESSION`, `CREATE PROCEDURE`, `CREATE PACKAGE` |
| Oracle packages used | `UTL_SMTP`, `UTL_CALL_STACK`, `APEX_APPLICATION`, `APEX_ERROR`, `APEX_DEBUG`, `APEX_UTIL` |
| Network ACL (for email) | Database ACL granting `UTL_SMTP` access to your SMTP host |

> **Note:** CORE23 is designed for use within an APEX session context. Some functions (e.g., `get_app_id`, `get_user_id`) will return `NULL` or raise an error when called outside of a valid APEX session.

---

## 3. Installation & Setup

### Step 1 — Clone or download the repository

```bash
git clone https://github.com/jkvetina/CORE23.git
```

Or download the ZIP from the GitHub repository page and extract it.

### Step 2 — Install the package

Connect to your Oracle schema using SQL*Plus, SQLcl, or SQL Developer and run the main package file:

```sql
@database/packages/core.sql
```

This file contains both the **package specification** and the **package body** in a single script.

### Step 3 — Verify installation

After installation, confirm the package compiled successfully:

```sql
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_name = 'CORE'
ORDER  BY object_type;
```

Both `PACKAGE` and `PACKAGE BODY` should show `VALID`.

### Step 4 — Register APEX error handling function (optional)

To use CORE23's custom APEX error handler, register it in your APEX application:

1. Go to **Shared Components → Application Definition**
2. Under **Error Handling**, set **Error Handling Function** to: `CORE.HANDLE_APEX_ERROR`

---

## 4. Architecture & Structure

### Repository layout

```
CORE23/
└── database/
    └── packages/
        └── core.sql        ← Single file: package spec + body
```

CORE23 is intentionally minimal. The entire framework lives in one file — `database/packages/core.sql` — which defines both the package specification (public API) and the package body (implementation).

### Package design philosophy

The `CORE` package follows these design principles:

**Stateless where possible** — most functions read from APEX's built-in session context (`APEX_APPLICATION`, `V()`, `NV()`) rather than maintaining their own state.

**Oracle APEX–centric** — all utility functions are designed to be called from within an active APEX session (page processes, validations, dynamic actions, PL/SQL regions).

**No custom tables** — unlike frameworks that log to custom tables or store translations in a custom schema, CORE23 relies entirely on Oracle's built-in packages and APEX's own APIs.

### Core internal components

| Component | Description |
|---|---|
| Package Specification | Public API: declares all functions, procedures, types, and constants |
| Package Body | Implementation of all declared subprograms |
| Application context helpers | Wrappers around `APEX_APPLICATION.G_*` globals |
| Error handler | Custom `APEX_ERROR_HANDLING_FUNCTION_T` implementation |
| Email utilities | PL/SQL SMTP sending via `UTL_SMTP` with MIME multipart support |
| Call stack utilities | Wrappers around `UTL_CALL_STACK` for readable error traces |

---

## 5. API Reference

> All functions and procedures below are members of the `core` package. Call them as `core.function_name(...)`.

---

### 5.1 Application Context Functions

These functions provide convenient access to the current APEX session context.

#### `core.get_app_id`

Returns the current APEX application ID (`APEX_APPLICATION.G_FLOW_ID`).

```sql
FUNCTION get_app_id RETURN NUMBER;
```

**Example:**
```sql
DECLARE
    l_app_id NUMBER := core.get_app_id();
BEGIN
    DBMS_OUTPUT.PUT_LINE('App ID: ' || l_app_id);
END;
```

---

#### `core.get_app_owner`

Returns the schema (parsing schema) that owns the current APEX application.

```sql
FUNCTION get_app_owner RETURN VARCHAR2;
```

---

#### `core.get_app_name`

Returns the name of the current APEX application.

```sql
FUNCTION get_app_name RETURN VARCHAR2;
```

---

#### `core.get_page_id`

Returns the current APEX page ID (`APEX_APPLICATION.G_FLOW_STEP_ID`).

```sql
FUNCTION get_page_id RETURN NUMBER;
```

---

#### `core.get_session_id`

Returns the current APEX session ID (`APEX_APPLICATION.G_INSTANCE`).

```sql
FUNCTION get_session_id RETURN NUMBER;
```

---

#### `core.get_user_id`

Returns the currently authenticated APEX user (`APEX_APPLICATION.G_USER`).

```sql
FUNCTION get_user_id RETURN VARCHAR2;
```

---

#### `core.get_context_app`

Returns the application ID from the application context. Useful when `APEX_APPLICATION` globals are not yet initialized, e.g., in background jobs.

```sql
FUNCTION get_context_app RETURN NUMBER;
```

---

### 5.2 Error Handling

#### `core.raise_error`

Raises an application error with a formatted message. Supports up to four substitution arguments (replacing `%1` through `%4` placeholders in the message string).

```sql
PROCEDURE raise_error (
    in_message      IN VARCHAR2,
    in_arg1         IN VARCHAR2  DEFAULT NULL,
    in_arg2         IN VARCHAR2  DEFAULT NULL,
    in_arg3         IN VARCHAR2  DEFAULT NULL,
    in_arg4         IN VARCHAR2  DEFAULT NULL
);
```

**Example:**
```sql
core.raise_error('Invalid value %1 for parameter %2', p_value, 'MAX_ROWS');
```

---

#### `core.handle_apex_error`

A custom APEX error handling function conforming to the `APEX_ERROR_HANDLING_FUNCTION_T` type. Intercepts APEX errors, provides user-friendly messages, and adds technical details (including stack traces) to the APEX debug log.

Register this in your APEX application under **Shared Components → Application Definition → Error Handling Function**.

```sql
FUNCTION handle_apex_error (
    p_error IN APEX_ERROR.T_ERROR
) RETURN APEX_ERROR.T_ERROR_RESULT;
```

---

### 5.3 Session State Management

#### `core.get_item`

Returns the value of an APEX page item or application item from session state.

```sql
FUNCTION get_item (
    in_name IN VARCHAR2
) RETURN VARCHAR2;
```

**Example:**
```sql
DECLARE
    l_val VARCHAR2(255) := core.get_item('P10_CUSTOMER_ID');
BEGIN
    NULL;
END;
```

---

#### `core.set_item`

Sets the value of an APEX page item or application item in session state using `APEX_UTIL.SET_SESSION_STATE`.

```sql
PROCEDURE set_item (
    in_name     IN VARCHAR2,
    in_value    IN VARCHAR2
);
```

---

### 5.4 Email / SMTP

CORE23 includes a built-in SMTP email utility built on top of Oracle's `UTL_SMTP` package, supporting MIME multipart messages, HTML bodies, and Base64-encoded attachments.

#### `core.send_mail`

Sends an email via SMTP. The body can be plain text or HTML. Email headers (Date, From, To, Subject, Reply-To) are automatically formatted per RFC 2822. The body is Base64-encoded for safe transmission.

```sql
PROCEDURE send_mail (
    in_to           IN VARCHAR2,
    in_subject      IN VARCHAR2,
    in_body         IN CLOB,
    in_from         IN VARCHAR2  DEFAULT NULL,
    in_cc           IN VARCHAR2  DEFAULT NULL,
    in_bcc          IN VARCHAR2  DEFAULT NULL,
    in_reply_to     IN VARCHAR2  DEFAULT NULL,
    in_smtp_host    IN VARCHAR2  DEFAULT 'localhost',
    in_smtp_port    IN NUMBER    DEFAULT 25
);
```

**Example:**
```sql
core.send_mail(
    in_to      => 'recipient@example.com',
    in_subject => 'Report Ready',
    in_body    => '<h1>Your report is ready.</h1>',
    in_from    => 'noreply@yourdomain.com'
);
```

---

### 5.5 Logging & Debugging

CORE23 integrates with Oracle APEX's built-in debug log (`APEX_DEBUG`) rather than maintaining a custom log table.

#### `core.log`

Writes a formatted message to the APEX debug log. Messages are only written when APEX debug mode is enabled for the current session.

```sql
PROCEDURE log (
    in_message  IN VARCHAR2,
    in_arg1     IN VARCHAR2  DEFAULT NULL,
    in_arg2     IN VARCHAR2  DEFAULT NULL,
    in_arg3     IN VARCHAR2  DEFAULT NULL,
    in_arg4     IN VARCHAR2  DEFAULT NULL
);
```

**Example:**
```sql
core.log('Processing customer %1 with %2 orders', l_customer_id, l_order_count);
```

---

#### `core.get_call_stack`

Returns a human-readable representation of the current PL/SQL call stack using `UTL_CALL_STACK`. Useful for including in error messages and debug output.

```sql
FUNCTION get_call_stack RETURN VARCHAR2;
```

---

### 5.6 Translations & Globalization

CORE23 provides lightweight message translation support that defers to APEX's built-in translation APIs where possible.

#### `core.get_message`

Retrieves a translated message by name from the APEX messages dictionary (`APEX_LANG.MESSAGE`), substituting up to four arguments. If the message is not found, the name itself is returned as a fallback.

```sql
FUNCTION get_message (
    in_name     IN VARCHAR2,
    in_arg1     IN VARCHAR2  DEFAULT NULL,
    in_arg2     IN VARCHAR2  DEFAULT NULL,
    in_arg3     IN VARCHAR2  DEFAULT NULL,
    in_arg4     IN VARCHAR2  DEFAULT NULL
) RETURN VARCHAR2;
```

---

### 5.7 Performance & Time Tracking

#### `core.get_timer`

Returns the elapsed time in milliseconds since the APEX session began (or since the last reset). Useful for performance profiling in page processes.

```sql
FUNCTION get_timer RETURN NUMBER;
```

---

### 5.8 JSON Utilities

CORE23 includes helpers for working with JSON data in PL/SQL, wrapping Oracle's built-in `APEX_JSON` package.

#### `core.get_json_value`

Extracts a scalar value from a JSON string given a dot-notation path.

```sql
FUNCTION get_json_value (
    in_json     IN CLOB,
    in_path     IN VARCHAR2
) RETURN VARCHAR2;
```

**Example:**
```sql
DECLARE
    l_name VARCHAR2(100);
BEGIN
    l_name := core.get_json_value('{"user":{"name":"Alice"}}', 'user.name');
    -- l_name = 'Alice'
END;
```

---

## Notes on This Documentation

> This documentation was generated by analyzing the public GitHub repository at [github.com/jkvetina/CORE23](https://github.com/jkvetina/CORE23) and indexed source code. Some function signatures and parameter names may be slightly paraphrased. For authoritative details, always refer to the source file `database/packages/core.sql` in the repository.

---

*Generated: April 2026*
