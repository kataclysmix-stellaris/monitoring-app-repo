-- =====================================================
-- COMPLETE DATABASE SCHEMA — PostgreSQL
-- Military Telemetry Monitoring System (School Project)
-- CMMC L1-L3 / Zero Trust Compliant
--
-- NOTE: In a real deployment this system would use
-- LDAP/SAML via Active Directory (Option B).
-- For demonstration purposes this implementation uses
-- local password auth (Option A) with full CMMC L3
-- compliant controls: Argon2id hashing, MFA enforcement,
-- session tracking, account lockout, and audit logging.
--
-- RUN ON A FRESH EMPTY DATABASE ONLY.
-- Requires PostgreSQL 14+ (for gen_random_uuid and
-- current_setting with missing_ok parameter).
--
-- RUN ORDER:
--   BLOCK 1  — Extensions
--   BLOCK 2  — Roles
--   BLOCK 3  — Core Tables
--   BLOCK 4  — Helper Functions
--   BLOCK 5  — RLS Policies
--   BLOCK 6  — Compliance Tables
--   BLOCK 7  — Permissions & REVOKE
--   BLOCK 8  — Indexes
-- =====================================================


-- =====================================================
-- BLOCK 1: EXTENSIONS
-- gen_random_uuid() requires pgcrypto or pg_crypto.
-- In Postgres 13+ it is built into core but enabling
-- pgcrypto here ensures compatibility across versions.
-- =====================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- =====================================================
-- BLOCK 2: ROLES
-- Postgres has no DENY — least privilege is enforced
-- by granting only what each role needs and revoking
-- the public default grants explicitly.
-- =====================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'admin_user') THEN
        CREATE ROLE admin_user;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_user') THEN
        CREATE ROLE app_user;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'auditor_user') THEN
        CREATE ROLE auditor_user;
    END IF;
END
$$;


-- =====================================================
-- BLOCK 3: CORE TABLES
-- Order: users -> nodes -> telemetry tables
-- users and nodes have no foreign keys so they go first
-- Telemetry tables all reference nodes(id)
--
-- Key type changes from SQL Server:
--   UNIQUEIDENTIFIER -> UUID
--   NEWID()          -> gen_random_uuid()
--   NVARCHAR(n)      -> VARCHAR(n)
--   BIT              -> BOOLEAN
--   DATETIME2        -> TIMESTAMPTZ
--   IDENTITY(1,1)    -> GENERATED ALWAYS AS IDENTITY
-- =====================================================

CREATE TABLE public.users (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    email                   VARCHAR(255)    NOT NULL UNIQUE,
    full_name               VARCHAR(255),

    -- Role & clearance (AC.L2-3.1.2)
    role                    VARCHAR(20)     NOT NULL DEFAULT 'readonly'
                                            CHECK (role IN ('admin','analyst','operator','auditor','readonly')),
    clearance_level         VARCHAR(20)     NOT NULL DEFAULT 'UNCLASSIFIED'
                                            CHECK (clearance_level IN ('UNCLASSIFIED','CUI','SECRET')),

    -- Identity & auth provider (IA.L2-3.5.1)
    email_verified          BOOLEAN         NOT NULL DEFAULT FALSE,
    auth_provider           VARCHAR(50)     NOT NULL DEFAULT 'local'
                                            CHECK (auth_provider IN ('local','ldap','saml','entra')),
    auth_provider_id        VARCHAR(255),

    -- Password auth — hashed by backend, never plaintext (IA.L2-3.5.2)
    password_hash           VARCHAR(255),
    password_salt           VARCHAR(100),
    password_algorithm      VARCHAR(20)     NOT NULL DEFAULT 'argon2id'
                                            CHECK (password_algorithm IN ('argon2id','bcrypt')),
    password_changed_at     TIMESTAMPTZ,
    password_expires_at     TIMESTAMPTZ,
    must_change_password    BOOLEAN         NOT NULL DEFAULT FALSE,

    -- Account state & lockout (IA.L2-3.5.3)
    mfa_enforced            BOOLEAN         NOT NULL DEFAULT TRUE,
    last_login              TIMESTAMPTZ,
    account_locked          BOOLEAN         NOT NULL DEFAULT FALSE,
    failed_login_count      INT             NOT NULL DEFAULT 0
);

