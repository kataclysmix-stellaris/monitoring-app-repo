CREATE TABLE CPU (
	CPU_percent INT,
	CPU_core_percent INT,
	CPU_frequency FLOAT
);
CREATE TABLE RAM (
	RAM_used FLOAT,
	RAM_total FLOAT,
	RAM_percent INT
);
CREATE TABLE disk (
	disk_used FLOAT,
	disk_total FLOAT,
	disk_percent INT,
	read_bytes FLOAT,
	write_bytes FLOAT
);
CREATE TABLE thermal (
	CPU_temp FLOAT,
	system_temp FLOAT
);
CREATE TABLE user_data (
	user_name VARCHAR(255),
	user_password VARCHAR(255),
	token_key VARCHAR(255)
);