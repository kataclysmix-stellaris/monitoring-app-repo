import requests
from requests.auth import HTTPDigestAuth
import json

table_id = "test2"
api_url = f"http://127.0.0.1:8000/api/gettelemetry/{table_id}/"
response = requests.get(api_url)
data = json.loads(response.content)
print(data)