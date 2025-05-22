-- Beispiele für die Verwendung verschiedener Foreign Data Wrappers in ExaPG
-- Diese Beispiele demonstrieren die Konfiguration und Nutzung verschiedener Datenquellen

-- 1. PostgreSQL FDW - Verbindung zu einer anderen PostgreSQL-Datenbank
-- Annahme: Ein Remote-PostgreSQL-Server ist auf 'remote_postgres' erreichbar

-- Server-Definition
DROP SERVER IF EXISTS postgres_remote CASCADE;
CREATE SERVER postgres_remote
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host 'remote_postgres', port '5432', dbname 'remote_db');

-- Benutzer-Mapping
CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
  SERVER postgres_remote
  OPTIONS (user 'remote_user', password 'remote_password');

-- Foreign Table
CREATE FOREIGN TABLE external_sources.remote_customers (
  customer_id integer,
  customer_name varchar(100),
  email varchar(100),
  created_at timestamp
)
SERVER postgres_remote
OPTIONS (schema_name 'public', table_name 'customers');

-- Beispielabfrage (auskommentiert, da Remote-Server nicht existiert)
-- SELECT * FROM external_sources.remote_customers LIMIT 10;

-- 2. MySQL FDW - Verbindung zu einer MySQL-Datenbank
-- Annahme: Ein MySQL-Server ist auf 'mysql_server' erreichbar

-- Server-Definition
DROP SERVER IF EXISTS mysql_server CASCADE;
CREATE SERVER mysql_server
  FOREIGN DATA WRAPPER mysql_fdw
  OPTIONS (host 'mysql_server', port '3306');

-- Benutzer-Mapping
CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
  SERVER mysql_server
  OPTIONS (username 'mysql_user', password 'mysql_password');

-- Foreign Table
CREATE FOREIGN TABLE external_sources.mysql_products (
  product_id integer,
  product_name varchar(100),
  price numeric(10,2),
  category varchar(50)
)
SERVER mysql_server
OPTIONS (dbname 'inventory', table_name 'products');

-- Beispielabfrage (auskommentiert, da MySQL-Server nicht existiert)
-- SELECT * FROM external_sources.mysql_products LIMIT 10;

-- 3. CSV-Datei über file_fdw
-- Hier nutzen wir die bereits erstellte Beispiel-CSV-Datei

-- Abfrage der bestehenden CSV-Tabelle
SELECT * FROM external_sources.example_csv;

-- 4. SQLite FDW - Verbindung zu einer SQLite-Datenbank
-- Annahme: Eine SQLite-Datenbank wurde erstellt

-- Erstelle eine Beispiel-SQLite-Datenbank (in einem Beispielszenario)
DO $$
BEGIN
  -- Dieser Block würde in der Praxis außerhalb von PostgreSQL ausgeführt
  -- und hier nur zur Demonstration
END$$;

-- Server-Definition
DROP SERVER IF EXISTS sqlite_db CASCADE;
CREATE SERVER sqlite_db
  FOREIGN DATA WRAPPER sqlite_fdw
  OPTIONS (database '/var/lib/postgresql/data/example.db');

-- Foreign Table
CREATE FOREIGN TABLE external_sources.sqlite_orders (
  order_id integer,
  customer_id integer,
  order_date date,
  total_amount numeric(10,2)
)
SERVER sqlite_db
OPTIONS (table 'orders');

-- Beispielabfrage (auskommentiert, da SQLite-DB nicht existiert)
-- SELECT * FROM external_sources.sqlite_orders LIMIT 10;

-- 5. MongoDB FDW - Verbindung zu einer MongoDB-Datenbank
-- Annahme: Ein MongoDB-Server ist auf 'mongodb_server' erreichbar

-- Server-Definition
DROP SERVER IF EXISTS mongo_server CASCADE;
CREATE SERVER mongo_server
  FOREIGN DATA WRAPPER mongo_fdw
  OPTIONS (address 'mongodb_server', port '27017');

