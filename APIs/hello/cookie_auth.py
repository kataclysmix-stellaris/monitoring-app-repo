from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from rest_framework.permissions import AllowAny
from django.http import JsonResponse



@method_decorator(csrf_exempt, name="dispatch")
class LoginView(TokenObtainPairView):
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):

        if request.method == "OPTIONS":
            response = JsonResponse({})
            response["Access-Control-Allow-Origin"] = "*"
            response["Access-Control-Allow-Methods"] = "POST, OPTIONS"
            response["Access-Control-Allow-Headers"] = "Content-Type"
            return response

        response = super().post(request, *args, **kwargs)

        access_token = response.data.get('access')
        refresh_token = response.data.get('refresh')

        res = Response({"message": "Login successful"})
        res.set_cookie(
            key='access_token',
            value=access_token,
            httponly=True,
            secure=True,
            samesite="None",
            path='/'
        )

        res.set_cookie(
            key='refresh_token',
            value=refresh_token,
            httponly=True,
            secure=True,
            samesite="None",
            path='/'
        )
        return res

class RefreshCookieView(APIView):
    def post(self, request, *args, **kwargs):
        refresh_token = request.COOKIES.get('refresh_token')
        if not refresh_token:
            return Response({"error": "Refresh token not found"}, status=400)

        try:
            refresh = RefreshToken(refresh_token)
            new_access_token = refresh.access_token
            new_refresh_token = str(refresh)

            res = Response({"message": "Token refreshed"})
            res.set_cookie('access_token', str(new_access_token), httponly=True, secure=True, samesite="None", path='/')
            res.set_cookie('refresh_token', str(new_refresh_token), httponly=True, secure=True, samesite="None", path='/')
            return res
        except Exception as e:
            return Response({"error": "Invalid refresh token"}, status=400)
        
class LogoutView(APIView):
    def post(self, request, *args, **kwargs):
        refresh_token = request.COOKIES.get('refresh_token')
        if refresh_token:
            try:
                refresh = RefreshToken(refresh_token)
                refresh.blacklist()
            except Exception as e:
                # Optionally log the exception here
                pass
        res = Response({"message": "Logout successful"})
        res.delete_cookie('access_token', path='/', samesite="None")
        res.delete_cookie('refresh_token', path='/', samesite="None")
        return res
