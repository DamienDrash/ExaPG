# Datenintegration in ExaPG

Dieses Dokument beschreibt die Datenintegrationsfunktionen von ExaPG, die es ermöglichen, Daten aus verschiedenen Quellen einzubinden und ETL-Prozesse (Extract, Transform, Load) zu automatisieren.

## Überblick

ExaPG bietet umfassende Datenintegrationsfunktionen für analytische Workloads:

1. **Foreign Data Wrappers (FDW)** für den Zugriff auf externe Datenquellen
2. **ETL-Automatisierung** mit pgAgent für regelmäßige Datenverarbeitung
3. **Einheitliche Datenzugriffsschicht** über virtuelle Views und Schemas

Diese Funktionen ermöglichen die Erstellung einer einheitlichen analytischen Plattform, die Daten aus verschiedenen Quellen konsolidiert.

## Foreign Data Wrappers

### Unterstützte Datenquellen

ExaPG unterstützt folgende Datenquellen über Foreign Data Wrappers:

| Datenquelle | FDW | Beschreibung |
|-------------|-----|--------------|
| PostgreSQL | postgres_fdw | Verbindung zu anderen PostgreSQL-Datenbanken |
| MySQL/MariaDB | mysql_fdw | Verbindung zu MySQL und MariaDB |
| MongoDB | mongo_fdw | Verbindung zu MongoDB-Datenbanken |
| SQL Server | tds_fdw | Verbindung zu Microsoft SQL Server |
| SQLite | sqlite_fdw | Verbindung zu SQLite-Datenbanken |
| Redis | redis_fdw | Verbindung zu Redis-Datenbanken |
| CSV/Textdateien | file_fdw | Zugriff auf CSV- und Textdateien |

### Einrichtung einer FDW-Verbindung

Die Einrichtung einer FDW-Verbindung erfolgt in drei Schritten:

1. **Server-Definition**: Erstellen eines Foreign Servers, der die Verbindungsinformationen enthält
2. **Benutzer-Mapping**: Verknüpfung von lokalen und entfernten Benutzerkonten
3. **Foreign Table**: Definition der Tabellen und Spalten für den Zugriff

#### Beispiel: PostgreSQL-Verbindung

```sql
-- 1. Server-Definition
CREATE SERVER postgres_remote
  FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host 'remote_server', port '5432', dbname 'remote_db');

-- 2. Benutzer-Mapping
CREATE USER MAPPING FOR CURRENT_USER
  SERVER postgres_remote
  OPTIONS (user 'remote_user', password 'remote_password');

-- 3. Foreign Table
CREATE FOREIGN TABLE external_sources.remote_customers (
  customer_id integer,
  customer_name varchar(100),
  email varchar(100)
)
SERVER postgres_remote
OPTIONS (schema_name 'public', table_name 'customers');
```

#### Beispiel: MySQL-Verbindung

```sql
-- 1. Server-Definition
CREATE SERVER mysql_server
  FOREIGN DATA WRAPPER mysql_fdw
  OPTIONS (host 'mysql_server', port '3306');

-- 2. Benutzer-Mapping
CREATE USER MAPPING FOR CURRENT_USER
  SERVER mysql_server
  OPTIONS (username 'mysql_user', password 'mysql_password');

-- 3. Foreign Table
CREATE FOREIGN TABLE external_sources.mysql_products (
  product_id integer,
  product_name varchar(100),
  price numeric(10,2)
)
SERVER mysql_server
OPTIONS (dbname 'inventory', table_name 'products');
```

### Virtuelle Views über mehrere Datenquellen

Ein besonders nützliches Feature ist die Möglichkeit, virtuelle Views zu erstellen, die Daten aus verschiedenen Quellen kombinieren:

```sql
CREATE VIEW external_sources.combined_sales AS
SELECT 
  'PostgreSQL' AS source,
  s.sale_id,
  s.sale_date,
  c.customer_name,
  p.product_name,
  s.quantity,
  s.total_price
FROM 
  external_sources.remote_sales s
  JOIN external_sources.remote_customers c ON s.customer_id = c.customer_id
  JOIN external_sources.mysql_products p ON s.product_id = p.product_id;
```

