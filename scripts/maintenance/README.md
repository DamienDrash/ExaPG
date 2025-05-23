# ExaPG Selbstdiagnose-Werkzeuge

Dieses Verzeichnis enthält Skripte zur automatischen Diagnose und Optimierung der ExaPG-Datenbank. Diese Werkzeuge sind speziell für analytische Workloads optimiert und helfen dabei, Leistungsprobleme zu identifizieren und zu beheben.

## Übersicht der Werkzeuge

### 1. Diagnose langsamer Abfragen (`diagnose_slow_queries.py`)

Dieses Werkzeug identifiziert langsame Abfragen in der Datenbank, führt automatisch EXPLAIN ANALYZE für diese Abfragen aus und analysiert die Ergebnisse, um Optimierungsempfehlungen zu generieren.

#### Funktionen:

- Identifizierung von langsamen Abfragen über `pg_stat_statements`
- Automatische Ausführung von EXPLAIN ANALYZE mit detaillierten Ausführungsplänen
- Analyse von Ausführungsplänen zur Erkennung von Engpässen wie:
  - Sequential Scans auf großen Tabellen
  - Teure Sortierungen
  - Ineffiziente Joins
  - Unzureichende Statistiken
- Generierung spezifischer Optimierungsempfehlungen
- Historische Analyse von Abfrage-Performance-Trends
- E-Mail-Benachrichtigungen mit Diagnoseberichten

#### Verwendung:

```bash
./diagnose_slow_queries.py -d exadb -U postgres -t 1000
```

Parameter:
- `-d, --dbname`: Datenbankname (erforderlich)
- `-U, --user`: Datenbankbenutzer (erforderlich)
- `-t, --threshold`: Schwellenwert für langsame Abfragen in Millisekunden (Standard: 1000)
- `-m, --max-queries`: Maximale Anzahl zu analysierender Abfragen (Standard: 10)
- `--email`: E-Mail-Berichte aktivieren
- `--email-to`: E-Mail-Empfänger

### 2. Index-Empfehlungssystem (`index_advisor.py`)

Dieses Werkzeug analysiert den aktuellen Workload und empfiehlt neue Indizes, die die Abfrageleistung verbessern können.

#### Funktionen:

- Analyse teurer Abfragen aus `pg_stat_statements`
- Identifizierung von Tabellen und Spalten, die von Indexierung profitieren würden
- Simulation von Indizes mit HypoPG (falls verfügbar)
- Bewertung des potenziellen Performance-Gewinns
- Generierung von CREATE INDEX Anweisungen
- Berücksichtigung bestehender Indizes, um Duplikate zu vermeiden

#### Verwendung:

```bash
./index_advisor.py -d exadb -U postgres -c 10 -m 5
```

Parameter:
- `-d, --dbname`: Datenbankname (erforderlich)
- `-U, --user`: Datenbankbenutzer (erforderlich)
- `-c, --min-calls`: Mindestanzahl an Aufrufen, bevor eine Abfrage betrachtet wird (Standard: 10)
- `-m, --max-indexes`: Maximale Anzahl empfohlener Indizes (Standard: 10)
- `-b, --min-benefit`: Minimaler Prozentsatz an potenzieller Verbesserung (Standard: 10.0)
- `-o, --output`: Ausgabedatei für SQL-Skript

### 3. Automatische Vacuum-Optimierung (`auto_vacuum_optimizer.py`)

Dieses Werkzeug überwacht Tabellen mit hohem Bloat und toten Tupeln und führt automatisch optimierte VACUUM-Operationen durch.

#### Funktionen:

- Identifizierung von Tabellen mit hohem Bloat und vielen toten Tupeln
- Automatische Anpassung von Vacuum-Parametern basierend auf Tabellencharakteristiken
- Priorisierung von Vacuum-Operationen für kritische Tabellen
- Planung von Maintenance-Arbeiten in Zeiten niedriger Datenbankauslastung
- Optimierte VACUUM- und ANALYZE-Ausführung

#### Verwendung:

```bash
./auto_vacuum_optimizer.py -d exadb -U postgres -w "22:00-06:00"
```

Parameter:
- `-d, --dbname`: Datenbankname (erforderlich)
- `-U, --user`: Datenbankbenutzer (erforderlich)
- `-t, --threshold-dead-tuples`: Schwellenwert für tote Tupel (Standard: 10000)
- `-b, --threshold-bloat-percent`: Schwellenwert für Bloat in Prozent (Standard: 20.0)
- `-w, --maintenance-window`: Wartungsfenster im Format "HH:MM-HH:MM"
- `-j, --parallel-jobs`: Anzahl paralleler Vacuum-Jobs (Standard: 2)
- `--dry-run`: Testmodus - zeigt Befehle an, führt sie aber nicht aus

## Installation und Abhängigkeiten

Diese Skripte benötigen Python 3.6+ und folgende Python-Pakete:
- psycopg2
- pandas
- matplotlib
- tabulate

Installation der Abhängigkeiten:

```bash
pip install psycopg2-binary pandas matplotlib tabulate
```

## Einrichtung regelmäßiger Ausführung

Für eine automatische Ausführung können die Skripte in die Crontab eingetragen werden:

```bash
# Diagnose langsamer Abfragen täglich um 7:00 Uhr
0 7 * * * /path/to/exapg/scripts/maintenance/diagnose_slow_queries.py -d exadb -U postgres --email --email-to admin@example.com

# Index-Empfehlung wöchentlich am Montag um 8:00 Uhr
0 8 * * 1 /path/to/exapg/scripts/maintenance/index_advisor.py -d exadb -U postgres -o /tmp/index_recommendations.sql

# Automatische Vacuum-Optimierung täglich um 23:00 Uhr
0 23 * * * /path/to/exapg/scripts/maintenance/auto_vacuum_optimizer.py -d exadb -U postgres -w "22:00-06:00"
```

## Empfohlene Arbeitsabläufe

1. **Wöchentliche Performance-Überprüfung**:
   - Führen Sie `diagnose_slow_queries.py` aus, um langsame Abfragen zu identifizieren
   - Analysieren Sie die Ergebnisse und implementieren Sie die Optimierungsempfehlungen

2. **Monatliche Indexüberprüfung**:
   - Führen Sie `index_advisor.py` aus, um neue Indexvorschläge zu erhalten
   - Testen Sie die empfohlenen Indizes in einer Staging-Umgebung
   - Implementieren Sie nützliche Indizes in der Produktionsumgebung

3. **Laufende Vacuum-Optimierung**:
   - Konfigurieren Sie `auto_vacuum_optimizer.py` für automatische Ausführung während des Wartungsfensters
   - Überwachen Sie den Bloat-Level in Ihrer Datenbank regelmäßig

## Fehlerbehebung

Wenn Probleme bei der Ausführung der Skripte auftreten:

1. Prüfen Sie die Berechtigungen des Benutzers (benötigt mindestens SELECT auf pg_stat_statements)
2. Stellen Sie sicher, dass pg_stat_statements aktiviert ist (in postgresql.conf)
3. Für Indexsimulation muss die HypoPG-Erweiterung installiert sein
4. Bei Speicherproblemen passen Sie die Werte für max_queries und parallel_jobs an 