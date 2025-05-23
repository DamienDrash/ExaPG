-- SQL-Skript zum Erstellen und Befüllen spaltenorientierter Tabellen
-- Diese Tabellen nutzen die Citus Columnar-Erweiterung für verbesserte analytische Performance

-- Schema für spaltenorientierte Daten
CREATE SCHEMA IF NOT EXISTS columnar_data;

-- 1. Faktentabelle für Verkäufe (columnar)
CREATE TABLE columnar_data.sales_fact (
    sale_id BIGSERIAL,
    sale_date DATE NOT NULL,
    customer_id INTEGER,
    product_id INTEGER,
    store_id INTEGER,
    promotion_id INTEGER,
    quantity INTEGER,
    unit_price NUMERIC(10,2),
    discount NUMERIC(10,2),
    total_price NUMERIC(10,2),
    profit NUMERIC(10,2),
    return_flag BOOLEAN,
    payment_method VARCHAR(20),
    delivery_type VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW()
) USING columnar;

-- 2. Zeitreihendaten für Sensoren (columnar)
CREATE TABLE columnar_data.sensor_measurements (
    measurement_id BIGSERIAL,
    sensor_id INTEGER NOT NULL,
    measurement_time TIMESTAMPTZ NOT NULL,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION,
    pressure DOUBLE PRECISION,
    wind_speed DOUBLE PRECISION,
    battery_level DOUBLE PRECISION,
    status VARCHAR(20),
    location_id INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
) USING columnar;

-- 3. Protokolltabelle für Systemereignisse (columnar)
CREATE TABLE columnar_data.system_logs (
    log_id BIGSERIAL,
    timestamp TIMESTAMPTZ NOT NULL,
    log_level VARCHAR(10),
    service_name VARCHAR(50),
    host VARCHAR(100),
    message TEXT,
    error_code VARCHAR(20),
    user_id INTEGER,
    session_id VARCHAR(50),
    request_id VARCHAR(50),
    execution_time_ms INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
) USING columnar;

-- 4. Dimensionstabellen (gewöhnliche Tabellen, da sie klein sind und oft für Lookups verwendet werden)
CREATE TABLE columnar_data.dim_product (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    subcategory VARCHAR(50),
    brand VARCHAR(50),
    supplier_id INTEGER,
    unit_cost NUMERIC(10,2),
    retail_price NUMERIC(10,2),
    weight_kg NUMERIC(5,2),
    is_active BOOLEAN
);

CREATE TABLE columnar_data.dim_customer (
    customer_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(50),
    country VARCHAR(50),
    postal_code VARCHAR(20),
    segment VARCHAR(20),
    registration_date DATE
);

-- Erstelle Indexe auf Dimensionstabellen für schnelle Joins
CREATE INDEX idx_product_category ON columnar_data.dim_product(category);
CREATE INDEX idx_customer_city ON columnar_data.dim_customer(city);

-- Beispieldaten einfügen
-- Einfügen von 100 Produkten
INSERT INTO columnar_data.dim_product (product_name, category, subcategory, brand, supplier_id, unit_cost, retail_price, weight_kg, is_active)
SELECT
    'Produkt ' || i,
    CASE WHEN i % 5 = 0 THEN 'Elektronik'
         WHEN i % 5 = 1 THEN 'Kleidung'
         WHEN i % 5 = 2 THEN 'Lebensmittel'
         WHEN i % 5 = 3 THEN 'Möbel'
         ELSE 'Bücher' END,
    CASE WHEN i % 3 = 0 THEN 'Premium'
         WHEN i % 3 = 1 THEN 'Standard'
         ELSE 'Budget' END,
    'Marke ' || (i % 10 + 1),
    (i % 20) + 1,
    (random() * 100)::numeric(10,2),
    (random() * 200)::numeric(10,2),
    (random() * 10)::numeric(5,2),
    i % 10 != 0
FROM generate_series(1, 100) i;

-- Einfügen von 50 Kunden
INSERT INTO columnar_data.dim_customer (customer_name, email, phone, address, city, country, postal_code, segment, registration_date)
SELECT
    'Kunde ' || i,
    'kunde' || i || '@example.com',
    '123-456-' || lpad(i::text, 4, '0'),
    'Straße ' || i,
    CASE WHEN i % 5 = 0 THEN 'Berlin'
         WHEN i % 5 = 1 THEN 'Hamburg'
         WHEN i % 5 = 2 THEN 'München'
         WHEN i % 5 = 3 THEN 'Köln'
         ELSE 'Frankfurt' END,
    'Deutschland',
    (10000 + i)::text,
    CASE WHEN i % 3 = 0 THEN 'Privat'
         WHEN i % 3 = 1 THEN 'Geschäft'
         ELSE 'Bildung' END,
    current_date - (i % 365 * '1 day'::interval)
