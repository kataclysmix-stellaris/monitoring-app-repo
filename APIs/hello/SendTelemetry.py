#SendTelemetry will be the POST api url the agent uses to send data formatted in data_string.json
from django.http import JsonResponse, HttpResponse
import json
from django.views.decorators.csrf import csrf_exempt
from datetime import datetime
import psycopg2
from psycopg2.extras import Json

#csrf_exempt temporary for testing
@csrf_exempt
def home(request):
    #prevents GET from raising an error/breaking the page
    print("test")
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
            "write_bytes": lambda x: 0 <= x,
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
    #CPU insert
    #sort data
    cpu_percent = jsondata["cpu_percent"]
    cpu_temp = jsondata["cpu_temp"]
    cpu_per_core = jsondata["cpu_per_core"]
    cpu_frequency = jsondata["cpu_freq"]
    #connect to DB, insert
    #EDIT DBNAME USER AND PASSWORD FOR DB
    conn = psycopg2.connect("dbname=postgres user=postgres password=password")
    cur=conn.cursor()
    cur.execute("INSERT INTO dbo.cpu (cpu_percent, cpu_core_per, cpu_frequency) VALUES (%s, %s, %s)", (cpu_percent, Json(cpu_per_core), Json(cpu_frequency)))
    cur.execute("SELECT * FROM dbo.cpu")
    rows = cur.fetchall()
    print(rows)
    conn.commit()
    cur.close()
    conn.close()
    return JsonResponse({"test":"test"})