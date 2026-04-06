-- =====================================================
-- RUN ON A FRESH EMPTY DATABASE ONLY.
-- RUN ORDER:
--   BLOCK 1  — Roles
--   BLOCK 2  — Core Tables
--   BLOCK 3  — Helper Functions (non-schema-bound)
--   BLOCK 4  — RLS Predicate Function (schema-bound)
--   BLOCK 5  — RLS Security Policies
--   BLOCK 6  — Compliance Tables
--   BLOCK 7  — Permissions & DENY
--   BLOCK 8  — Indexes
-- =====================================================


-- =====================================================
-- BLOCK 1: ROLES
-- Must exist before any GRANT/DENY statements
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'admin_user'   AND type = 'R')
    CREATE ROLE admin_user;
GO
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'app_user'     AND type = 'R')
    CREATE ROLE app_user;
GO
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'auditor_user' AND type = 'R')
    CREATE ROLE auditor_user;
GO


-- =====================================================
-- BLOCK 2: CORE TABLES
-- Order: users -> nodes -> telemetry tables
-- users and nodes have no foreign keys so they go first
-- Telemetry tables all reference nodes(id)
-- =====================================================

CREATE TABLE dbo.users (
    id                      UNIQUEIDENTIFIER    PRIMARY KEY DEFAULT NEWID(),
    email                   NVARCHAR(255)       NOT NULL UNIQUE,
    full_name               NVARCHAR(255)       NULL,

    -- Role & clearance (AC.L2-3.1.2)
    role                    NVARCHAR(20)        NOT NULL DEFAULT 'readonly'
                                                CONSTRAINT CK_users_role
                                                CHECK (role IN ('admin','analyst','operator','auditor','readonly')),
    clearance_level         NVARCHAR(20)        NOT NULL DEFAULT 'UNCLASSIFIED'
                                                CONSTRAINT CK_users_clearance
                                                CHECK (clearance_level IN ('UNCLASSIFIED','CUI','SECRET')),

    -- Identity & auth provider (IA.L2-3.5.1)
    email_verified          BIT                 NOT NULL DEFAULT 0,
    auth_provider           NVARCHAR(50)        NOT NULL DEFAULT 'local'
                                                CONSTRAINT CK_users_auth_provider
                                                CHECK (auth_provider IN ('local','ldap','saml','entra')),
    auth_provider_id        NVARCHAR(255)       NULL,

    -- Password auth — hashed by backend, never plaintext (IA.L2-3.5.2)
    password_hash           NVARCHAR(255)       NULL,
    password_salt           NVARCHAR(100)       NULL,
    password_algorithm      NVARCHAR(20)        NOT NULL DEFAULT 'argon2id'
                                                CONSTRAINT CK_users_pwd_algo
                                                CHECK (password_algorithm IN ('argon2id','bcrypt')),
    password_changed_at     DATETIME2           NULL,
    password_expires_at     DATETIME2           NULL,
    must_change_password    BIT                 NOT NULL DEFAULT 0,

    -- Account state & lockout (IA.L2-3.5.3)
    mfa_enforced            BIT                 NOT NULL DEFAULT 1,
    last_login              DATETIME2           NULL,
    account_locked          BIT                 NOT NULL DEFAULT 0,
    failed_login_count      INT                 NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.nodes (
    id                  UNIQUEIDENTIFIER    PRIMARY KEY DEFAULT NEWID(),
    -- Classification used by RLS to enforce data isolation (SC.L2-3.13.8)
    classification      NVARCHAR(20)        NOT NULL DEFAULT 'UNCLASSIFIED'
                                            CONSTRAINT CK_nodes_classification
                                            CHECK (classification IN ('UNCLASSIFIED','CUI','SECRET')),
    organization_id     UNIQUEIDENTIFIER    NULL
);
GO

CREATE TABLE dbo.cpu (
    row_id              INT IDENTITY(1,1)   PRIMARY KEY,
    cpu_percent         FLOAT               NOT NULL,
    cpu_core_percent    INT                 NOT NULL,
    cpu_frequency       FLOAT               NOT NULL,
    user_id             UNIQUEIDENTIFIER    NULL,
    node_id             UNIQUEIDENTIFIER    NULL,
    CONSTRAINT FK_cpu_node FOREIGN KEY (node_id) REFERENCES dbo.nodes(id)
);
GO

CREATE TABLE dbo.disk (
    row_id              INT IDENTITY(1,1)   PRIMARY KEY,
    disk_used           FLOAT               NOT NULL,
    disk_total          FLOAT               NOT NULL,
    disk_percent        INT                 NOT NULL,
    read_bytes          FLOAT               NOT NULL,
    write_bytes         FLOAT               NOT NULL,
    user_id             UNIQUEIDENTIFIER    NULL,
    node_id             UNIQUEIDENTIFIER    NULL,
    CONSTRAINT FK_disk_node FOREIGN KEY (node_id) REFERENCES dbo.nodes(id)
);
GO

CREATE TABLE dbo.ram (
    row_id              INT IDENTITY(1,1)   PRIMARY KEY,
    ram_used            FLOAT               NOT NULL,
    ram_total           FLOAT               NOT NULL,
    ram_percent         INT                 NOT NULL,
    user_id             UNIQUEIDENTIFIER    NULL,
    node_id             UNIQUEIDENTIFIER    NULL,
    CONSTRAINT FK_ram_node FOREIGN KEY (node_id) REFERENCES dbo.nodes(id)
);
GO

CREATE TABLE dbo.thermal (
    row_id              INT IDENTITY(1,1)   PRIMARY KEY,
    cpu_temp            FLOAT               NOT NULL,
    system_temp         FLOAT               NOT NULL,
    user_id             UNIQUEIDENTIFIER    NULL,
    node_id             UNIQUEIDENTIFIER    NULL,
    CONSTRAINT FK_thermal_node FOREIGN KEY (node_id) REFERENCES dbo.nodes(id)
);
GO


-- =====================================================
-- BLOCK 3: HELPER FUNCTIONS (non-schema-bound)
-- For backend and application use only.
-- These CANNOT be called inside fn_rls_telemetry
-- because they are not schema-bound.
-- =====================================================

-- Returns the current session user's ID
CREATE FUNCTION dbo.fn_user_id()
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
    RETURN CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER);
