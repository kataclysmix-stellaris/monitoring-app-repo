#GetTelemetry will be used from frontend to retrieve data in the SQL database.
from django.http import JsonResponse
import psycopg2
import json
from psycopg2.extras import RealDictCursor

def home(request):
    conn = psycopg2.connect("dbname=postgres user=postgres password=password")
    cur=conn.cursor(cursor_factory=RealDictCursor)
    data = {}

    #cpu
    cur.execute("SELECT cpu_percent, cpu_core_per, cpu_frequency FROM dbo.cpu LIMIT 10")
    for row in cur:
        rows = cur.fetchone()
        data.update(rows)
    
    #ram
    cur.execute("SELECT ram_used, ram_total, ram_percent FROM dbo.ram LIMIT 10")
    for row in cur:
        rows = cur.fetchone()
        data.update(rows)

    # #disk
    cur.execute("SELECT disk_used, disk_total, disk_percent, read_bytes, wite_bytes FROM dbo.disk LIMIT 10")
    for row in cur:
        rows = cur.fetchone()
        data.update(rows)

    # #thermal
    cur.execute("SELECT cpu_temp, system_temp FROM dbo.thermal LIMIT 10")
    for row in cur:
        rows = cur.fetchone()
        data.update(rows)

    #end of value insertion
    cur.close()
    conn.close()

    data = json.dumps(data, indent=4)
    with open('data.json', 'w') as f:
        f.write(data)
    return JsonResponse({"Action":"Completed"})

def search(request, table_id):
    return JsonResponse({"cpu":table_id})