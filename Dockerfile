FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

RUN pip install flask psycopg2-binary

COPY . .
CMD ["python", "app.py"]