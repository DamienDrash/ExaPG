#!/bin/bash
# Test-Skript für spaltenorientierte Tabellen in ExaPG
# Dieses Skript erstellt spaltenorientierte Tabellen, lädt Daten und führt Vergleichstests durch

set -e

echo "=== ExaPG Columnar Storage Test ==="
echo "Dieses Skript testet die Performance der spaltenorientierten Speicherung"
echo ""

# Prüfen, ob ExaPG läuft
if ! docker ps | grep -q exapg-coordinator; then
    echo "Fehler: ExaPG scheint nicht zu laufen. Bitte starten Sie es mit ./start-exapg.sh"
    exit 1
fi

# Prüfen, ob Citus Columnar installiert ist
echo "1. Prüfe Citus Columnar Installation..."
COLUMNAR_STATUS=$(docker exec exapg-coordinator psql -U postgres -d exadb -t -c "SELECT extname FROM pg_extension WHERE extname = 'citus_columnar';" | tr -d '[:space:]')

if [ "$COLUMNAR_STATUS" != "citus_columnar" ]; then
    echo "Fehler: Citus Columnar ist nicht installiert."
    exit 1
fi
echo "✓ Citus Columnar ist installiert"

# Umgebung vorbereiten
echo ""
echo "2. Bereite Testumgebung vor..."
docker exec exapg-coordinator psql -U postgres -d exadb -c "
    DROP SCHEMA IF EXISTS columnar_test CASCADE;
    CREATE SCHEMA columnar_test;
"
echo "✓ Testschema erstellt"

# Spaltenorientierte und zeilenorientierte Tabellen erstellen
echo ""
echo "3. Erstelle Test-Tabellen (spalten- und zeilenorientiert)..."
docker exec exapg-coordinator psql -U postgres -d exadb -c "
    -- Spaltenorientierte Tabelle
    CREATE TABLE columnar_test.columnar_table (
        id SERIAL,
        timestamp TIMESTAMPTZ NOT NULL,
        customer_id INTEGER,
        product_id INTEGER,
        quantity INTEGER,
        price NUMERIC(10,2),
        total NUMERIC(10,2),
        notes TEXT
    ) USING columnar;
    
    -- Zeilenorientierte Tabelle mit identischer Struktur
    CREATE TABLE columnar_test.row_table (
        id SERIAL,
        timestamp TIMESTAMPTZ NOT NULL,
        customer_id INTEGER,
        product_id INTEGER,
        quantity INTEGER,
        price NUMERIC(10,2),
        total NUMERIC(10,2),
        notes TEXT
    );
"
echo "✓ Test-Tabellen erstellt"

# Daten generieren
echo ""
echo "4. Generiere Testdaten (500.000 Zeilen)..."
docker exec exapg-coordinator psql -U postgres -d exadb -c "
    INSERT INTO columnar_test.columnar_table (timestamp, customer_id, product_id, quantity, price, total, notes)
    SELECT
        now() - (random() * interval '1 year'),
        (random() * 1000)::int,
        (random() * 100)::int,
        (random() * 10 + 1)::int,
        (random() * 100)::numeric(10,2),
        (random() * 1000)::numeric(10,2),
        'Notiz für Transaktion ' || i || ' mit zufälligem Text, um die Kompression zu testen. ' || 
        CASE WHEN i % 5 = 0 THEN 'Extra Informationen sind hier angegeben.' ELSE '' END
    FROM generate_series(1, 500000) i;
    
    -- Kopiere Daten in die zeilenorientierte Tabelle
    INSERT INTO columnar_test.row_table
    SELECT * FROM columnar_test.columnar_table;
"
echo "✓ Testdaten generiert"

# Vergleiche Größe
echo ""
echo "5. Vergleiche Speicherbedarf..."
docker exec exapg-coordinator psql -U postgres -d exadb -c "
    SELECT 
        'Columnar' AS storage_type,
        pg_size_pretty(pg_total_relation_size('columnar_test.columnar_table')) AS total_size
    UNION ALL
    SELECT 
        'Row' AS storage_type,
        pg_size_pretty(pg_total_relation_size('columnar_test.row_table')) AS total_size;
"

# Performance-Test
echo ""
echo "6. Führe Performance-Tests durch..."

echo "a) Aggregationsabfrage (besser für columnar):"
docker exec exapg-coordinator psql -U postgres -d exadb -c "
    \timing on
    
    -- Columnar
    SELECT 'Columnar' AS type;
    SELECT 
        date_trunc('month', timestamp) AS month,
        COUNT(*) AS transaction_count,
        SUM(quantity) AS total_quantity,
        SUM(total) AS total_sales,
        AVG(price) AS avg_price
    FROM columnar_test.columnar_table
    GROUP BY date_trunc('month', timestamp)
    ORDER BY month;
    
    -- Row
    SELECT 'Row' AS type;
    SELECT 
        date_trunc('month', timestamp) AS month,
        COUNT(*) AS transaction_count,
        SUM(quantity) AS total_quantity,
        SUM(total) AS total_sales,
        AVG(price) AS avg_price
    FROM columnar_test.row_table
    GROUP BY date_trunc('month', timestamp)
    ORDER BY month;
"

echo "b) Vollständige Zeilenabfrage (besser für row):"
docker exec exapg-coordinator psql -U postgres -d exadb -c "
    \timing on
    
    -- Columnar
    SELECT 'Columnar' AS type;
    SELECT * FROM columnar_test.columnar_table LIMIT 10000;
    
    -- Row
    SELECT 'Row' AS type;
    SELECT * FROM columnar_test.row_table LIMIT 10000;
"

echo "c) Filterung mit Projektion (gemischter Vorteil):"
docker exec exapg-coordinator psql -U postgres -d exadb -c "
    \timing on
    
    -- Columnar
    SELECT 'Columnar' AS type;
    SELECT 
        timestamp,
        customer_id,
        total
    FROM columnar_test.columnar_table
    WHERE product_id BETWEEN 10 AND 20
    AND quantity > 5
    ORDER BY timestamp DESC
    LIMIT 1000;
    
    -- Row
    SELECT 'Row' AS type;
    SELECT 
        timestamp,
        customer_id,
        total
    FROM columnar_test.row_table
    WHERE product_id BETWEEN 10 AND 20
    AND quantity > 5
    ORDER BY timestamp DESC
    LIMIT 1000;
"

echo ""
echo "=== Test abgeschlossen ==="
echo "Die Ergebnisse zeigen die Vorteile spaltenorientierter Speicherung für analytische Abfragen."
echo "Weitere Details finden Sie in der Dokumentation: docs/columnar-storage.md" 