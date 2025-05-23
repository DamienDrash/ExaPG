# ExaPG Management-UI

Diese Komponente bietet eine moderne Web-Oberfläche zur Verwaltung von ExaPG, einer PostgreSQL-basierten Alternative zu Exasol. Die Management-UI ermöglicht die einfache Steuerung und Überwachung der ExaPG-Umgebung.

## Funktionen

- **Dashboard**: Echtzeit-Metriken, System-Gesundheitsstatus, Performance-Graphs
- **ETL-Job-Management**: Überwachung und Steuerung von ETL-Prozessen
- **Query-Monitor**: Aktive Abfragen anzeigen, abbrechen und analysieren
- **Cluster-Management**: Knoten-Status, Ressourcen-Auslastung, Hochverfügbarkeits-Konfiguration
- **Benutzerverwaltung**: Benutzer erstellen, bearbeiten und Berechtigungen zuweisen

## Architektur

Die Management-UI besteht aus:

- **Frontend**: React/TypeScript mit Material-UI für eine moderne Benutzeroberfläche
- **Backend**: FastAPI (Python) für eine performante API mit PostgreSQL-Integration
- **Docker-Integration**: Multi-container Setup mit Nginx als Reverse-Proxy

## Installation

Die Management-UI kann mit den bereitgestellten Start-Skripten einfach gestartet werden:

```bash
./start-management-ui.sh
```

Oder direkt mit Docker Compose:

```bash
cd docker/docker-compose
docker-compose -f docker-compose.management-ui.yml up -d
```

## Zugriff

Nach dem Start ist die Management-UI unter folgenden URLs erreichbar:

- Management-UI: http://localhost:3002
- PgAdmin (optional): http://localhost:5051
- PostgreSQL: localhost:5435

## Standardanmeldedaten

- **Management-UI**: 
  - Benutzername: `admin`
  - Passwort: `admin123`

- **PgAdmin**:
  - E-Mail: `admin@exapg.local`
  - Passwort: `admin123`

## Konfiguration

Die Konfiguration erfolgt über Umgebungsvariablen, die in der `.env`-Datei oder direkt in der Docker-Compose-Datei definiert werden können:

- `POSTGRES_USER`: PostgreSQL-Benutzername (Standard: postgres)
- `POSTGRES_PASSWORD`: PostgreSQL-Passwort (Standard: postgres)
- `POSTGRES_DB`: PostgreSQL-Datenbankname (Standard: postgres)
- `SECRET_KEY`: Geheimer Schlüssel für JWT-Token (Standard: exapg-secret-key-change-in-production)
- `EXAPG_CLUSTER_NAME`: Name des Clusters (Standard: ExaPG Development)
- `EXAPG_ENVIRONMENT`: Umgebungstyp (Standard: development)

## Entwicklung

Für die Entwicklung können Frontend und Backend separat gestartet werden:

### Frontend

```bash
cd management-ui/frontend
npm install
npm start
```

### Backend

```bash
cd management-ui/backend
pip install -r requirements.txt
uvicorn app:app --reload
```

## Architektur-Details

- **Frontend**: React mit TypeScript, Material-UI, Recharts für Grafiken, Axios für API-Aufrufe
- **Backend**: FastAPI, Pydantic für Datenvalidierung, Psycopg2 für PostgreSQL-Anbindung
- **Authentifizierung**: JWT-Token-basierte Authentifizierung
- **Deployment**: Multi-Stage Docker-Build für optimierte Container-Größe 