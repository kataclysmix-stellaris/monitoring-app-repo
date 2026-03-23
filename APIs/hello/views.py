from django.shortcuts import render
from django.http import JsonResponse

def home(request):
    return JsonResponse({"cpu":40,"ram":60})