-- Benutzer-Mapping
CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
  SERVER mongo_server
  OPTIONS (username 'mongo_user', password 'mongo_password');

-- Foreign Table
CREATE FOREIGN TABLE external_sources.mongo_users (
  _id name,
  user_id integer,
  username text,
  email text,
  last_login timestamp
)
SERVER mongo_server
OPTIONS (database 'userdb', collection 'users');

-- Beispielabfrage (auskommentiert, da MongoDB-Server nicht existiert)
-- SELECT * FROM external_sources.mongo_users LIMIT 10;

-- 6. SQL Server FDW (TDS) - Verbindung zu einem MS SQL Server
-- Annahme: Ein SQL Server ist auf 'mssql_server' erreichbar

-- Server-Definition
DROP SERVER IF EXISTS mssql_server CASCADE;
CREATE SERVER mssql_server
  FOREIGN DATA WRAPPER tds_fdw
  OPTIONS (servername 'mssql_server', port '1433', database 'SalesDB');

-- Benutzer-Mapping
CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
  SERVER mssql_server
  OPTIONS (username 'mssql_user', password 'mssql_password');

-- Foreign Table
CREATE FOREIGN TABLE external_sources.mssql_sales (
  sale_id integer,
  product_id integer,
  sale_date date,
  quantity integer,
  amount numeric(10,2)
)
SERVER mssql_server
OPTIONS (schema_name 'dbo', table_name 'Sales');

-- Beispielabfrage (auskommentiert, da SQL Server nicht existiert)
-- SELECT * FROM external_sources.mssql_sales LIMIT 10;

-- 7. Redis FDW - Verbindung zu einer Redis-Datenbank
-- Annahme: Ein Redis-Server ist auf 'redis_server' erreichbar

-- Server-Definition
DROP SERVER IF EXISTS redis_server CASCADE;
CREATE SERVER redis_server
  FOREIGN DATA WRAPPER redis_fdw
  OPTIONS (address 'redis_server', port '6379');

-- Foreign Table (Redis verwendet Key-Value-Speicher)
CREATE FOREIGN TABLE external_sources.redis_cache (
  key text,
  value text,
  type text
)
SERVER redis_server
OPTIONS (database '0');

-- Beispielabfrage (auskommentiert, da Redis-Server nicht existiert)
-- SELECT * FROM external_sources.redis_cache WHERE key LIKE 'user:%';

-- 8. Demonstration eines virtuellen Views, der Daten aus verschiedenen Quellen kombiniert
CREATE OR REPLACE VIEW external_sources.combined_data AS
SELECT 
  'CSV' AS source,
  id::text AS record_id,
  name AS description,
  value AS amount
FROM 
  external_sources.example_csv
-- In einem realen Szenario würden hier weitere UNIONs mit anderen Quellen folgen
-- UNION ALL
-- SELECT 
--   'PostgreSQL' AS source,
--   customer_id::text AS record_id,
--   customer_name AS description,
--   NULL AS amount
-- FROM 
--   external_sources.remote_customers
;

-- Abfrage der kombinierten Daten
SELECT * FROM external_sources.combined_data;

-- 9. Datenintegritätsprüfung zwischen Quellen
-- Dieses Beispiel würde in einem realen Szenario die Konsistenz zwischen Datenquellen prüfen
CREATE OR REPLACE FUNCTION external_sources.check_data_consistency()
RETURNS TABLE(source_name text, inconsistency_count bigint) AS
$$
BEGIN
  RETURN QUERY
  SELECT 
    'Zwischen CSV und anderen Quellen' AS source_name,
    COUNT(*) AS inconsistency_count
  FROM 
    external_sources.example_csv
  WHERE 
    id NOT IN (SELECT 1 WHERE FALSE); -- Placeholder für echte Prüfungen
END;
$$ LANGUAGE plpgsql;

-- Ausführen der Konsistenzprüfung
SELECT * FROM external_sources.check_data_consistency(); 