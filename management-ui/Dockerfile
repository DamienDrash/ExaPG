# Multi-Stage Dockerfile für ExaPG Management UI

# Backend Stage
FROM python:3.11-slim as backend

WORKDIR /app/backend

# Installiere System-Abhängigkeiten
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Kopiere requirements und installiere Python-Abhängigkeiten
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Kopiere Backend-Code
COPY backend/ .

# Frontend Build Stage
FROM node:18-alpine as frontend-build

WORKDIR /app/frontend

# Kopiere package.json und installiere Abhängigkeiten
COPY frontend/package*.json ./
RUN npm install --production

# Kopiere Frontend-Code und baue die Anwendung
COPY frontend/ .
RUN npm run build

# Production Stage
FROM python:3.11-slim

LABEL maintainer="ExaPG Team"
LABEL description="ExaPG Management UI - Web-basierte Verwaltungsoberfläche"
LABEL version="1.0"

WORKDIR /app

# Installiere System-Abhängigkeiten
RUN apt-get update && apt-get install -y \
    libpq-dev \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Kopiere Backend-Code und Abhängigkeiten
COPY --from=backend /app/backend /app/backend
COPY --from=backend /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=backend /usr/local/bin /usr/local/bin

# Kopiere gebautes Frontend
COPY --from=frontend-build /app/frontend/build /app/frontend/build

# Nginx Konfiguration
COPY nginx.conf /etc/nginx/nginx.conf

# Supervisor Konfiguration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Erstelle Log-Verzeichnisse
RUN mkdir -p /var/log/nginx /var/log/supervisor /var/log/exapg

# Umgebungsvariablen
ENV PYTHONPATH=/app/backend
ENV DATABASE_URL=postgresql://postgres:postgres@exapg:5432/postgres
ENV SECRET_KEY=exapg-secret-key-change-in-production

# Ports
EXPOSE 80

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"] 