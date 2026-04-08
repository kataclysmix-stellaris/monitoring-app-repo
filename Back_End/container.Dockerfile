FROM python:3.11

# Create the destination directory
RUN mkdir -p "/app/Back_End"

# Copy your files into the container
COPY Node3.py "/app/Back_End/Node3.py"
COPY data_string.json "/app/Back_End/data_string.json"

WORKDIR "/app/Back_End"

CMD ["python", "Node3.py"]