END;
GO

-- Returns 1 if the current session user has the admin role
-- Use in application/backend code only — NOT inside RLS
CREATE FUNCTION dbo.fn_is_admin()
RETURNS BIT
AS
BEGIN
    DECLARE @result BIT = 0;
    IF EXISTS (
        SELECT 1 FROM dbo.users
        WHERE id   = CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER)
          AND role = 'admin'
    )
        SET @result = 1;
    RETURN @result;
END;
GO


-- =====================================================
-- BLOCK 4: RLS PREDICATE FUNCTION (schema-bound)
--
-- Classification-aware Row-Level Security predicate.
-- A telemetry row is visible to the session user ONLY
-- when BOTH of the following conditions are true:
--
--   CONDITION 1 — Ownership or admin:
--     The row's user_id matches the session user
--     OR the session user has the 'admin' role
--
--   CONDITION 2 — Clearance hierarchy:
--     SECRET      -> can see SECRET, CUI, UNCLASSIFIED nodes
--     CUI         -> can see CUI and UNCLASSIFIED nodes only
--     UNCLASSIFIED -> can see UNCLASSIFIED nodes only
--
-- This prevents low-clearance users from accessing
-- telemetry rows tied to higher-classification nodes.
-- Fixes SC.L2-3.13.8 data leakage vulnerability.
--
-- SCHEMABINDING rules:
--   All referenced objects must be schema-qualified.
--   fn_is_admin() is NOT schema-bound so it cannot
--   be called here — admin check is inlined instead.
-- =====================================================
CREATE FUNCTION dbo.fn_rls_telemetry(@user_id UNIQUEIDENTIFIER, @node_id UNIQUEIDENTIFIER)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS result
    FROM dbo.users u
    JOIN dbo.nodes n ON n.id = @node_id
    WHERE
        -- CONDITION 1: row owner or admin
        (
            @user_id = CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER)
            OR
            (
                u.id   = CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER)
                AND u.role = 'admin'
            )
        )
        AND
        -- CONDITION 2: clearance level check is always against the session user
        u.id = CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER)
        AND
        (
            -- SECRET users can see all classification levels
            u.clearance_level = 'SECRET'
            OR
            -- CUI users can see CUI and UNCLASSIFIED
            (u.clearance_level = 'CUI'          AND n.classification IN ('CUI','UNCLASSIFIED'))
            OR
            -- UNCLASSIFIED users can only see UNCLASSIFIED
            (u.clearance_level = 'UNCLASSIFIED' AND n.classification = 'UNCLASSIFIED')
        )
);
GO


