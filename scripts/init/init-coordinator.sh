#!/bin/bash
set -e

# Parameter aus Umgebungsvariablen lesen
DEPLOYMENT_MODE=${DEPLOYMENT_MODE:-cluster}
WORKER_COUNT=${WORKER_COUNT:-2}

echo "Starte PostgreSQL mit Citus in Modus: $DEPLOYMENT_MODE"
echo "Anzahl der Worker-Knoten: $WORKER_COUNT"

# Warten auf PostgreSQL
until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
  echo "Warte auf PostgreSQL..."
  sleep 1
done

echo "PostgreSQL Koordinator ist bereit - aktiviere Erweiterungen"

# SQL-Befehle ausführen
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
  -- Aktiviere Citus-Erweiterung
  CREATE EXTENSION IF NOT EXISTS citus;
  
  -- Weitere Erweiterungen aktivieren
  CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
  CREATE EXTENSION IF NOT EXISTS vector;
  CREATE EXTENSION IF NOT EXISTS timescaledb;
  CREATE EXTENSION IF NOT EXISTS postgis;
  CREATE EXTENSION IF NOT EXISTS btree_gin;
  CREATE EXTENSION IF NOT EXISTS btree_gist;
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
  CREATE EXTENSION IF NOT EXISTS hstore;
  CREATE EXTENSION IF NOT EXISTS intarray;
  
  -- Citus-Knoten-Typ setzen
  SELECT citus_set_coordinator_host('coordinator', 5432);
  
  -- Erstelle Schema für Analysen
  CREATE SCHEMA IF NOT EXISTS analytics;
EOSQL

if [[ "$DEPLOYMENT_MODE" == "single" ]]; then
  echo "Single-Node-Modus: Konfiguriere für lokale Ausführung..."
  
  # Konfiguriere Citus für Single-Node-Betrieb
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
    -- Aktiviere lokale Ausführung
    ALTER SYSTEM SET citus.enable_local_execution = true;
    SELECT pg_reload_conf();
  EOSQL
  
  # Erstelle lokale Tabellen
  psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
    -- Erstelle Beispiel-Tabellen als normale PostgreSQL-Tabellen
    CREATE TABLE IF NOT EXISTS analytics.sensor_data (
      time TIMESTAMPTZ NOT NULL,
      sensor_id INTEGER NOT NULL,
      temperature DOUBLE PRECISION,
      humidity DOUBLE PRECISION,
      pressure DOUBLE PRECISION
    );
    
    CREATE TABLE IF NOT EXISTS analytics.sales (
      sale_id SERIAL,
      sale_date DATE NOT NULL,
      customer_id INTEGER,
      product_id INTEGER,
      quantity INTEGER,
      amount NUMERIC(10, 2)
    );
    
    CREATE TABLE IF NOT EXISTS analytics.document_embeddings (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL,
      content_embedding vector(384)
    );
    
    CREATE TABLE IF NOT EXISTS analytics.locations (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      position geometry(Point, 4326) NOT NULL
    );
  EOSQL
  
