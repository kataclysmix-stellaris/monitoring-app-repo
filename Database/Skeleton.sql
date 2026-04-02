-- =========================
-- SCHEMA
-- =========================
-- We used ChatGPT to convert all of the Supabase code to SQL Server code for a proper schema. Ensure that this works, especially in RLS policies.
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'public')
BEGIN
    EXEC('CREATE SCHEMA public');
END
GO

-- =========================
-- ROLES
-- =========================
CREATE ROLE admin_user;
CREATE ROLE app_user;
GO

-- =========================
-- USERS TABLE (AUTH CORE)
-- =========================
CREATE TABLE public.users (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    email NVARCHAR(255) NOT NULL UNIQUE,
    full_name NVARCHAR(255),
    role NVARCHAR(10) NOT NULL DEFAULT 'user' CHECK (role IN ('admin','user')),
    email_verified BIT NOT NULL DEFAULT 0
);
GO

-- =========================
-- NODES
-- =========================
CREATE TABLE public.nodes (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID()
);
GO

-- =========================
-- CPU
-- =========================
CREATE TABLE public.cpu (
    row_id INT IDENTITY(1,1) PRIMARY KEY,
    cpu_percent FLOAT NOT NULL,
    cpu_core_percent INT NOT NULL,
    cpu_frequency FLOAT NOT NULL,
    user_id UNIQUEIDENTIFIER,
    node_id UNIQUEIDENTIFIER,
    FOREIGN KEY (node_id) REFERENCES public.nodes(id)
);
GO

-- =========================
-- DISK
-- =========================
CREATE TABLE public.disk (
    row_id INT IDENTITY(1,1) PRIMARY KEY,
    disk_used FLOAT NOT NULL,
    disk_total FLOAT NOT NULL,
    disk_percent INT NOT NULL,
    read_bytes FLOAT NOT NULL,
    write_bytes FLOAT NOT NULL,
    user_id UNIQUEIDENTIFIER,
    node_id UNIQUEIDENTIFIER,
    FOREIGN KEY (node_id) REFERENCES public.nodes(id)
);
GO

-- =========================
-- RAM
-- =========================
CREATE TABLE public.ram (
    row_id INT IDENTITY(1,1) PRIMARY KEY,
    ram_used FLOAT NOT NULL,
    ram_total FLOAT NOT NULL,
    ram_percent INT NOT NULL,
    user_id UNIQUEIDENTIFIER,
    node_id UNIQUEIDENTIFIER,
    FOREIGN KEY (node_id) REFERENCES public.nodes(id)
);
GO

-- =========================
-- THERMAL
-- =========================
CREATE TABLE public.thermal (
    row_id INT IDENTITY(1,1) PRIMARY KEY,
    cpu_temp FLOAT NOT NULL,
    system_temp FLOAT NOT NULL,
    user_id UNIQUEIDENTIFIER,
    node_id UNIQUEIDENTIFIER,
    FOREIGN KEY (node_id) REFERENCES public.nodes(id)
);
GO

-- =========================
-- LOGS
-- =========================
CREATE TABLE public.logs (
    date_log DATE DEFAULT CAST(GETDATE() AS DATE),
    time_log TIME DEFAULT CAST(GETDATE() AS TIME)
);
GO

-- =========================
-- 🔐 AUTH FLOW FUNCTIONS
-- =========================

-- Get current user ID (set by backend)
CREATE FUNCTION public.fn_user_id()
RETURNS UNIQUEIDENTIFIER
AS
BEGIN
    RETURN CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER);
END;
GO

-- Check if admin
CREATE FUNCTION public.fn_is_admin()
RETURNS BIT
AS
BEGIN
    DECLARE @result BIT = 0;

    IF EXISTS (
        SELECT 1 FROM public.users
        WHERE id = CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER)
        AND role = 'admin'
    )
        SET @result = 1;

    RETURN @result;
END;
GO

-- =========================
-- 🔐 RLS PREDICATE
-- =========================
CREATE FUNCTION public.fn_rls_telemetry(@user_id UNIQUEIDENTIFIER)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS result
    WHERE 
        @user_id = CAST(SESSION_CONTEXT(N'user_id') AS UNIQUEIDENTIFIER)
        OR dbo.fn_is_admin() = 1
);
GO

-- =========================
-- 🔐 APPLY RLS (Telemetry Only)
-- =========================
CREATE SECURITY POLICY cpu_policy
ADD FILTER PREDICATE public.fn_rls_telemetry(user_id) ON public.cpu
WITH (STATE = ON);
GO

CREATE SECURITY POLICY disk_policy
ADD FILTER PREDICATE public.fn_rls_telemetry(user_id) ON public.disk
WITH (STATE = ON);
GO

CREATE SECURITY POLICY ram_policy
ADD FILTER PREDICATE public.fn_rls_telemetry(user_id) ON public.ram
WITH (STATE = ON);
GO

CREATE SECURITY POLICY thermal_policy
ADD FILTER PREDICATE public.fn_rls_telemetry(user_id) ON public.thermal
WITH (STATE = ON);
GO

-- =========================
-- ❌ BLOCK USERS TABLE ACCESS
-- =========================
DENY SELECT ON public.users TO app_user;
GO

-- =========================
-- 📈 PERFORMANCE INDEXES
-- =========================

-- Most common queries: user_id + node_id
CREATE INDEX idx_cpu_user_node ON public.cpu(user_id, node_id);
CREATE INDEX idx_disk_user_node ON public.disk(user_id, node_id);
CREATE INDEX idx_ram_user_node ON public.ram(user_id, node_id);
CREATE INDEX idx_thermal_user_node ON public.thermal(user_id, node_id);

-- Node-based queries (dashboards)
CREATE INDEX idx_cpu_node ON public.cpu(node_id);
CREATE INDEX idx_disk_node ON public.disk(node_id);
CREATE INDEX idx_ram_node ON public.ram(node_id);
CREATE INDEX idx_thermal_node ON public.thermal(node_id);

GO

-- =========================
-- 🔐 PERMISSIONS
-- =========================

-- App users: telemetry only
GRANT SELECT, INSERT ON public.cpu TO app_user;
GRANT SELECT, INSERT ON public.disk TO app_user;
GRANT SELECT, INSERT ON public.ram TO app_user;
GRANT SELECT, INSERT ON public.thermal TO app_user;

GRANT SELECT ON public.nodes TO app_user;
GRANT SELECT ON public.logs TO app_user;

-- Admins: full access
GRANT CONTROL ON SCHEMA::public TO admin_user;

GO

--Authentication flow for RLS policies to work in.
EXEC sp_set_session_context 
    @key = N'user_id', 
    @value = 'USER-UUID-HERE';
