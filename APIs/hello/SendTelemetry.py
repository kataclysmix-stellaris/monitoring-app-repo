#SendTelemetry will be the POST api url the agent uses to send data formatted in data_string.json
from django.http import JsonResponse, HttpResponse
import json, pyodbc, datetime, django_cryptography
from django.views.decorators.csrf import csrf_exempt
from psycopg2.extras import Json
import psycopg2

#csrf_exempt temporary for testing
@csrf_exempt
def home(request):
    #prevents GET from raising an error/breaking the page
    if request.method != "POST":
        return JsonResponse({"error":"POST required"}, status=405)
    
    #retrieves file sent
    file = request.FILES.get("file")
    if not file:
        return JsonResponse({"error":"file not found"}, status=400)
    try:
        jsondata = json.load(file)
    except Exception:
        return JsonResponse({"error":"invalid JSON"}, status=400)
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
    conn = psycopg2.connect(
                host="192.168.30.134",
                port="5432",
                database="Telemetry",
                user="carocha",
                password="285827619;"

            )
    cur=conn.cursor()

    cur.execute(
    "INSERT INTO public.cpu (cpu_percent, cpu_core_per, cpu_frequency) VALUES (%s, %s, %s)",
    (
        jsondata["cpu_percent"],
        Json(jsondata["cpu_per_core"]),
        Json(jsondata["cpu_freq"]),
    )
)


    cur.execute(
    "INSERT INTO public.ram (ram_used, ram_total, ram_percent) VALUES (%s, %s, %s)",
    (
        jsondata["ram_used"],
        jsondata["ram_total"],
        jsondata["ram_percent"],
    )
)


    cur.execute(
    "INSERT INTO public.disk (disk_total, disk_used, disk_percent, read_bytes, write_bytes) VALUES (%s, %s, %s, %s, %s)",
    (
        jsondata["disk_total"],
        jsondata["disk_used"],
        jsondata["disk_percent"],
        jsondata["read_bytes"],
        jsondata["write_bytes"],
    )
)
    cur.execute(
    "INSERT INTO public.thermal (cpu_temp, system_temp) VALUES (%s, %s)",
    (
        jsondata["cpu_temp"],
        jsondata["system_temp"],
    )
)

    conn.commit()

    #end of value insertion
    cur.close()
    conn.close()
    
    return JsonResponse({"Task":"Completed"})
