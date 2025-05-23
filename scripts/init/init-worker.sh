#!/bin/bash
set -e

# Parameter aus Umgebungsvariablen
HOSTNAME=$(hostname)
echo "Initialisiere Worker-Knoten: $HOSTNAME"

# Warten auf PostgreSQL
until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
  echo "Warte auf PostgreSQL..."
  sleep 1
done

echo "PostgreSQL Worker ist bereit - aktiviere Erweiterungen"

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
  
  -- Erstelle Schema für Analysen (wird in verteilten Tabellen benötigt)
  CREATE SCHEMA IF NOT EXISTS analytics;
EOSQL

# Setze zusätzliche Parameter für bessere Leistung
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
  -- Optimiere für analytische Workloads
  ALTER SYSTEM SET effective_cache_size = '$EFFECTIVE_CACHE_SIZE';
  ALTER SYSTEM SET shared_buffers = '$SHARED_BUFFERS';
  ALTER SYSTEM SET work_mem = '$WORK_MEM';
  ALTER SYSTEM SET max_parallel_workers = '$MAX_PARALLEL_WORKERS';
  ALTER SYSTEM SET max_parallel_workers_per_gather = '$MAX_PARALLEL_WORKERS';
  
  -- Lade Konfiguration neu
  SELECT pg_reload_conf();
EOSQL

echo "Worker-Knoten $HOSTNAME ist konfiguriert und bereit für Verbindung mit Koordinator" 