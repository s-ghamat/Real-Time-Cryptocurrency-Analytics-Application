FROM python:3.12-slim

WORKDIR /app

# Copier les fichiers requirements
COPY requirements.txt .

# Installer les dépendances système pour duckdb
RUN apt-get update && apt-get install -y \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Installer les dépendances Python
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code
COPY analytics/ ./analytics/
COPY storage/ ./storage/
COPY data-ingestion/ ./data-ingestion/

# Créer le répertoire pour DuckDB
RUN mkdir -p /app/analytics

# Variables d'environnement
ENV PYTHONUNBUFFERED=1
ENV POSTGRES_HOST=postgres
ENV POSTGRES_PORT=5432
ENV POSTGRES_USER=admin
ENV POSTGRES_PASSWORD=admin
ENV KAFKA_BOOTSTRAP_SERVERS=kafka:29092

# Commande par défaut
CMD ["python", "analytics/spark_analytics_builder.py"]

