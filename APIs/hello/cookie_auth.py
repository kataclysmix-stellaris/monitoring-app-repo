from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework.response import Response
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.exceptions import AuthenticationFailed



class LoginView(TokenObtainPairView):
    def post(self, request, *args, **kwargs):
       response = super().post(request, *args, **kwargs)

       access_token = response.data.get('access')
       refresh_token = response.data.get('refresh')

       res = Response({"message": "Login successful", "access": access_token, "refresh": refresh_token})
       res.set_cookie(
           key='access_token',
           value=access_token,
           httponly=True,
           secure=True,
           samesite="Lax",
           path='/'
       )

       res.set_cookie(
            key='refresh_token',
            value=refresh_token,
            httponly=True,
            secure=True,
            samesite="Lax",
            path='/'
        )
       return res

class CookieJWTAuthentication(JWTAuthentication):
    def authenticate(self, request):
        access_token = request.COOKIES.get('access_token')
        if not access_token:
            return None
        try:
            validated_token = self.get_validated_token(access_token)
            return self.get_user(validated_token), validated_token
        except Exception:
            raise AuthenticationFailed("Invalid or expired token")

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
            res.set_cookie('access_token', str(new_access_token), httponly=True, secure=True, samesite="Lax", path='/')
            res.set_cookie('refresh_token', str(new_refresh_token), httponly=True, secure=True, samesite="Lax", path='/')
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
        res.delete_cookie('access_token', path='/', samesite="Lax")
        res.delete_cookie('refresh_token', path='/', samesite="Lax")
        return res