-- =====================================================
-- BLOCK 5: RLS SECURITY POLICIES
-- Applies fn_rls_telemetry to all four telemetry tables.
-- Predicate takes two columns: (user_id, node_id).
-- Both columns exist on every telemetry table.
-- Must come after fn_rls_telemetry is created.
-- =====================================================
CREATE SECURITY POLICY cpu_policy
    ADD FILTER PREDICATE dbo.fn_rls_telemetry(user_id, node_id) ON dbo.cpu
    WITH (STATE = ON);
GO

CREATE SECURITY POLICY disk_policy
    ADD FILTER PREDICATE dbo.fn_rls_telemetry(user_id, node_id) ON dbo.disk
    WITH (STATE = ON);
GO

CREATE SECURITY POLICY ram_policy
    ADD FILTER PREDICATE dbo.fn_rls_telemetry(user_id, node_id) ON dbo.ram
    WITH (STATE = ON);
GO

CREATE SECURITY POLICY thermal_policy
    ADD FILTER PREDICATE dbo.fn_rls_telemetry(user_id, node_id) ON dbo.thermal
    WITH (STATE = ON);
GO


-- =====================================================
-- BLOCK 6: COMPLIANCE TABLES
-- All reference dbo.users via FK so users must exist.
-- Order: audit_log -> mfa_config -> sessions -> password_reset
-- =====================================================

-- Audit log — append-only, tamper-proof (AU.L2-3.3.1)
-- Captures: user identity, timestamp, action, result
CREATE TABLE dbo.audit_log (
    log_id              UNIQUEIDENTIFIER    PRIMARY KEY DEFAULT NEWID(),
    user_id             UNIQUEIDENTIFIER    NOT NULL,
    action_type         NVARCHAR(100)       NOT NULL
                                            CONSTRAINT CK_audit_action
                                            CHECK (action_type IN (
                                                'LOGIN',            -- successful full auth
                                                'LOGIN_FAILED',     -- wrong password
                                                'MFA_FAILED',       -- password ok, MFA failed
                                                'LOCKED',           -- account locked out
                                                'LOGOUT',           -- user-initiated signout
                                                'PWD_RESET',        -- password was reset
                                                'SESSION_EXPIRE',   -- session TTL exceeded
                                                'QUERY',            -- data access event
                                                'EXPORT',           -- data exported
                                                'CONFIG_CHANGE',    -- settings modified
                                                'ACCESS_DENIED'     -- RLS or permission block
                                            )),
    target_resource     NVARCHAR(255)       NULL,   -- e.g. 'dbo.cpu', 'dashboard/node-overview'
    ip_address          NVARCHAR(45)        NULL,   -- supports IPv4 and IPv6
    session_id          NVARCHAR(255)       NULL,
    result              NVARCHAR(20)        NOT NULL
                                            CONSTRAINT CK_audit_result
                                            CHECK (result IN ('SUCCESS','DENIED','FAILED')),
    logged_at           DATETIME2           NOT NULL DEFAULT SYSUTCDATETIME(),
    detail              NVARCHAR(MAX)       NULL    -- JSON blob for extra context
);
GO