## ETL-Automatisierung mit pgAgent

### ETL-Architektur

Die ETL-Architektur in ExaPG basiert auf folgenden Komponenten:

1. **Staging-Tabellen**: Temporäre Tabellen für importierte Rohdaten
2. **Transformationsprozeduren**: SQL-Prozeduren für die Datenaufbereitung
3. **Zieltabellen**: Finale Tabellen für bereinigte und transformierte Daten
4. **pgAgent-Jobs**: Zeitgesteuerte Aufgaben für die Automatisierung

### ETL-Prozess

Der typische ETL-Prozess in ExaPG umfasst folgende Schritte:

1. **Extraktion**: Daten werden aus externen Quellen in Staging-Tabellen geladen
2. **Transformation**: Daten werden bereinigt, validiert und transformiert
3. **Laden**: Transformierte Daten werden in die Zieltabellen geschrieben
4. **Protokollierung**: Alle Schritte werden protokolliert für Monitoring und Fehlersuche

### Beispiel-Prozedur für ETL

```sql
-- ETL-Prozedur für Kundendaten
CREATE OR REPLACE PROCEDURE etl.load_customers()
LANGUAGE plpgsql AS $$
BEGIN
    -- Protokollierung starten
    PERFORM etl.log_etl_activity('load_customers', 'STARTED');
    
    -- ETL-Prozess
    BEGIN
        -- Upsert für Kundendaten
        INSERT INTO etl.dim_customers (
            customer_id, customer_name, email, updated_at
        )
        SELECT 
            s.customer_id, 
            s.customer_name, 
            s.email, 
            now()
        FROM 
            etl.staging_customers s
        ON CONFLICT (customer_id) 
        DO UPDATE SET
            customer_name = EXCLUDED.customer_name,
            email = EXCLUDED.email,
            updated_at = now();
            
        -- Bereinigung der Staging-Tabelle
        TRUNCATE TABLE etl.staging_customers;
        
        -- Protokollierung erfolgreich
        PERFORM etl.log_etl_activity('load_customers', 'COMPLETED');
    EXCEPTION WHEN OTHERS THEN
        -- Protokollierung bei Fehler
        PERFORM etl.log_etl_activity('load_customers', 'ERROR', SQLERRM);
        RAISE;
    END;
END;
$$;
```

### pgAgent-Jobs

pgAgent ermöglicht die zeitgesteuerte Ausführung von ETL-Prozessen:

| Job-Typ | Beschreibung | Typischer Zeitplan |
|---------|--------------|-------------------|
| Vollständige Datenaktualisierung | Vollständiger ETL-Prozess für alle Daten | Täglich (z.B. 02:00 Uhr) |
| Inkrementelle Aktualisierung | Nur neue oder geänderte Daten werden verarbeitet | Stündlich |
| Dimensionsdaten-Aktualisierung | Aktualisierung von Stammdaten | Mehrmals täglich |
| Faktendaten-Aktualisierung | Aktualisierung von Transaktionsdaten | Häufig (z.B. alle 30 Minuten) |

Die Konfiguration der Jobs erfolgt über pgAdmin oder direkt über SQL-Befehle:

```sql
-- Beispiel für einen täglichen ETL-Job
SELECT pgagent.create_job(
    'Daily Full ETL',
    'Tägliche vollständige ETL-Verarbeitung',
    '0 2 * * *',
    'CALL etl.run_full_etl();'
);
```

## Best Practices

### Sicherheit

1. **Benutzer mit minimalen Rechten**: Verwenden Sie dedizierte Benutzer mit minimalen Rechten für FDW-Verbindungen
2. **Verschlüsselte Verbindungen**: Aktivieren Sie SSL/TLS für Verbindungen zu externen Datenquellen
3. **Passwort-Management**: Speichern Sie Passwörter niemals im Klartext, sondern verwenden Sie sichere Methoden

### Performance

