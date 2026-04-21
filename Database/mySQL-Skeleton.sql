-- =====================================================
-- DATABASE + FILEGROUP
-- =====================================================
USE master;
GO

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'TelemetryDB')
    CREATE DATABASE TelemetryDB;
GO

USE TelemetryDB;
GO

IF NOT EXISTS (SELECT * FROM sys.filegroups WHERE name = 'FG_Telemetry')
BEGIN
    ALTER DATABASE TelemetryDB ADD FILEGROUP FG_Telemetry;

    ALTER DATABASE TelemetryDB ADD FILE (
        NAME = N'TelemetryData',
        FILENAME = N'C:\SQLData\TelemetryData.ndf',
        SIZE = 128MB,
        FILEGROWTH = 64MB
    ) TO FILEGROUP FG_Telemetry;
END
GO

-- =====================================================
-- ROLES
-- =====================================================
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name='admin_user')
    CREATE ROLE admin_user;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name='app_user')
    CREATE ROLE app_user;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name='auditor_user')
    CREATE ROLE auditor_user;
GO

-- =====================================================
-- USERS / NODES
-- =====================================================
CREATE TABLE dbo.users (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    email NVARCHAR(255) UNIQUE NOT NULL,
    role NVARCHAR(20) NOT NULL DEFAULT 'readonly'
        CHECK (role IN ('admin','analyst','operator','auditor','readonly')),
    clearance_level NVARCHAR(20) NOT NULL DEFAULT 'UNCLASSIFIED'
        CHECK (clearance_level IN ('UNCLASSIFIED','CUI','SECRET'))
);
GO

CREATE TABLE dbo.nodes (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    classification NVARCHAR(20) NOT NULL
        CHECK (classification IN ('UNCLASSIFIED','CUI','SECRET'))
);
GO

-- =====================================================
-- CPU
-- =====================================================
CREATE TABLE dbo.cpu (
    row_id INT IDENTITY(1,1),
    cpu_percent DECIMAL(5,2),
    cpu_core_per NVARCHAR(MAX),
    user_id UNIQUEIDENTIFIER,
    node_id UNIQUEIDENTIFIER,
    recorded_at DATETIME2 DEFAULT SYSUTCDATETIME(),

    PRIMARY KEY CLUSTERED (row_id, recorded_at),

    FOREIGN KEY (user_id) REFERENCES dbo.users(id),
    FOREIGN KEY (node_id) REFERENCES dbo.nodes(id),

    CHECK (ISJSON(cpu_core_per)=1)
);
GO

-- =====================================================
-- DISK
-- =====================================================
CREATE TABLE dbo.disk (
    row_id INT IDENTITY(1,1),
    disk_used DECIMAL(18,2),
    disk_total DECIMAL(18,2),
    disk_percent DECIMAL(5,2),
    user_id UNIQUEIDENTIFIER,
    node_id UNIQUEIDENTIFIER,
    recorded_at DATETIME2 DEFAULT SYSUTCDATETIME(),

    PRIMARY KEY CLUSTERED (row_id, recorded_at),

    FOREIGN KEY (user_id) REFERENCES dbo.users(id),
    FOREIGN KEY (node_id) REFERENCES dbo.nodes(id)
);
GO

-- =====================================================
-- RAM
-- =====================================================
CREATE TABLE dbo.ram (
    row_id INT IDENTITY(1,1),
    ram_used DECIMAL(18,2),
    ram_total DECIMAL(18,2),
    ram_per DECIMAL(5,2),
    user_id UNIQUEIDENTIFIER,
    node_id UNIQUEIDENTIFIER,
    recorded_at DATETIME2 DEFAULT SYSUTCDATETIME(),

    PRIMARY KEY CLUSTERED (row_id, recorded_at),

    FOREIGN KEY (user_id) REFERENCES dbo.users(id),
    FOREIGN KEY (node_id) REFERENCES dbo.nodes(id)
);
GO

-- =====================================================
-- THERMAL
-- =====================================================
CREATE TABLE dbo.thermal (
    row_id INT IDENTITY(1,1),
    cpu_temp DECIMAL(5,2),
    system_temp DECIMAL(5,2),
    user_id UNIQUEIDENTIFIER,
    node_id UNIQUEIDENTIFIER,
    recorded_at DATETIME2 DEFAULT SYSUTCDATETIME(),

    PRIMARY KEY CLUSTERED (row_id, recorded_at),

    FOREIGN KEY (user_id) REFERENCES dbo.users(id),
    FOREIGN KEY (node_id) REFERENCES dbo.nodes(id)
);
GO

-- =====================================================
-- VMS (NOT PARTITIONED)
-- =====================================================
CREATE TABLE dbo.vms (
    row_id INT IDENTITY(1,1) PRIMARY KEY,
    node_id UNIQUEIDENTIFIER,
    user_id UNIQUEIDENTIFIER,
    recorded_at DATETIME2 DEFAULT SYSUTCDATETIME(),
    vm_name NVARCHAR(255),
    status NVARCHAR(50)
);
GO

-- =====================================================
-- RLS (GLOBAL)
-- =====================================================
CREATE FUNCTION dbo.fn_rls_access(
    @user_id UNIQUEIDENTIFIER,
    @node_id UNIQUEIDENTIFIER
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1
    FROM dbo.users u
    JOIN dbo.nodes n ON n.id = @node_id
    WHERE u.id = CAST(SESSION_CONTEXT(N'app_user_id') AS UNIQUEIDENTIFIER)
      AND (@user_id = u.id OR u.role='admin')
      AND (
        u.clearance_level='SECRET'
        OR (u.clearance_level='CUI' AND n.classification IN ('CUI','UNCLASSIFIED'))
        OR (u.clearance_level='UNCLASSIFIED' AND n.classification='UNCLASSIFIED')
      )
);
GO

CREATE SECURITY POLICY sp_all_rls
ADD FILTER PREDICATE dbo.fn_rls_access(user_id,node_id) ON dbo.cpu,
ADD BLOCK  PREDICATE dbo.fn_rls_access(user_id,node_id) ON dbo.cpu,

ADD FILTER PREDICATE dbo.fn_rls_access(user_id,node_id) ON dbo.disk,
ADD BLOCK  PREDICATE dbo.fn_rls_access(user_id,node_id) ON dbo.disk,

ADD FILTER PREDICATE dbo.fn_rls_access(user_id,node_id) ON dbo.ram,
ADD BLOCK  PREDICATE dbo.fn_rls_access(user_id,node_id) ON dbo.ram,

ADD FILTER PREDICATE dbo.fn_rls_access(user_id,node_id) ON dbo.thermal,
ADD BLOCK  PREDICATE dbo.fn_rls_access(user_id,node_id) ON dbo.thermal,

ADD FILTER PREDICATE dbo.fn_rls_access(user_id,node_id) ON dbo.vms,
ADD BLOCK  PREDICATE dbo.fn_rls_access(user_id,node_id) ON dbo.vms
WITH (STATE = ON);
GO

-- =====================================================
-- SECURITY HARDENING
-- =====================================================
DENY UPDATE ON dbo.users(role) TO app_user;
GO

-- =====================================================
-- COMPRESSION
-- =====================================================
ALTER INDEX ALL ON dbo.cpu REBUILD WITH (DATA_COMPRESSION = PAGE);
ALTER INDEX ALL ON dbo.disk REBUILD WITH (DATA_COMPRESSION = PAGE);
ALTER INDEX ALL ON dbo.ram REBUILD WITH (DATA_COMPRESSION = PAGE);
ALTER INDEX ALL ON dbo.thermal REBUILD WITH (DATA_COMPRESSION = PAGE);
GO