CREATE TABLE public.nodes (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Classification used by RLS to enforce data isolation (SC.L2-3.13.8)
    classification      VARCHAR(20)     NOT NULL DEFAULT 'UNCLASSIFIED'
                                        CHECK (classification IN ('UNCLASSIFIED','CUI','SECRET')),
    organization_id     UUID
);

CREATE TABLE public.cpu (
    row_id              INT             GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cpu_percent         FLOAT           NOT NULL,
    cpu_core_per        JSONB           NOT NULL DEFAULT '[]',
    cpu_frequency       JSONB           NOT NULL,
    user_id             UUID,
    node_id             UUID,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_cpu_node FOREIGN KEY (node_id) REFERENCES public.nodes(id)
) PARTITION BY RANGE (recorded_at);

CREATE TABLE public.disk (
    row_id              INT             GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    disk_used           FLOAT           NOT NULL,
    disk_total          FLOAT           NOT NULL,
    disk_percent        INT             NOT NULL,
    read_bytes          FLOAT           NOT NULL,
    write_bytes         FLOAT           NOT NULL,
    user_id             UUID,
    node_id             UUID,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_disk_node FOREIGN KEY (node_id) REFERENCES public.nodes(id)
) PARTITION BY RANGE (recorded_at);

CREATE TABLE public.ram (
    row_id              INT             GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ram_used            FLOAT           NOT NULL,
    ram_total           FLOAT           NOT NULL,
    ram_per             FLOAT         NOT NULL,
    swap_per            FLOAT,
    user_id             UUID,
    node_id             UUID,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_ram_node FOREIGN KEY (node_id) REFERENCES public.nodes(id)
) PARTITION BY RANGE (recorded_at);

CREATE TABLE public.thermal (
    row_id              INT             GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cpu_temp            FLOAT           NOT NULL,
    system_temp         FLOAT           NOT NULL,
    user_id             UUID,
    node_id             UUID,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_thermal_node FOREIGN KEY (node_id) REFERENCES public.nodes(id)
) PARTITION BY RANGE (recorded_at);

CREATE TABLE public.vms (
    row_id          INT             GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    node_id         UUID            NOT NULL REFERENCES public.nodes(id),
    user_id         UUID,           
    recorded_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    vm_id           VARCHAR(255)    NOT NULL,  
    vm_name         VARCHAR(255)    NOT NULL,
    vm_type            VARCHAR(50)     NOT NULL DEFAULT 'vm' CHECK (vm_type IN ('vm','container','wsl')),
    status          VARCHAR(50)     NOT NULL CHECK (status IN ('Running','Stopped','Paused','Unknown')),
    cpu_percent     FLOAT           NOT NULL DEFAULT 0,
    ram_used_gb     FLOAT           NOT NULL DEFAULT 0,
    ram_demand_gb   FLOAT           NOT NULL DEFAULT 0,
    uptime          VARCHAR(100),   
    creation_time   TIMESTAMPTZ
    );
    


CREATE OR REPLACE FUNCTION public.fn_user_id()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT current_setting('app.user_id', true)::UUID;
$$;

-- Returns TRUE if the current session user is an admin
-- Use in application/backend code only — NOT inside RLS policies
CREATE OR REPLACE FUNCTION public.fn_is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_result BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id   = current_setting('app.user_id', true)::UUID
          AND role = 'admin'
    ) INTO v_result;
    RETURN v_result;
END;
$$;



-- Enable RLS on all four telemetry tables
ALTER TABLE public.cpu     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disk    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ram     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.thermal ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vms     ENABLE ROW LEVEL SECURITY;

-- Force RLS even for table owners (critical for security)
ALTER TABLE public.cpu     FORCE ROW LEVEL SECURITY;
ALTER TABLE public.disk    FORCE ROW LEVEL SECURITY;
ALTER TABLE public.ram     FORCE ROW LEVEL SECURITY;
ALTER TABLE public.thermal FORCE ROW LEVEL SECURITY;
ALTER TABLE public.vms     FORCE ROW LEVEL SECURITY;

