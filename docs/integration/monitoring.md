# ExaPG Monitoring und Verwaltung

Dieses Dokument beschreibt die Monitoring- und Verwaltungsfunktionen von ExaPG auf Basis von Prometheus und Grafana.

## Architektur des Monitoring-Systems

Das Monitoring-System besteht aus folgenden Komponenten:

1. **Prometheus**: Zeitreihendatenbank zur Speicherung und Abfrage von Metriken
2. **Grafana**: Visualisierungsplattform für Dashboards und Grafiken
3. **Alertmanager**: Komponente für die Verwaltung und Weiterleitung von Alarmen
4. **Exporter**:
   - **PostgreSQL-Exporter**: Sammelt Metriken von PostgreSQL-Instanzen
   - **Node-Exporter**: Sammelt Systemmetriken (CPU, RAM, Disk, Netzwerk)

![Monitoring-Architektur](images/monitoring-architecture.png)

## Installation und Konfiguration

Das Monitoring-System wird als Teil des ExaPG-Stacks bereitgestellt und kann mit dem mitgelieferten Skript gestartet werden:

```bash
./start-monitoring.sh
```

### Konfigurationseinstellungen

Die Konfiguration erfolgt über folgende Dateien:

- **docker-compose.monitoring.yml**: Docker-Compose-Konfiguration für alle Monitoring-Komponenten
- **monitoring/prometheus/prometheus.yml**: Prometheus-Konfiguration (Scrape-Intervalle, Targets)
- **monitoring/prometheus/alerts.yml**: Alarmdefinitionen
- **monitoring/alertmanager/alertmanager.yml**: Konfiguration für Benachrichtigungen
- **monitoring/postgres_exporter/queries.yaml**: Benutzerdefinierte PostgreSQL-Abfragen für Metriken

Anpassungen der Konfiguration können in diesen Dateien vorgenommen werden.

### Anpassen der Benachrichtigungen

Um E-Mail-Benachrichtigungen zu konfigurieren, bearbeiten Sie die `alertmanager.yml`-Datei:

```yaml
global:
  smtp_from: 'alertmanager@yourdomain.com'
  smtp_smarthost: 'smtp.yourdomain.com:587'
  smtp_auth_username: 'username'
  smtp_auth_password: 'password'
  smtp_require_tls: true

receivers:
  - name: 'email-notifications'
    email_configs:
      - to: 'dba@yourdomain.com'
```

## Monitoring-Komponenten im Detail

### Prometheus

Prometheus sammelt Metriken von verschiedenen Quellen:

- PostgreSQL-Metriken (Abfragen, Verbindungen, Cache-Nutzung)
- Citus-spezifische Metriken (Cluster-Status, Shard-Verteilung)
- System-Metriken (CPU, RAM, Disk I/O, Netzwerk)

Zugänglich unter: http://localhost:9090

### Grafana

Grafana bietet vordefinierte Dashboards:

1. **ExaPG Overview**: Allgemeiner Systemüberblick
   - CPU- und Speichernutzung
   - Aktive Verbindungen und Datenbankoperationen
   - Citus-Cluster-Status
   - Datenbankgrößen

2. **ExaPG Analytische Leistung**: Leistungsmetriken für analytische Workloads
   - Top-Abfragen nach Ausführungszeit
   - Cache-Hit-Ratio
   - Transaktionsraten
   - Spaltenorientierte Speichernutzung
   - TimescaleDB-Metriken

Zugänglich unter: http://localhost:3000 (Standard: admin/exapg_admin)

### Alertmanager

Der Alertmanager verwaltet Benachrichtigungen bei Alarmen:

- Gruppierung ähnlicher Alarme
- Verzögerung von Benachrichtigungen zur Vermeidung von "Alert Storms"
- Unterdrückung redundanter Alarme
- Weiterleitung an verschiedene Empfänger (E-Mail, Slack, PagerDuty, etc.)

Zugänglich unter: http://localhost:9093

## Vordefinierte Alarme

Das System überwacht folgende kritische Zustände:

