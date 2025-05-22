# ExaPG

ExaPG ist eine hochleistungsfähige, PostgreSQL-basierte Alternative zu Exasol für analytische Workloads. Die Lösung kombiniert PostgreSQL 15 mit TimescaleDB, PostGIS und pgvector und bietet sowohl Single-Node- als auch Cluster-Deployment mit Citus.

## Übersicht

ExaPG wurde entwickelt, um eine kosteneffiziente, Open-Source-basierte Alternative zu proprietären analytischen Datenbanksystemen zu bieten. Das Projekt konzentriert sich auf die Bereitstellung von:

- **Hochleistungs-Analytik**: Optimiert für analytische Workloads mit Columnar Storage
- **Skalierbarkeit**: Flexible Deployment-Optionen (Single-Node oder Cluster)
- **Umfassende Überwachung**: Integriertes Monitoring mit Prometheus und Grafana
- **Erweiterbarkeit**: Integration mit TimescaleDB, PostGIS und pgvector

## Architektur

ExaPG kann in verschiedenen Modi bereitgestellt werden:

- **Single-Node**: Einfache Bereitstellung für kleinere Workloads
- **Cluster-Modus**: Verteilte Verarbeitung mit Citus (1 Koordinator, mehrere Worker)
- **FDW-Modus**: Integration mit externen Datenquellen über Foreign Data Wrapper

## Schnellstart

```bash
# Single-Node-Modus starten
./start-exapg.sh

# Cluster-Modus starten (über .env konfigurierbar)
DEPLOYMENT_MODE=cluster ./start-exapg.sh

# Monitoring-Stack starten
./start-monitoring.sh
```

## Komponenten

- **PostgreSQL 15**: Basiskomponente mit analytischen Optimierungen
- **Citus**: Für horizontale Skalierung und verteilte Abfragen
- **TimescaleDB**: Für effiziente Zeitreihenanalyse
- **PostGIS**: Für räumliche Datenanalyse
- **pgvector**: Für Vektorähnlichkeitssuche und ML-Workloads
- **Prometheus/Grafana**: Für umfassendes Monitoring

## Lizenz

Dieses Projekt steht unter der [GNU General Public License v3.0](LICENSE).

## Funktionen

- **Clustering und Skalierung** mit Citus für horizontale Skalierung
- **Spaltenorientierte Speicherung** mit Citus Columnar für verbesserte analytische Performance und Datenkompression
- **Umfassende Datenintegration** mit Foreign Data Wrappers und ETL-Automatisierung
- **Zeitreihenanalyse** mit TimescaleDB für effiziente Speicherung und Abfrage von Zeitreihendaten
- **Räumliche Daten** mit PostGIS für Geodaten-Analyse
- **Vektorähnlichkeitssuche** mit pgvector für Machine Learning und KI-Anwendungen
- **Optimierte Konfiguration** für analytische Workloads mit angepassten Speicher- und Leistungseinstellungen
- **Monitoring und Verwaltung** mit Prometheus und Grafana für Echtzeitüberwachung und Benachrichtigungen

## Systemvoraussetzungen

- Docker (Version 19.03 oder höher)
- Docker Compose (Version 1.27 oder höher)
- Mindestens 8 GB RAM für den Single-Node-Modus
- Mindestens 16 GB RAM für den Cluster-Modus

## Testen der Installation

ExaPG verfügt über umfassende Testskripte, um die korrekte Funktionalität sicherzustellen:

```bash
# Führt alle Tests aus
./scripts/run-all-tests.sh

# Einzelne Testbereiche
./scripts/test-exapg.sh       # Grundfunktionalität
./scripts/test-fdw.sh         # Foreign Data Wrapper
./scripts/test-etl.sh         # ETL-Prozesse
./scripts/test-performance.sh # Leistungstests (small, medium, large)
```

Die Tests überprüfen:
- Korrekte Installation aller Komponenten und Erweiterungen
- Funktionalität der Foreign Data Wrapper und Datenintegration
- ETL-Prozesse und Datentransformationen
- Leistung bei analytischen Workloads