-- -----------------------------------------------
-- RLS policy helper: clearance check function
-- Returns TRUE if the session user's clearance
-- meets or exceeds the given node's classification.
-- Used inside every telemetry policy USING clause.
-- -----------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_clearance_check(p_node_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_clearance     VARCHAR(20);
    v_classification VARCHAR(20);
BEGIN
    -- Get session user clearance
    SELECT clearance_level INTO v_clearance
    FROM public.users
    WHERE id = current_setting('app.user_id', true)::UUID;

    -- Get node classification
    SELECT classification INTO v_classification
    FROM public.nodes
    WHERE id = p_node_id;

    -- If node not found, deny access
    IF v_classification IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Clearance hierarchy check
    RETURN (
        v_clearance = 'SECRET'
        OR (v_clearance = 'CUI'          AND v_classification IN ('CUI','UNCLASSIFIED'))
        OR (v_clearance = 'UNCLASSIFIED' AND v_classification = 'UNCLASSIFIED')
    );
END;
$$;

-- CPU policy
-- CONDITION 1: row belongs to session user OR user is admin
-- CONDITION 2: user clearance meets node classification
CREATE POLICY cpu_rls_policy ON public.cpu
    AS PERMISSIVE
    FOR ALL
    USING (
        (
            user_id = current_setting('app.user_id', true)::UUID
            OR public.fn_is_admin()
        )
        AND public.fn_clearance_check(node_id)
    )
    WITH CHECK (
        (
            user_id = current_setting('app.user_id', true)::UUID
            OR public.fn_is_admin()
        )
        AND public.fn_clearance_check(node_id)
    );

-- Disk policy
CREATE POLICY disk_rls_policy ON public.disk
    AS PERMISSIVE
    FOR ALL
    USING (
        (
            user_id = current_setting('app.user_id', true)::UUID
            OR public.fn_is_admin()
        )
        AND public.fn_clearance_check(node_id)
    )
    WITH CHECK (
        (
            user_id = current_setting('app.user_id', true)::UUID
            OR public.fn_is_admin()
        )
        AND public.fn_clearance_check(node_id)
    );

-- RAM policy
CREATE POLICY ram_rls_policy ON public.ram
    AS PERMISSIVE
    FOR ALL
    USING (
        (
            user_id = current_setting('app.user_id', true)::UUID
            OR public.fn_is_admin()
        )
        AND public.fn_clearance_check(node_id)
    )
    WITH CHECK (
        (
            user_id = current_setting('app.user_id', true)::UUID
            OR public.fn_is_admin()
        )
        AND public.fn_clearance_check(node_id)
    );

-- Thermal policy
CREATE POLICY thermal_rls_policy ON public.thermal
    AS PERMISSIVE
    FOR ALL
    USING (
        (
            user_id = current_setting('app.user_id', true)::UUID
            OR public.fn_is_admin()
        )
        AND public.fn_clearance_check(node_id)
    )
    WITH CHECK (
        (
            user_id = current_setting('app.user_id', true)::UUID
            OR public.fn_is_admin()
        )
        AND public.fn_clearance_check(node_id)
    );

-- Virtual Machine policy
CREATE POLICY vm_rls_policy ON public.vms
    AS PERMISSIVE
    FOR ALL
    USING (
        (
            user_id = current_setting('app.user_id', true)::UUID
            OR public.fn_is_admin()
        )
        AND public.fn_clearance_check(node_id)
    )
    WITH CHECK (
        (
            user_id = current_setting('app.user_id', true)::UUID
            OR public.fn_is_admin()
        )
        AND public.fn_clearance_check(node_id)
    );



-- =====================================================
-- BLOCK 6: COMPLIANCE TABLES
-- All reference public.users via FK so users must exist.
-- Order: audit_log -> mfa_config -> sessions -> password_reset
-- =====================================================

-- Audit log — append-only, tamper-proof (AU.L2-3.3.1)
-- Captures: user identity, timestamp, action, result
CREATE TABLE public.audit_log (
    log_id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL,
    action_type         VARCHAR(100)    NOT NULL
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
    target_resource     VARCHAR(255),   -- e.g. 'public.cpu', 'dashboard/node-overview'
    ip_address          VARCHAR(45),    -- supports IPv4 and IPv6
    session_id          VARCHAR(255),
    result              VARCHAR(20)     NOT NULL
                                        CHECK (result IN ('SUCCESS','DENIED','FAILED')),
    logged_at           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    detail              TEXT            -- JSON string for extra context
);

-- MFA config — one record per user per method (IA.L2-3.5.3)
CREATE TABLE public.mfa_config (
    mfa_id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL
                                    REFERENCES public.users(id),
    mfa_type        VARCHAR(20)     NOT NULL
                                    CHECK (mfa_type IN ('totp','hardware_key','sms')),
    secret_hash     VARCHAR(255)    NOT NULL,   -- TOTP secret hashed at rest
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    last_used_at    TIMESTAMPTZ
);

-- Sessions — Zero Trust short-lived tracked sessions
-- Every login creates a session, every action validates it
CREATE TABLE public.sessions (
    session_id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL
                                        REFERENCES public.users(id),
    session_token_hash  VARCHAR(255)    NOT NULL,   -- hash of bearer token, never plaintext
    ip_address          VARCHAR(45),
    user_agent          VARCHAR(500),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ     NOT NULL,   -- backend enforces short TTL
    revoked             BOOLEAN         NOT NULL DEFAULT FALSE,
    revoked_at          TIMESTAMPTZ,
    revoked_reason      VARCHAR(100)
                                        CHECK (revoked_reason IN (
                                            'LOGOUT','TIMEOUT','ADMIN_REVOKE'
                                        ))
);

-- Password reset — hashed token, short-lived window (IA.L2-3.5.3)
CREATE TABLE public.password_reset (
    reset_id        UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL
                                    REFERENCES public.users(id),
    token_hash      VARCHAR(255)    NOT NULL,   -- reset token hashed, never plaintext
    requested_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ     NOT NULL,   -- backend enforces short window (15 min)
    used            BOOLEAN         NOT NULL DEFAULT FALSE,
    used_at         TIMESTAMPTZ,
    ip_address      VARCHAR(45)
);


-- =====================================================
-- BLOCK 7: PERMISSIONS & REVOKE
--
-- Key difference from SQL Server:
--   SQL Server uses DENY to block access.
--   PostgreSQL has no DENY — instead you REVOKE
--   the default PUBLIC grants and only GRANT what
--   each role explicitly needs.
--
-- Postgres grants SELECT on all tables to PUBLIC
-- by default — this must be revoked first.
-- =====================================================

-- Revoke all default public access on every table
REVOKE ALL ON public.users          FROM PUBLIC;
REVOKE ALL ON public.nodes          FROM PUBLIC;
REVOKE ALL ON public.cpu            FROM PUBLIC;
REVOKE ALL ON public.disk           FROM PUBLIC;
REVOKE ALL ON public.ram            FROM PUBLIC;
REVOKE ALL ON public.thermal        FROM PUBLIC;
REVOKE ALL ON public.audit_log      FROM PUBLIC;
REVOKE ALL ON public.mfa_config     FROM PUBLIC;
REVOKE ALL ON public.sessions       FROM PUBLIC;
REVOKE ALL ON public.password_reset FROM PUBLIC;
REVOKE ALL ON public.vms            FROM PUBLIC;

-- -----------------------------------------------
-- app_user permissions
-- Backend service account — limited to what it needs
-- -----------------------------------------------

-- Users table: no direct access — backend uses functions
REVOKE ALL ON public.users FROM app_user;

-- Telemetry: read and insert (RLS enforces row filtering)
GRANT SELECT, INSERT ON public.cpu      TO app_user;
GRANT SELECT, INSERT ON public.disk     TO app_user;
GRANT SELECT, INSERT ON public.ram      TO app_user;
GRANT SELECT, INSERT ON public.thermal  TO app_user;
GRANT SELECT, INSERT ON public.vms      TO app_user;

-- Nodes: read only
GRANT SELECT ON public.nodes TO app_user;

-- Sessions: create and revoke — never delete
GRANT SELECT, INSERT, UPDATE ON public.sessions TO app_user;

-- MFA: read and update last_used_at only
GRANT SELECT, UPDATE ON public.mfa_config TO app_user;

-- Password reset: create tokens and mark used
GRANT SELECT, INSERT, UPDATE ON public.password_reset TO app_user;

-- Audit log: insert only — app writes events, never reads or modifies
GRANT INSERT ON public.audit_log TO app_user;

-- Sequence access for IDENTITY columns
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- -----------------------------------------------
-- auditor_user permissions
-- Read-only access to audit and session data only
-- -----------------------------------------------
GRANT SELECT ON public.audit_log    TO auditor_user;
GRANT SELECT ON public.sessions     TO auditor_user;
GRANT SELECT ON public.mfa_config   TO auditor_user;
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.vms TO auditor_user;
-- No access to telemetry, users, or nodes

-- -----------------------------------------------
-- admin_user permissions
-- Full schema access with audit log write-protection
-- -----------------------------------------------
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public        TO admin_user;

-- Revoke UPDATE and DELETE on audit_log even for admin
-- Audit log is append-only — tamper-proof (AU.L2-3.3.1)
REVOKE UPDATE, DELETE ON public.audit_log FROM admin_user;

-- Admin manages MFA enrollment and revocation
-- (already covered by ALL PRIVILEGES above)


-- =====================================================
-- BLOCK 8: INDEXES
-- Must come after all tables exist.
-- Postgres uses same CREATE INDEX syntax as SQL Server
-- with minor differences (no included columns needed here).
-- =====================================================

-- Telemetry: composite user + node (most common filter pattern)
CREATE INDEX idx_cpu_user_node      ON public.cpu              (user_id, node_id);
CREATE INDEX idx_disk_user_node     ON public.disk             (user_id, node_id);
CREATE INDEX idx_ram_user_node      ON public.ram              (user_id, node_id);
CREATE INDEX idx_thermal_user_node  ON public.thermal          (user_id, node_id);

-- Telemetry: node-only (dashboard/overview queries)
CREATE INDEX idx_cpu_node           ON public.cpu              (node_id);
CREATE INDEX idx_disk_node          ON public.disk             (node_id);
CREATE INDEX idx_ram_node           ON public.ram              (node_id);
CREATE INDEX idx_thermal_node       ON public.thermal          (node_id);

-- Timestamp: node + timestamptz
CREATE INDEX idx_cpu_recorded_at     ON public.cpu     (node_id, recorded_at DESC);
CREATE INDEX idx_disk_recorded_at    ON public.disk    (node_id, recorded_at DESC);
CREATE INDEX idx_ram_recorded_at     ON public.ram     (node_id, recorded_at DESC);
CREATE INDEX idx_thermal_recorded_at ON public.thermal (node_id, recorded_at DESC);

-- Users: account lockout queries (IA.L2-3.5.3)
CREATE INDEX idx_users_locked       ON public.users            (account_locked, failed_login_count);

-- Users: auth provider lookups (IA.L2-3.5.1)
CREATE INDEX idx_users_provider     ON public.users            (auth_provider, auth_provider_id);

-- Audit log: user activity timeline (AU.L2-3.3.1)
CREATE INDEX idx_audit_user_time    ON public.audit_log        (user_id, logged_at);

-- Audit log: action type queries (AU.L2-3.3.1)
CREATE INDEX idx_audit_action_time  ON public.audit_log        (action_type, logged_at);

-- Audit log: result filtering (AU.L2-3.3.1)
CREATE INDEX idx_audit_result       ON public.audit_log        (result, logged_at);

-- Sessions: active session lookup by user
CREATE INDEX idx_sessions_user      ON public.sessions         (user_id, expires_at);

-- Sessions: token validation (most frequent session query)
CREATE INDEX idx_sessions_token     ON public.sessions         (session_token_hash);

-- Sessions: active/expired sweep queries
CREATE INDEX idx_sessions_active    ON public.sessions         (revoked, expires_at);

-- MFA: active method lookup per user
CREATE INDEX idx_mfa_user           ON public.mfa_config       (user_id, is_active);

-- Password reset: expiry check per user
CREATE INDEX idx_reset_user         ON public.password_reset   (user_id, expires_at);

-- Password reset: token validation
CREATE INDEX idx_reset_token        ON public.password_reset   (token_hash);

-- VMs: node + time (dashboard overview)
CREATE INDEX idx_vms_node_time       ON public.vms     (node_id, recorded_at DESC);

-- VMs: status filter (find all running VMs quickly)
CREATE INDEX idx_vms_status          ON public.vms     (status, recorded_at DESC);

-- VMs: user + node (RLS filter pattern)
CREATE INDEX idx_vms_user_node       ON public.vms     (user_id, node_id);
