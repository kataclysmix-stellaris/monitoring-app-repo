import json
from django.contrib.auth.models import User
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.db import IntegrityError
import logging
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.validators import validate_email



logger = logging.getLogger(__name__)

@csrf_exempt
def register_user(request):
    
    if request.method != "POST":
        logger.warning("Registration attempt: Non-POST request received")
        return JsonResponse({"error": "POST required"}, status=405)
    
    content_type = request.content_type or ""
    if not content_type.startswith("application/json"):
        return JsonResponse({"error": "Content-Type must be application/json"}, status=400)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        logger.warning("Registration failed: invalid JSON")
        return JsonResponse({"error": "Invalid JSON"}, status=400)

    username = data.get("username")
    password = data.get("password")
    email = data.get("email")

    if not username or not password or not email:
        logger.warning("Registration failed: missing fields")
        return JsonResponse({"error": "Username, password, and email are required"}, status=400)
    
    username = username.strip()
    email = email.strip().lower()

    try: 
        validate_email(email)
    except ValidationError:
        logger.warning(f"Invalid email format: {email}")
        return JsonResponse({"error": "Invalid email address"}, status=400)
    try:
        validate_password(password, user=User(username=username, email=email))
    except ValidationError as e:
        logger.warning(f"Password validation failed for user: {username}")
        return JsonResponse({"error": "Password does not meet requirements"}, status=400)
    
    if User.objects.filter(email=email).exists():
        logger.warning(f"Registration failed: email already in use")
        return JsonResponse({"error": "Email already in use"}, status=400)

    try:
        User.objects.create_user(username=username, password=password, email=email)
        logger.info(f"User registered successfully: {username}")
        return JsonResponse({"message": "User registered successfully"}, status=201)
    
    except IntegrityError:
        if User.objects.filter(username=username).exists():
            logger.warning(f"Registration failed: username already exists ({username})")
            return JsonResponse({"error": "Username already exists"}, status=400)
        return JsonResponse({"error": "Database error"}, status=500)
    
    except Exception as e:
        logger.error("Unexpected error: during registration", exc_info=True)
        return JsonResponse({"error": "Something went wrong"}, status=500)