| Alarm | Beschreibung | Schwellenwert |
|-------|--------------|---------------|
| PostgreSQLHighCPUUsage | Hohe CPU-Auslastung | >80% für 5 Minuten |
| PostgreSQLDiskSpaceRunningOut | Speicherplatz wird knapp | <10% frei für 5 Minuten |
| PostgreSQLDiskSpaceCritical | Kritischer Speicherplatzmangel | <5% frei für 5 Minuten |
| PostgreSQLTooManyConnections | Zu viele Verbindungen | >80% der max. Verbindungen für 5 Minuten |
| PostgreSQLSlowQueries | Langsame Abfragen | Transaktionen >5 Minuten |
| PostgreSQLDeadlocks | Deadlocks | >0 in 5 Minuten |
| PostgreSQLHighMemoryUsage | Hohe Speichernutzung | >80% für 5 Minuten |
| CitusNodeOffline | Citus-Knoten offline | Knoten nicht erreichbar |

## Benutzerdefinierte Metriken

ExaPG sammelt spezielle Metriken für analytische Workloads:

- **Columnar Storage**: Metriken zu spaltenorientierten Tabellen (Größe, Chunks)
- **TimescaleDB**: Hypertable-Metriken und Chunk-Verteilung
- **Citus**: Cluster-Status und Shard-Verteilung
- **Abfrageleistung**: Ausführungszeiten und Ressourcennutzung für komplexe Abfragen

## Anwendungsfälle

### Leistungsoptimierung

1. Identifizieren langsamer Abfragen im "Top-Abfragen" Dashboard
2. Analysieren der Ressourcennutzung während Spitzenzeiten
3. Überwachen der Cache-Hit-Ratio für optimale Speicherkonfiguration

### Kapazitätsplanung

1. Beobachten von Wachstumstrends bei Datenbankgrößen
2. Analyse der Ressourcennutzung über längere Zeiträume
3. Identifizieren von Leistungsengpässen (CPU, Speicher, I/O)

### Fehlerbehebung

1. Korrelieren von Systemereignissen mit Datenbankmetriken
2. Erkennen von Deadlocks und Blockierungen
3. Identifizieren von Problemquellen bei Cluster-Problemen

## Best Practices

- Behalten Sie regelmäßig die Dashboards im Auge, insbesondere nach Konfigurationsänderungen
- Passen Sie die Alarmschwellenwerte an Ihre spezifischen Anforderungen an
- Testen Sie die Alarmbenachrichtigungen regelmäßig
- Bewahren Sie Metriken für mindestens 30 Tage auf (standardmäßig konfiguriert)
- Ergänzen Sie das Monitoring bei Bedarf um anwendungsspezifische Metriken

## Wartung des Monitoring-Systems

Das Monitoring-System speichert Daten in Docker-Volumes:

- **prometheus_data**: Zeitreihendaten von Prometheus
- **grafana_data**: Grafana-Konfiguration, Dashboards und Benutzer

Zum Sichern dieser Daten können die Docker-Volumes gesichert werden.

### Aktualisierung des Monitoring-Systems

Um das Monitoring-System zu aktualisieren:

1. Stoppen Sie den Monitoring-Stack: `./stop-monitoring.sh`
2. Aktualisieren Sie die Konfigurationsdateien nach Bedarf
3. Starten Sie den Monitoring-Stack neu: `./start-monitoring.sh`

## Fehlerbehebung

### Problem: Keine Metriken in Prometheus

1. Prüfen Sie, ob die Exporter laufen: `docker ps | grep exporter`
2. Prüfen Sie die Prometheus-Targets: http://localhost:9090/targets
3. Prüfen Sie die Prometheus-Logs: `docker logs exapg-prometheus`

### Problem: Dashboards zeigen keine Daten

1. Prüfen Sie, ob die Prometheus-Datenquelle in Grafana konfiguriert ist
2. Prüfen Sie, ob Prometheus Daten sammelt
3. Prüfen Sie die Grafana-Logs: `docker logs exapg-grafana`

### Problem: Keine Benachrichtigungen bei Alarmen

1. Prüfen Sie die Alertmanager-Konfiguration
2. Prüfen Sie, ob die SMTP-Einstellungen korrekt sind
3. Prüfen Sie die Alertmanager-Logs: `docker logs exapg-alertmanager` 