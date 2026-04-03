-- =====================================================
-- STEP 1: ROLES
-- Must exist before any GRANT/DENY statements
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'admin_user' AND type = 'R')
    CREATE ROLE admin_user;
GO
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'app_user' AND type = 'R')
    CREATE ROLE app_user;
GO

-- =====================================================
-- STEP 2: TABLES
-- Order matters: nodes/users first (referenced by FKs)
-- =====================================================

CREATE TABLE dbo.users (
    id              UNIQUEIDENTIFIER    PRIMARY KEY DEFAULT NEWID(),
    email           NVARCHAR(255)       NOT NULL UNIQUE,
    full_name       NVARCHAR(255),
    role            NVARCHAR(10)        NOT NULL DEFAULT 'user'
                                        CHECK (role IN ('admin', 'user')),
    email_verified  BIT                 NOT NULL DEFAULT 0
);
GO

CREATE TABLE dbo.nodes (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID()
);
GO

CREATE TABLE dbo.cpu (
    row_id              INT IDENTITY(1,1)   PRIMARY KEY,
    cpu_percent         FLOAT               NOT NULL,
    cpu_core_percent    INT                 NOT NULL,
    cpu_frequency       FLOAT               NOT NULL,
    user_id             UNIQUEIDENTIFIER,
    node_id             UNIQUEIDENTIFIER,
    FOREIGN KEY (node_id) REFERENCES dbo.nodes(id)
);
GO

CREATE TABLE dbo.disk (
    row_id          INT IDENTITY(1,1)   PRIMARY KEY,
    disk_used       FLOAT               NOT NULL,
    disk_total      FLOAT               NOT NULL,
    disk_percent    INT                 NOT NULL,
    read_bytes      FLOAT               NOT NULL,
    write_bytes     FLOAT               NOT NULL,
    user_id         UNIQUEIDENTIFIER,
    node_id         UNIQUEIDENTIFIER,
    FOREIGN KEY (node_id) REFERENCES dbo.nodes(id)
);
GO

CREATE TABLE dbo.ram (
    row_id          INT IDENTITY(1,1)   PRIMARY KEY,
    ram_used        FLOAT               NOT NULL,
    ram_total       FLOAT               NOT NULL,
    ram_percent     INT                 NOT NULL,
    user_id         UNIQUEIDENTIFIER,
    node_id         UNIQUEIDENTIFIER,
    FOREIGN KEY (node_id) REFERENCES dbo.nodes(id)
);
GO

CREATE TABLE dbo.thermal (
    row_id          INT IDENTITY(1,1)   PRIMARY KEY,
    cpu_temp        FLOAT               NOT NULL,
    system_temp     FLOAT               NOT NULL,
    user_id         UNIQUEIDENTIFIER,
    node_id         UNIQUEIDENTIFIER,
    FOREIGN KEY (node_id) REFERENCES dbo.nodes(id)
);
GO

CREATE TABLE dbo.logs (
    date_log    DATE    DEFAULT CAST(GETDATE() AS DATE),
    time_log    TIME    DEFAULT CAST(GETDATE() AS TIME)
);
GO

-- =====================================================
-- STEP 3: HELPER FUNCTIONS (non-schema-bound)
-- These are for backend/application use only
-- NOT referenced inside the RLS predicate
-- =====================================================

-- Returns the current session user's ID
CREATE FUNCTION dbo.fn_user_id()
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
    RETURN CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER);
END;
GO

-- Returns 1 if the current session user is an admin
-- Use this in your application code, NOT inside RLS
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
-- STEP 4: RLS PREDICATE FUNCTION (schema-bound)
-- Admin check is INLINED here — cannot call fn_is_admin()
-- because SCHEMABINDING forbids calling non-bound functions
-- =====================================================
CREATE FUNCTION dbo.fn_rls_telemetry(@user_id UNIQUEIDENTIFIER)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS result
    FROM dbo.users u
    WHERE
        -- Allow if the row belongs to the current session user
        @user_id = CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER)
        OR
        -- Allow if the current session user is an admin (inlined check)
        (
            u.id   = CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER)
            AND u.role = 'admin'
        )
);
GO

-- =====================================================
-- STEP 5: ROW-LEVEL SECURITY POLICIES
-- Must come after fn_rls_telemetry exists
-- =====================================================
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

-- =====================================================
-- STEP 6: DENY app_user ACCESS TO USERS TABLE
-- Must come after the table and role both exist
-- =====================================================
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.users TO app_user;
GO

-- =====================================================
-- STEP 7: PERMISSIONS
-- Must come after tables and roles exist
-- =====================================================

-- app_user: telemetry read/insert only
GRANT SELECT, INSERT ON dbo.cpu     TO app_user;
GRANT SELECT, INSERT ON dbo.disk    TO app_user;
GRANT SELECT, INSERT ON dbo.ram     TO app_user;
GRANT SELECT, INSERT ON dbo.thermal TO app_user;
GRANT SELECT         ON dbo.nodes   TO app_user;
GRANT SELECT         ON dbo.logs    TO app_user;

-- admin_user: full control over everything in dbo
GRANT CONTROL ON SCHEMA::dbo TO admin_user;
GO

-- =====================================================
-- STEP 8: INDEXES
-- Must come after tables exist
-- Last because they are non-blocking and non-critical
-- =====================================================

-- Composite: user + node (most frequent query pattern)
CREATE INDEX idx_cpu_user_node     ON dbo.cpu     (user_id, node_id);
CREATE INDEX idx_disk_user_node    ON dbo.disk    (user_id, node_id);
CREATE INDEX idx_ram_user_node     ON dbo.ram     (user_id, node_id);
CREATE INDEX idx_thermal_user_node ON dbo.thermal (user_id, node_id);

-- Node-only (dashboard/overview queries)
CREATE INDEX idx_cpu_node     ON dbo.cpu     (node_id);
CREATE INDEX idx_disk_node    ON dbo.disk    (node_id);
CREATE INDEX idx_ram_node     ON dbo.ram     (node_id);
CREATE INDEX idx_thermal_node ON dbo.thermal (node_id);
GO

-- Authentication flow, we need to figure out how authentication works for RLS to work.
EXEC sp_set_session_context 
    @key = N'user_id', 
    @value = 'USER-UUID-HERE';