1. **Selektive Extraktion**: Extrahieren Sie nur die benötigten Daten aus externen Quellen
2. **Parallele Verarbeitung**: Nutzen Sie die Citus-Verteilung für große ETL-Workloads
3. **Partitionierung**: Partitionieren Sie große Faktentabellen nach Datum für effiziente Verarbeitung
4. **Inkrementelle Updates**: Implementieren Sie Change Data Capture (CDC) für inkrementelle Aktualisierungen

### Zuverlässigkeit

1. **Transaktionsmanagement**: Verwenden Sie Transaktionen für atomare ETL-Prozesse
2. **Fehlerprotokollierung**: Protokollieren Sie alle ETL-Aktivitäten für Audit und Fehlersuche
3. **Datenvalidierung**: Implementieren Sie Validierungsregeln für importierte Daten
4. **Wiederholungsstrategien**: Automatisieren Sie Wiederholungsversuche für fehlgeschlagene ETL-Prozesse

## Beispiele

### 1. Täglicher Import von Verkaufsdaten aus verschiedenen Quellen

```sql
-- ETL-Prozedur für täglichen Verkaufsimport
CREATE OR REPLACE PROCEDURE etl.import_daily_sales()
LANGUAGE plpgsql AS $$
BEGIN
    -- Verkaufsdaten aus PostgreSQL importieren
    INSERT INTO etl.staging_sales
    SELECT * FROM external_sources.remote_sales
    WHERE sale_date = current_date - interval '1 day';
    
    -- Verkaufsdaten aus MySQL importieren
    INSERT INTO etl.staging_sales
    SELECT * FROM external_sources.mysql_sales
    WHERE sale_date = current_date - interval '1 day';
    
    -- ETL-Prozess für Verkaufsdaten ausführen
    CALL etl.load_sales();
END;
$$;
```

### 2. Datenqualitätsprüfungen

```sql
-- Datenqualitätsprüfung
CREATE OR REPLACE FUNCTION etl.check_data_quality()
RETURNS TABLE(source_name text, error_type text, error_count bigint) AS $$
BEGIN
    RETURN QUERY
    
    -- Prüfung auf fehlende Werte
    SELECT 
        'customer_dimension' AS source_name,
        'missing_values' AS error_type,
        COUNT(*) AS error_count
    FROM 
        etl.dim_customers
    WHERE 
        customer_name IS NULL OR email IS NULL
    
    UNION ALL
    
    -- Prüfung auf Duplikate
    SELECT 
        'sales_fact' AS source_name,
        'duplicates' AS error_type,
        COUNT(*) - COUNT(DISTINCT sale_id) AS error_count
    FROM 
        etl.fact_sales;
END;
$$ LANGUAGE plpgsql;
```

## Integration mit anderen ExaPG-Funktionen

Die Datenintegrationsfunktionen lassen sich nahtlos mit anderen ExaPG-Funktionen kombinieren:

1. **Citus-Cluster**: Verteilung von ETL-Workloads über mehrere Knoten
2. **Columnar Storage**: Effiziente Speicherung transformierter Daten für analytische Abfragen
3. **TimescaleDB**: Zeitreihenanalyse für historische ETL-Daten
4. **PostGIS**: Räumliche Datenverarbeitung in ETL-Prozessen

## Vergleich mit Exasol

| Funktion | ExaPG | Exasol |
|----------|-------|--------|
| Externe Datenquellen | Vielfältige FDWs für verschiedene Datenbanken | Virtual Schemas, hauptsächlich über JDBC |
| ETL-Automatisierung | pgAgent-Integration | Exasol-eigene Scheduler |
| Transformationssprache | PL/pgSQL, SQL | Lua, SQL |
| Skalierbarkeit | Horizontal mit Citus | Nativ horizontal skalierbar |
| Anpassbarkeit | Sehr flexibel, Open-Source | Beschränkt auf verfügbare Konnektoren |

## Fazit

Die Datenintegrationsfunktionen von ExaPG bieten eine flexible und leistungsfähige Lösung für die Konsolidierung von Daten aus verschiedenen Quellen. Durch die Kombination von Foreign Data Wrappers und ETL-Automatisierung ermöglicht ExaPG die Erstellung einer einheitlichen analytischen Plattform, die mit der von Exasol vergleichbar, aber flexibler und kostengünstiger ist. 