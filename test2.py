import requests

api_url = f"http://127.0.0.1:8000/api/gettelemetry"

response = requests.get(api_url)
json_data = response.text
#status code should be 200 if everything is working
print(json_data)