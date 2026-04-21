import pyodbc

conn = pyodbc.connect(
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=192.168.30.134,1433;'
    'DATABASE=Telemetry data;'
    'UID=sa;'
    'PWD=Password1;'
)

# Create a cursor and execute a query
cursor = conn.cursor()
cursor.execute("SELECT * FROM dbo.cpu")

# Fetch and print results
for row in cursor.fetchall():
    print(row)

# Always close connections
conn.close()
