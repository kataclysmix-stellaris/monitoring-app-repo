-- =====================================================
-- COMPLETE DATABASE SCHEMA — T-SQL / SQL Server 2022
-- Military Telemetry Monitoring System (School Project)
-- Converted from PostgreSQL
--
-- CONVERSION NOTES:
--   UUID / gen_random_uuid() -> UNIQUEIDENTIFIER / NEWID()
--   VARCHAR(n)               -> NVARCHAR(n)
--   BOOLEAN                  -> BIT
--   TIMESTAMPTZ              -> DATETIME2
--   FLOAT                    -> FLOAT (same)
--   JSONB                    -> NVARCHAR(MAX)  (SQL Server 2022 supports JSON natively)
--   GENERATED ALWAYS AS IDENTITY -> IDENTITY(1,1)
--   CREATE EXTENSION         -> not applicable; built-in equivalents used
--   pg_partman / pg_cron     -> Partition Functions + SQL Agent job
--   RLS USING/WITH CHECK     -> SQL Server RLS (FILTER + BLOCK predicates)
--   REVOKE ALL FROM PUBLIC   -> SQL Server uses schema/object permissions directly
--   ROLES                    -> SQL Server ROLE via CREATE ROLE
--
-- PARTITIONING:
--   PostgreSQL uses pg_partman for automated time-based partitioning.
--   SQL Server 2022 uses Partition Functions and Partition Schemes.
--   Daily partitions are pre-created for -7 days through +7 days relative
--   to deployment, covering the same 1-week retention window.
--   A SQL Agent job handles rolling partition maintenance.
--
-- RUN ORDER:
--   BLOCK 1  — Database & Filegroups (run as sysadmin)
--   BLOCK 2  — Roles
--   BLOCK 3  — Partition Infrastructure
--   BLOCK 4  — Core Tables
--   BLOCK 5  — Helper Functions
--   BLOCK 6  — RLS Security Policies
--   BLOCK 7  — Compliance Tables
--   BLOCK 8  — Permissions
--   BLOCK 9  — Indexes
--   BLOCK 10 — SQL Agent Maintenance Job
-- =====================================================


-- =====================================================
-- BLOCK 1: DATABASE & FILEGROUPS
-- SQL Server requires filegroups for partitioning.
-- Run as sysadmin on the target database.
-- =====================================================
USE master;
GO

-- Create the database if it does not already exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'TelemetryDB')
BEGIN
    CREATE DATABASE TelemetryDB;
END
GO

USE TelemetryDB;
GO

-- Add a secondary filegroup for partition storage
-- In production, point the FILENAME to appropriate volumes
IF NOT EXISTS (
    SELECT name FROM sys.filegroups WHERE name = N'FG_Telemetry'
)
BEGIN
    ALTER DATABASE TelemetryDB
    ADD FILEGROUP FG_Telemetry;

    ALTER DATABASE TelemetryDB
    ADD FILE (
        NAME        = N'TelemetryData',
        FILENAME    = N'C:\SQLData\TelemetryData.ndf',
        SIZE        = 128MB,
        MAXSIZE     = UNLIMITED,
        FILEGROWTH  = 64MB
    ) TO FILEGROUP FG_Telemetry;
END
GO


-- =====================================================
-- BLOCK 2: ROLES
-- SQL Server uses DATABASE ROLES (not server roles here).
-- Permissions are granted per role below in BLOCK 8.
-- =====================================================
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = N'admin_user' AND type = 'R')
    CREATE ROLE admin_user;
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = N'app_user' AND type = 'R')
    CREATE ROLE app_user;
GO

IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = N'auditor_user' AND type = 'R')
    CREATE ROLE auditor_user;
GO


-- =====================================================
-- BLOCK 3: PARTITION INFRASTRUCTURE
-- One Partition Function + Scheme per telemetry table.
-- Boundary values cover 14 days (7 past + today + 7 future)
-- using daily RANGE RIGHT boundaries at midnight UTC.
--
-- RANGE RIGHT: the boundary value is the START of the
-- right partition, so a row at exactly midnight falls
-- into the newer partition — consistent with pg_partman
-- range semantics.
--
-- All four telemetry tables (cpu, disk, ram, thermal)
-- share identical partition logic but SQL Server requires
-- separate function/scheme per object to allow independent
-- split/merge operations during rolling maintenance.
-- =====================================================

