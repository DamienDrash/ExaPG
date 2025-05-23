# Performance-Tuning-Handbuch für ExaPG

Dieses Handbuch bietet umfassende Anleitungen zur Optimierung von ExaPG für analytische Workloads. Durch die Anwendung dieser Optimierungsstrategien können Sie die Leistung Ihrer ExaPG-Installation erheblich verbessern und an die speziellen Anforderungen analytischer Datenbanken anpassen.

## Inhaltsverzeichnis

1. [Hardware-Optimierung](#hardware-optimierung)
2. [PostgreSQL-Konfiguration](#postgresql-konfiguration)
3. [Tabellen- und Schemadesign](#tabellen--und-schemadesign)
4. [Indexierungsstrategien](#indexierungsstrategien)
5. [Abfrageoptimierung](#abfrageoptimierung)
6. [Parallelverarbeitung](#parallelverarbeitung)
7. [Partitionierung](#partitionierung)
8. [Columnar Storage](#columnar-storage)
9. [Materialisierte Sichten](#materialisierte-sichten)
10. [Wartung und Monitoring](#wartung-und-monitoring)
11. [Verteilte Abfragen mit Citus](#verteilte-abfragen-mit-citus)

## Hardware-Optimierung

### Empfohlene Hardware-Spezifikationen

Für optimale Leistung bei analytischen Workloads:

| Komponente | Empfehlung | Begründung |
|------------|------------|------------|
| CPU | 16+ Kerne mit hoher Taktrate | Parallele Abfrageverarbeitung profitiert von vielen Kernen |
| RAM | Mindestens 25% der Datengröße, optimal 50%+ | Reduziert I/O-Operationen durch Zwischenspeicherung |
| Speicher | NVMe-SSDs im RAID-0 für Leistung | Schneller Zugriff auf große Datenmengen |
| Netzwerk | 10+ GbE zwischen Clusterknoten | Schneller Datenaustausch zwischen Knoten |

### I/O-Optimierung

```bash
# Überprüfen der aktuellen I/O-Scheduler-Einstellung
cat /sys/block/nvme0n1/queue/scheduler

# Für NVMe-SSDs empfohlen: none oder mq-deadline
echo "mq-deadline" > /sys/block/nvme0n1/queue/scheduler

# I/O-Optimierung in der Systemkonfiguration
echo "vm.dirty_background_ratio = 5" >> /etc/sysctl.conf
echo "vm.dirty_ratio = 10" >> /etc/sysctl.conf
echo "vm.swappiness = 10" >> /etc/sysctl.conf
sysctl -p
```

### NUMA-Konfiguration für große Server

Bei Servern mit mehreren CPU-Sockeln:

```bash
# Überprüfen der NUMA-Topologie
numactl --hardware

# PostgreSQL mit NUMA-Bewusstsein starten
numactl --interleave=all postgres -D /path/to/data
```

Fügen Sie diese Konfiguration in ExaPG-Startskripten hinzu:

```bash
# In start-exapg.sh oder ähnlichen Skripten
if command -v numactl &> /dev/null; then
  NUMACTL="numactl --interleave=all"
else
  NUMACTL=""
fi

$NUMACTL postgres -D $PGDATA
```

## PostgreSQL-Konfiguration

### Speicherkonfiguration

Für analytische Workloads:

```
# Memory-Einstellungen für einen Server mit 128 GB RAM
shared_buffers = 32GB                   # 25% des verfügbaren RAMs
work_mem = 128MB                        # Ausreichend für komplexe Sortierungen und Hashes
maintenance_work_mem = 2GB              # Beschleunigt Wartungsoperationen
effective_cache_size = 80GB             # Schätzung des verfügbaren Cachespeichers (System + PostgreSQL)
effective_io_concurrency = 200          # Optimiert für SSDs
random_page_cost = 1.1                  # Näher an 1.0 für SSDs
```

### Checkpointing und WAL

```
# Checkpoint-Optimierung für analytische Workloads
checkpoint_timeout = 15min              # Längere Intervalle zwischen Checkpoints
checkpoint_completion_target = 0.9      # Verteilt Checkpoint-Schreiboperationen
max_wal_size = 16GB                     # Größerer WAL-Puffer für längere Checkpoint-Intervalle
min_wal_size = 4GB                      # Mindestgröße für WAL-Dateien
```

### Autovacuum-Einstellungen

```
# Aggressive Autovacuum-Einstellungen für analytische Workloads
autovacuum = on
autovacuum_max_workers = 6              # Mehr Worker für größere Datenbanken
autovacuum_vacuum_threshold = 1000      # Höhere Schwelle für analytische Tabellen
autovacuum_analyze_threshold = 1000     # Statistiken erst nach mehr Änderungen aktualisieren
autovacuum_vacuum_scale_factor = 0.05   # Prozentsatz bezogen auf Tabellengröße
autovacuum_analyze_scale_factor = 0.025 # Prozentsatz für ANALYZE
autovacuum_vacuum_cost_limit = 2000     # Höherer Wert für schnelleres Vacuum
```

### JIT-Kompilierung

```
# JIT-Einstellungen für komplexe analytische Abfragen
jit = on
jit_above_cost = 100000                 # Niedrigerer Wert für häufigere JIT-Kompilierung
jit_inline_above_cost = 150000          # Niedrigerer Wert für häufigeres Inlining
jit_optimize_above_cost = 200000        # Niedrigerer Wert für häufigere Optimierung
```

## Tabellen- und Schemadesign

### Optimale Datentypen

Wählen Sie die richtigen Datentypen für analytische Workloads:

| Datentyp | Empfehlung | Begründung |
|----------|------------|------------|
| Integers | `INT` statt `BIGINT` wenn möglich | Benötigt weniger Speicher |
| Dezimalzahlen | `NUMERIC(p,s)` mit minimaler Präzision | Genau, aber speichereffizient |
| Zeitstempel | `TIMESTAMP` ohne Zeitzone für lokale Daten | Kompakter als mit Zeitzone |
| Zeichenketten | `VARCHAR(n)` mit realistischem Maximum | Verhindert Überdimensionierung |
| Boolesche Werte | `BOOLEAN` statt `INT` | Semantisch klarer und kompakter |

### Normalisierung vs. Denormalisierung

Für analytische Workloads:

```sql
-- Denormalisierte Tabelle für schnelle Analytik
CREATE TABLE sales_analytics (
    sale_date DATE,
    product_id INT,
    product_name VARCHAR(100),  -- Denormalisiert aus products
    category_name VARCHAR(50),  -- Denormalisiert aus categories
    region_name VARCHAR(50),    -- Denormalisiert aus regions
    quantity INT,
    revenue NUMERIC(12,2),
    discount NUMERIC(5,2)
) USING columnar;

-- Alternativ: Star-Schema mit Dimensionstabellen
CREATE TABLE fact_sales (
    sale_date_id INT,
    product_id INT,
    region_id INT,
    quantity INT,
    revenue NUMERIC(12,2),
    discount NUMERIC(5,2)
) USING columnar;

CREATE TABLE dim_products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category_id INT,
    -- weitere Attribute
);
```

### Speicheroptionen

```sql
-- FILLFACTOR für analytische Tabellen reduzieren (mehr Datendichte)
ALTER TABLE fact_sales SET (fillfactor = 90);

-- TOAST-Einstellungen für große Text-/JSONB-Spalten
ALTER TABLE log_data SET (toast_tuple_target = 8192);
ALTER TABLE event_data ALTER COLUMN event_details SET STORAGE EXTENDED;
```

## Indexierungsstrategien

### Indextypen für analytische Workloads

```sql
-- B-Tree-Index für Equality und Range-Scans
CREATE INDEX idx_sales_date ON fact_sales(sale_date);

-- BRIN-Index für sehr große Tabellen mit sequentieller Korrelation
CREATE INDEX idx_logs_timestamp_brin ON logs USING BRIN (timestamp);

-- Partial Index für häufig abgefragte Teilmengen
CREATE INDEX idx_sales_large_orders ON sales(order_id, customer_id) 
WHERE total_amount > 1000;

-- Multi-Column-Index für gemeinsam verwendete Filter
CREATE INDEX idx_sales_composite ON sales(region_id, product_id, sale_date);

-- Include-Spalten für Index-Only-Scans
CREATE INDEX idx_sales_region_include ON sales(region_id) INCLUDE (total_amount);
```

### Bitmap- und Hash-Joins

```sql
-- Bitmap-Scan ermöglichen durch geeignete Indizes bei Abfragen mit mehreren Bedingungen
SET enable_bitmapscan = on;

-- Hash-Joins aktivieren für große Tabellen-Joins
SET enable_hashjoin = on;
SET hash_mem_multiplier = a 2.0;  -- Mehr Speicher für Hash-Tabellen
```

## Abfrageoptimierung

### Erklärungspläne verstehen

```sql
-- Grundlegende Analyse eines Abfrageplans
EXPLAIN SELECT * FROM fact_sales 
WHERE sale_date BETWEEN '2023-01-01' AND '2023-01-31'
AND product_id = 123;

-- Detaillierte Analyse mit tatsächlichen Ausführungszeiten
EXPLAIN ANALYZE SELECT * FROM fact_sales 
WHERE sale_date BETWEEN '2023-01-01' AND '2023-01-31'
AND product_id = 123;

-- Grafische Darstellung des Ausführungsplans generieren
EXPLAIN (FORMAT JSON) SELECT * FROM fact_sales 
WHERE sale_date BETWEEN '2023-01-01' AND '2023-01-31'
AND product_id = 123;
```

Verwenden Sie Tools wie [explain.dalibo.com](https://explain.dalibo.com/) oder pgAdmin für grafische Darstellungen.

### Häufige Optimierungsprobleme

#### Problem: Table Scan statt Index Scan

```sql
-- Erkennen des Problems
EXPLAIN ANALYZE SELECT * FROM fact_sales WHERE sale_date = '2023-01-01';
-- Wenn "Seq Scan" angezeigt wird, fehlt ein effektiver Index

-- Lösung
CREATE INDEX idx_fact_sales_date ON fact_sales(sale_date);
```

#### Problem: Ineffiziente Joins

```sql
-- Erkennen des Problems
EXPLAIN ANALYZE SELECT s.*, p.product_name 
FROM fact_sales s JOIN dim_products p ON s.product_id = p.product_id
WHERE s.sale_date = '2023-01-01';
-- Wenn "Hash Join" oder "Nested Loop" mit hohen Kosten angezeigt wird

-- Lösung
CREATE INDEX idx_fact_sales_product ON fact_sales(product_id);
-- UND/ODER Statistiken aktualisieren
ANALYZE fact_sales;
ANALYZE dim_products;
```

#### Problem: Suboptimale GROUP BY

```sql
-- Erkennen des Problems
EXPLAIN ANALYZE SELECT product_id, SUM(revenue) 
FROM fact_sales GROUP BY product_id;
-- Wenn "HashAggregate" mit hohen Kosten

-- Lösung (wenn häufig abgefragt)
CREATE INDEX idx_fact_sales_product_revenue ON fact_sales(product_id, revenue);
-- ODER materialisierte Sicht erstellen
CREATE MATERIALIZED VIEW mv_product_revenue AS
SELECT product_id, SUM(revenue) as total_revenue 
FROM fact_sales GROUP BY product_id;
```

## Parallelverarbeitung

### Konfiguration für parallele Abfragen

```
# Grundlegende Parallelitätseinstellungen
max_worker_processes = 32           # Maximale Anzahl paralleler Prozesse
max_parallel_workers_per_gather = 8 # Maximale Anzahl von Worker-Prozessen pro Gather-Knoten
max_parallel_workers = 16           # Maximale Anzahl paralleler Worker-Prozesse
max_parallel_maintenance_workers = 4 # Maximale Anzahl paralleler Maintenance-Worker

# Kostenparameter für parallele Abfragen
parallel_setup_cost = 100           # Kosten für die Einrichtung paralleler Worker
parallel_tuple_cost = 0.01          # Zusätzliche Kosten für die Verarbeitung pro Tupel durch einen Worker
```

### Tabellenoptionen für Parallele Abfragen

```sql
-- Tabellen für parallele Abfragen optimieren
ALTER TABLE fact_sales SET (parallel_workers = 8);

-- Paralleles Einfügen aktivieren
ALTER TABLE fact_sales SET (parallel_tuple_target = 10000);
```

### Parallele Abfragen erzwingen/verhindern

```sql
-- Parallele Abfragen erzwingen
SET force_parallel_mode = on;

-- Parallelität für eine bestimmte Abfrage steuern
SET max_parallel_workers_per_gather = 4;
SELECT COUNT(*) FROM fact_sales WHERE sale_date > '2023-01-01';

-- Parallele Abfragen für bestimmte Operationen verhindern
SET max_parallel_workers_per_gather = 0;
-- Komplexe Abfrage ausführen...
RESET max_parallel_workers_per_gather;
```

## Partitionierung

### Partitionierungsstrategien

#### Bereichspartitionierung (Range)

```sql
-- Partitionierung nach Datum (zeitbasiert)
CREATE TABLE sales (
    id SERIAL,
    sale_date DATE,
    customer_id INT,
    amount NUMERIC(10,2)
) PARTITION BY RANGE (sale_date);

-- Monatliche Partitionen erstellen
CREATE TABLE sales_y2023m01 PARTITION OF sales
    FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');
CREATE TABLE sales_y2023m02 PARTITION OF sales
    FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');
-- Weitere Partitionen...
```

#### Listenpartitionierung (List)

```sql
-- Partitionierung nach diskreten Werten (z.B. Region)
CREATE TABLE customers (
    id SERIAL,
    name VARCHAR(100),
    region VARCHAR(50),
    address TEXT
) PARTITION BY LIST (region);

-- Regionale Partitionen erstellen
CREATE TABLE customers_europe PARTITION OF customers
    FOR VALUES IN ('Europe', 'EU', 'EMEA');
CREATE TABLE customers_asia PARTITION OF customers
    FOR VALUES IN ('Asia', 'APAC');
CREATE TABLE customers_americas PARTITION OF customers
    FOR VALUES IN ('North America', 'South America', 'LATAM', 'NA');
```

#### Hashpartitionierung (Hash)

```sql
-- Gleichmäßige Verteilung von Daten (z.B. nach Kunden-ID)
CREATE TABLE orders (
    id SERIAL,
    order_date DATE,
    customer_id INT,
    total_amount NUMERIC(12,2)
) PARTITION BY HASH (customer_id);

-- Hashpartitionen erstellen (z.B. 8 Partitionen)
CREATE TABLE orders_p0 PARTITION OF orders
    FOR VALUES WITH (MODULUS 8, REMAINDER 0);
CREATE TABLE orders_p1 PARTITION OF orders
    FOR VALUES WITH (MODULUS 8, REMAINDER 1);
-- Weitere Partitionen...
```

### Automatische Partitionserzeugung

Verwenden Sie unser Partitionierungstool:

```bash
scripts/maintenance/create_partitions.py \
  --table sales \
  --type range \
  --column sale_date \
  --interval month \
  --format "sales_y%Ym%m" \
  --start "2023-01-01" \
  --end "2023-12-31"
```

### Partitionen verwalten

```sql
-- Alte Partition abtrennen
ALTER TABLE sales DETACH PARTITION sales_y2022m01;

-- Partition archivieren oder löschen
DROP TABLE sales_y2022m01;
-- ODER
-- Partition in kältere Speicherebene verschieben
-- (benötigt entsprechende Tablespace-Konfiguration)
ALTER TABLE sales_y2022m01 SET TABLESPACE cold_storage;

-- Neue Partition hinzufügen
CREATE TABLE sales_y2024m01 PARTITION OF sales
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

## Columnar Storage

### Tabellen für Columnar Storage einrichten

```sql
-- Neue Tabelle mit Columnar Storage erstellen
CREATE TABLE analytics_data (
    id SERIAL,
    event_date TIMESTAMP,
    customer_id INT,
    event_type VARCHAR(50),
    metrics JSONB,
    dimensions VARCHAR(255)
) USING columnar;

-- Vorhandene Tabelle zu Columnar konvertieren
CREATE TABLE analytics_data_columnar USING columnar AS 
SELECT * FROM analytics_data_row;
```

### Columnar-Kompressionseinstellungen

```sql
-- Optimierte Kompressionseinstellungen für analytische Tabellen
ALTER TABLE analytics_data 
SET (columnar.compression = 'zstd');

-- Kompressionsgrad anpassen (höhere Werte = stärkere Kompression, langsamere Verarbeitung)
ALTER TABLE analytics_data 
SET (columnar.compression_level = 3);

-- Stripesize anpassen (Anzahl der Zeilen pro Stripe)
ALTER TABLE analytics_data 
SET (columnar.stripe_row_limit = 10000);
```

### Columnar-Wartung

```sql
-- Fragmentierte Columnar-Tabelle reorganisieren
VACUUM FULL analytics_data;

-- Columnar-Statistiken aktualisieren
ANALYZE analytics_data;
```

## Materialisierte Sichten

### Strategien für materialisierte Sichten

```sql
-- Materialisierte Sicht für häufig angefragte Aggregationen
CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT 
    date_trunc('day', sale_date) AS day,
    product_id,
    SUM(quantity) AS total_quantity,
    SUM(revenue) AS total_revenue
FROM fact_sales
GROUP BY 1, 2;

-- Index auf materialisierte Sicht
CREATE INDEX idx_mv_daily_sales_day ON mv_daily_sales(day);
CREATE INDEX idx_mv_daily_sales_product ON mv_daily_sales(product_id);
```

### Aktualisierung materialisierter Sichten

```sql
-- Vollständige Aktualisierung
REFRESH MATERIALIZED VIEW mv_daily_sales;

-- Inkrementelle Aktualisierung (benötigt Primärschlüssel)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_sales;
```

### Automatische Aktualisierungen planen

```sql
-- Beispiel-Funktion für die Aktualisierung
CREATE OR REPLACE FUNCTION refresh_materialized_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_sales;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales;
    -- Weitere materialisierte Sichten...
END;
$$ LANGUAGE plpgsql;

-- In pg_cron registrieren (erfordert pg_cron-Erweiterung)
SELECT cron.schedule('0 3 * * *', 'SELECT refresh_materialized_views()');
```

## Wartung und Monitoring

### Regelmäßige Wartung

```sql
-- Tägliche Wartungsaufgaben
VACUUM ANALYZE;

-- Wöchentliche Aufgaben
REINDEX DATABASE exapg;

-- Monatliche Aufgaben
VACUUM FULL;
```

### Leistungsüberwachung

Verwenden Sie unsere Grafana-Dashboards zur Leistungsüberwachung:

1. **ExaPG-Übersichtsdashboard**: Allgemeine Datenbankmetriken
2. **ExaPG-Abfrage-Dashboard**: Analyse langsamer Abfragen
3. **ExaPG-Ressourcen-Dashboard**: CPU-, Speicher- und I/O-Auslastung

### Query-Performance-Tracking

```sql
-- pg_stat_statements-Erweiterung aktivieren
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Langsame Abfragen identifizieren
SELECT 
    query,
    calls,
    total_time / 1000 AS total_seconds,
    total_time / calls / 1000 AS avg_seconds,
    rows / calls AS avg_rows,
    100 * shared_blks_hit / (shared_blks_hit + shared_blks_read) AS hit_percent
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 20;

-- Statistiken zurücksetzen
SELECT pg_stat_statements_reset();
```

### Automatisierte Leistungsoptimierung

```sql
-- Tabellen-Statistiken aktualisieren
ANALYZE fact_sales;

-- Index-Nutzung überwachen
SELECT 
    schemaname, relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes 
JOIN pg_statio_user_indexes USING (indexrelid)
ORDER BY idx_scan DESC;

-- Ungenutzte Indizes identifizieren
SELECT 
    schemaname, relname, indexrelname
FROM pg_stat_user_indexes 
WHERE idx_scan = 0 AND indexrelname NOT LIKE 'pg_%';
```

## Verteilte Abfragen mit Citus

### Distributed Tables konfigurieren

```sql
-- Citus-Erweiterung aktivieren
CREATE EXTENSION citus;

-- Distributionsschlüssel festlegen und Tabelle verteilen
SELECT create_distributed_table('fact_sales', 'tenant_id');

-- Referenztabellen für Dimensionsdaten (auf allen Knoten repliziert)
SELECT create_reference_table('dim_products');
```

### Sharding-Strategien

```sql
-- Sharding nach Mandant (für Multi-Tenant-Anwendungen)
SELECT create_distributed_table('customer_data', 'tenant_id');

-- Sharding nach Zeitraum (für Zeitreihendaten)
SELECT create_distributed_table('time_series_data', 'time_bucket');

-- Kolokalität von Tabellen für effiziente Joins sicherstellen
SELECT create_distributed_table('orders', 'customer_id');
SELECT create_distributed_table('order_items', 'customer_id');
```

### Verteilte Abfragen optimieren

```sql
-- Ausführungsplan für verteilte Abfrage anzeigen
EXPLAIN SELECT * 
FROM fact_sales fs 
JOIN dim_products dp ON fs.product_id = dp.product_id
WHERE fs.sale_date >= '2023-01-01';

-- Statistiken für den Citus-Planer aktualisieren
SELECT citus_update_node_statistics();

-- Anzahl der parallelisierten Tasks für einen Knoten ändern
SET citus.max_adaptive_executor_pool_size = 16;
```

## Wartungs- und Optimierungsskripte

### Übersicht der verfügbaren Wartungsskripte

| Skript | Beschreibung | Empfohlene Häufigkeit |
|--------|--------------|----------------------|
| `scripts/maintenance/analyze_tables.sh` | Statistiken aller Tabellen aktualisieren | Täglich |
| `scripts/maintenance/optimize_indexes.sh` | Indexoptimierung durchführen | Wöchentlich |
| `scripts/maintenance/create_partitions.py` | Zukünftige Partitionen erstellen | Monatlich |
| `scripts/maintenance/query_advisor.py` | Empfehlungen für langsame Abfragen | Nach Bedarf |
| `scripts/maintenance/check_bloat.sh` | Prüfen auf aufgeblähte Tabellen und Indizes | Wöchentlich |
| `scripts/maintenance/vacuum_full_scheduler.py` | VACUUM FULL-Operationen planen | Monatlich |

### Einrichtung automatisierter Wartung

```bash
# Cron-Jobs für regelmäßige Wartung einrichten
(crontab -l ; echo "0 1 * * * /path/to/exapg/scripts/maintenance/analyze_tables.sh") | crontab -
(crontab -l ; echo "0 2 * * 0 /path/to/exapg/scripts/maintenance/optimize_indexes.sh") | crontab -
(crontab -l ; echo "0 3 1 * * /path/to/exapg/scripts/maintenance/create_partitions.py --advance-months=3") | crontab -
```

## Migrationsoptimierung

Spezielle Leistungsoptimierungen für Anwender, die von anderen analytischen Datenbanken zu ExaPG migrieren.

### Von Exasol zu ExaPG

```sql
-- Columnar Storage für Exasol DISTRIBUTE BY-Tabellen
CREATE TABLE sales (
    id INT,
    sale_date DATE,
    product_id INT,
    amount NUMERIC(10,2)
) USING columnar PARTITION BY RANGE (sale_date);

-- Kompression einstellen (vergleichbar mit Exasol)
ALTER TABLE sales SET (columnar.compression = 'zstd', columnar.compression_level = 3);

-- Berechtigungen für Analytics-Benutzer (vergleichbar mit Exasol-Rollen)
CREATE ROLE analytics_users;
GRANT USAGE ON SCHEMA analytics TO analytics_users;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO analytics_users;
```

### Von Redshift zu ExaPG

```sql
-- DISTKEY-ähnliche Verteilung in Citus
SELECT create_distributed_table('sales', 'customer_id');

-- SORTKEY-ähnliche Optimierung mit Indizes
CREATE INDEX idx_sales_date ON sales(sale_date, product_id);

-- Parallel-Verarbeitung wie bei Redshift
ALTER TABLE sales SET (parallel_workers = 8);
``` 