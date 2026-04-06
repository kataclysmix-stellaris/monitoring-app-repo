-- =====================================================
-- ROLES
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
--  TABLES
 
CREATE TABLE dbo.users (
    id                      UNIQUEIDENTIFIER    PRIMARY KEY DEFAULT NEWID(),
    email                   NVARCHAR(255)       NOT NULL UNIQUE,
    full_name               NVARCHAR(255)       NULL,
 
    -- Role & clearance
    role                    NVARCHAR(20)        NOT NULL DEFAULT 'readonly'
                                                CONSTRAINT CK_users_role
                                                CHECK (role IN ('admin','analyst','operator','auditor','readonly')),
    clearance_level         NVARCHAR(20)        NOT NULL DEFAULT 'UNCLASSIFIED'
                                                CONSTRAINT CK_users_clearance
                                                CHECK (clearance_level IN ('UNCLASSIFIED','CUI','SECRET')),
 
    -- Identity & auth provider
    email_verified          BIT                 NOT NULL DEFAULT 0,
    auth_provider           NVARCHAR(50)        NOT NULL DEFAULT 'local'
                                                CONSTRAINT CK_users_auth_provider
                                                CHECK (auth_provider IN ('local','ldap','saml','entra')),
    auth_provider_id        NVARCHAR(255)       NULL,
 
    -- Password auth
    password_hash           NVARCHAR(255)       NULL,
    password_salt           NVARCHAR(100)       NULL,
    password_algorithm      NVARCHAR(20)        NOT NULL DEFAULT 'argon2id'
                                                CONSTRAINT CK_users_pwd_algo
                                                CHECK (password_algorithm IN ('argon2id','bcrypt')),
    password_changed_at     DATETIME2           NULL,
    password_expires_at     DATETIME2           NULL,
    must_change_password    BIT                 NOT NULL DEFAULT 0,
 
    -- Account state (IA.L2-3.5.3)
    mfa_enforced            BIT                 NOT NULL DEFAULT 1,
    last_login              DATETIME2           NULL,
    account_locked          BIT                 NOT NULL DEFAULT 0,
    failed_login_count      INT                 NOT NULL DEFAULT 0
);
GO
 
CREATE TABLE dbo.nodes (
    id                  UNIQUEIDENTIFIER    PRIMARY KEY DEFAULT NEWID(),
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
 
 
-- HELPER FUNCTIONS
 
-- Returns current session user ID
CREATE FUNCTION dbo.fn_user_id()
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
    RETURN CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER);
END;
GO
 
-- Returns 1 if current session user is admin
-- Use in application code only — not inside RLS
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
-- RLS PREDICATE FUNCTION
CREATE FUNCTION dbo.fn_rls_telemetry(@user_id UNIQUEIDENTIFIER)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS result
    FROM dbo.users u
    WHERE
        -- Row belongs to current session user
        @user_id = CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER)
        OR
        -- Current session user is an admin (inlined — cannot call fn_is_admin here)
        (
            u.id   = CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER)
            AND u.role = 'admin'
        )
);
GO
 
 
-- ROW LEVEL SECURITY
CREATE SECURITY POLICY cpu_policy
    ADD FILTER PREDICATE dbo.fn_rls_telemetry(user_id) ON dbo.cpu
    WITH (STATE = ON);
GO
 
CREATE SECURITY POLICY disk_policy
    ADD FILTER PREDICATE dbo.fn_rls_telemetry(user_id) ON dbo.disk
    WITH (STATE = ON);
GO
 
CREATE SECURITY POLICY ram_policy
    ADD FILTER PREDICATE dbo.fn_rls_telemetry(user_id) ON dbo.ram
    WITH (STATE = ON);
GO
 
CREATE SECURITY POLICY thermal_policy
    ADD FILTER PREDICATE dbo.fn_rls_telemetry(user_id) ON dbo.thermal
    WITH (STATE = ON);
GO
 
 

