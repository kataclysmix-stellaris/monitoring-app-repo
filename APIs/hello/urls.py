from django.urls import path
from hello import SendTelemetry, GetTelemetry, views

urlpatterns = [
    path("", views.home, name="home"),
    path("api/view", views.home),
    path("api/sendtelemetry", SendTelemetry.home),
    path("api/gettelemetry", GetTelemetry.home),
    path("api/gettelemetry/<str:table_id>/", GetTelemetry.test),
]
