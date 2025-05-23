#!/bin/bash
# Initialisierungsskript für optimale Columnar-Konfiguration

set -e

# Aktiviere columnar-Erweiterung wenn verfügbar
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS citus_columnar;
    ALTER SYSTEM SET columnar.compression TO 'zstd';
    ALTER SYSTEM SET columnar.compression_level TO 3;
    ALTER SYSTEM SET columnar.stripe_row_limit TO 250000;
    ALTER SYSTEM SET columnar.chunk_group_row_limit TO 15000;
EOSQL

echo "Columnar-Konfiguration mit optimaler Kompression (ZSTD Level 3) abgeschlossen." 