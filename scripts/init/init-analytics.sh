#!/bin/bash
set -e

# Warten auf PostgreSQL
until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
  echo "Warte auf PostgreSQL..."
  sleep 1
done

echo "PostgreSQL ist bereit - aktiviere analytische Erweiterungen"

# SQL-Befehle ausführen
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
  -- Aktiviere Erweiterungen
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  CREATE EXTENSION IF NOT EXISTS vector;
  CREATE EXTENSION IF NOT EXISTS timescaledb;
  CREATE EXTENSION IF NOT EXISTS postgis;
  CREATE EXTENSION IF NOT EXISTS btree_gin;
  CREATE EXTENSION IF NOT EXISTS btree_gist;
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
  CREATE EXTENSION IF NOT EXISTS hstore;
  CREATE EXTENSION IF NOT EXISTS intarray;
  
  -- Erstelle einen Schema für Analysen
  CREATE SCHEMA IF NOT EXISTS analytics;
  
  -- Erstelle eine Beispiel-Timeseries-Tabelle
  CREATE TABLE analytics.sensor_data (
    time TIMESTAMPTZ NOT NULL,
    sensor_id INTEGER NOT NULL,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION,
    pressure DOUBLE PRECISION
  );
  
  -- Konvertiere zur TimescaleDB Hypertabelle
  SELECT create_hypertable('analytics.sensor_data', 'time');
  
  -- Erstelle eine partitionierte Tabelle für Verkaufsdaten
  CREATE TABLE analytics.sales (
    sale_id SERIAL,
    sale_date DATE NOT NULL,
    customer_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    amount NUMERIC(10, 2),
    PRIMARY KEY (sale_id, sale_date)
  ) PARTITION BY RANGE (sale_date);
  
  -- Erstelle Partitionen für Verkaufsdaten
  CREATE TABLE analytics.sales_2023 PARTITION OF analytics.sales
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
    
  CREATE TABLE analytics.sales_2024 PARTITION OF analytics.sales
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
    
  CREATE TABLE analytics.sales_2025 PARTITION OF analytics.sales
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
  
  -- Beispiel für Vektor-Ähnlichkeitssuche mit pgvector
  CREATE TABLE analytics.document_embeddings (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    content_embedding vector(384)  -- BERT embeddings haben 384 Dimensionen
  );
  
  -- Erstelle einen Index für schnelle Ähnlichkeitssuche
  CREATE INDEX ON analytics.document_embeddings USING ivfflat (content_embedding vector_l2_ops);
  
  -- Erstelle GIS-Beispieltabelle
  CREATE TABLE analytics.locations (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    position geometry(Point, 4326) NOT NULL
  );
  
  -- Erstelle GIS-Index
  CREATE INDEX locations_position_idx ON analytics.locations USING GIST (position);
EOSQL

# Füge Beispieldaten ein
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
  -- Füge Beispieldaten für TimescaleDB ein
  INSERT INTO analytics.sensor_data (time, sensor_id, temperature, humidity, pressure)
  SELECT
    timestamp '2024-01-01 00:00:00' + (i || ' hours')::interval,
    (i % 5) + 1,
    20.0 + (random() * 10.0),
    50.0 + (random() * 20.0),
    1000.0 + (random() * 50.0)
  FROM generate_series(0, 999) i;
  
  -- Füge Beispieldaten für partitionierte Tabelle ein
  INSERT INTO analytics.sales (sale_date, customer_id, product_id, quantity, amount)
  SELECT
    '2024-01-01'::date + (i % 365 || ' days')::interval,
    (random() * 1000)::integer + 1,
    (random() * 100)::integer + 1,
    (random() * 10)::integer + 1,
    (random() * 1000)::numeric(10,2)
  FROM generate_series(0, 999) i;
  
  -- Füge Beispieldaten für GIS-Tabelle ein
  INSERT INTO analytics.locations (name, position)
  VALUES
    ('Berlin', ST_SetSRID(ST_MakePoint(13.4050, 52.5200), 4326)),
    ('Hamburg', ST_SetSRID(ST_MakePoint(10.0000, 53.5500), 4326)),
    ('München', ST_SetSRID(ST_MakePoint(11.5820, 48.1351), 4326)),
    ('Köln', ST_SetSRID(ST_MakePoint(6.9570, 50.9367), 4326)),
    ('Frankfurt', ST_SetSRID(ST_MakePoint(8.6821, 50.1109), 4326));
EOSQL

echo "Analytische Erweiterungen aktiviert und Beispieldaten geladen" 