CREATE TABLE dbo.audit_log (
    log_id              UNIQUEIDENTIFIER    PRIMARY KEY DEFAULT NEWID(),
    user_id             UNIQUEIDENTIFIER    NOT NULL,
    action_type         NVARCHAR(100)       NOT NULL
                                            CONSTRAINT CK_audit_action
                                            CHECK (action_type IN (
                                                'LOGIN',
                                                'LOGIN_FAILED',
                                                'MFA_FAILED',
                                                'LOCKED',
                                                'LOGOUT',
                                                'PWD_RESET',
                                                'SESSION_EXPIRE',
                                                'QUERY',
                                                'EXPORT',
                                                'CONFIG_CHANGE',
                                                'ACCESS_DENIED'
                                            )),
    target_resource     NVARCHAR(255)       NULL,
    ip_address          NVARCHAR(45)        NULL,
    session_id          NVARCHAR(255)       NULL,
    result              NVARCHAR(20)        NOT NULL
                                            CONSTRAINT CK_audit_result
                                            CHECK (result IN ('SUCCESS','DENIED','FAILED')),
    logged_at           DATETIME2           NOT NULL DEFAULT SYSUTCDATETIME(),
    detail              NVARCHAR(MAX)       NULL
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
    secret_hash     NVARCHAR(255)       NOT NULL,
    is_active       BIT                 NOT NULL DEFAULT 1,
    created_at      DATETIME2           NOT NULL DEFAULT SYSUTCDATETIME(),
    last_used_at    DATETIME2           NULL
);
GO
 
-- Sessions — Zero Trust short-lived tracked sessions
CREATE TABLE dbo.sessions (
    session_id          UNIQUEIDENTIFIER    PRIMARY KEY DEFAULT NEWID(),
    user_id             UNIQUEIDENTIFIER    NOT NULL
                                            CONSTRAINT FK_session_user
                                            REFERENCES dbo.users(id),
    session_token_hash  NVARCHAR(255)       NOT NULL,
    ip_address          NVARCHAR(45)        NULL,
    user_agent          NVARCHAR(500)       NULL,
    created_at          DATETIME2           NOT NULL DEFAULT SYSUTCDATETIME(),
    expires_at          DATETIME2           NOT NULL,
    revoked             BIT                 NOT NULL DEFAULT 0,
    revoked_at          DATETIME2           NULL,
    revoked_reason      NVARCHAR(100)       NULL
                                            CONSTRAINT CK_session_revoke_reason
                                            CHECK (revoked_reason IN (
                                                'LOGOUT','TIMEOUT','ADMIN_REVOKE', NULL
                                            ))
);
GO
 
-- Password reset — hashed token, short-lived (IA.L2-3.5.3)
CREATE TABLE dbo.password_reset (
    reset_id        UNIQUEIDENTIFIER    PRIMARY KEY DEFAULT NEWID(),
    user_id         UNIQUEIDENTIFIER    NOT NULL
                                        CONSTRAINT FK_reset_user
                                        REFERENCES dbo.users(id),
    token_hash      NVARCHAR(255)       NOT NULL,
    requested_at    DATETIME2           NOT NULL DEFAULT SYSUTCDATETIME(),
    expires_at      DATETIME2           NOT NULL,
    used            BIT                 NOT NULL DEFAULT 0,
    used_at         DATETIME2           NULL,
    ip_address      NVARCHAR(45)        NULL
);
GO
 
 
-- =====================================================
-- BLOCK 7: PERMISSIONS & DENY
-- Must come after all tables and roles exist
-- =====================================================
 
-- Block app_user from reading users table directly
-- Backend uses stored procedures for auth only
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.users          TO app_user;
GO
 
-- app_user: telemetry read + insert
GRANT SELECT, INSERT ON dbo.cpu                           TO app_user;
GRANT SELECT, INSERT ON dbo.disk                          TO app_user;
GRANT SELECT, INSERT ON dbo.ram                           TO app_user;
GRANT SELECT, INSERT ON dbo.thermal                       TO app_user;
GRANT SELECT         ON dbo.nodes                         TO app_user;
GO
 
-- app_user: cannot edit or delete nodes
DENY  UPDATE, DELETE ON dbo.nodes                         TO app_user;
GO
 
