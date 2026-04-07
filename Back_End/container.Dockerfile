FROM python:3.11-slim

WORKDIR /app

COPY test.py .
COPY data_string.json .

CMD [ "python", "test.py" ]