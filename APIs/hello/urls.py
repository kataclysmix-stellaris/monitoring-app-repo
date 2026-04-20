from django.urls import path
from hello import SendTelemetry, GetTelemetry

urlpatterns = [
    path("", GetTelemetry.home, name="home"),
    path("api/sendtelemetry", SendTelemetry.home),
    path("api/gettelemetry", GetTelemetry.home),
    path("api/gettelemetry/<str:table_id>/", GetTelemetry.search),
]