-- app_user: sessions — create and revoke, never delete
GRANT SELECT, INSERT, UPDATE ON dbo.sessions              TO app_user;
DENY  DELETE                 ON dbo.sessions              TO app_user;
GO
 
-- app_user: MFA — read and update last_used only
GRANT SELECT, UPDATE         ON dbo.mfa_config            TO app_user;
DENY  INSERT, DELETE         ON dbo.mfa_config            TO app_user;
GO
 
-- app_user: password reset — create and mark used
GRANT SELECT, INSERT, UPDATE ON dbo.password_reset        TO app_user;
DENY  DELETE                 ON dbo.password_reset        TO app_user;
GO
 
-- app_user: audit log — insert only, never modify
GRANT INSERT                 ON dbo.audit_log             TO app_user;
DENY  SELECT, UPDATE, DELETE ON dbo.audit_log             TO app_user;
GO
 
-- auditor_user: read only on audit log and sessions
GRANT SELECT ON dbo.audit_log                             TO auditor_user;
GRANT SELECT ON dbo.sessions                              TO auditor_user;
GRANT SELECT ON dbo.mfa_config                            TO auditor_user;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.cpu           TO auditor_user;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.disk          TO auditor_user;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.ram           TO auditor_user;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.thermal       TO auditor_user;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.nodes         TO auditor_user;
DENY  SELECT, INSERT, UPDATE, DELETE ON dbo.users         TO auditor_user;
GO
 
-- admin_user: full schema control
GRANT CONTROL ON SCHEMA::dbo                              TO admin_user;
 
-- Audit log is append-only even for admins — tamper proof
DENY  UPDATE, DELETE ON dbo.audit_log                     TO admin_user;
GO
 
-- admin_user: can enroll and revoke MFA
GRANT INSERT, DELETE ON dbo.mfa_config                    TO admin_user;
GO
 
 
-- =====================================================
-- BLOCK 8: INDEXES
-- Must come after all tables exist
-- =====================================================
 
-- Telemetry: composite user + node (most common filter)
CREATE INDEX idx_cpu_user_node      ON dbo.cpu          (user_id, node_id);
CREATE INDEX idx_disk_user_node     ON dbo.disk         (user_id, node_id);
CREATE INDEX idx_ram_user_node      ON dbo.ram          (user_id, node_id);
CREATE INDEX idx_thermal_user_node  ON dbo.thermal      (user_id, node_id);
 
-- Telemetry: node-only (dashboard queries)
CREATE INDEX idx_cpu_node           ON dbo.cpu          (node_id);
CREATE INDEX idx_disk_node          ON dbo.disk         (node_id);
CREATE INDEX idx_ram_node           ON dbo.ram          (node_id);
CREATE INDEX idx_thermal_node       ON dbo.thermal      (node_id);
 
-- Users: lockout + provider lookups (IA.L2-3.5.3)
CREATE INDEX idx_users_locked       ON dbo.users        (account_locked, failed_login_count);
CREATE INDEX idx_users_provider     ON dbo.users        (auth_provider, auth_provider_id);
 
-- Audit log: user timeline + action queries (AU.L2-3.3.1)
CREATE INDEX idx_audit_user_time    ON dbo.audit_log    (user_id, logged_at);
CREATE INDEX idx_audit_action_time  ON dbo.audit_log    (action_type, logged_at);
CREATE INDEX idx_audit_result       ON dbo.audit_log    (result, logged_at);
 
-- Sessions: token lookup + active session queries
CREATE INDEX idx_sessions_user      ON dbo.sessions     (user_id, expires_at);
CREATE INDEX idx_sessions_token     ON dbo.sessions     (session_token_hash);
CREATE INDEX idx_sessions_active    ON dbo.sessions     (revoked, expires_at);
 
-- MFA: active config per user
CREATE INDEX idx_mfa_user           ON dbo.mfa_config   (user_id, is_active);
 
-- Password reset: token lookup + expiry
CREATE INDEX idx_reset_user         ON dbo.password_reset (user_id, expires_at);
CREATE INDEX idx_reset_token        ON dbo.password_reset (token_hash);
GO