-- -----------------------------------------------
-- CPU partition function & scheme
-- -----------------------------------------------
IF NOT EXISTS (
    SELECT name FROM sys.partition_functions WHERE name = N'pf_cpu_daily'
)
BEGIN
    CREATE PARTITION FUNCTION pf_cpu_daily (DATETIME2)
    AS RANGE RIGHT FOR VALUES (
        CAST(DATEADD(DAY, -7, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -6, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -5, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -4, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -3, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -2, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -1, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(CAST(GETUTCDATE() AS DATE) AS DATETIME2),
        CAST(DATEADD(DAY,  1, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  2, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  3, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  4, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  5, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  6, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  7, CAST(GETUTCDATE() AS DATE)) AS DATETIME2)
    );
END
GO

IF NOT EXISTS (
    SELECT name FROM sys.partition_schemes WHERE name = N'ps_cpu_daily'
)
BEGIN
    CREATE PARTITION SCHEME ps_cpu_daily
    AS PARTITION pf_cpu_daily
    ALL TO (FG_Telemetry);
END
GO

-- -----------------------------------------------
-- DISK partition function & scheme
-- -----------------------------------------------
IF NOT EXISTS (
    SELECT name FROM sys.partition_functions WHERE name = N'pf_disk_daily'
)
BEGIN
    CREATE PARTITION FUNCTION pf_disk_daily (DATETIME2)
    AS RANGE RIGHT FOR VALUES (
        CAST(DATEADD(DAY, -7, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -6, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -5, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -4, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -3, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -2, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -1, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(CAST(GETUTCDATE() AS DATE) AS DATETIME2),
        CAST(DATEADD(DAY,  1, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  2, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  3, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  4, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  5, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  6, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  7, CAST(GETUTCDATE() AS DATE)) AS DATETIME2)
    );
END
GO

IF NOT EXISTS (
    SELECT name FROM sys.partition_schemes WHERE name = N'ps_disk_daily'
)
BEGIN
    CREATE PARTITION SCHEME ps_disk_daily
    AS PARTITION pf_disk_daily
    ALL TO (FG_Telemetry);
END
GO

-- -----------------------------------------------
-- RAM partition function & scheme
-- -----------------------------------------------
IF NOT EXISTS (
    SELECT name FROM sys.partition_functions WHERE name = N'pf_ram_daily'
)
BEGIN
    CREATE PARTITION FUNCTION pf_ram_daily (DATETIME2)
    AS RANGE RIGHT FOR VALUES (
        CAST(DATEADD(DAY, -7, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -6, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -5, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -4, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -3, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -2, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -1, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(CAST(GETUTCDATE() AS DATE) AS DATETIME2),
        CAST(DATEADD(DAY,  1, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  2, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  3, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  4, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  5, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  6, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  7, CAST(GETUTCDATE() AS DATE)) AS DATETIME2)
    );
END
GO

IF NOT EXISTS (
    SELECT name FROM sys.partition_schemes WHERE name = N'ps_ram_daily'
)
BEGIN
    CREATE PARTITION SCHEME ps_ram_daily
    AS PARTITION pf_ram_daily
    ALL TO (FG_Telemetry);
END
GO

-- -----------------------------------------------
-- THERMAL partition function & scheme
-- -----------------------------------------------
IF NOT EXISTS (
    SELECT name FROM sys.partition_functions WHERE name = N'pf_thermal_daily'
)
BEGIN
    CREATE PARTITION FUNCTION pf_thermal_daily (DATETIME2)
    AS RANGE RIGHT FOR VALUES (
        CAST(DATEADD(DAY, -7, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -6, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -5, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -4, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -3, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -2, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY, -1, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(CAST(GETUTCDATE() AS DATE) AS DATETIME2),
        CAST(DATEADD(DAY,  1, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  2, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  3, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  4, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  5, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  6, CAST(GETUTCDATE() AS DATE)) AS DATETIME2),
        CAST(DATEADD(DAY,  7, CAST(GETUTCDATE() AS DATE)) AS DATETIME2)
    );
END
GO

IF NOT EXISTS (
    SELECT name FROM sys.partition_schemes WHERE name = N'ps_thermal_daily'
)
BEGIN
    CREATE PARTITION SCHEME ps_thermal_daily
    AS PARTITION pf_thermal_daily
    ALL TO (FG_Telemetry);
END
GO


-- =====================================================
-- BLOCK 4: CORE TABLES
-- Order: users -> nodes -> telemetry tables -> vms
--
-- Partitioned tables: the clustered index must include
-- the partition column (recorded_at) because SQL Server
-- requires the partition key to be part of any unique
-- clustered index key.  row_id + recorded_at together
-- form the clustered PK on partitioned tables.
-- =====================================================

-- -----------------------------------------------
-- users
-- -----------------------------------------------
IF OBJECT_ID(N'dbo.users', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.users (
        id                      UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_users_id DEFAULT NEWID(),
        email                   NVARCHAR(255)       NOT NULL,
        full_name               NVARCHAR(255)       NULL,

        -- Role & clearance
        role                    NVARCHAR(20)        NOT NULL CONSTRAINT DF_users_role DEFAULT N'readonly',
        clearance_level         NVARCHAR(20)        NOT NULL CONSTRAINT DF_users_clearance DEFAULT N'UNCLASSIFIED',

        -- Identity & auth provider
        email_verified          BIT                 NOT NULL CONSTRAINT DF_users_email_verified DEFAULT 0,
        auth_provider           NVARCHAR(50)        NOT NULL CONSTRAINT DF_users_auth_provider DEFAULT N'local',
        auth_provider_id        NVARCHAR(255)       NULL,

        -- Password auth
        password_hash           NVARCHAR(255)       NULL,
        password_salt           NVARCHAR(100)       NULL,
        password_algorithm      NVARCHAR(20)        NOT NULL CONSTRAINT DF_users_pw_algorithm DEFAULT N'argon2id',
        password_changed_at     DATETIME2           NULL,
        password_expires_at     DATETIME2           NULL,
        must_change_password    BIT                 NOT NULL CONSTRAINT DF_users_must_change DEFAULT 0,

        -- Account state & lockout
        mfa_enforced            BIT                 NOT NULL CONSTRAINT DF_users_mfa DEFAULT 1,
        last_login              DATETIME2           NULL,
        account_locked          BIT                 NOT NULL CONSTRAINT DF_users_locked DEFAULT 0,
        failed_login_count      INT                 NOT NULL CONSTRAINT DF_users_fail_count DEFAULT 0,

        CONSTRAINT PK_users PRIMARY KEY CLUSTERED (id),
        CONSTRAINT UQ_users_email UNIQUE (email),
        CONSTRAINT CK_users_role CHECK (role IN (N'admin', N'analyst', N'operator', N'auditor', N'readonly')),
        CONSTRAINT CK_users_clearance CHECK (clearance_level IN (N'UNCLASSIFIED', N'CUI', N'SECRET')),
        CONSTRAINT CK_users_auth_provider CHECK (auth_provider IN (N'local', N'ldap', N'saml', N'entra')),
        CONSTRAINT CK_users_pw_algorithm CHECK (password_algorithm IN (N'argon2id', N'bcrypt'))
    );
END
GO

-- -----------------------------------------------
-- nodes
-- -----------------------------------------------
IF OBJECT_ID(N'dbo.nodes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.nodes (
        id                  UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_nodes_id DEFAULT NEWID(),
        classification      NVARCHAR(20)        NOT NULL CONSTRAINT DF_nodes_class DEFAULT N'UNCLASSIFIED',
        organization_id     UNIQUEIDENTIFIER    NULL,

        CONSTRAINT PK_nodes PRIMARY KEY CLUSTERED (id),
        CONSTRAINT CK_nodes_classification CHECK (classification IN (N'UNCLASSIFIED', N'CUI', N'SECRET'))
    );
END
GO

-- -----------------------------------------------
-- cpu  (partitioned by recorded_at)
-- PK is (row_id, recorded_at) — SQL Server requires
-- the partition key inside the clustered index.
-- -----------------------------------------------
IF OBJECT_ID(N'dbo.cpu', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.cpu (
        row_id          INT             NOT NULL IDENTITY(1,1),
        cpu_percent     FLOAT           NOT NULL,
        cpu_core_per    NVARCHAR(MAX)   NOT NULL CONSTRAINT DF_cpu_core_per DEFAULT N'[]',
        cpu_frequency   NVARCHAR(MAX)   NOT NULL,
        user_id         UNIQUEIDENTIFIER NULL,
        node_id         UNIQUEIDENTIFIER NULL,
        recorded_at     DATETIME2       NOT NULL CONSTRAINT DF_cpu_recorded_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_cpu PRIMARY KEY CLUSTERED (row_id, recorded_at)
            ON ps_cpu_daily(recorded_at),
        CONSTRAINT FK_cpu_node FOREIGN KEY (node_id) REFERENCES dbo.nodes(id),
        CONSTRAINT FK_cpu_user FOREIGN KEY (user_id) REFERENCES dbo.users(id)
    ) ON ps_cpu_daily(recorded_at);
END
GO

-- -----------------------------------------------
-- disk  (partitioned by recorded_at)
-- -----------------------------------------------
IF OBJECT_ID(N'dbo.disk', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.disk (
        row_id          INT             NOT NULL IDENTITY(1,1),
        disk_used       FLOAT           NOT NULL,
        disk_total      FLOAT           NOT NULL,
        disk_percent    INT             NOT NULL,
        read_bytes      FLOAT           NOT NULL,
        write_bytes     FLOAT           NOT NULL,
        user_id         UNIQUEIDENTIFIER NULL,
        node_id         UNIQUEIDENTIFIER NULL,
        recorded_at     DATETIME2       NOT NULL CONSTRAINT DF_disk_recorded_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_disk PRIMARY KEY CLUSTERED (row_id, recorded_at)
            ON ps_disk_daily(recorded_at),
        CONSTRAINT FK_disk_node FOREIGN KEY (node_id) REFERENCES dbo.nodes(id),
        CONSTRAINT FK_disk_user FOREIGN KEY (user_id) REFERENCES dbo.users(id)
    ) ON ps_disk_daily(recorded_at);
END
GO

-- -----------------------------------------------
-- ram  (partitioned by recorded_at)
-- -----------------------------------------------
IF OBJECT_ID(N'dbo.ram', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ram (
        row_id          INT             NOT NULL IDENTITY(1,1),
        ram_used        FLOAT           NOT NULL,
        ram_total       FLOAT           NOT NULL,
        ram_per         FLOAT           NOT NULL,
        swap_per        FLOAT           NULL,
        user_id         UNIQUEIDENTIFIER NULL,
        node_id         UNIQUEIDENTIFIER NULL,
        recorded_at     DATETIME2       NOT NULL CONSTRAINT DF_ram_recorded_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_ram PRIMARY KEY CLUSTERED (row_id, recorded_at)
            ON ps_ram_daily(recorded_at),
        CONSTRAINT FK_ram_node FOREIGN KEY (node_id) REFERENCES dbo.nodes(id),
        CONSTRAINT FK_ram_user FOREIGN KEY (user_id) REFERENCES dbo.users(id)
    ) ON ps_ram_daily(recorded_at);
END
GO

-- -----------------------------------------------
-- thermal  (partitioned by recorded_at)
-- -----------------------------------------------
IF OBJECT_ID(N'dbo.thermal', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.thermal (
        row_id          INT             NOT NULL IDENTITY(1,1),
        cpu_temp        FLOAT           NOT NULL,
        system_temp     FLOAT           NOT NULL,
        user_id         UNIQUEIDENTIFIER NULL,
        node_id         UNIQUEIDENTIFIER NULL,
        recorded_at     DATETIME2       NOT NULL CONSTRAINT DF_thermal_recorded_at DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_thermal PRIMARY KEY CLUSTERED (row_id, recorded_at)
            ON ps_thermal_daily(recorded_at),
        CONSTRAINT FK_thermal_node FOREIGN KEY (node_id) REFERENCES dbo.nodes(id),
        CONSTRAINT FK_thermal_user FOREIGN KEY (user_id) REFERENCES dbo.users(id)
    ) ON ps_thermal_daily(recorded_at);
END
GO

-- -----------------------------------------------
-- vms  (not partitioned — matches original schema)
-- -----------------------------------------------
IF OBJECT_ID(N'dbo.vms', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.vms (
        row_id          INT             NOT NULL IDENTITY(1,1),
        node_id         UNIQUEIDENTIFIER NOT NULL,
        user_id         UNIQUEIDENTIFIER NULL,
        recorded_at     DATETIME2       NOT NULL CONSTRAINT DF_vms_recorded_at DEFAULT SYSUTCDATETIME(),
        vm_id           NVARCHAR(255)   NOT NULL,
        vm_name         NVARCHAR(255)   NOT NULL,
        vm_type         NVARCHAR(50)    NOT NULL CONSTRAINT DF_vms_type DEFAULT N'vm',
        status          NVARCHAR(50)    NOT NULL,
        cpu_percent     FLOAT           NOT NULL CONSTRAINT DF_vms_cpu DEFAULT 0,
        ram_used_gb     FLOAT           NOT NULL CONSTRAINT DF_vms_ram_used DEFAULT 0,
        ram_demand_gb   FLOAT           NOT NULL CONSTRAINT DF_vms_ram_demand DEFAULT 0,
        uptime          NVARCHAR(100)   NULL,
        creation_time   DATETIME2       NULL,

        CONSTRAINT PK_vms PRIMARY KEY CLUSTERED (row_id),
        CONSTRAINT FK_vms_node FOREIGN KEY (node_id) REFERENCES dbo.nodes(id),
        CONSTRAINT FK_vms_user FOREIGN KEY (user_id) REFERENCES dbo.users(id),
        CONSTRAINT CK_vms_type   CHECK (vm_type IN (N'vm', N'container', N'wsl')),
        CONSTRAINT CK_vms_status CHECK (status  IN (N'Running', N'Stopped', N'Paused', N'Unknown'))
    );
END
GO


-- =====================================================
-- BLOCK 5: HELPER FUNCTIONS
--
-- PostgreSQL current_setting('app.user_id') maps to
-- SQL Server SESSION_CONTEXT(N'app_user_id').
-- The backend sets this via sp_set_session_context
-- before executing any query.
--
-- fn_is_admin() is used ONLY in application/backend
-- code, not inside RLS predicates, to avoid recursive
-- permission checks — same caveat as the original.
-- =====================================================

-- Returns the session user UUID (set by backend on connect)
CREATE OR ALTER FUNCTION dbo.fn_user_id()
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
    RETURN CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER);
END
GO

-- Returns 1 if the session user has the 'admin' role
CREATE OR ALTER FUNCTION dbo.fn_is_admin()
RETURNS BIT
AS
BEGIN
    DECLARE @result BIT = 0;
    IF EXISTS (
        SELECT 1
        FROM   dbo.users
        WHERE  id   = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER)
          AND  role = N'admin'
    )
        SET @result = 1;
    RETURN @result;
END
GO

-- Clearance check: returns 1 if session user clearance
-- meets or exceeds the given node's classification.
CREATE OR ALTER FUNCTION dbo.fn_clearance_check(@p_node_id UNIQUEIDENTIFIER)
RETURNS BIT
AS
BEGIN
    DECLARE @clearance       NVARCHAR(20);
    DECLARE @classification  NVARCHAR(20);

    SELECT @clearance = clearance_level
    FROM   dbo.users
    WHERE  id = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER);

    SELECT @classification = classification
    FROM   dbo.nodes
    WHERE  id = @p_node_id;

    -- Node not found → deny
    IF @classification IS NULL
        RETURN 0;

    -- Clearance hierarchy
    IF @clearance = N'SECRET'
        RETURN 1;
    IF @clearance = N'CUI'     AND @classification IN (N'CUI', N'UNCLASSIFIED')
        RETURN 1;
    IF @clearance = N'UNCLASSIFIED' AND @classification = N'UNCLASSIFIED'
        RETURN 1;

    RETURN 0;
END
GO


-- =====================================================
-- BLOCK 6: RLS SECURITY POLICIES
--
-- SQL Server RLS uses inline table-valued functions
-- as predicates, then binds them with CREATE SECURITY
-- POLICY.
--
-- FILTER predicate  → controls SELECT (equivalent to
--                     PostgreSQL USING clause).
-- BLOCK  predicate  → controls INSERT/UPDATE/DELETE
--                     (equivalent to WITH CHECK).
--
-- Two predicate functions per table:
--   fn_rls_filter_<table>  — FILTER (read)
--   fn_rls_block_<table>   — BLOCK  (write)
--
-- Both enforce the same dual condition:
--   1. Row belongs to session user OR user is admin
--   2. User clearance meets node classification
-- =====================================================

-- -----------------------------------------------
-- CPU predicates
-- -----------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_rls_filter_cpu(
    @user_id UNIQUEIDENTIFIER,
    @node_id UNIQUEIDENTIFIER
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS rls_result
    WHERE (
        @user_id = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER)
        OR dbo.fn_is_admin() = 1
    )
    AND dbo.fn_clearance_check(@node_id) = 1;
GO

CREATE OR ALTER FUNCTION dbo.fn_rls_block_cpu(
    @user_id UNIQUEIDENTIFIER,
    @node_id UNIQUEIDENTIFIER
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS rls_result
    WHERE (
        @user_id = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER)
        OR dbo.fn_is_admin() = 1
    )
    AND dbo.fn_clearance_check(@node_id) = 1;
GO

-- -----------------------------------------------
-- Disk predicates
-- -----------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_rls_filter_disk(
    @user_id UNIQUEIDENTIFIER,
    @node_id UNIQUEIDENTIFIER
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS rls_result
    WHERE (
        @user_id = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER)
        OR dbo.fn_is_admin() = 1
    )
    AND dbo.fn_clearance_check(@node_id) = 1;
GO

CREATE OR ALTER FUNCTION dbo.fn_rls_block_disk(
    @user_id UNIQUEIDENTIFIER,
    @node_id UNIQUEIDENTIFIER
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS rls_result
    WHERE (
        @user_id = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER)
        OR dbo.fn_is_admin() = 1
    )
    AND dbo.fn_clearance_check(@node_id) = 1;
GO

-- -----------------------------------------------
-- RAM predicates
-- -----------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_rls_filter_ram(
    @user_id UNIQUEIDENTIFIER,
    @node_id UNIQUEIDENTIFIER
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS rls_result
    WHERE (
        @user_id = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER)
        OR dbo.fn_is_admin() = 1
    )
    AND dbo.fn_clearance_check(@node_id) = 1;
GO

CREATE OR ALTER FUNCTION dbo.fn_rls_block_ram(
    @user_id UNIQUEIDENTIFIER,
    @node_id UNIQUEIDENTIFIER
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS rls_result
    WHERE (
        @user_id = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER)
        OR dbo.fn_is_admin() = 1
    )
    AND dbo.fn_clearance_check(@node_id) = 1;
GO

-- -----------------------------------------------
-- Thermal predicates
-- -----------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_rls_filter_thermal(
    @user_id UNIQUEIDENTIFIER,
    @node_id UNIQUEIDENTIFIER
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS rls_result
    WHERE (
        @user_id = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER)
        OR dbo.fn_is_admin() = 1
    )
    AND dbo.fn_clearance_check(@node_id) = 1;
GO

CREATE OR ALTER FUNCTION dbo.fn_rls_block_thermal(
    @user_id UNIQUEIDENTIFIER,
    @node_id UNIQUEIDENTIFIER
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS rls_result
    WHERE (
        @user_id = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER)
        OR dbo.fn_is_admin() = 1
    )
    AND dbo.fn_clearance_check(@node_id) = 1;
GO

-- -----------------------------------------------
-- VMs predicates
-- -----------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_rls_filter_vms(
    @user_id UNIQUEIDENTIFIER,
    @node_id UNIQUEIDENTIFIER
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS rls_result
    WHERE (
        @user_id = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER)
        OR dbo.fn_is_admin() = 1
    )
    AND dbo.fn_clearance_check(@node_id) = 1;
GO

CREATE OR ALTER FUNCTION dbo.fn_rls_block_vms(
    @user_id UNIQUEIDENTIFIER,
    @node_id UNIQUEIDENTIFIER
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS rls_result
    WHERE (
        @user_id = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER)
        OR dbo.fn_is_admin() = 1
    )
    AND dbo.fn_clearance_check(@node_id) = 1;
GO

-- -----------------------------------------------
-- Bind security policies
-- STATE = ON activates the policy immediately.
-- -----------------------------------------------
IF NOT EXISTS (
    SELECT name FROM sys.security_policies WHERE name = N'sp_cpu_rls'
)
BEGIN
    CREATE SECURITY POLICY dbo.sp_cpu_rls
        ADD FILTER PREDICATE dbo.fn_rls_filter_cpu(user_id, node_id) ON dbo.cpu,
        ADD BLOCK  PREDICATE dbo.fn_rls_block_cpu (user_id, node_id) ON dbo.cpu
    WITH (STATE = ON);
END
GO

IF NOT EXISTS (
    SELECT name FROM sys.security_policies WHERE name = N'sp_disk_rls'
)
BEGIN
    CREATE SECURITY POLICY dbo.sp_disk_rls
        ADD FILTER PREDICATE dbo.fn_rls_filter_disk(user_id, node_id) ON dbo.disk,
        ADD BLOCK  PREDICATE dbo.fn_rls_block_disk (user_id, node_id) ON dbo.disk
    WITH (STATE = ON);
END
GO

IF NOT EXISTS (
    SELECT name FROM sys.security_policies WHERE name = N'sp_ram_rls'
)
BEGIN
    CREATE SECURITY POLICY dbo.sp_ram_rls
        ADD FILTER PREDICATE dbo.fn_rls_filter_ram(user_id, node_id) ON dbo.ram,
        ADD BLOCK  PREDICATE dbo.fn_rls_block_ram (user_id, node_id) ON dbo.ram
    WITH (STATE = ON);
END
GO

IF NOT EXISTS (
    SELECT name FROM sys.security_policies WHERE name = N'sp_thermal_rls'
)
BEGIN
    CREATE SECURITY POLICY dbo.sp_thermal_rls
        ADD FILTER PREDICATE dbo.fn_rls_filter_thermal(user_id, node_id) ON dbo.thermal,
        ADD BLOCK  PREDICATE dbo.fn_rls_block_thermal (user_id, node_id) ON dbo.thermal
    WITH (STATE = ON);
END
GO

IF NOT EXISTS (
    SELECT name FROM sys.security_policies WHERE name = N'sp_vms_rls'
)
BEGIN
    CREATE SECURITY POLICY dbo.sp_vms_rls
        ADD FILTER PREDICATE dbo.fn_rls_filter_vms(user_id, node_id) ON dbo.vms,
        ADD BLOCK  PREDICATE dbo.fn_rls_block_vms (user_id, node_id) ON dbo.vms
    WITH (STATE = ON);
END
GO


-- =====================================================
-- BLOCK 7: COMPLIANCE TABLES
-- audit_log, mfa_config, sessions, password_reset
-- =====================================================

-- -----------------------------------------------
-- audit_log — append-only, tamper-proof
-- -----------------------------------------------
IF OBJECT_ID(N'dbo.audit_log', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.audit_log (
        log_id          UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_audit_log_id DEFAULT NEWID(),
        user_id         UNIQUEIDENTIFIER    NOT NULL,
        action_type     NVARCHAR(100)       NOT NULL,
        target_resource NVARCHAR(255)       NULL,
        ip_address      NVARCHAR(45)        NULL,
        session_id      NVARCHAR(255)       NULL,
        result          NVARCHAR(20)        NOT NULL,
        logged_at       DATETIME2           NOT NULL CONSTRAINT DF_audit_log_at DEFAULT SYSUTCDATETIME(),
        detail          NVARCHAR(MAX)       NULL,

        CONSTRAINT PK_audit_log PRIMARY KEY CLUSTERED (log_id),
        CONSTRAINT CK_audit_action CHECK (action_type IN (
            N'LOGIN', N'LOGIN_FAILED', N'MFA_FAILED', N'LOCKED',
            N'LOGOUT', N'PWD_RESET', N'SESSION_EXPIRE', N'QUERY',
            N'EXPORT', N'CONFIG_CHANGE', N'ACCESS_DENIED'
        )),
        CONSTRAINT CK_audit_result CHECK (result IN (N'SUCCESS', N'DENIED', N'FAILED'))
    );
END
GO

-- -----------------------------------------------
-- mfa_config
-- -----------------------------------------------
IF OBJECT_ID(N'dbo.mfa_config', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.mfa_config (
        mfa_id          UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_mfa_id DEFAULT NEWID(),
        user_id         UNIQUEIDENTIFIER    NOT NULL,
        mfa_type        NVARCHAR(20)        NOT NULL,
        secret_hash     NVARCHAR(255)       NOT NULL,
        is_active       BIT                 NOT NULL CONSTRAINT DF_mfa_active DEFAULT 1,
        created_at      DATETIME2           NOT NULL CONSTRAINT DF_mfa_created DEFAULT SYSUTCDATETIME(),
        last_used_at    DATETIME2           NULL,

        CONSTRAINT PK_mfa_config PRIMARY KEY CLUSTERED (mfa_id),
        CONSTRAINT FK_mfa_user  FOREIGN KEY (user_id) REFERENCES dbo.users(id),
        CONSTRAINT CK_mfa_type  CHECK (mfa_type IN (N'totp', N'hardware_key', N'sms'))
    );
END
GO

-- -----------------------------------------------
-- sessions
-- -----------------------------------------------
IF OBJECT_ID(N'dbo.sessions', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.sessions (
        session_id          UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_sessions_id DEFAULT NEWID(),
        user_id             UNIQUEIDENTIFIER    NOT NULL,
        session_token_hash  NVARCHAR(255)       NOT NULL,
        ip_address          NVARCHAR(45)        NULL,
        user_agent          NVARCHAR(500)       NULL,
        created_at          DATETIME2           NOT NULL CONSTRAINT DF_sessions_created DEFAULT SYSUTCDATETIME(),
        expires_at          DATETIME2           NOT NULL,
        revoked             BIT                 NOT NULL CONSTRAINT DF_sessions_revoked DEFAULT 0,
        revoked_at          DATETIME2           NULL,
        revoked_reason      NVARCHAR(100)       NULL,

        CONSTRAINT PK_sessions PRIMARY KEY CLUSTERED (session_id),
        CONSTRAINT FK_sessions_user    FOREIGN KEY (user_id) REFERENCES dbo.users(id),
        CONSTRAINT CK_sessions_reason  CHECK (revoked_reason IN (N'LOGOUT', N'TIMEOUT', N'ADMIN_REVOKE'))
    );
END
GO

-- -----------------------------------------------
-- password_reset
-- -----------------------------------------------
IF OBJECT_ID(N'dbo.password_reset', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.password_reset (
        reset_id        UNIQUEIDENTIFIER    NOT NULL CONSTRAINT DF_reset_id DEFAULT NEWID(),
        user_id         UNIQUEIDENTIFIER    NOT NULL,
        token_hash      NVARCHAR(255)       NOT NULL,
        requested_at    DATETIME2           NOT NULL CONSTRAINT DF_reset_requested DEFAULT SYSUTCDATETIME(),
        expires_at      DATETIME2           NOT NULL,
        used            BIT                 NOT NULL CONSTRAINT DF_reset_used DEFAULT 0,
        used_at         DATETIME2           NULL,
        ip_address      NVARCHAR(45)        NULL,

        CONSTRAINT PK_password_reset PRIMARY KEY CLUSTERED (reset_id),
        CONSTRAINT FK_reset_user FOREIGN KEY (user_id) REFERENCES dbo.users(id)
    );
END
GO


-- =====================================================
-- BLOCK 8: PERMISSIONS
--
-- SQL Server does not have REVOKE ALL FROM PUBLIC —
-- there is no public grant to revoke.  Instead, we
-- explicitly GRANT only what each role requires.
-- DENY is available and used where needed (e.g.,
-- blocking UPDATE/DELETE on audit_log for admin_user).
-- =====================================================

-- -----------------------------------------------
-- app_user permissions
-- -----------------------------------------------

-- Telemetry: SELECT + INSERT (RLS filters rows)
GRANT SELECT, INSERT ON dbo.cpu     TO app_user;
GRANT SELECT, INSERT ON dbo.disk    TO app_user;
GRANT SELECT, INSERT ON dbo.ram     TO app_user;
GRANT SELECT, INSERT ON dbo.thermal TO app_user;
GRANT SELECT, INSERT ON dbo.vms     TO app_user;

-- Nodes: read only
GRANT SELECT ON dbo.nodes TO app_user;

-- Sessions: create and revoke (no delete)
GRANT SELECT, INSERT, UPDATE ON dbo.sessions TO app_user;

-- MFA: read and update last_used_at
GRANT SELECT, UPDATE ON dbo.mfa_config TO app_user;

-- Password reset: create tokens and mark used
GRANT SELECT, INSERT, UPDATE ON dbo.password_reset TO app_user;

-- Audit log: insert only
GRANT INSERT ON dbo.audit_log TO app_user;

-- Helper functions: execute
GRANT EXECUTE ON dbo.fn_user_id         TO app_user;
GRANT EXECUTE ON dbo.fn_is_admin        TO app_user;
GRANT EXECUTE ON dbo.fn_clearance_check TO app_user;

-- -----------------------------------------------
-- auditor_user permissions
-- -----------------------------------------------
GRANT SELECT ON dbo.audit_log   TO auditor_user;
GRANT SELECT ON dbo.sessions    TO auditor_user;
GRANT SELECT ON dbo.mfa_config  TO auditor_user;
-- No access to telemetry, users, nodes, or vms

-- -----------------------------------------------
-- admin_user permissions
-- -----------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.users           TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.nodes           TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.cpu             TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.disk            TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.ram             TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.thermal         TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.vms             TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.mfa_config      TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.sessions        TO admin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.password_reset  TO admin_user;
GRANT SELECT, INSERT               ON dbo.audit_log        TO admin_user;

-- Audit log is append-only even for admin — tamper-proof
DENY UPDATE, DELETE ON dbo.audit_log TO admin_user;

GRANT EXECUTE ON dbo.fn_user_id         TO admin_user;
GRANT EXECUTE ON dbo.fn_is_admin        TO admin_user;
GRANT EXECUTE ON dbo.fn_clearance_check TO admin_user;
GO


-- =====================================================
-- BLOCK 9: INDEXES
--
-- SQL Server index syntax is nearly identical to the
-- original PostgreSQL syntax.  Partitioned tables require
-- ON <partition_scheme>(column) on non-clustered indexes
-- that should be partition-aligned.
-- =====================================================

-- -----------------------------------------------
-- Telemetry: user + node composite
-- -----------------------------------------------
CREATE INDEX idx_cpu_user_node
    ON dbo.cpu (user_id, node_id)
    ON ps_cpu_daily(recorded_at);

CREATE INDEX idx_disk_user_node
    ON dbo.disk (user_id, node_id)
    ON ps_disk_daily(recorded_at);

CREATE INDEX idx_ram_user_node
    ON dbo.ram (user_id, node_id)
    ON ps_ram_daily(recorded_at);

CREATE INDEX idx_thermal_user_node
    ON dbo.thermal (user_id, node_id)
    ON ps_thermal_daily(recorded_at);

-- -----------------------------------------------
-- Telemetry: node-only
-- -----------------------------------------------
CREATE INDEX idx_cpu_node
    ON dbo.cpu (node_id)
    ON ps_cpu_daily(recorded_at);

CREATE INDEX idx_disk_node
    ON dbo.disk (node_id)
    ON ps_disk_daily(recorded_at);

CREATE INDEX idx_ram_node
    ON dbo.ram (node_id)
    ON ps_ram_daily(recorded_at);

CREATE INDEX idx_thermal_node
    ON dbo.thermal (node_id)
    ON ps_thermal_daily(recorded_at);

-- -----------------------------------------------
-- Telemetry: node + timestamp (DESC)
-- -----------------------------------------------
CREATE INDEX idx_cpu_recorded_at
    ON dbo.cpu (node_id, recorded_at DESC)
    ON ps_cpu_daily(recorded_at);

CREATE INDEX idx_disk_recorded_at
    ON dbo.disk (node_id, recorded_at DESC)
    ON ps_disk_daily(recorded_at);

CREATE INDEX idx_ram_recorded_at
    ON dbo.ram (node_id, recorded_at DESC)
    ON ps_ram_daily(recorded_at);

CREATE INDEX idx_thermal_recorded_at
    ON dbo.thermal (node_id, recorded_at DESC)
    ON ps_thermal_daily(recorded_at);

-- -----------------------------------------------
-- users
-- -----------------------------------------------
CREATE INDEX idx_users_locked
    ON dbo.users (account_locked, failed_login_count);

CREATE INDEX idx_users_provider
    ON dbo.users (auth_provider, auth_provider_id);

-- -----------------------------------------------
-- audit_log
-- -----------------------------------------------
CREATE INDEX idx_audit_user_time
    ON dbo.audit_log (user_id, logged_at);

CREATE INDEX idx_audit_action_time
    ON dbo.audit_log (action_type, logged_at);

CREATE INDEX idx_audit_result
    ON dbo.audit_log (result, logged_at);

-- -----------------------------------------------
-- sessions
-- -----------------------------------------------
CREATE INDEX idx_sessions_user
    ON dbo.sessions (user_id, expires_at);

CREATE INDEX idx_sessions_token
    ON dbo.sessions (session_token_hash);

CREATE INDEX idx_sessions_active
    ON dbo.sessions (revoked, expires_at);

-- -----------------------------------------------
-- mfa_config
-- -----------------------------------------------
CREATE INDEX idx_mfa_user
    ON dbo.mfa_config (user_id, is_active);

-- -----------------------------------------------
-- password_reset
-- -----------------------------------------------
CREATE INDEX idx_reset_user
    ON dbo.password_reset (user_id, expires_at);

CREATE INDEX idx_reset_token
    ON dbo.password_reset (token_hash);

-- -----------------------------------------------
-- vms
-- -----------------------------------------------
CREATE INDEX idx_vms_node_time
    ON dbo.vms (node_id, recorded_at DESC);

CREATE INDEX idx_vms_status
    ON dbo.vms (status, recorded_at DESC);

CREATE INDEX idx_vms_user_node
    ON dbo.vms (user_id, node_id);
GO


-- =====================================================
-- BLOCK 10: SQL AGENT MAINTENANCE JOB
--
-- Replaces pg_cron + pg_partman run_maintenance().
-- Runs daily at midnight UTC.
-- Job steps:
--   Step 1 — Add tomorrow's partition boundary (SPLIT)
--   Step 2 — Drop partitions older than 7 days (MERGE)
--
-- SPLIT adds a new right boundary at the start of the
-- day 8 days from now, creating a fresh empty partition.
-- MERGE collapses the oldest boundary into the catch-all
-- leftmost partition, discarding old data.
--
-- NOTE: The job is created disabled (enabled = 0) so
-- you can review and enable it manually after deployment.
-- Change @server_name to match your SQL Server instance.
-- =====================================================

USE msdb;
GO

IF NOT EXISTS (
    SELECT job_id FROM msdb.dbo.sysjobs WHERE name = N'Telemetry_Partition_Maintenance'
)
BEGIN
    EXEC sp_add_job
        @job_name       = N'Telemetry_Partition_Maintenance',
        @enabled        = 0,          -- enable manually after review
        @description    = N'Daily rolling partition split (add future) and merge (drop old) for telemetry tables.',
        @category_name  = N'Database Maintenance';

    -- Step 1: Add next boundary (SPLIT) for all four partition functions
    EXEC sp_add_jobstep
        @job_name       = N'Telemetry_Partition_Maintenance',
        @step_name      = N'Split - Add Future Partition',
        @subsystem      = N'TSQL',
        @database_name  = N'TelemetryDB',
        @command        = N'
DECLARE @new_boundary DATETIME2 = CAST(DATEADD(DAY, 8, CAST(GETUTCDATE() AS DATE)) AS DATETIME2);

-- Ensure FG_Telemetry has a next-used filegroup allocated
ALTER PARTITION SCHEME ps_cpu_daily     NEXT USED FG_Telemetry;
ALTER PARTITION SCHEME ps_disk_daily    NEXT USED FG_Telemetry;
ALTER PARTITION SCHEME ps_ram_daily     NEXT USED FG_Telemetry;
ALTER PARTITION SCHEME ps_thermal_daily NEXT USED FG_Telemetry;

-- Split each partition function to add the new boundary
ALTER PARTITION FUNCTION pf_cpu_daily()     SPLIT RANGE (@new_boundary);
ALTER PARTITION FUNCTION pf_disk_daily()    SPLIT RANGE (@new_boundary);
ALTER PARTITION FUNCTION pf_ram_daily()     SPLIT RANGE (@new_boundary);
ALTER PARTITION FUNCTION pf_thermal_daily() SPLIT RANGE (@new_boundary);
';

    -- Step 2: Drop old boundary (MERGE) for partitions older than 7 days
    EXEC sp_add_jobstep
        @job_name       = N'Telemetry_Partition_Maintenance',
        @step_name      = N'Merge - Remove Expired Partition',
        @subsystem      = N'TSQL',
        @database_name  = N'TelemetryDB',
        @command        = N'
DECLARE @old_boundary DATETIME2 = CAST(DATEADD(DAY, -7, CAST(GETUTCDATE() AS DATE)) AS DATETIME2);

-- Merging a boundary deletes the partition and its data
ALTER PARTITION FUNCTION pf_cpu_daily()     MERGE RANGE (@old_boundary);
ALTER PARTITION FUNCTION pf_disk_daily()    MERGE RANGE (@old_boundary);
ALTER PARTITION FUNCTION pf_ram_daily()     MERGE RANGE (@old_boundary);
ALTER PARTITION FUNCTION pf_thermal_daily() MERGE RANGE (@old_boundary);
';

    -- Schedule: daily at 00:00 UTC
    EXEC sp_add_schedule
        @schedule_name      = N'Daily_Midnight_UTC',
        @freq_type          = 4,       -- daily
        @freq_interval      = 1,
        @active_start_time  = 000000;  -- 00:00:00

    EXEC sp_attach_schedule
        @job_name       = N'Telemetry_Partition_Maintenance',
        @schedule_name  = N'Daily_Midnight_UTC';

    -- Attach to the local server
    EXEC sp_add_jobserver
        @job_name   = N'Telemetry_Partition_Maintenance',
        @server_name = N'(LOCAL)';
END
GO

USE TelemetryDB;
GO

-- =====================================================
-- END OF SCHEMA
-- =====================================================
