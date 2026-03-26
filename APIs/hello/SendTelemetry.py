#SendTelemetry will be the POST api url the agent uses to send data formatted in data_string.json
from django.http import JsonResponse, HttpResponse
import json
from django.views.decorators.csrf import csrf_exempt
from datetime import datetime

#csrf_exempt temporary for testing
@csrf_exempt
def home(request):
    #prevents GET from raising an error/breaking the page
    if request.method != "POST":
        return JsonResponse({"error":"POST required"}, status=405)
    
    #retrieves file sent
    file = request.FILES.get("file")
    jsondata = json.loads(file.read())

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
            "date_log": lambda x: isinstance(datetime.strptime(x, "%m/%d/%y"), datetime),
            "time_log": lambda x: isinstance(datetime.strptime(x, "%I:%M %p"), datetime),
        }    

        if all(rules[key](jsondata.get(key)) for key in rules):
            #should print data_string.json -- testing purposes
            print(jsondata)
            #return will need to update the db once it is added
            return JsonResponse(jsondata, safe=False)
        else:
            print("data impossible or incorrectly formatted")
            return JsonResponse({"error":"data incorrect"}, status=400)
    
    except:
        print("data impossible or incorrectly formatted")
        return JsonResponse({"error":"data incorrect"}, status=400)

    #if rules are all true, send file to database
