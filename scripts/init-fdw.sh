#!/bin/bash
# Initialisierungsskript für Foreign Data Wrappers in ExaPG
set -e

echo "Starte Initialisierung der Foreign Data Wrappers..."

# Warten auf die Datenbank
until pg_isready; do
  echo "Warte auf die Datenbank..."
  sleep 2
done

echo "Datenbank ist bereit. Initialisiere Foreign Data Wrappers..."

# Zeige verfügbare Erweiterungen an
echo "Verfügbare PostgreSQL-Erweiterungen:"
psql -U "$POSTGRES_USER" -d "postgres" -c "SELECT name, default_version, installed_version, comment FROM pg_available_extensions ORDER BY name;" || true

# Verbindung zur exadb-Datenbank herstellen
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "exadb" <<-EOSQL
  -- Schema für externe Datenquellen erstellen
  CREATE SCHEMA IF NOT EXISTS external_sources;

  -- Verfügbare FDW-Erweiterungen aktivieren
  CREATE EXTENSION IF NOT EXISTS postgres_fdw;
  CREATE EXTENSION IF NOT EXISTS file_fdw;
  
  -- Zusätzliche FDW-Erweiterungen aktivieren, sofern verfügbar
  DO \$\$
  BEGIN
    -- MySQL FDW
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'mysql_fdw') THEN
      EXECUTE 'CREATE EXTENSION IF NOT EXISTS mysql_fdw';
      RAISE NOTICE 'MySQL FDW wurde aktiviert';
    ELSE
      RAISE NOTICE 'MySQL FDW ist nicht verfügbar';
    END IF;
    
    -- MongoDB FDW
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'mongo_fdw') THEN
      EXECUTE 'CREATE EXTENSION IF NOT EXISTS mongo_fdw';
      RAISE NOTICE 'MongoDB FDW wurde aktiviert';
    ELSE
      RAISE NOTICE 'MongoDB FDW ist nicht verfügbar';
    END IF;
    
    -- SQLite FDW
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'sqlite_fdw') THEN
      EXECUTE 'CREATE EXTENSION IF NOT EXISTS sqlite_fdw';
      RAISE NOTICE 'SQLite FDW wurde aktiviert';
    ELSE
      RAISE NOTICE 'SQLite FDW ist nicht verfügbar';
    END IF;
    
    -- TDS FDW (SQL Server)
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'tds_fdw') THEN
      EXECUTE 'CREATE EXTENSION IF NOT EXISTS tds_fdw';
      RAISE NOTICE 'TDS FDW wurde aktiviert';
    ELSE
      RAISE NOTICE 'TDS FDW ist nicht verfügbar';
    END IF;
    
    -- Redis FDW
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'redis_fdw') THEN
      EXECUTE 'CREATE EXTENSION IF NOT EXISTS redis_fdw';
      RAISE NOTICE 'Redis FDW wurde aktiviert';
    ELSE
      RAISE NOTICE 'Redis FDW ist nicht verfügbar';
    END IF;
    
    -- Multicorn (für Python-basierte FDWs)
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'multicorn') THEN
      EXECUTE 'CREATE EXTENSION IF NOT EXISTS multicorn';
      RAISE NOTICE 'Multicorn wurde aktiviert';
    ELSE
      RAISE NOTICE 'Multicorn ist nicht verfügbar';
    END IF;
  END
  \$\$;

  -- Aktiviere pgAgent für die ETL-Automatisierung
  CREATE EXTENSION IF NOT EXISTS pgagent;
  
  -- Erstelle pgAgent Job-Tabellen im eigenen Schema
  CREATE SCHEMA IF NOT EXISTS pgagent;
  
  -- Rechte für pgAgent-Schema einrichten
  GRANT USAGE ON SCHEMA pgagent TO postgres;
  GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA pgagent TO postgres;
  GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA pgagent TO postgres;
  
  -- Erstelle Rolle für FDW-Verbindungen
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fdw_user') THEN
      CREATE ROLE fdw_user WITH LOGIN PASSWORD 'fdw_secure_password';
    END IF;
  END
  \$\$;
  
  GRANT USAGE ON SCHEMA external_sources TO fdw_user;
  GRANT SELECT ON ALL TABLES IN SCHEMA external_sources TO fdw_user;
  
  -- Erstelle einen Beispiel-Server für PostgreSQL FDW
  -- (Dieser Eintrag wird als Vorlage bereitgestellt und kann an die tatsächliche Konfiguration angepasst werden)
  DROP SERVER IF EXISTS example_postgres_server CASCADE;
  CREATE SERVER example_postgres_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'remote_postgres_host', port '5432', dbname 'remote_db');
  
  -- Erstelle Benutzer-Mapping für die Verbindung
  CREATE USER MAPPING IF NOT EXISTS FOR fdw_user
    SERVER example_postgres_server
    OPTIONS (user 'remote_user', password 'remote_password');
  
  -- Beispiel für eine Foreign Table von PostgreSQL
  DROP FOREIGN TABLE IF EXISTS external_sources.example_foreign_table;
  CREATE FOREIGN TABLE external_sources.example_foreign_table (
    id int,
    name text,
    value numeric
  )
  SERVER example_postgres_server
  OPTIONS (schema_name 'public', table_name 'remote_table');
  
  -- Erstelle Beispiel-Server für CSV-Dateien
  DROP SERVER IF EXISTS csv_files CASCADE;
  CREATE SERVER csv_files
    FOREIGN DATA WRAPPER file_fdw;
  
  -- Beispiel für eine Foreign Table aus einer CSV-Datei
  DROP FOREIGN TABLE IF EXISTS external_sources.example_csv;
  CREATE FOREIGN TABLE external_sources.example_csv (
    id int,
    name text,
    value numeric
  )
  SERVER csv_files
  OPTIONS (
    filename '/var/lib/postgresql/data/example.csv',
    format 'csv',
    header 'true',
    delimiter ','
  );
  
  -- Informationen zu installierten FDWs anzeigen
  SELECT fdw.fdwname AS "Foreign Data Wrapper",
         pg_catalog.obj_description(c.oid, 'pg_class') AS "Description"
  FROM pg_catalog.pg_foreign_data_wrapper fdw
  LEFT JOIN pg_catalog.pg_class c ON c.oid = fdw.oid
  ORDER BY 1;
  
  -- Zeige installierte Erweiterungen an
  SELECT name, default_version, installed_version, comment 
  FROM pg_available_extensions 
  WHERE installed_version IS NOT NULL
  ORDER BY name;
