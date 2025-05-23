-- Einrichtung von ETL-Jobs mit pgAgent für ExaPG
-- Dieses Skript demonstriert verschiedene ETL-Szenarien und deren Automatisierung

-- 1. Schema für ETL-Prozesse erstellen
CREATE SCHEMA IF NOT EXISTS etl;

-- 2. Hilfsfunktionen für ETL-Prozesse
-- Funktion zum Protokollieren von ETL-Aktivitäten
CREATE OR REPLACE FUNCTION etl.log_etl_activity(
    p_job_name text,
    p_status text,
    p_message text DEFAULT NULL
) RETURNS void AS $$
BEGIN
    CREATE TABLE IF NOT EXISTS etl.activity_log (
        log_id SERIAL PRIMARY KEY,
        job_name text NOT NULL,
        status text NOT NULL,
        message text,
        logged_at timestamp with time zone DEFAULT now()
    );
    
    INSERT INTO etl.activity_log (job_name, status, message)
    VALUES (p_job_name, p_status, p_message);
END;
$$ LANGUAGE plpgsql;

-- 3. Staging-Tabellen für ETL-Prozesse
-- Staging-Tabelle für Kundendaten
CREATE TABLE IF NOT EXISTS etl.staging_customers (
    customer_id integer,
    customer_name varchar(100),
    email varchar(100),
    phone varchar(20),
    address text,
    city varchar(50),
    country varchar(50),
    updated_at timestamp with time zone DEFAULT now()
);

-- Staging-Tabelle für Produktdaten
CREATE TABLE IF NOT EXISTS etl.staging_products (
    product_id integer,
    product_name varchar(100),
    category varchar(50),
    price numeric(10,2),
    stock_quantity integer,
    updated_at timestamp with time zone DEFAULT now()
);

-- Staging-Tabelle für Verkaufsdaten
CREATE TABLE IF NOT EXISTS etl.staging_sales (
    sale_id integer,
    sale_date date,
    customer_id integer,
    product_id integer,
    quantity integer,
    unit_price numeric(10,2),
    total_price numeric(10,2),
    updated_at timestamp with time zone DEFAULT now()
);

