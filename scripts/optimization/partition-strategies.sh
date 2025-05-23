#!/bin/bash
# Initialisierungsskript für Partitionierungsstrategien

set -e

echo "Richte Partitionierungsstrategien ein..."

# Erstelle das analytics Schema, falls es nicht existiert
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE SCHEMA IF NOT EXISTS analytics;
EOSQL

# Führe das Partitionierungsstrategien-Skript aus
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /docker-entrypoint-initdb.d/partition-strategies.sql

echo "Partitionierungsstrategien wurden erfolgreich eingerichtet." 