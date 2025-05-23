-- Teil 2: Performance-Vergleiche für verschiedene Abfragetypen
\timing on

-- 1. Performance-Vergleich: Abfrage von Spalten (besser für columnar)
\echo '--- Performance-Vergleich: Abfrage einzelner Spalten ---'
\echo 'Spaltenorientiert:'
EXPLAIN ANALYZE SELECT AVG(temperature), MIN(temperature), MAX(temperature) FROM columnar_data.sensor_measurements;

\echo 'Zeilenorientiert:'
EXPLAIN ANALYZE SELECT AVG(temperature), MIN(temperature), MAX(temperature) FROM row_data.sensor_measurements;

-- 2. Performance-Vergleich: Abfrage aller Spalten (besser für row)
\echo '--- Performance-Vergleich: Abfrage aller Spalten ---'
\echo 'Spaltenorientiert:'
EXPLAIN ANALYZE SELECT * FROM columnar_data.sensor_measurements LIMIT 1000;

\echo 'Zeilenorientiert:'
EXPLAIN ANALYZE SELECT * FROM row_data.sensor_measurements LIMIT 1000;

-- 3. Performance-Vergleich: Aggregation mit Gruppierung
\echo '--- Performance-Vergleich: Aggregation mit Gruppierung ---'
\echo 'Spaltenorientiert:'
EXPLAIN ANALYZE
SELECT 
    service_name,
    log_level,
    DATE_TRUNC('day', timestamp) AS day,
    COUNT(*) AS log_count,
    AVG(execution_time_ms) AS avg_execution_time
FROM columnar_data.system_logs
GROUP BY service_name, log_level, DATE_TRUNC('day', timestamp)
ORDER BY day, service_name, log_level;

\echo 'Zeilenorientiert:'
EXPLAIN ANALYZE
SELECT 
    service_name,
    log_level,
    DATE_TRUNC('day', timestamp) AS day,
    COUNT(*) AS log_count,
    AVG(execution_time_ms) AS avg_execution_time
FROM row_data.system_logs
GROUP BY service_name, log_level, DATE_TRUNC('day', timestamp)
ORDER BY day, service_name, log_level;

-- 4. Performance-Vergleich: Join-Operation
\echo '--- Performance-Vergleich: Join-Operation ---'
\echo 'Spaltenorientiert:'
EXPLAIN ANALYZE
SELECT 
    p.category,
    SUM(s.quantity) AS total_quantity,
    SUM(s.total_price) AS total_sales,
    AVG(s.unit_price) AS avg_unit_price
FROM columnar_data.sales_fact s
JOIN columnar_data.dim_product p ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY total_sales DESC;

\echo 'Zeilenorientiert:'
EXPLAIN ANALYZE
SELECT 
    p.category,
    SUM(s.quantity) AS total_quantity,
    SUM(s.total_price) AS total_sales,
    AVG(s.unit_price) AS avg_unit_price
FROM row_data.sales_fact s
JOIN columnar_data.dim_product p ON s.product_id = p.product_id
GROUP BY p.category
ORDER BY total_sales DESC;

-- 5. Performance-Vergleich: Filterung
\echo '--- Performance-Vergleich: Filterung ---'
\echo 'Spaltenorientiert:'
EXPLAIN ANALYZE
SELECT 
    sale_date,
    COUNT(*) AS sale_count,
    SUM(total_price) AS daily_revenue
FROM columnar_data.sales_fact
WHERE sale_date > (CURRENT_DATE - INTERVAL '1 year')
AND payment_method = 'Kreditkarte'
GROUP BY sale_date
ORDER BY sale_date;

\echo 'Zeilenorientiert:'
EXPLAIN ANALYZE
SELECT 
    sale_date,
    COUNT(*) AS sale_count,
    SUM(total_price) AS daily_revenue
FROM row_data.sales_fact
WHERE sale_date > (CURRENT_DATE - INTERVAL '1 year')
AND payment_method = 'Kreditkarte'
GROUP BY sale_date
ORDER BY sale_date;

\timing off 