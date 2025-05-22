-- Teil 1: Vorbereitung und Speicherverbrauch-Vergleich
\timing on

-- 1. Erstelle identische Tabellen im row-basierten Format für den Vergleich
CREATE SCHEMA IF NOT EXISTS row_data;

-- Tabellen mit identischer Struktur wie die spaltenorientierten Tabellen
CREATE TABLE row_data.sales_fact (LIKE columnar_data.sales_fact);
CREATE TABLE row_data.sensor_measurements (LIKE columnar_data.sensor_measurements);
CREATE TABLE row_data.system_logs (LIKE columnar_data.system_logs);

-- Kopiere die Daten aus den columnar-Tabellen
INSERT INTO row_data.sales_fact SELECT * FROM columnar_data.sales_fact;
INSERT INTO row_data.sensor_measurements SELECT * FROM columnar_data.sensor_measurements;
INSERT INTO row_data.system_logs SELECT * FROM columnar_data.system_logs;

-- 2. Größenvergleich zwischen columnar und row-basiertem Format
\echo '--- Vergleich des Speicherverbrauchs ---'
WITH columnar_tables AS (
    SELECT 
        'columnar' AS storage_type,
        relname,
        pg_total_relation_size(c.oid) AS total_size
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'columnar_data'
    AND c.relkind = 'r'
),
row_tables AS (
    SELECT 
        'row' AS storage_type,
        relname,
        pg_total_relation_size(c.oid) AS total_size
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'row_data'
    AND c.relkind = 'r'
)
SELECT 
    c.relname AS table_name,
    pg_size_pretty(c.total_size) AS columnar_size,
    pg_size_pretty(r.total_size) AS row_size,
    ROUND((r.total_size::numeric / NULLIF(c.total_size, 0)), 2) AS compression_ratio
FROM columnar_tables c
JOIN row_tables r ON c.relname = r.relname
ORDER BY compression_ratio DESC;

-- 3. Optimierung der Kompressionsstrategie: Analyze für bessere Statistiken
ANALYZE columnar_data.sales_fact;
ANALYZE columnar_data.sensor_measurements;
ANALYZE columnar_data.system_logs;

-- 4. Informationen über die columnar-Tabellen
\echo '--- Detaillierte Informationen über columnar-Tabellen ---'
SELECT 
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    pg_size_pretty(pg_relation_size(c.oid)) AS table_size,
    (pg_stat_get_numscans(c.oid)) AS sequential_scans,
    c.reltuples AS estimated_row_count
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'columnar_data'
AND c.relkind = 'r'; 