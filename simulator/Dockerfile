FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY simulator ./simulator

# Los flags (escenario, seed, --base-url) los pasa docker-compose por `command`.
CMD ["python", "-m", "simulator"]