-- 4. Zieltabellen für transformierte Daten
-- Zieltabelle für Kundendaten
CREATE TABLE IF NOT EXISTS etl.dim_customers (
    customer_id integer PRIMARY KEY,
    customer_name varchar(100) NOT NULL,
    email varchar(100),
    phone varchar(20),
    address text,
    city varchar(50),
    country varchar(50),
    first_purchase_date date,
    last_purchase_date date,
    total_purchases numeric(12,2) DEFAULT 0,
    customer_segment varchar(20),
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Zieltabelle für Produktdaten
CREATE TABLE IF NOT EXISTS etl.dim_products (
    product_id integer PRIMARY KEY,
    product_name varchar(100) NOT NULL,
    category varchar(50),
    subcategory varchar(50),
    price numeric(10,2),
    cost numeric(10,2),
    stock_quantity integer,
    reorder_level integer,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Faktentabelle für Verkäufe
CREATE TABLE IF NOT EXISTS etl.fact_sales (
    sale_id integer,
    sale_date date NOT NULL,
    customer_id integer REFERENCES etl.dim_customers(customer_id),
    product_id integer REFERENCES etl.dim_products(product_id),
    quantity integer NOT NULL,
    unit_price numeric(10,2) NOT NULL,
    discount_amount numeric(10,2) DEFAULT 0,
    total_price numeric(10,2) NOT NULL,
    profit numeric(10,2),
    created_at timestamp with time zone DEFAULT now(),
    PRIMARY KEY (sale_id)
);

-- 5. ETL-Prozeduren für verschiedene Transformationen
-- Prozedur zum Laden von Kundendaten
CREATE OR REPLACE PROCEDURE etl.load_customers()
LANGUAGE plpgsql AS $$
BEGIN
    -- Protokollierung starten
    PERFORM etl.log_etl_activity('load_customers', 'STARTED');
    
    -- Versuche den ETL-Prozess
    BEGIN
        -- Upsert für Kundendaten
        INSERT INTO etl.dim_customers (
            customer_id, customer_name, email, phone, address, city, country, updated_at
        )
        SELECT 
            s.customer_id, 
            s.customer_name, 
            s.email, 
            s.phone, 
            s.address, 
            s.city, 
            s.country, 
            now()
        FROM 
            etl.staging_customers s
        ON CONFLICT (customer_id) 
        DO UPDATE SET
            customer_name = EXCLUDED.customer_name,
            email = EXCLUDED.email,
            phone = EXCLUDED.phone,
            address = EXCLUDED.address,
            city = EXCLUDED.city,
            country = EXCLUDED.country,
            updated_at = now();
            
        -- Bereinigung der Staging-Tabelle
        TRUNCATE TABLE etl.staging_customers;
        
        -- Protokollierung erfolgreich
        PERFORM etl.log_etl_activity('load_customers', 'COMPLETED', 'Erfolgreich abgeschlossen');
    EXCEPTION WHEN OTHERS THEN
        -- Protokollierung bei Fehler
        PERFORM etl.log_etl_activity('load_customers', 'ERROR', 'Fehler: ' || SQLERRM);
        RAISE;
    END;
END;
$$;

-- Prozedur zum Laden von Produktdaten
CREATE OR REPLACE PROCEDURE etl.load_products()
LANGUAGE plpgsql AS $$
BEGIN
    -- Protokollierung starten
    PERFORM etl.log_etl_activity('load_products', 'STARTED');
    
    -- Versuche den ETL-Prozess
    BEGIN
        -- Upsert für Produktdaten
        INSERT INTO etl.dim_products (
            product_id, product_name, category, price, stock_quantity, updated_at
        )
        SELECT 
            s.product_id, 
            s.product_name, 
            s.category, 
            s.price, 
            s.stock_quantity, 
            now()
        FROM 
            etl.staging_products s
        ON CONFLICT (product_id) 
        DO UPDATE SET
            product_name = EXCLUDED.product_name,
            category = EXCLUDED.category,
            price = EXCLUDED.price,
            stock_quantity = EXCLUDED.stock_quantity,
            updated_at = now();
            
        -- Bereinigung der Staging-Tabelle
        TRUNCATE TABLE etl.staging_products;
        
        -- Protokollierung erfolgreich
        PERFORM etl.log_etl_activity('load_products', 'COMPLETED', 'Erfolgreich abgeschlossen');
    EXCEPTION WHEN OTHERS THEN
        -- Protokollierung bei Fehler
        PERFORM etl.log_etl_activity('load_products', 'ERROR', 'Fehler: ' || SQLERRM);
        RAISE;
    END;
END;
$$;

-- Prozedur zum Laden von Verkaufsdaten
CREATE OR REPLACE PROCEDURE etl.load_sales()
LANGUAGE plpgsql AS $$
BEGIN
    -- Protokollierung starten
    PERFORM etl.log_etl_activity('load_sales', 'STARTED');
    
    -- Versuche den ETL-Prozess
    BEGIN
        -- Einfügen von Verkaufsdaten
        INSERT INTO etl.fact_sales (
            sale_id, sale_date, customer_id, product_id, 
            quantity, unit_price, total_price
        )
        SELECT 
            s.sale_id, 
            s.sale_date, 
            s.customer_id, 
            s.product_id, 
            s.quantity, 
            s.unit_price, 
            s.total_price
        FROM 
            etl.staging_sales s
        WHERE 
            NOT EXISTS (
                SELECT 1 FROM etl.fact_sales fs 
                WHERE fs.sale_id = s.sale_id
            );
            
        -- Berechnung des Gewinns basierend auf Produktkosten (vereinfachtes Beispiel)
        UPDATE etl.fact_sales fs
        SET profit = fs.total_price - (p.cost * fs.quantity)
        FROM etl.dim_products p
        WHERE fs.product_id = p.product_id
        AND fs.profit IS NULL;
        
        -- Aktualisierung von Kundendaten basierend auf Verkäufen
        UPDATE etl.dim_customers c
        SET 
            first_purchase_date = CASE 
                WHEN c.first_purchase_date IS NULL THEN subquery.first_purchase
                WHEN subquery.first_purchase < c.first_purchase_date THEN subquery.first_purchase
                ELSE c.first_purchase_date
            END,
            last_purchase_date = CASE 
                WHEN c.last_purchase_date IS NULL THEN subquery.last_purchase
                WHEN subquery.last_purchase > c.last_purchase_date THEN subquery.last_purchase
                ELSE c.last_purchase_date
            END,
            total_purchases = subquery.total_amount
        FROM (
            SELECT 
                customer_id,
                MIN(sale_date) as first_purchase,
                MAX(sale_date) as last_purchase,
                SUM(total_price) as total_amount
            FROM 
                etl.fact_sales
            GROUP BY 
                customer_id
        ) subquery
        WHERE c.customer_id = subquery.customer_id;
        
        -- Bereinigung der Staging-Tabelle
        TRUNCATE TABLE etl.staging_sales;
        
        -- Protokollierung erfolgreich
        PERFORM etl.log_etl_activity('load_sales', 'COMPLETED', 'Erfolgreich abgeschlossen');
    EXCEPTION WHEN OTHERS THEN
        -- Protokollierung bei Fehler
        PERFORM etl.log_etl_activity('load_sales', 'ERROR', 'Fehler: ' || SQLERRM);
        RAISE;
    END;
END;
$$;

-- 6. Vollständiger ETL-Job, der alle Prozesse ausführt
CREATE OR REPLACE PROCEDURE etl.run_full_etl()
LANGUAGE plpgsql AS $$
BEGIN
    -- Protokollierung starten
    PERFORM etl.log_etl_activity('run_full_etl', 'STARTED');
    
    -- Versuche den gesamten ETL-Prozess
    BEGIN
        -- Laden von Stammdaten
        CALL etl.load_customers();
        CALL etl.load_products();
        
        -- Laden von Transaktionsdaten
        CALL etl.load_sales();
        
        -- Protokollierung erfolgreich
        PERFORM etl.log_etl_activity('run_full_etl', 'COMPLETED', 'Alle ETL-Prozesse erfolgreich abgeschlossen');
    EXCEPTION WHEN OTHERS THEN
        -- Protokollierung bei Fehler
        PERFORM etl.log_etl_activity('run_full_etl', 'ERROR', 'Fehler im ETL-Prozess: ' || SQLERRM);
        RAISE;
    END;
END;
$$;

-- 7. Funktionen zum Füllen der Staging-Tabellen mit Beispieldaten
-- Diese würden in einer realen Umgebung durch echte Datenimporte ersetzt

-- Funktion zum Füllen der Staging-Tabelle für Kunden
CREATE OR REPLACE FUNCTION etl.fill_staging_customers(p_count integer DEFAULT 10)
RETURNS void AS $$
BEGIN
    INSERT INTO etl.staging_customers (customer_id, customer_name, email, phone, address, city, country)
    SELECT 
        i AS customer_id,
        'Kunde ' || i AS customer_name,
        'kunde' || i || '@example.com' AS email,
        '0123-456' || lpad(i::text, 4, '0') AS phone,
        'Musterstraße ' || i AS address,
        CASE i % 5 
            WHEN 0 THEN 'Berlin'
            WHEN 1 THEN 'Hamburg'
            WHEN 2 THEN 'München'
            WHEN 3 THEN 'Köln'
            ELSE 'Frankfurt'
        END AS city,
        'Deutschland' AS country
    FROM generate_series(1, p_count) i;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Füllen der Staging-Tabelle für Produkte
CREATE OR REPLACE FUNCTION etl.fill_staging_products(p_count integer DEFAULT 10)
RETURNS void AS $$
BEGIN
    INSERT INTO etl.staging_products (product_id, product_name, category, price, stock_quantity)
    SELECT 
        i AS product_id,
        'Produkt ' || i AS product_name,
        CASE i % 3 
            WHEN 0 THEN 'Elektronik'
            WHEN 1 THEN 'Kleidung'
            ELSE 'Haushalt'
        END AS category,
        (random() * 100 + 10)::numeric(10,2) AS price,
        (random() * 100)::integer AS stock_quantity
    FROM generate_series(1, p_count) i;
    
    -- Einfügen der entsprechenden Produktkosten in die Zieltabelle
    INSERT INTO etl.dim_products (product_id, product_name, category, price, cost)
    SELECT 
        product_id,
        product_name,
        category,
        price,
        price * 0.7 -- Einfache Kalkulation: Kosten = 70% des Preises
    FROM etl.staging_products
    ON CONFLICT (product_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Füllen der Staging-Tabelle für Verkäufe
CREATE OR REPLACE FUNCTION etl.fill_staging_sales(p_count integer DEFAULT 20)
RETURNS void AS $$
DECLARE
    v_customer_count integer;
    v_product_count integer;
BEGIN
    -- Anzahl der verfügbaren Kunden und Produkte ermitteln
    SELECT COUNT(*) INTO v_customer_count FROM etl.dim_customers;
    SELECT COUNT(*) INTO v_product_count FROM etl.dim_products;
    
    -- Wenn keine Stammdaten vorhanden sind, Demo-Daten erstellen
    IF v_customer_count = 0 THEN
        PERFORM etl.fill_staging_customers(10);
        CALL etl.load_customers();
        SELECT COUNT(*) INTO v_customer_count FROM etl.dim_customers;
    END IF;
    
    IF v_product_count = 0 THEN
        PERFORM etl.fill_staging_products(10);
        CALL etl.load_products();
        SELECT COUNT(*) INTO v_product_count FROM etl.dim_products;
    END IF;
    
    -- Verkaufsdaten generieren
    INSERT INTO etl.staging_sales (
        sale_id, sale_date, customer_id, product_id, quantity, unit_price, total_price
    )
    SELECT 
        i AS sale_id,
        current_date - (random() * 30)::integer AS sale_date,
        (random() * (v_customer_count - 1) + 1)::integer AS customer_id,
        (random() * (v_product_count - 1) + 1)::integer AS product_id,
        (random() * 5 + 1)::integer AS quantity,
        (random() * 50 + 10)::numeric(10,2) AS unit_price,
        (random() * 5 + 1)::integer * (random() * 50 + 10)::numeric(10,2) AS total_price
    FROM generate_series(1, p_count) i;
END;
$$ LANGUAGE plpgsql;

-- 8. Einrichtung von pgAgent-Jobs
-- Diese SQL-Befehle demonstrieren, wie Jobs in pgAgent erstellt werden

-- Beispiel-Jobs für pgAgent
-- Diese Befehle müssen in einer SQL-Umgebung ausgeführt werden, die pgAdmin oder ein anderes Tool mit pgAgent-Integration verwendet

-- Hinweis: Die eigentliche Job-Erstellung würde über die pgAdmin-Oberfläche oder spezielle API-Aufrufe erfolgen
-- Die folgenden Kommentare beschreiben die Jobs, die erstellt werden sollten

/*
-- Täglicher ETL-Job für vollständige Datenaktualisierung
SELECT pgagent.create_job(
    'Daily Full ETL',                    -- Jobname
    'Tägliche vollständige ETL-Verarbeitung',   -- Beschreibung
    '0 2 * * *',                        -- Zeitplan (täglich um 2:00 Uhr)
    'CALL etl.run_full_etl();'          -- SQL-Befehl
);

-- Stündlicher Job für Kundenaktualisierung
SELECT pgagent.create_job(
    'Hourly Customer Update',             -- Jobname
    'Stündliche Aktualisierung der Kundendaten', -- Beschreibung
    '0 * * * *',                          -- Zeitplan (stündlich)
    'CALL etl.load_customers();'         -- SQL-Befehl
);

-- Stündlicher Job für Produktaktualisierung
SELECT pgagent.create_job(
    'Hourly Product Update',              -- Jobname
    'Stündliche Aktualisierung der Produktdaten', -- Beschreibung
    '30 * * * *',                         -- Zeitplan (30 Minuten nach jeder Stunde)
    'CALL etl.load_products();'          -- SQL-Befehl
);

-- Halbstündlicher Job für Verkaufsaktualisierung
SELECT pgagent.create_job(
    'Sales Update Every 30min',           -- Jobname
    'Aktualisierung der Verkaufsdaten alle 30 Minuten', -- Beschreibung
    '*/30 * * * *',                       -- Zeitplan (alle 30 Minuten)
    'CALL etl.load_sales();'             -- SQL-Befehl
);
*/

-- 9. Beispiel für die Ausführung des gesamten ETL-Prozesses mit Testdaten
-- Testdaten für Kunden erstellen
SELECT etl.fill_staging_customers(5);

-- Testdaten für Produkte erstellen
SELECT etl.fill_staging_products(5);

-- Testdaten für Verkäufe erstellen
SELECT etl.fill_staging_sales(10);

-- ETL-Prozess ausführen
CALL etl.run_full_etl();

-- Ergebnisse anzeigen
SELECT * FROM etl.activity_log ORDER BY logged_at DESC LIMIT 10;
SELECT * FROM etl.dim_customers;
SELECT * FROM etl.dim_products;
SELECT * FROM etl.fact_sales; 