Für Leistungstests können Sie die Datenmenge anpassen:
```bash
./scripts/test-performance.sh small  # 10.000 Datensätze
./scripts/test-performance.sh medium # 100.000 Datensätze
./scripts/test-performance.sh large  # 1.000.000 Datensätze
```

## Deployment-Modi

### Single-Node-Modus

- Geeignet für Entwicklung, Tests und kleinere Produktivumgebungen
- Alle Erweiterungen auf einem einzelnen PostgreSQL-Server
- Geringere Hardware-Anforderungen

### Cluster-Modus

- Horizontale Skalierung über mehrere Knoten
- Ein Koordinator-Knoten und mehrere Worker-Knoten
- Datenverteilung für parallele Verarbeitung
- Höhere Leistung für große Datenmengen und komplexe Abfragen

## Konfiguration

Die Konfiguration erfolgt über die `.env`-Datei. Wichtige Parameter:

| Parameter | Beschreibung | Standardwert |
|-----------|--------------|--------------|
| `DEPLOYMENT_MODE` | Deployment-Modus (`single` oder `cluster`) | `single` |
| `WORKER_COUNT` | Anzahl der Worker-Knoten im Cluster-Modus | `2` |
| `COORDINATOR_MEMORY_LIMIT` | Speicherlimit für den Koordinator | `8g` |
| `WORKER_MEMORY_LIMIT` | Speicherlimit für Worker-Knoten | `8g` |
| `SHARED_BUFFERS` | PostgreSQL shared_buffers | `2GB` |
| `WORK_MEM` | PostgreSQL work_mem | `128MB` |
| `POSTGRES_PORT` | Port für PostgreSQL | `5432` |

## Verbinden mit der Datenbank

Nach dem Start können Sie sich mit der Datenbank verbinden:

```bash
docker exec -it exapg-coordinator psql -U postgres -d exadb
```

Oder mit einem externen PostgreSQL-Client:

- Host: localhost
- Port: 5432 (oder wie in `.env` konfiguriert)
- Benutzer: postgres
- Passwort: postgres
- Datenbank: exadb

## Beispieltabellen

Die folgenden Beispieltabellen werden automatisch erstellt:

- `analytics.sensor_data` - Zeitreihendaten für Sensormessungen
- `analytics.sales` - Verkaufsdaten
- `analytics.document_embeddings` - Vektordaten für Ähnlichkeitssuche
- `analytics.locations` - Räumliche Daten mit PostGIS

## Fehlerbehebung

Bei Problemen überprüfen Sie die Logs:

```bash
docker-compose logs coordinator
docker-compose logs worker1
```

## Produktionsempfehlungen

Für den Produktiveinsatz beachten Sie:

1. Ändern Sie die Standard-Passwörter in der `.env`-Datei
2. Passen Sie die Speichereinstellungen an Ihre Hardware an
3. Aktivieren Sie SSL für Verbindungen
4. Konfigurieren Sie regelmäßige Backups
5. Überwachen Sie die Systemressourcen und PostgreSQL-Metriken

## Vergleich mit Exasol

| Funktion | ExaPG | Exasol |
|----------|-------|--------|
| Spaltenorientierte Speicherung | Ja (via Citus Columnar) | Vollständig |
| In-Memory-Verarbeitung | Teilweise | Vollständig |
| Clustering | Ja (via Citus) | Ja |
| Virtuelle Schemas | Ja (via Foreign Data Wrappers) | Ja |
| Datenintegration | Umfassend (vielfältige FDWs) | Begrenzt (JDBC-basiert) |
| ETL-Automatisierung | Ja (pgAgent) | Ja (eigene Scheduler) |
| SQL-Unterstützung | ANSI SQL | Exasol SQL (ANSI-Erweiterung) |
| OLAP-Funktionen | Ja | Ja |
| Erweiterbarkeit | Sehr hoch | Begrenzt |
| Ökosystem | Umfangreich | Proprietär |
| Kompressionsraten | Hoch (bis zu 8x) | Sehr hoch (10-15x) |

