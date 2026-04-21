#SendTelemetry will be the POST api url the agent uses to send data formatted in data_string.json
from django.http import JsonResponse, HttpResponse
import json, pyodbc, datetime, django_cryptography
from django.views.decorators.csrf import csrf_exempt
from psycopg2.extras import Json

#csrf_exempt temporary for testing
@csrf_exempt
def home(request):
    #prevents GET from raising an error/breaking the page
    if request.method != "POST":
        return JsonResponse({"error":"POST required"}, status=405)
    
    #retrieves file sent
    file = request.FILES.get("file")
    jsondata = json.load(file)
    #rules checks if values are valid before sending -- rules for other datatypes need added
    try:
        rules = {
            #cpu
            "cpu_percent": lambda x: 0 <= x <= 100,
            "cpu_temp": lambda x: x == None or 0 <= x <= 100,
            #ram
            "ram_used": lambda x: 0 <= x,
            "ram_total": lambda x: 0 <= x,
            "ram_percent": lambda x: 0 <= x <= 100,
            "swap_percent": lambda x: 0 <= x <= 100,
            #disk
            "disk_total": lambda x: 0 <= x,
            "disk_used" : lambda x: 0 <= x,
            "disk_percent": lambda x: 0 <= x <= 100,
            #system/other
            "system_temp": lambda x: x == None or 0 <= x <= 100,
            "read_bytes": lambda x: 0 <= x,
            "write_bytes": lambda x: x == None or 0 <= x,
        }    

        if all(rules[key](jsondata.get(key)) for key in rules):
            #return will need to update the db once it is added
            # return JsonResponse(jsondata, safe=False)
            pass
        else:
            print("data impossible or incorrectly formatted")
            return JsonResponse({"error":"data incorrect"}, status=400)
    
    except:
        print("data impossible or incorrectly formatted 2")
        return JsonResponse({"error":"data incorrect"}, status=400)

    #if rules are all true, separate key and value, use key to determine where in the database to place it, insert value into db.
    
    #connect to DB, insert
    #EDIT DBNAME, USER, AND PASSWORD FOR DB
    
    conn = pyodbc.connect(
        'DRIVER={ODBC Driver 17 for SQL Server};'
        'SERVER=192.168.30.134,1433;'
        'DATABASE=Telemetry data;'
        'UID=sa;'
        'PWD=Password1;'
    )
    cur=conn.cursor()

    cur.execute("INSERT INTO dbo.cpu (cpu_percent, cpu_core_per, cpu_frequency) VALUES (?, ?, ?)", 
                ( json.dumps(jsondata["cpu_percent"]),
                  json.dumps(jsondata["cpu_per_core"]),
                  json.dumps(jsondata["cpu_freq"])))
    
    # cur.execute("INSERT INTO dbo.ram (ram_used, ram_total, ram_percent) VALUES (%s, %s, %s)", 
    #             (Json(jsondata["ram_used"]), 
    #              Json(jsondata["ram_total"]), 
    #              Json(jsondata["ram_percent"])))
    
    # cur.execute("INSERT INTO dbo.disk (disk_total, disk_used, disk_percent, read_bytes, write_bytes) VALUES (%s, %s, %s)", 
    #             (Json(jsondata["disk_total"]), 
    #              Json(jsondata["disk_used"]), 
    #              Json(jsondata["disk_percent"]),
    #              Json(jsondata["read_bytes"]),
    #              Json(jsondata["write_bytes"])))
    
    # cur.execute("INSERT INTO dbo.thermal (cpu_temp, system_temp) VALUES (%s, %s, %s)", 
    #             (Json(jsondata["cpu_temp"]), 
    #              Json(jsondata["system_temp"])))
    
    conn.commit()

    #end of value insertion
    cur.close()
    conn.close()
    
    return JsonResponse({"Task":"Completed"})