-- MFA config — one record per user per method (IA.L2-3.5.3)
CREATE TABLE dbo.mfa_config (
    mfa_id          UNIQUEIDENTIFIER    PRIMARY KEY DEFAULT NEWID(),
    user_id         UNIQUEIDENTIFIER    NOT NULL
                                        CONSTRAINT FK_mfa_user
                                        REFERENCES dbo.users(id),
    mfa_type        NVARCHAR(20)        NOT NULL
                                        CONSTRAINT CK_mfa_type
                                        CHECK (mfa_type IN ('totp','hardware_key','sms')),
    secret_hash     NVARCHAR(255)       NOT NULL,   -- TOTP secret hashed at rest
    is_active       BIT                 NOT NULL DEFAULT 1,
    created_at      DATETIME2           NOT NULL DEFAULT SYSUTCDATETIME(),
    last_used_at    DATETIME2           NULL
);
GO

-- Sessions — Zero Trust short-lived tracked sessions
-- Every login creates a session, every action validates it
CREATE TABLE dbo.sessions (
    session_id          UNIQUEIDENTIFIER    PRIMARY KEY DEFAULT NEWID(),
    user_id             UNIQUEIDENTIFIER    NOT NULL
                                            CONSTRAINT FK_session_user
                                            REFERENCES dbo.users(id),
    session_token_hash  NVARCHAR(255)       NOT NULL,   -- hash of bearer token, never plaintext
    ip_address          NVARCHAR(45)        NULL,
    user_agent          NVARCHAR(500)       NULL,
    created_at          DATETIME2           NOT NULL DEFAULT SYSUTCDATETIME(),
    expires_at          DATETIME2           NOT NULL,   -- backend enforces short TTL
    revoked             BIT                 NOT NULL DEFAULT 0,
    revoked_at          DATETIME2           NULL,
    revoked_reason      NVARCHAR(100)       NULL
                                            CONSTRAINT CK_session_revoke_reason
                                            CHECK (revoked_reason IN (
                                                'LOGOUT','TIMEOUT','ADMIN_REVOKE',NULL
                                            ))
);
GO

-- Password reset — hashed token, short-lived window (IA.L2-3.5.3)
CREATE TABLE dbo.password_reset (
    reset_id        UNIQUEIDENTIFIER    PRIMARY KEY DEFAULT NEWID(),
    user_id         UNIQUEIDENTIFIER    NOT NULL
                                        CONSTRAINT FK_reset_user
                                        REFERENCES dbo.users(id),
    token_hash      NVARCHAR(255)       NOT NULL,   -- reset token hashed, never plaintext
    requested_at    DATETIME2           NOT NULL DEFAULT SYSUTCDATETIME(),
    expires_at      DATETIME2           NOT NULL,   -- backend enforces short window (15 min)
    used            BIT                 NOT NULL DEFAULT 0,
    used_at         DATETIME2           NULL,
    ip_address      NVARCHAR(45)        NULL
);
GO


-- =====================================================
-- BLOCK 7: PERMISSIONS & DENY
-- Must come after all tables and roles exist.
-- Principle of least privilege throughout (AC.L2-3.1.6)
-- =====================================================

-- -----------------------------------------------
-- app_user permissions
-- Backend service account — limited to what it needs
-- -----------------------------------------------

-- Users table: never directly accessible by app_user
-- Backend uses stored procedures for auth only
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.users           TO app_user;
GO

-- Telemetry: read and insert only (RLS enforces row filtering)
GRANT SELECT, INSERT ON dbo.cpu                             TO app_user;
GRANT SELECT, INSERT ON dbo.disk                            TO app_user;
GRANT SELECT, INSERT ON dbo.ram                             TO app_user;
GRANT SELECT, INSERT ON dbo.thermal                         TO app_user;
GO

-- Nodes: read only — app cannot create or modify nodes
GRANT SELECT             ON dbo.nodes                       TO app_user;
DENY  INSERT, UPDATE, DELETE ON dbo.nodes                   TO app_user;
GO

-- Sessions: create and revoke — never hard delete
GRANT SELECT, INSERT, UPDATE ON dbo.sessions                TO app_user;
DENY  DELETE                 ON dbo.sessions                TO app_user;
GO

-- MFA: read and update last_used_at only
-- Enrollment is admin-only
GRANT SELECT, UPDATE         ON dbo.mfa_config              TO app_user;
DENY  INSERT, DELETE         ON dbo.mfa_config              TO app_user;
GO

