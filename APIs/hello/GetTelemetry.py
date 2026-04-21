#GetTelemetry will be used from frontend to retrieve data in the SQL database.
from django.http import JsonResponse
import json, pyodbc

def home(request):

    if request.method != "GET":
        return JsonResponse({"error":"GET required"}, status=405)

    import pyodbc

    conn = pyodbc.connect(
        'DRIVER={ODBC Driver 17 for SQL Server};'
        'SERVER=192.168.30.134,1433;'
        'DATABASE=Telemetry data;'
        'UID=sa;'
        'PWD=Password1;'
    )
    cur=conn.cursor()
    data = []
    #cpu
    cur.execute("SELECT TOP 10 cpu_percent, cpu_core_per, cpu_frequency FROM dbo.cpu")
    
    columns = [column[0] for column in cur.description]

    rows = [
        dict(zip(columns, row))
        for row in cur.fetchall()
    ]
    data.append(rows)
    
    # #ram
    # cur.execute("SELECT ram_used, ram_total, ram_percent FROM dbo.ram LIMIT %s", (number,) )
    # for row in cur:
    #     rows = cur.fetchone()
    #     data.update(rows)

    # # #disk
    # cur.execute("SELECT disk_used, disk_total, disk_percent, read_bytes, wite_bytes FROM dbo.disk LIMIT %s", (number,) )
    # for row in cur:
    #     rows = cur.fetchone()
    #     data.update(rows)

    # # #thermal
    # cur.execute("SELECT cpu_temp, system_temp FROM dbo.thermal LIMIT %s", (number,) )
    # for row in cur:
    #     rows = cur.fetchone()
    #     data.update(rows)

    #end of value insertion
    cur.close()
    conn.close()

    data = json.dumps(data, indent=4)
    with open('data.json', 'w') as f:
        f.write(data)
    return JsonResponse({"Action":"Completed"})

def search(request, table_id):
    return JsonResponse({"cpu":table_id})