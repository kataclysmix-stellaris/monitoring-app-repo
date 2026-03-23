#SendTelemetry will be the POST api url the agent uses to send data formatted in data_string.json
from django.http import JsonResponse

def home(request):
    return JsonResponse({"cpu":50,"ram":60})