-- Password reset: create tokens and mark them used
GRANT SELECT, INSERT, UPDATE ON dbo.password_reset          TO app_user;
DENY  DELETE                 ON dbo.password_reset          TO app_user;
GO

-- Audit log: insert only — app writes events, never reads or modifies
GRANT INSERT                 ON dbo.audit_log               TO app_user;
DENY  SELECT, UPDATE, DELETE ON dbo.audit_log               TO app_user;
GO

-- -----------------------------------------------
-- auditor_user permissions
-- Read-only access to audit and session data only
-- Cannot see telemetry, users, or nodes
-- -----------------------------------------------
GRANT SELECT ON dbo.audit_log                               TO auditor_user;
GRANT SELECT ON dbo.sessions                                TO auditor_user;
GRANT SELECT ON dbo.mfa_config                              TO auditor_user;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.cpu             TO auditor_user;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.disk            TO auditor_user;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.ram             TO auditor_user;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.thermal         TO auditor_user;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.nodes           TO auditor_user;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.users           TO auditor_user;
GO

-- -----------------------------------------------
-- admin_user permissions
-- Full schema control with one critical exception:
-- Audit log is append-only even for admins
-- -----------------------------------------------
GRANT CONTROL ON SCHEMA::dbo                                TO admin_user;
GO

-- Audit log tamper protection — no one can modify or delete (AU.L2-3.3.1)
DENY  UPDATE, DELETE ON dbo.audit_log                       TO admin_user;
GO

-- Admin manages MFA enrollment and revocation
GRANT INSERT, DELETE ON dbo.mfa_config                      TO admin_user;
GO


-- =====================================================
-- BLOCK 8: INDEXES
-- Must come after all tables exist.
-- Ordered by query pattern priority.
-- =====================================================

-- Telemetry: composite user + node (most common filter pattern)
CREATE INDEX idx_cpu_user_node      ON dbo.cpu              (user_id, node_id);
CREATE INDEX idx_disk_user_node     ON dbo.disk             (user_id, node_id);
CREATE INDEX idx_ram_user_node      ON dbo.ram              (user_id, node_id);
CREATE INDEX idx_thermal_user_node  ON dbo.thermal          (user_id, node_id);

-- Telemetry: node-only (dashboard/overview queries)
CREATE INDEX idx_cpu_node           ON dbo.cpu              (node_id);
CREATE INDEX idx_disk_node          ON dbo.disk             (node_id);
CREATE INDEX idx_ram_node           ON dbo.ram              (node_id);
CREATE INDEX idx_thermal_node       ON dbo.thermal          (node_id);

-- Users: account lockout queries (IA.L2-3.5.3)
CREATE INDEX idx_users_locked       ON dbo.users            (account_locked, failed_login_count);

-- Users: auth provider lookups (IA.L2-3.5.1)
CREATE INDEX idx_users_provider     ON dbo.users            (auth_provider, auth_provider_id);

-- Audit log: user activity timeline (AU.L2-3.3.1)
CREATE INDEX idx_audit_user_time    ON dbo.audit_log        (user_id, logged_at);

-- Audit log: action type queries (AU.L2-3.3.1)
CREATE INDEX idx_audit_action_time  ON dbo.audit_log        (action_type, logged_at);

-- Audit log: result filtering (AU.L2-3.3.1)
CREATE INDEX idx_audit_result       ON dbo.audit_log        (result, logged_at);

-- Sessions: active session lookup by user
CREATE INDEX idx_sessions_user      ON dbo.sessions         (user_id, expires_at);

-- Sessions: token validation (most frequent session query)
CREATE INDEX idx_sessions_token     ON dbo.sessions         (session_token_hash);

-- Sessions: active/expired sweep queries
CREATE INDEX idx_sessions_active    ON dbo.sessions         (revoked, expires_at);

-- MFA: active method lookup per user
CREATE INDEX idx_mfa_user           ON dbo.mfa_config       (user_id, is_active);

-- Password reset: expiry check per user
CREATE INDEX idx_reset_user         ON dbo.password_reset   (user_id, expires_at);

-- Password reset: token validation
CREATE INDEX idx_reset_token        ON dbo.password_reset   (token_hash);
GO