FROM generate_series(1, 50) i;

-- Einfügen von 10.000 Verkaufsdatensätzen in die Faktentabelle
INSERT INTO columnar_data.sales_fact (
    sale_date, customer_id, product_id, store_id, promotion_id, 
    quantity, unit_price, discount, total_price, profit, 
    return_flag, payment_method, delivery_type
)
SELECT
    current_date - ((random() * 365 * 2)::int || ' days')::interval,
    (random() * 49 + 1)::int,
    (random() * 99 + 1)::int,
    (random() * 9 + 1)::int,
    CASE WHEN random() < 0.3 THEN (random() * 5 + 1)::int ELSE NULL END,
    (random() * 5 + 1)::int,
    (random() * 100 + 10)::numeric(10,2),
    CASE WHEN random() < 0.2 THEN (random() * 20)::numeric(10,2) ELSE 0 END,
    (random() * 500 + 50)::numeric(10,2),
    (random() * 100)::numeric(10,2),
    random() < 0.05,
    CASE WHEN random() < 0.6 THEN 'Kreditkarte'
         WHEN random() < 0.8 THEN 'PayPal'
         ELSE 'Überweisung' END,
    CASE WHEN random() < 0.7 THEN 'Standard'
         WHEN random() < 0.9 THEN 'Express'
         ELSE 'Abholung' END
FROM generate_series(1, 10000) i;

-- Einfügen von 20.000 Sensormessungen
INSERT INTO columnar_data.sensor_measurements (
    sensor_id, measurement_time, temperature, humidity, pressure, 
    wind_speed, battery_level, status, location_id
)
SELECT
    (i % 20) + 1,
    now() - ((random() * 30)::int || ' days')::interval - ((random() * 24)::int || ' hours')::interval,
    20.0 + (random() * 15.0) - 5.0,
    40.0 + (random() * 40.0),
    1000.0 + (random() * 50.0) - 25.0,
    random() * 30.0,
    60.0 + (random() * 40.0),
    CASE WHEN random() < 0.9 THEN 'Active' ELSE 'Maintenance' END,
    (random() * 9 + 1)::int
FROM generate_series(1, 20000) i;

-- Einfügen von 5.000 Systemprotokollen
INSERT INTO columnar_data.system_logs (
    timestamp, log_level, service_name, host, 
    message, error_code, user_id, session_id, 
    request_id, execution_time_ms
)
SELECT
    now() - ((random() * 7)::int || ' days')::interval - ((random() * 24)::int || ' hours')::interval,
    CASE WHEN random() < 0.7 THEN 'INFO'
         WHEN random() < 0.9 THEN 'WARN'
         ELSE 'ERROR' END,
    CASE WHEN i % 5 = 0 THEN 'web-server'
         WHEN i % 5 = 1 THEN 'database'
         WHEN i % 5 = 2 THEN 'auth-service'
         WHEN i % 5 = 3 THEN 'payment-processor'
         ELSE 'analytics-engine' END,
    'server-' || (i % 10 + 1),
    'System log message ' || i,
    CASE WHEN random() < 0.1 THEN 'ERR' || (random() * 1000)::int ELSE NULL END,
    CASE WHEN random() < 0.8 THEN (random() * 100)::int ELSE NULL END,
    'sess-' || lpad((random() * 10000)::int::text, 8, '0'),
    'req-' || lpad((random() * 1000000)::int::text, 10, '0'),
    (random() * 1000)::int
FROM generate_series(1, 5000) i;

-- Anzeigen der Tabellengröße und des Kompressionsverhältnisses
\echo 'Informationen über spaltenorientierte Tabellen:'
SELECT
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(oid)) AS total_size,
    pg_size_pretty(pg_relation_size(oid)) AS table_size,
    pg_size_pretty(pg_total_relation_size(oid) - pg_relation_size(oid)) AS index_size,
    reltuples::bigint AS row_count
FROM pg_class
WHERE relname LIKE 'sales_fact' OR relname LIKE 'sensor_measurements' OR relname LIKE 'system_logs'
ORDER BY pg_total_relation_size(oid) DESC; 