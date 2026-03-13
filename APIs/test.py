import requests
from requests.auth import HTTPDigestAuth
import json

api_url = "http://127.0.0.1:8000/api/view"
response = requests.get(api_url)
data = json.loads(response.content)
print(data)