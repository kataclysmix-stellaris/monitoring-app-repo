import json
from django.contrib.auth.models import User
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.db import IntegrityError

@csrf_exempt
def register_user(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST required"}, status=405)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "Invalid JSON"}, status=400)

    username = data.get("username")
    password = data.get("password")

    if not username or not password:
        return JsonResponse({"error": "Username and password are required"}, status=400)

    try:
        User.objects.create_user(username=username, password=password)
        return JsonResponse({"message": "User registered successfully"})
    except IntegrityError:
        return JsonResponse({"error": "Username already exists"}, status=400)