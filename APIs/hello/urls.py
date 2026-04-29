from django.urls import path
from hello import SendTelemetry, GetTelemetry, cookie_auth, UserRegister

urlpatterns = [
    path("", GetTelemetry.home, name="home"),
    path("api/sendtelemetry", SendTelemetry.home),
    path("api/gettelemetry/", GetTelemetry.home),
    path("api/gettelemetry/<str:table_id>/", GetTelemetry.search),
    path("api/login/", cookie_auth.LoginView.as_view(), name="login"),
    path("api/refresh/", cookie_auth.RefreshCookieView.as_view(), name="token_refresh"),
    path("api/logout/", cookie_auth.LogoutView.as_view(), name="logout"),
    path("api/register/", UserRegister.register_user, name="register"),
]
