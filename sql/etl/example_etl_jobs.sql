-- ExaPG - ETL-Framework Beispiel-ETL-Jobs
-- SQL-Skript mit Beispiel-ETL-Jobs für das ETL-Framework

-- Erstelle Testschemas und -tabellen
CREATE SCHEMA IF NOT EXISTS source_data;
CREATE SCHEMA IF NOT EXISTS target_data;

-- Erstelle eine Quelltabelle für Kundendaten
CREATE TABLE IF NOT EXISTS source_data.customers (
    customer_id SERIAL PRIMARY KEY,
    customer_number VARCHAR(50) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(50),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Erstelle eine Quelltabelle für Bestellungen
CREATE TABLE IF NOT EXISTS source_data.orders (
    order_id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    customer_id INTEGER REFERENCES source_data.customers(customer_id),
    order_date TIMESTAMP WITH TIME ZONE NOT NULL,
    ship_date TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    tax_amount DECIMAL(10, 2) NOT NULL,
    shipping_amount DECIMAL(10, 2) NOT NULL,
    discount_amount DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Erstelle eine Quelltabelle für Bestellpositionen
CREATE TABLE IF NOT EXISTS source_data.order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES source_data.orders(order_id),
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Füge Beispieldaten in die Quelltabellen ein
INSERT INTO source_data.customers 
    (customer_number, first_name, last_name, email, phone, address_line1, city, postal_code, country)
VALUES
    ('C001', 'Max', 'Mustermann', 'max.mustermann@example.com', '+4930123456', 'Hauptstr. 1', 'Berlin', '10115', 'Deutschland'),
    ('C002', 'Anna', 'Schmidt', 'anna.schmidt@example.com', '+4989987654', 'Marienplatz 2', 'München', '80331', 'Deutschland'),
    ('C003', 'Hans', 'Müller', 'hans.mueller@example.com', '+4940112233', 'Reeperbahn 3', 'Hamburg', '20359', 'Deutschland');

INSERT INTO source_data.orders
    (order_number, customer_id, order_date, status, total_amount, tax_amount, shipping_amount, discount_amount)
VALUES
    ('ORD-001', 1, NOW() - INTERVAL '10 days', 'COMPLETED', 150.00, 28.50, 4.99, 0.00),
    ('ORD-002', 1, NOW() - INTERVAL '5 days', 'SHIPPED', 75.50, 14.35, 4.99, 10.00),
    ('ORD-003', 2, NOW() - INTERVAL '2 days', 'PROCESSING', 210.85, 40.06, 0.00, 20.00),
    ('ORD-004', 3, NOW() - INTERVAL '1 day', 'PENDING', 50.00, 9.50, 4.99, 0.00);

INSERT INTO source_data.order_items
    (order_id, product_id, quantity, unit_price, total_price)
VALUES
    (1, 101, 2, 49.99, 99.98),
    (1, 102, 1, 50.02, 50.02),
    (2, 103, 1, 75.50, 75.50),
    (3, 104, 3, 59.95, 179.85),
    (3, 105, 1, 31.00, 31.00),
    (4, 106, 2, 25.00, 50.00);

-- Erstelle einen ETL-Job für Kundendaten
SELECT etl_framework.register_etl_job(
    'customer_data_etl',
    'ETL-Job zum Laden der Kundendaten aus der Quelldatenbank',
    'database',
    jsonb_build_object(
        'host', 'localhost',
        'port', '5432',
        'database', current_database(),
        'user', current_user,
        'schema', 'source_data',
        'table', 'customers'
    ),
    'target_data',
    'dim_customers',
    'SELECT
        customer_id,
        customer_number,
        first_name,
        last_name,
        email,
        COALESCE(phone, ''N/A'') as phone,
        address_line1,
        address_line2,
        city,
        state,
        postal_code,
        country,
        created_at,
        updated_at
    FROM source_data.customers',
    4,  -- parallel_workers
    1000, -- batch_size
    TRUE, -- is_incremental
    'updated_at', -- incremental_column
    ARRAY['customers', 'dimension', 'demographics']
);

-- Füge Spaltenmappings für Kundendaten hinzu
DO $$
DECLARE
    v_job_id INTEGER;
BEGIN
    -- Hole die Job-ID
    SELECT job_id INTO v_job_id FROM etl_framework.etl_jobs WHERE job_name = 'customer_data_etl';
    
    -- Füge Spaltenmappings hinzu
    PERFORM etl_framework.add_column_mapping(v_job_id, 'customer_id', 'customer_key', 'INTEGER', NULL, TRUE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'customer_number', 'customer_number', 'VARCHAR(50)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'first_name', 'first_name', 'VARCHAR(100)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'last_name', 'last_name', 'VARCHAR(100)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'email', 'email_address', 'VARCHAR(255)', NULL, FALSE, TRUE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'phone', 'phone_number', 'VARCHAR(50)', NULL, FALSE, TRUE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'address_line1', 'address_line1', 'VARCHAR(255)', NULL, FALSE, TRUE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'address_line2', 'address_line2', 'VARCHAR(255)', NULL, FALSE, TRUE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'city', 'city', 'VARCHAR(100)', NULL, FALSE, TRUE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'state', 'state_province', 'VARCHAR(100)', NULL, FALSE, TRUE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'postal_code', 'postal_code', 'VARCHAR(20)', NULL, FALSE, TRUE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'country', 'country', 'VARCHAR(100)', NULL, FALSE, TRUE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'created_at', 'created_at', 'TIMESTAMP WITH TIME ZONE', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'updated_at', 'updated_at', 'TIMESTAMP WITH TIME ZONE', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, NULL, 'etl_batch_id', 'INTEGER', 'etl_framework.get_current_batch_id()', FALSE, FALSE, '0');
    PERFORM etl_framework.add_column_mapping(v_job_id, NULL, 'etl_updated_at', 'TIMESTAMP WITH TIME ZONE', 'CURRENT_TIMESTAMP', FALSE, FALSE);
    
    -- Erstelle die Zieltabelle
    PERFORM etl_framework.create_target_table(v_job_id, TRUE);
    
    -- Füge Datenqualitätsprüfungen hinzu
    PERFORM etl_framework.add_data_quality_check(
        v_job_id,
        'check_null_emails',
        'null_check',
        'SELECT COUNT(*) FROM {target_schema}.{target_table} WHERE email_address IS NULL',
        'WARNING',
        10.0  -- Maximal 10% dürfen NULL sein
    );
    
    PERFORM etl_framework.add_data_quality_check(
        v_job_id,
        'check_unique_customers',
        'unique_check',
        'SELECT COUNT(*) FROM (SELECT customer_number FROM {target_schema}.{target_table} GROUP BY customer_number HAVING COUNT(*) > 1) t',
        'ERROR',
        0.0  -- Es dürfen keine Duplikate existieren
    );
    
    PERFORM etl_framework.add_data_quality_check(
        v_job_id,
        'check_valid_email_format',
        'regex_check',
        'SELECT COUNT(*) FROM {target_schema}.{target_table} WHERE email_address IS NOT NULL AND email_address !~ ''^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$''',
        'ERROR',
        0.0  -- Alle E-Mails müssen dem Format entsprechen
    );
END $$;

-- Erstelle einen ETL-Job für Bestellungen (mit CDC-Konfiguration)
SELECT etl_framework.register_etl_job(
    'orders_data_etl',
    'ETL-Job zum Laden der Bestelldaten aus der Quelldatenbank mit CDC',
    'database',
    jsonb_build_object(
        'host', 'localhost',
        'port', '5432',
        'database', current_database(),
        'user', current_user,
        'schema', 'source_data',
        'table', 'orders'
    ),
    'target_data',
    'fact_orders',
    'SELECT 
        o.order_id,
        o.order_number,
        o.customer_id,
        c.customer_number,
        o.order_date,
        o.ship_date,
        o.status,
        o.total_amount,
        o.tax_amount,
        o.shipping_amount,
        o.discount_amount,
        (o.total_amount - o.discount_amount) as net_amount,
        o.created_at,
        o.updated_at
    FROM source_data.orders o
    JOIN source_data.customers c ON o.customer_id = c.customer_id',
    4,  -- parallel_workers
    1000, -- batch_size
    TRUE, -- is_incremental
    'updated_at', -- incremental_column
    ARRAY['orders', 'fact', 'sales']
);

-- Füge Spaltenmappings für Bestelldaten hinzu und aktiviere CDC
DO $$
DECLARE
    v_job_id INTEGER;
BEGIN
    -- Hole die Job-ID
    SELECT job_id INTO v_job_id FROM etl_framework.etl_jobs WHERE job_name = 'orders_data_etl';
    
    -- Füge Spaltenmappings hinzu
    PERFORM etl_framework.add_column_mapping(v_job_id, 'order_id', 'order_key', 'INTEGER', NULL, TRUE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'order_number', 'order_number', 'VARCHAR(50)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'customer_id', 'customer_id', 'INTEGER', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'customer_number', 'customer_number', 'VARCHAR(50)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'order_date', 'order_date', 'TIMESTAMP WITH TIME ZONE', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'ship_date', 'ship_date', 'TIMESTAMP WITH TIME ZONE', NULL, FALSE, TRUE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'status', 'order_status', 'VARCHAR(50)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'total_amount', 'total_amount', 'DECIMAL(10, 2)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'tax_amount', 'tax_amount', 'DECIMAL(10, 2)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'shipping_amount', 'shipping_amount', 'DECIMAL(10, 2)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'discount_amount', 'discount_amount', 'DECIMAL(10, 2)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'net_amount', 'net_amount', 'DECIMAL(10, 2)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'created_at', 'created_at', 'TIMESTAMP WITH TIME ZONE', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'updated_at', 'updated_at', 'TIMESTAMP WITH TIME ZONE', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, NULL, 'etl_batch_id', 'INTEGER', 'etl_framework.get_current_batch_id()', FALSE, FALSE, '0');
    PERFORM etl_framework.add_column_mapping(v_job_id, NULL, 'etl_updated_at', 'TIMESTAMP WITH TIME ZONE', 'CURRENT_TIMESTAMP', FALSE, FALSE);
    
    -- Erstelle die Zieltabelle
    PERFORM etl_framework.create_target_table(v_job_id, TRUE);
    
    -- Aktiviere CDC für diesen ETL-Job
    PERFORM etl_framework.enable_cdc(
        v_job_id,
        'orders_cdc_connector',
        'orders_changes'
    );
    
    -- Füge Datenqualitätsprüfungen hinzu
    PERFORM etl_framework.add_data_quality_check(
        v_job_id,
        'check_order_total',
        'custom_sql',
        'SELECT COUNT(*) FROM {target_schema}.{target_table} WHERE net_amount <= 0',
        'ERROR',
        0.0  -- Keine Bestellungen mit Nettobeträgen <= 0 erlaubt
    );
    
    PERFORM etl_framework.add_data_quality_check(
        v_job_id,
        'check_missing_customer_id',
        'null_check',
        'SELECT COUNT(*) FROM {target_schema}.{target_table} WHERE customer_id IS NULL',
        'ERROR',
        0.0  -- Keine Bestellungen ohne Kundenbezug erlaubt
    );
    
    PERFORM etl_framework.add_data_quality_check(
        v_job_id,
        'check_ship_date_after_order_date',
        'custom_sql',
        'SELECT COUNT(*) FROM {target_schema}.{target_table} WHERE ship_date IS NOT NULL AND ship_date < order_date',
        'ERROR',
        0.0  -- Versanddatum muss nach Bestelldatum liegen
    );
END $$;

-- Erstelle einen ETL-Job für denormalisierte Bestellpositionen
SELECT etl_framework.register_etl_job(
    'order_items_data_etl',
    'ETL-Job zum Laden der Bestellpositionsdaten in eine denormalisierte Form',
    'database',
    jsonb_build_object(
        'host', 'localhost',
        'port', '5432',
        'database', current_database(),
        'user', current_user,
        'schema', 'source_data',
        'table', 'order_items'
    ),
    'target_data',
    'fact_order_items',
    'SELECT 
        oi.order_item_id,
        oi.order_id,
        o.order_number,
        o.customer_id,
        c.customer_number,
        c.first_name,
        c.last_name,
        o.order_date,
        o.status as order_status,
        oi.product_id,
        oi.quantity,
        oi.unit_price,
        oi.total_price,
        o.tax_amount * (oi.total_price / o.total_amount) as item_tax_amount,
        oi.created_at
    FROM source_data.order_items oi
    JOIN source_data.orders o ON oi.order_id = o.order_id
    JOIN source_data.customers c ON o.customer_id = c.customer_id',
    4,  -- parallel_workers
    1000, -- batch_size
    TRUE, -- is_incremental
    'created_at', -- incremental_column
    ARRAY['order_items', 'fact', 'sales']
);

-- Füge Spaltenmappings für Bestellpositionsdaten hinzu
DO $$
DECLARE
    v_job_id INTEGER;
BEGIN
    -- Hole die Job-ID
    SELECT job_id INTO v_job_id FROM etl_framework.etl_jobs WHERE job_name = 'order_items_data_etl';
    
    -- Füge Spaltenmappings hinzu
    PERFORM etl_framework.add_column_mapping(v_job_id, 'order_item_id', 'order_item_key', 'INTEGER', NULL, TRUE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'order_id', 'order_id', 'INTEGER', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'order_number', 'order_number', 'VARCHAR(50)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'customer_id', 'customer_id', 'INTEGER', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'customer_number', 'customer_number', 'VARCHAR(50)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'first_name', 'customer_first_name', 'VARCHAR(100)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'last_name', 'customer_last_name', 'VARCHAR(100)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'order_date', 'order_date', 'TIMESTAMP WITH TIME ZONE', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'order_status', 'order_status', 'VARCHAR(50)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'product_id', 'product_id', 'INTEGER', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'quantity', 'quantity', 'INTEGER', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'unit_price', 'unit_price', 'DECIMAL(10, 2)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'total_price', 'total_price', 'DECIMAL(10, 2)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'item_tax_amount', 'tax_amount', 'DECIMAL(10, 2)', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, 'created_at', 'created_at', 'TIMESTAMP WITH TIME ZONE', NULL, FALSE, FALSE);
    PERFORM etl_framework.add_column_mapping(v_job_id, NULL, 'etl_batch_id', 'INTEGER', 'etl_framework.get_current_batch_id()', FALSE, FALSE, '0');
    PERFORM etl_framework.add_column_mapping(v_job_id, NULL, 'etl_updated_at', 'TIMESTAMP WITH TIME ZONE', 'CURRENT_TIMESTAMP', FALSE, FALSE);
    
    -- Erstelle die Zieltabelle
    PERFORM etl_framework.create_target_table(v_job_id, TRUE);
    
    -- Füge Datenqualitätsprüfungen hinzu
    PERFORM etl_framework.add_data_quality_check(
        v_job_id,
        'check_quantity',
        'custom_sql',
        'SELECT COUNT(*) FROM {target_schema}.{target_table} WHERE quantity <= 0',
        'ERROR',
        0.0  -- Keine Positionen mit Mengen <= 0 erlaubt
    );
    
    PERFORM etl_framework.add_data_quality_check(
        v_job_id,
        'check_price_calculation',
        'custom_sql',
        'SELECT COUNT(*) FROM {target_schema}.{target_table} WHERE ABS(total_price - (quantity * unit_price)) > 0.01',
        'ERROR',
        0.0  -- Gesamtpreis muss Menge * Einzelpreis entsprechen (mit kleiner Toleranz)
    );
END $$;

-- Erstelle fehlende Funktion etl_framework.get_current_batch_id()
CREATE OR REPLACE FUNCTION etl_framework.get_current_batch_id() RETURNS INTEGER AS $$
DECLARE
    batch_id INTEGER;
BEGIN
    -- Hole oder erstelle eine neue Batch-ID für den aktuellen Tag
    SELECT EXTRACT(EPOCH FROM date_trunc('day', CURRENT_TIMESTAMP))::INTEGER INTO batch_id;
    RETURN batch_id;
END;
$$ LANGUAGE plpgsql; 