EOSQL

echo "Foreign Data Wrappers wurden initialisiert."

# Zeige Informationen über die installierten Erweiterungen
echo "Installierte PostgreSQL-Erweiterungen:"
psql -U "$POSTGRES_USER" -d "exadb" -c "SELECT name, default_version, installed_version, comment FROM pg_available_extensions WHERE installed_version IS NOT NULL ORDER BY name;" || true

# Prüfe und zeige installierte FDW-Erweiterungen
echo "Installierte Foreign Data Wrappers:"
psql -U "$POSTGRES_USER" -d "exadb" -c "SELECT fdw.fdwname AS \"Foreign Data Wrapper\", pg_catalog.obj_description(c.oid, 'pg_class') AS \"Description\" FROM pg_catalog.pg_foreign_data_wrapper fdw LEFT JOIN pg_catalog.pg_class c ON c.oid = fdw.oid ORDER BY 1;" || true

# Erstelle eine Beispiel-CSV-Datei für den Test
cat > /var/lib/postgresql/data/example.csv << EOL
id,name,value
1,Beispiel1,100.50
2,Beispiel2,200.75
3,Beispiel3,300.25
4,Beispiel4,400.00
5,Beispiel5,500.99
EOL

echo "Beispiel-CSV-Datei wurde erstellt." 