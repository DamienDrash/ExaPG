# ExaPG Monitoring-System

Dieses Verzeichnis enthält die Konfiguration für das umfassende Monitoring-System von ExaPG, das speziell für analytische Workloads optimiert wurde.

## Übersicht

Das ExaPG Monitoring-System besteht aus folgenden Komponenten:

- **Prometheus**: Zeitreihendatenbank für die Erfassung und Speicherung von Metriken
- **Grafana**: Visualisierungstool für Dashboards
- **Postgres Exporter**: Erfasst PostgreSQL-spezifische Metriken
- **Node Exporter**: Erfasst System-Metriken (CPU, Speicher, Festplatte, etc.)
- **Alertmanager**: Verwaltet Benachrichtigungen basierend auf Prometheus-Alerts

## Dashboards

Wir bieten spezialisierte Dashboards für unterschiedliche Anwendungsfälle:

### 1. ExaPG Overview

Ein allgemeines Dashboard mit Basiskennzahlen über:
- Systemressourcen (CPU, Speicher, Festplatte)
- Datenbankaktivität (Verbindungen, Transaktionen)
- Citus-Cluster-Status (falls aktiviert)
- Grundlegende Performance-Metriken

### 2. ExaPG Analytics

Ein erweitertes Dashboard speziell für analytische Workloads:
- Abfrage-Performance (Top-Abfragen nach Ausführungszeit)
- Detaillierte Transaktionsmetriken
- Cache-Effizienz und Speichernutzung
- Spezifische Metriken für spaltenorientierte Speicherung
- Prädiktive Analysen für Ressourcenengpässe
- Historische Performance-Analyse für Query-Optimierung

## Prädiktive Analysen

Die prädiktive Analysekomponente verwendet lineare Regressionsmodelle, um zukünftige Ressourcennutzung vorherzusagen:

- **CPU-Trend-Prognose**: Zeigt die prognostizierte CPU-Auslastung für die nächsten 6 Stunden
- **Speichertrend-Prognose**: Zeigt die prognostizierte Speichernutzung für die nächsten 12 Stunden

Diese Prognosen helfen dabei, proaktiv auf potenzielle Ressourcenengpässe zu reagieren, bevor sie auftreten. Automatische Benachrichtigungen werden ausgelöst, wenn prognostizierte Werte bestimmte Schwellenwerte überschreiten.

## Historische Performance-Analyse

Die historische Performance-Analyse bietet Einblicke in langfristige Trends:

- **Abfragezeitentrend**: Zeigt die Entwicklung der Ausführungszeiten für Top-Abfragen über 30 Tage
- **Top langsamste Abfragen**: Identifiziert die rechenintensivsten Abfragen mit Trendanalyse
- Visuelle Indikatoren für Verbesserungen oder Verschlechterungen der Abfrageleistung

Diese Informationen sind besonders nützlich für:
- Identifizierung von langsam degradierenden Abfragen
- Erkennung von Optimierungspotential nach Software-Updates oder Schema-Änderungen
- Validierung der Wirksamkeit von Performance-Optimierungen

## Alerts und Benachrichtigungen

Das System enthält vorkonfigurierte Alerts für:

- Systemressourcen (CPU, Speicher, Festplatte)
- Datenbankzustand (erreichbar, Anzahl der Verbindungen)
- Langsame Abfragen und lange Transaktionen
- Deadlocks und andere kritische Ereignisse
- Prädiktive Warnungen für drohende Ressourcenengpässe

## Nutzung

### Start des Monitoring-Stacks

```bash
cd /path/to/exapg
./start-monitoring.sh
```

### Zugriff auf die Dashboards

- Grafana: http://your-server:3000
  - Standard-Login: admin/admin
  - Dashboards befinden sich im Ordner "ExaPG"

### Anpassung der Konfiguration

- Prometheus-Konfiguration: `prometheus/prometheus.yml`
- Alert-Regeln: `prometheus/alerts.yml`
- Grafana-Dashboards: `grafana/dashboards/`

## Empfohlene Vorgehensweise für Performance-Optimierung

1. Überwachen Sie regelmäßig das ExaPG Analytics Dashboard
2. Achten Sie auf die prädiktiven Warnungen für Ressourcenengpässe
3. Analysieren Sie die historische Performance der Top-Abfragen
4. Identifizieren Sie Abfragen mit Verschlechterungstrend
5. Optimieren Sie die identifizierten Abfragen (Indizes, Umschreiben, etc.)
6. Überprüfen Sie nach der Optimierung die Trends, um die Wirksamkeit zu messen

## Wartung und Fehlerbehebung

- Logs befinden sich in den jeweiligen Container-Logs
- Prometheus-Daten werden in einem Volume gespeichert
- Bei Problemen mit der Datenerfassung prüfen Sie die Erreichbarkeit der Exporter 