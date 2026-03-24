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
