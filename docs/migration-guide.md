# Migrationsleitfaden: Von Exasol zu ExaPG

Dieser Leitfaden bietet eine umfassende Anleitung für die Migration von einer Exasol-Datenbank zu ExaPG, unserer PostgreSQL-basierten Alternative für analytische Workloads.

## Inhaltsverzeichnis

1. [Überblick und Vorbereitungen](#überblick-und-vorbereitungen)
2. [Datenschemakonvertierung](#datenschemakonvertierung)
3. [Datenmigration](#datenmigration)
4. [SQL-Kompatibilität](#sql-kompatibilität)
5. [UDF-Migration](#udf-migration)
6. [Anwendungsanpassungen](#anwendungsanpassungen)
7. [Performance-Optimierung](#performance-optimierung)
8. [Validierung und Tests](#validierung-und-tests)
9. [Produktionsumstellung](#produktionsumstellung)
10. [Häufige Probleme und Lösungen](#häufige-probleme-und-lösungen)

## Überblick und Vorbereitungen

### Migrationsansätze

Für die Migration von Exasol zu ExaPG stehen drei grundlegende Ansätze zur Verfügung:

1. **Big Bang Migration**: Komplette Migration in einem Schritt
2. **Phasenweise Migration**: Schrittweise Migration von Tabellen und Anwendungen
3. **Parallelbetrieb**: Exasol und ExaPG laufen parallel mit Datensynchronisation

Die Wahl des Ansatzes hängt von folgenden Faktoren ab:
- Datenmenge und Komplexität
- Verfügbarkeitsanforderungen
- Risikobereitschaft
- Verfügbare Ressourcen

### Vorbereitende Schritte

1. **Bestandsaufnahme**:
   - Gesamtdatenvolumen ermitteln
   - Komplexe Abfragen und ETL-Prozesse identifizieren
   - Abhängigkeiten zu anderen Systemen dokumentieren
   - UDFs und benutzerdefinierte Funktionen erfassen

2. **Hardware-Dimensionierung**:
   - Empfohlene Spezifikationen für ExaPG:
     - CPU: 2 Kerne pro 100GB Daten für analytische Workloads
     - RAM: Mindestens 25% des Datenvolumens
     - Speicher: 1.5-fache der Originaldatengröße (unter Berücksichtigung der Columnar-Kompression)
     - Netzwerk: Mindestens 10 Gbit/s zwischen Cluster-Knoten

3. **Installation von ExaPG**:
   ```bash
   # ExaPG Basis-Installation
   ./start-exapg.sh
   
   # Für Citus-Cluster mit horizontaler Skalierung
   ./start-exapg-citus.sh
   
   # Für Hochverfügbarkeit mit Patroni
   ./start-exapg-ha.sh
   ```

## Datenschemakonvertierung

### Datentypen-Mapping

| Exasol-Datentyp | ExaPG-Datentyp | Hinweise |
|-----------------|----------------|----------|
| DECIMAL(p,s)    | NUMERIC(p,s)   | Direkte Entsprechung |
| DOUBLE          | DOUBLE PRECISION | Fließkommazahl mit doppelter Genauigkeit |
| VARCHAR(n)      | VARCHAR(n)     | Direkte Entsprechung |
| CHAR(n)         | CHAR(n)        | Direkte Entsprechung |
| BOOLEAN         | BOOLEAN        | Direkte Entsprechung |
| DATE            | DATE           | Direkte Entsprechung |
| TIMESTAMP       | TIMESTAMP      | Direkte Entsprechung |
| INTERVAL        | INTERVAL       | Syntax kann abweichen |
| GEOMETRY        | GEOMETRY (PostGIS) | Erfordert PostGIS-Erweiterung |

### Automatisierte Schemakonvertierung

Wir haben ein Tool zur Automatisierung der Schemakonvertierung entwickelt:

```bash
# Schema aus Exasol extrahieren und für ExaPG konvertieren
scripts/migration/extract_schema.py --source-dsn "exa:user/password@host:port" --output schema.sql

# Schema in ExaPG importieren
psql -h localhost -U postgres -d exapg -f schema.sql
```

### Partitionierungsstrategien

Exasol-Distributionsschlüssel müssen in PostgreSQL-Partitionierungen umgewandelt werden:

```sql
-- Beispiel: Zeitbasierte Partitionierung in ExaPG
CREATE TABLE sales (
    id SERIAL,
    sale_date DATE,
    amount NUMERIC(10,2),
    customer_id INTEGER
) PARTITION BY RANGE (sale_date);

-- Monatliche Partitionen erstellen
CREATE TABLE sales_y2023m01 PARTITION OF sales
    FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');
CREATE TABLE sales_y2023m02 PARTITION OF sales
    FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');
-- Weitere Partitionen...
```

## Datenmigration

### Direkter Export/Import

Der einfachste Weg zur Datenmigration ist der direkte Export aus Exasol und Import in ExaPG:

```bash
# Daten aus Exasol exportieren
exaplus -c "exa:user/password@host:port" -sql "EXPORT table TO LOCAL CSV FILE 'table.csv' ENCODING = 'UTF8';"

# Daten in ExaPG importieren
psql -h localhost -U postgres -d exapg -c "\COPY table FROM 'table.csv' WITH CSV DELIMITER ',' NULL '';"
```

### Für große Datenmengen: Parallele Migration

Bei großen Datenmengen empfehlen wir die Nutzung unseres parallelen Migrationsskripts:

```bash
scripts/migration/parallel_migrator.py --source "exa:user/password@host:port" \
  --target "postgresql://postgres:postgres@localhost:5432/exapg" \
  --tables customer,orders,sales \
  --workers 8
```

### Migration mit CDC (Change Data Capture)

Für Migrationen mit minimaler Ausfallzeit:

1. Initialen Datenbestand migrieren
2. CDC mit Postgres Logical Replication oder Debezium einrichten
3. Nach Synchronisation die Anwendungen umstellen

## SQL-Kompatibilität

### Syntax-Unterschiede

| Exasol-Syntax | ExaPG-Syntax | Beschreibung |
|---------------|--------------|--------------|
| `SELECT ... LIMIT n OFFSET m` | `SELECT ... OFFSET m ROWS FETCH FIRST n ROWS ONLY` | Alternative Syntax in ExaPG auch verfügbar |
| `MERGE INTO` | `INSERT ... ON CONFLICT DO UPDATE` | Upsert-Operation |
| `CONNECT BY` | Rekursive CTEs | Hierarchische Abfragen |
| `REGEXP_SUBSTR` | `substring(text from pattern)` oder `regexp_substring` | Reguläre Ausdrücke |
| `NVL(expr1, expr2)` | `COALESCE(expr1, expr2)` | NULL-Behandlung |

### Kompatibilitätsfunktionen

ExaPG enthält eine Kompatibilitätsschicht mit Exasol-ähnlichen Funktionen:

```sql
-- Installieren der Exasol-Kompatibilitätsfunktionen
CREATE EXTENSION exapg_compat;

-- Beispiel für eine Exasol-Syntax, die jetzt in ExaPG funktioniert
SELECT ADD_DAYS(date_column, 7) FROM mytable;
```

Eine vollständige Liste der verfügbaren Kompatibilitätsfunktionen finden Sie in der Datei `sql/compat/exasol_functions.sql`.

## UDF-Migration

### LUA-UDFs zu PL/Lua migrieren

Exasol LUA-UDFs können mit minimalen Änderungen zu PL/Lua in ExaPG migriert werden:

```sql
-- Exasol LUA-UDF
CREATE LUA SCALAR SCRIPT calculate_distance(lat1, lon1, lat2, lon2) RETURNS DOUBLE AS
function run(ctx)
  -- Haversine-Formel zur Distanzberechnung
  local earth_radius = 6371
  local dLat = math.rad(ctx.lat2 - ctx.lat1)
  local dLon = math.rad(ctx.lon2 - ctx.lon1)
  local a = math.sin(dLat/2) * math.sin(dLat/2) +
            math.cos(math.rad(ctx.lat1)) * math.cos(math.rad(ctx.lat2)) *
            math.sin(dLon/2) * math.sin(dLon/2)
  local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
  return earth_radius * c
end
/

-- Entsprechende ExaPG PL/Lua-Funktion
CREATE OR REPLACE FUNCTION calculate_distance(lat1 float, lon1 float, lat2 float, lon2 float)
RETURNS float AS $$
  -- Haversine-Formel zur Distanzberechnung
  local earth_radius = 6371
  local dLat = math.rad(lat2 - lat1)
  local dLon = math.rad(lon2 - lon1)
  local a = math.sin(dLat/2) * math.sin(dLat/2) +
            math.cos(math.rad(lat1)) * math.cos(math.rad(lat2)) *
            math.sin(dLon/2) * math.sin(dLon/2)
  local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
  return earth_radius * c
$$ LANGUAGE pllua;
```

### Weitere UDF-Sprachen

Exasol unterstützt neben LUA auch R, Python und Java UDFs. In ExaPG werden diese wie folgt umgesetzt:

| Exasol UDF Sprache | ExaPG Alternative | Installationsanleitung |
|--------------------|-------------------|------------------------|
| R                  | PL/R             | `CREATE EXTENSION plr;` |
| Python             | PL/Python        | `CREATE EXTENSION plpython3u;` |
| Java               | PL/Java          | Siehe separate Anleitung in UDF-Framework-Dokumentation |

## Anwendungsanpassungen

### JDBC-Verbindungen

Anpassung von JDBC-Verbindungen von Exasol zu ExaPG:

```java
// Exasol-JDBC-Verbindung
String exaUrl = "jdbc:exa:host:port;schema=public";
Connection exaConn = DriverManager.getConnection(exaUrl, "user", "password");

// ExaPG-JDBC-Verbindung
String pgUrl = "jdbc:postgresql://host:port/database";
Connection pgConn = DriverManager.getConnection(pgUrl, "user", "password");
```

### ODBC-Verbindungen

```python
# Exasol-ODBC in Python
exaConn = pyodbc.connect('DRIVER={EXAODBC};EXAHOST=host:port;EXAUID=user;EXAPWD=password')

# ExaPG-ODBC in Python
pgConn = pyodbc.connect('DRIVER={PostgreSQL};SERVER=host;PORT=port;DATABASE=exapg;UID=user;PWD=password')
```

### ETL-Prozesse

Bei der Migration von ETL-Prozessen beachten:

1. IMPORT/EXPORT-Anweisungen durch COPY-Befehle ersetzen
2. Anpassung von Bulk-Lade-Operationen an das COPY-Format
3. Change Data Capture mit PostgreSQL-Logical-Replication implementieren

## Performance-Optimierung

### Indexierungsstrategien

```sql
-- Für analytische Abfragen mit Bereichsfiltern: B-Tree-Indizes
CREATE INDEX idx_sales_date ON sales(sale_date);

-- Für Spalten mit wenigen unterschiedlichen Werten: Include-Spalten hinzufügen
CREATE INDEX idx_sales_region_include_amount ON sales(region) INCLUDE (amount);

-- Für analytische Abfragen mit hoher Selektivität: BRIN-Indizes für große Tabellen
CREATE INDEX idx_logs_timestamp_brin ON logs USING BRIN (timestamp);
```

### Columnar Storage für analytische Tabellen

```sql
-- Tabellen mit Columnar Storage für analytische Workloads
CREATE TABLE sales_columnar (
    id SERIAL,
    sale_date DATE,
    amount NUMERIC(10,2),
    customer_id INTEGER
) USING columnar;

-- Optimale Kompressionseinstellungen für analytische Daten
ALTER TABLE sales_columnar SET (columnar.compression = 'zstd', columnar.compression_level = 3);
```

### Parallel Query Optimierung

```sql
-- PostgreSQL-Konfiguration für parallele Abfragen
ALTER SYSTEM SET max_parallel_workers_per_gather = 8;
ALTER SYSTEM SET max_parallel_workers = 16;
ALTER SYSTEM SET parallel_setup_cost = 100;
ALTER SYSTEM SET parallel_tuple_cost = 0.01;

-- Parallele Abfragemöglichkeiten erzwingen
ALTER TABLE large_table SET (parallel_workers = 8);
```

## Validierung und Tests

### Datenvalidierung

Zur Sicherstellung der korrekten Datenmigration:

```sql
-- Anzahl der Datensätze vergleichen
SELECT COUNT(*) FROM exasol_db.table1;
SELECT COUNT(*) FROM exapg.table1;

-- Summen wichtiger numerischer Spalten vergleichen
SELECT SUM(amount) FROM exasol_db.sales;
SELECT SUM(amount) FROM exapg.sales;

-- Validierungsabfragen für bestimmte Geschäftsregeln
```

### Leistungstests

Benchmark-Skripte zur Validierung der Leistung:

```bash
# Performance-Vergleich zwischen Exasol und ExaPG
scripts/benchmarks/compare_performance.py --queries benchmark_queries.sql \
  --exasol "exa:user/password@host:port" \
  --exapg "postgresql://postgres:postgres@localhost:5432/exapg"
```

## Produktionsumstellung

### Checkliste vor der Umstellung

- [ ] Schema vollständig migriert und validiert
- [ ] Daten vollständig migriert und validiert
- [ ] Anwendungen angepasst und getestet
- [ ] Performance-Tests durchgeführt und validiert
- [ ] Backup- und Wiederherstellungsprozesse etabliert
- [ ] Monitoring-System eingerichtet
- [ ] Schulung der Administratoren und Entwickler durchgeführt

### Umstellungsstrategie

Wir empfehlen folgende Umstellungsstrategie:

1. **Letzte Synchronisation**: Letzte Datensynchronisation zwischen Exasol und ExaPG
2. **Datenverkehr reduzieren**: Anwendungen in Wartungsmodus setzen
3. **Finale Validierung**: Letzte Prüfung der Datenintegrität
4. **DNS/Verbindungs-Umstellung**: Verbindungen auf ExaPG umleiten
5. **Monitoring**: Engmaschiges Monitoring in den ersten Stunden/Tagen
6. **Rollback-Plan**: Vorbereitung für Notfallrollback zu Exasol

## Häufige Probleme und Lösungen

### Datentyp-Kompatibilität

**Problem**: Exasol TIMESTAMP WITH LOCAL TIME ZONE-Datentyp fehlt in PostgreSQL.
**Lösung**: Verwendung von TIMESTAMP WITH TIME ZONE mit expliziter Umwandlung:
```sql
-- Exasol
CREATE TABLE events (event_time TIMESTAMP WITH LOCAL TIME ZONE);

-- ExaPG
CREATE TABLE events (event_time TIMESTAMP WITH TIME ZONE);
-- Beim Import AT TIME ZONE 'user_timezone' anwenden
```

### Performance-Unterschiede

**Problem**: Langsame analytische Abfragen nach der Migration.
**Lösung**: 
1. EXPLAIN ANALYZE zur Identifizierung von Engpässen verwenden
2. Partitionierung für große Tabellen implementieren
3. Columnar Storage für analytische Tabellen aktivieren
4. Konfiguration für parallele Abfragen optimieren

### Speicherplatzverbrauch

**Problem**: Höherer Speicherverbrauch im Vergleich zu Exasol.
**Lösung**:
1. ZSTD-Kompression für Columnar-Tabellen aktivieren
2. Automatische Tabellenpartitionierung implementieren
3. Regelmäßige VACUUM FULL und Tabellenanalyse planen

## Support und weitere Ressourcen

Für weiterführende Hilfe bei der Migration von Exasol zu ExaPG:

- [ExaPG-Community-Forum](https://github.com/exapg/community)
- [SQL-Kompatibilitätsreferenz](docs/sql-compatibility.md)
- [UDF-Framework-Dokumentation](docs/udf-framework.md)
- [Performance-Tuning-Handbuch](docs/performance-tuning.md)

Für direkte Unterstützung kontaktieren Sie unser Migrations-Expertenteam unter migration-support@exapg.org. 