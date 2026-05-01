#GetTelemetry will be used from frontend to retrieve data in the SQL database.
from django.http import JsonResponse
import json, pyodbc 
from psycopg2.extras import Json
import psycopg2

def home(request):

    if request.method != "GET":
        return JsonResponse({"error":"GET required"}, status=405)

    conn = psycopg2.connect(
             host="192.168.30.134",
             port="5432",
             database="telemetry",
             user="postgres",
             password="abcd"
    )
    cur=conn.cursor()
    data = []

    #cpu
    cur.execute("SELECT cpu_percent, cpu_per_core, cpu_frequency FROM cpu LIMIT 10")
    
    columns = [column[0] for column in cur.description]

    rows = [
        dict(zip(columns, row))
        for row in cur.fetchall()
    ]
    data.append(rows)
    
    #ram
    cur.execute("SELECT ram_used, ram_total, ram_per FROM ram LIMIT 10")
    
    columns = [column[0] for column in cur.description]

    rows = [
        dict(zip(columns, row))
        for row in cur.fetchall()
    ]
    data.append(rows)
    
    #disk
    cur.execute("SELECT disk_used, disk_total, disk_percent, read_bytes, write_bytes FROM disk LIMIT 10")
    
    columns = [column[0] for column in cur.description]

    rows = [
        dict(zip(columns, row))
        for row in cur.fetchall()
    ]
    data.append(rows)
    
    #temperatue
    cur.execute("SELECT cpu_temp, system_temp FROM thermal LIMIT 10")
    
    columns = [column[0] for column in cur.description]

    rows = [
        dict(zip(columns, row))
        for row in cur.fetchall()
    ]
    data.append(rows)

    #end of value insertion
    cur.close()
    conn.close()

    data = json.dumps(data, indent=4)
    # print(data)
    with open('data.json', 'w') as f:
        f.write(data)
    return JsonResponse(data, safe=False)

def search(request, table_id):

    if request.method != "GET":
        return JsonResponse({"error":"GET required"}, status=405)
    
    conn = psycopg2.connect(
             host="192.168.30.134",
             port="5432",
             database="telemetry",
             user="postgres",
             password="abcd"
    )
    
    cur=conn.cursor()
    data = []

    match table_id:
        case "cpu":
            cur.execute("SELECT cpu_percent, cpu_per_core, cpu_frequency FROM cpu LIMIT 10")
    
            columns = [column[0] for column in cur.description]

            rows = [
                dict(zip(columns, row))
                for row in cur.fetchall()
            ]
            data.append(rows)
        case "ram":
            cur.execute("SELECT ram_used, ram_total, ram_per FROM ram LIMIT 10")
    
            columns = [column[0] for column in cur.description]

            rows = [
                dict(zip(columns, row))
                for row in cur.fetchall()
            ]
            data.append(rows)
        case "disk":
            cur.execute("SELECT disk_used, disk_total, disk_percent, read_bytes, write_bytes FROM disk LIMIT 10")
    
            columns = [column[0] for column in cur.description]

            rows = [
                dict(zip(columns, row))
                for row in cur.fetchall()
            ]
            data.append(rows)
        case "temperature":
            cur.execute("SELECT cpu_temp, system_temp FROM thermal LIMIT 10")
    
            columns = [column[0] for column in cur.description]

            rows = [
                dict(zip(columns, row))
                for row in cur.fetchall()
            ]
            data.append(rows)
            
    return JsonResponse(data, safe=False)
