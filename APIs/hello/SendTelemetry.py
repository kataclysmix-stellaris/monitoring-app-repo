#SendTelemetry will be the POST api url the agent uses to send data formatted in data_string.json
import re

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

    # Call validation function to check if data is valid before inserting into DB   
    validation_response = validate(jsondata)
    if isinstance(validation_response, JsonResponse):
        return validation_response
    normalized_data = validation_response

    # Call function to insert data into DB
    db_response = insert_into_db(normalized_data)
    if isinstance(db_response, JsonResponse):
        return db_response
    
    return JsonResponse({"message":"Data received and processed successfully"})
    #rules checks if values are valid before sending -- rules for other datatypes need added

def normalize_value(x):
    if x is None:
        return None

    if isinstance(x, (int, float)):
        return x

    if isinstance(x, str):
        x = x.strip().lower()

        if x in ['none', 'null', 'n/a', 'na', '']:
            return None

        match = re.search(r"-?\d+(\.\d+)?", x)
        if match:
            return float(match.group())

    return x


def validate(jsondata):
    try:
        rules = {
            "cpu_percent": lambda x: x is not None and 0 <= x <= 100,
            "cpu_temp": lambda x: x is None or 0 <= x <= 100,
            "cpu_per_core": lambda x: isinstance(x, list) and all(isinstance(i, (int, float)) and 0 <= i <= 100 for i in x if i is not None),
            "cpu_freq": lambda x: isinstance(x, dict) and all(isinstance(v, (int, float)) and v >= 0 for v in x.values()),

            "ram_used": lambda x: x is not None and x >= 0,
            "ram_total": lambda x: x is not None and x >= 0,
            "ram_percent": lambda x: x is not None and 0 <= x <= 100,
            "swap_percent": lambda x: x is not None and 0 <= x <= 100,

            "disk_total": lambda x: x is not None and x >= 0,
            "disk_used": lambda x: x is not None and x >= 0,
            "disk_percent": lambda x: x is not None and 0 <= x <= 100,

            "system_temp": lambda x: x is None or 0 <= x <= 100,

            "read_bytes": lambda x: x is not None and x >= 0,
            "write_bytes": lambda x: x is None or x >= 0,

        }

        # Normalize all values first
        normalized = {
            k: [normalize_value(i) for i in v] if isinstance(v, list)
            else normalize_value(v)
            for k, v in jsondata.items()
        }

        missing_keys = [key for key in rules if key not in normalized]
        if missing_keys:
            return JsonResponse(
                {"error": "missing keys", "missing": missing_keys},
                status=400
            )

        invalid_keys = [
            key for key, rule in rules.items()
            if not rule(normalized.get(key))
        ]

        if invalid_keys:
            return JsonResponse(
                {"error": "invalid keys", "invalid": invalid_keys},
                status=400
            )
        
        unexpected_keys = [key for key in normalized if key not in rules]
        if unexpected_keys:
            return JsonResponse(
                {"error": "unexpected keys", "unexpected": unexpected_keys},
                status=400
            )
        
        return normalized
    
    except Exception as e:
        print(f"Error processing data: {e}")
        return JsonResponse({"error": "error processing data"}, status=400)

        
    
    
    #if rules are all true, separate key and value, use key to determine where in the database to place it, insert value into db.
    
    #connect to DB, insert
    #EDIT DBNAME, USER, AND PASSWORD FOR DB
def insert_into_db(jsondata):
    try:
        conn = psycopg2.connect(
                host="192.168.30.134",
                port="5432",
                database="Telemetry",
                user="carocha",
                password="285827619"

            )
        cur=conn.cursor()

        cur.execute(
    "INSERT INTO public.cpu (cpu_percent, cpu_per_core, cpu_frequency) VALUES (%s, %s, %s)",
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
    except Exception as e:
        conn.rollback()
        return JsonResponse({"error": "database error", "details": str(e)}, status=500)
    

    #end of value insertion
    finally:
        if 'cur' in locals():
            cur.close()
        if 'conn' in locals():
            conn.close()

   
    return JsonResponse({"Task":"Completed"})
   
