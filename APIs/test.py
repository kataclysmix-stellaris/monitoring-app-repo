import requests
from requests.auth import HTTPDigestAuth
import json

api_url = f"http://127.0.0.1:8000/api/sendtelemetry"

#this files format is required for the POST method -- changing any variables requires changing variable names in SendTelemetry.py
files = {
        "file": open(r"data_string.json","rb")
    }

response = requests.post(api_url, files=files)

#status code should be 200 if everything is working
print(response.status_code, response.text)