## Datenintegration

ExaPG bietet umfassende Datenintegrationsfunktionen:

- **Foreign Data Wrappers** für den Zugriff auf verschiedene Datenquellen:
  - PostgreSQL, MySQL, MongoDB, SQL Server, SQLite, Redis und mehr
  - Zugriff auf CSV- und Textdateien
  - Virtuelle Views über mehrere Datenquellen

- **ETL-Automatisierung** mit pgAgent:
  - Zeitgesteuerte Ausführung von ETL-Prozessen
  - Robustes Fehlerbehandlung und Protokollierung
  - Inkrementelle und vollständige Datenaktualisierungen

```sql
-- Beispiel für eine FDW-Verbindung zu MySQL
CREATE SERVER mysql_server
  FOREIGN DATA WRAPPER mysql_fdw
  OPTIONS (host 'mysql_server', port '3306');

-- Beispiel für eine ETL-Prozedur
CREATE PROCEDURE etl.load_customers()
LANGUAGE plpgsql AS $$
BEGIN
    -- ETL-Logik hier
END;
$$;
```

Weitere Details finden Sie in der [Datenintegrationsdokumentation](docs/data-integration.md).

## Spaltenorientierte Speicherung

ExaPG nutzt Citus Columnar für spaltenorientierte Speicherung, was folgende Vorteile bietet:

- **Verbesserte analytische Performance** bei Spaltenoperationen und Aggregationen
- **Hohe Kompressionsraten** (2-8x je nach Datentyp)
- **Effiziente Abfrageverarbeitung** für Data-Warehouse-Workloads
- **Kombinierbar mit Clustering** für maximale Skalierbarkeit

Spaltenorientierte Tabellen werden mit der Syntax `USING columnar` erstellt:

```sql
CREATE TABLE facts (
    id BIGSERIAL,
    time TIMESTAMPTZ NOT NULL,
    value NUMERIC(10,2)
) USING columnar;
```

Weitere Details finden Sie in der [Columnar Storage Dokumentation](docs/columnar-storage.md).

## Erweiterungsmöglichkeiten

- Integration weiterer PostgreSQL-Erweiterungen für spezifische Anwendungsfälle
- Hinzufügen von Monitoring-Tools (z.B. Prometheus, Grafana)
- Implementierung automatischer Skalierung
- Konfiguration für Cloud-Umgebungen (AWS, Azure, GCP)

## Monitoring und Verwaltung

ExaPG verfügt über ein umfassendes Monitoring-System auf Basis von Prometheus und Grafana:

### Funktionen

- **Echtzeit-Metriken** für alle Datenbankkomponenten
- **Vordefinierte Dashboards** für schnellen Überblick und Detailanalysen
- **Automatisierte Alarme** bei kritischen Ereignissen
- **Leistungsanalyse** für Abfragen und Datenbankoperationen
- **Ressourcennutzung** der Cluster-Knoten im Überblick

### Starten des Monitoring-Systems

```bash
./start-monitoring.sh
```

Nach dem Start sind folgende Komponenten verfügbar:

- **Grafana**: http://localhost:3000 (Standard: admin/exapg_admin)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093

### Vordefinierte Dashboards

- **ExaPG Overview**: Allgemeiner Systemstatus, Ressourcennutzung, Datenbankaktivität
- **ExaPG Analytische Leistung**: Detaillierte Leistungsmetriken für analytische Workloads

### Alarme und Benachrichtigungen

Das System überwacht kritische Metriken und löst bei Bedarf Alarme aus:

- Hohe CPU- oder Speicherauslastung
- Speicherplatzknappheit
- Zu viele aktive Verbindungen
- Langsame Abfragen
- Deadlocks oder Fehler
- Citus-Knotenausfall

Benachrichtigungen können per E-Mail oder Webhook-Integration an externe Systeme gesendet werden.

### Beenden des Monitoring-Systems

```bash
./stop-monitoring.sh
``` 