else
  echo "Cluster-Modus: Warte auf Worker-Knoten..."
  
  # Warte auf Worker-Knoten
  sleep 30
  
  # Versuche, Worker-Knoten hinzuzufügen
  for i in {1..20}; do
    echo "Versuch $i: Füge Worker-Knoten hinzu..."
    WORKER_ADDED=0
    
    # Füge Worker-Knoten basierend auf WORKER_COUNT hinzu
    for j in $(seq 1 $WORKER_COUNT); do
      WORKER_NAME="worker$j"
      
      # Überprüfe, ob Verbindung zum Worker möglich ist
      if pg_isready -h "$WORKER_NAME" -U "$POSTGRES_USER"; then
        # Versuche, den Worker hinzuzufügen, wenn er noch nicht existiert
        WORKER_EXISTS=$(psql -t -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT COUNT(*) FROM pg_dist_node WHERE nodename = '$WORKER_NAME';" | tr -d ' ')
        if [ "$WORKER_EXISTS" -eq "0" ]; then
          psql -v ON_ERROR_STOP=0 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT citus_add_node('$WORKER_NAME', 5432);"
          echo "Worker $WORKER_NAME hinzugefügt."
          WORKER_ADDED=$((WORKER_ADDED + 1))
        else
          echo "Worker $WORKER_NAME bereits hinzugefügt."
          WORKER_ADDED=$((WORKER_ADDED + 1))
        fi
      else
        echo "Worker $WORKER_NAME ist noch nicht bereit."
      fi
    done
    
    # Überprüfe, ob alle Worker-Knoten hinzugefügt wurden
    if [ "$WORKER_ADDED" -eq "$WORKER_COUNT" ]; then
      echo "Alle $WORKER_COUNT Worker-Knoten erfolgreich hinzugefügt!"
      break
    else
      echo "Noch nicht alle Worker-Knoten hinzugefügt ($WORKER_ADDED/$WORKER_COUNT). Warte 10 Sekunden..."
      sleep 10
    fi
  done
  
  # Überprüfe, ob Worker-Knoten verfügbar sind
  WORKER_COUNT_ACTUAL=$(psql -t -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT COUNT(*) FROM pg_dist_node WHERE noderole = 'primary' AND nodename != 'coordinator';" | tr -d ' ')
  
  if [ "$WORKER_COUNT_ACTUAL" -gt "0" ]; then
    echo "Worker-Knoten verfügbar: $WORKER_COUNT_ACTUAL. Erstelle verteilte Tabellen..."
    
    # Erstelle verteilte Tabellen
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOQ
      -- Reduziere Replikationsfaktor für Tests
      ALTER SYSTEM SET citus.shard_replication_factor = 1;
      SELECT pg_reload_conf();
      
      -- Erstelle und verteilte eine Beispiel-Timeseries-Tabelle
      CREATE TABLE analytics.sensor_data (
        time TIMESTAMPTZ NOT NULL,
        sensor_id INTEGER NOT NULL,
        temperature DOUBLE PRECISION,
        humidity DOUBLE PRECISION,
        pressure DOUBLE PRECISION
      );
      
      -- Erstelle Referenztabelle (funktioniert auch mit wenigen Worker-Knoten)
      SELECT create_reference_table('analytics.sensor_data');
      
      -- Erstelle eine Tabelle für Verkaufsdaten
      CREATE TABLE analytics.sales (
        sale_id SERIAL,
        sale_date DATE NOT NULL,
        customer_id INTEGER,
        product_id INTEGER,
        quantity INTEGER,
        amount NUMERIC(10, 2)
      );
      
      -- Erstelle Referenztabelle
      SELECT create_reference_table('analytics.sales');
      
      -- Beispiel für Vektor-Ähnlichkeitssuche mit pgvector
      CREATE TABLE analytics.document_embeddings (
        id SERIAL PRIMARY KEY,
        title TEXT NOT NULL,
        content_embedding vector(384)  -- BERT embeddings haben 384 Dimensionen
      );
      
      -- Erstelle Referenztabelle
      SELECT create_reference_table('analytics.document_embeddings');
      
      -- Erstelle GIS-Beispieltabelle
      CREATE TABLE analytics.locations (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        position geometry(Point, 4326) NOT NULL
      );
      
      -- Erstelle Referenztabelle
      SELECT create_reference_table('analytics.locations');
EOQ
    
  else
    echo "Keine Worker-Knoten verfügbar. Erstelle lokale Tabellen..."
    
    # Erstelle lokale Tabellen
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOD
      -- Erstelle Beispiel-Tabellen als normale PostgreSQL-Tabellen
      CREATE TABLE analytics.sensor_data (
        time TIMESTAMPTZ NOT NULL,
        sensor_id INTEGER NOT NULL,
        temperature DOUBLE PRECISION,
        humidity DOUBLE PRECISION,
        pressure DOUBLE PRECISION
      );
      
      CREATE TABLE analytics.sales (
        sale_id SERIAL,
        sale_date DATE NOT NULL,
        customer_id INTEGER,
        product_id INTEGER,
        quantity INTEGER,
        amount NUMERIC(10, 2)
      );
      
      CREATE TABLE analytics.document_embeddings (
        id SERIAL PRIMARY KEY,
        title TEXT NOT NULL,
        content_embedding vector(384)
      );
      
      CREATE TABLE analytics.locations (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        position geometry(Point, 4326) NOT NULL
      );
EOD
  fi
fi

# Füge Beispieldaten ein
echo "Füge Beispieldaten ein..."
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOD
  -- Füge Beispieldaten für TimescaleDB ein
  INSERT INTO analytics.sensor_data (time, sensor_id, temperature, humidity, pressure)
  SELECT
    timestamp '2024-01-01 00:00:00' + (i || ' hours')::interval,
    (i % 50) + 1,
    20.0 + (random() * 10.0),
    50.0 + (random() * 20.0),
    1000.0 + (random() * 50.0)
  FROM generate_series(0, 999) i;
  
  -- Füge Beispieldaten für Verkäufe ein
  INSERT INTO analytics.sales (sale_date, customer_id, product_id, quantity, amount)
  SELECT
    '2024-01-01'::date + (i % 365 || ' days')::interval,
    (random() * 10000)::integer + 1,
    (random() * 1000)::integer + 1,
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
EOD

echo "Initialisierung abgeschlossen. ExaPG ist bereit." 