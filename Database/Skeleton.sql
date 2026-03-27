CREATE TABLE CPU (
	CPU_percent INT,
	CPU_core_percent INT,
	CPU_frequency FLOAT,
	timestamp TIMESTAMP
);
CREATE TABLE RAM (
	RAM_used FLOAT,
	RAM_total FLOAT,
	RAM_percent INT,
	timestamp TIMESTAMP
);
CREATE TABLE disk (
	disk_used FLOAT,
	disk_total FLOAT,
	disk_percent INT,
	read_bytes FLOAT,
	write_bytes FLOAT,
	timestamp TIMESTAMP
);
CREATE TABLE thermal (
	CPU_temp FLOAT,
	system_temp FLOAT,
	timestamp TIMESTAMP
);
CREATE TABLE user_data (
	user_name VARCHAR(255),
	user_password VARCHAR(255),
	token_key VARCHAR(255)
);


how it looks in supabase
	
CREATE TABLE public.cpu (
  cpu_percent double precision NOT NULL,
  cpu_core_percent integer NOT NULL,
  cpu_frequency double precision NOT NULL,
  timestamp timestamp without time zone DEFAULT now(),
  user_id uuid NOT NULL,
  row_id integer NOT NULL DEFAULT nextval('cpu_row_id_seq'::regclass),
  CONSTRAINT cpu_pkey PRIMARY KEY (row_id)
);
CREATE TABLE public.disk (
  disk_used double precision,
  disk_total double precision,
  disk_percent integer NOT NULL,
  read_bytes double precision,
  write_bytes double precision,
  timestamp timestamp without time zone DEFAULT now(),
  user_id uuid,
  row_id integer NOT NULL DEFAULT nextval('disk_row_id_seq'::regclass),
  CONSTRAINT disk_pkey PRIMARY KEY (row_id)
);
CREATE TABLE public.ram (
  ram_used double precision NOT NULL,
  ram_total double precision NOT NULL,
  ram_percent integer NOT NULL,
  timestamp timestamp without time zone DEFAULT now(),
  user_id uuid NOT NULL,
  row_id integer NOT NULL DEFAULT nextval('ram_row_id_seq'::regclass),
  CONSTRAINT ram_pkey PRIMARY KEY (row_id)
);
CREATE TABLE public.thermal (
  cpu_temp double precision NOT NULL,
  system_temp double precision NOT NULL,
  timestamp timestamp without time zone DEFAULT now(),
  user_id uuid NOT NULL,
  row_id integer NOT NULL DEFAULT nextval('thermal_row_id_seq'::regclass),
  CONSTRAINT thermal_pkey PRIMARY KEY (row_id)
);
CREATE TABLE public.user_data (
  row_id integer NOT NULL DEFAULT nextval('user_data_user_id_seq'::regclass),
  user_id uuid NOT NULL,
  CONSTRAINT user_data_pkey PRIMARY KEY (row_id)
);
