#GetTelemetry will be used from frontend to retrieve data in the SQL database.
from django.http import JsonResponse

def home(request):
    return JsonResponse({"cpu":50,"ram":60})

def test(request, table_id):
    return JsonResponse({"cpu":table_id})