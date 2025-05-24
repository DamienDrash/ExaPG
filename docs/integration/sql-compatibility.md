# SQL-Kompatibilitätsreferenz: Exasol zu ExaPG

Diese Referenz dokumentiert die SQL-Kompatibilität zwischen Exasol und ExaPG und bietet Lösungen für die wichtigsten Syntax- und Funktionsunterschiede.

## Inhaltsverzeichnis

1. [Allgemeine Syntax](#allgemeine-syntax)
2. [Datentypen](#datentypen)
3. [Funktionen](#funktionen)
4. [Systemansichten](#systemansichten)
5. [Besondere Konstrukte](#besondere-konstrukte)
6. [Performance-Hinweise](#performance-hinweise)
7. [Eingebaute Verfahren](#eingebaute-verfahren)
8. [Fehlercodes und -meldungen](#fehlercodes-und--meldungen)

## Allgemeine Syntax

### SELECT-Statement

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `SELECT * FROM table LIMIT 10;` | `SELECT * FROM table LIMIT 10;` | Identische Syntax |
| `SELECT TOP 10 * FROM table;` | `SELECT * FROM table LIMIT 10;` | Alternative Syntax |
| `SELECT * FROM table ORDER BY col LIMIT 10;` | `SELECT * FROM table ORDER BY col LIMIT 10;` | Identische Syntax |
| `SELECT * FROM table LIMIT 10 OFFSET 20;` | `SELECT * FROM table LIMIT 10 OFFSET 20;` oder<br>`SELECT * FROM table OFFSET 20 ROWS FETCH FIRST 10 ROWS ONLY;` | Beide Varianten funktionieren in ExaPG |

### INSERT-Statement

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `INSERT INTO table VALUES (1, 'text');` | `INSERT INTO table VALUES (1, 'text');` | Identische Syntax |
| `INSERT INTO table (col1, col2) VALUES (1, 'text');` | `INSERT INTO table (col1, col2) VALUES (1, 'text');` | Identische Syntax |
| `INSERT INTO table VALUES (1, 'text'), (2, 'more');` | `INSERT INTO table VALUES (1, 'text'), (2, 'more');` | Identische Syntax |

### UPDATE-Statement

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `UPDATE table SET col1 = 1 WHERE col2 = 'text';` | `UPDATE table SET col1 = 1 WHERE col2 = 'text';` | Identische Syntax |
| `UPDATE table SET col1 = 1, col2 = 'text' WHERE id = 100;` | `UPDATE table SET col1 = 1, col2 = 'text' WHERE id = 100;` | Identische Syntax |

### DELETE-Statement

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `DELETE FROM table WHERE col1 = 1;` | `DELETE FROM table WHERE col1 = 1;` | Identische Syntax |

### MERGE-Statement (Upsert)

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| ```sql
MERGE INTO target_table t
USING source_table s
ON (t.id = s.id)
WHEN MATCHED THEN
  UPDATE SET t.val = s.val
WHEN NOT MATCHED THEN
  INSERT (id, val) VALUES (s.id, s.val);
``` | ```sql
INSERT INTO target_table (id, val)
SELECT id, val FROM source_table
ON CONFLICT (id)
DO UPDATE SET val = EXCLUDED.val;
``` | Unterschiedliche Syntax, aber ähnliche Funktionalität |

### Gespeicherte Prozeduren

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| ```sql
CREATE OR REPLACE PROCEDURE my_proc(param1 IN VARCHAR, param2 OUT NUMBER)
AS
BEGIN
  -- Code
END;
``` | ```sql
CREATE OR REPLACE FUNCTION my_proc(param1 VARCHAR, OUT param2 NUMERIC)
RETURNS RECORD AS $$
BEGIN
  -- Code
END;
$$ LANGUAGE plpgsql;
``` | In ExaPG werden Funktionen mit OUT-Parametern verwendet |

## Datentypen

| Exasol-Datentyp | ExaPG-Datentyp | Anmerkungen |
|-----------------|----------------|-------------|
| `DECIMAL(p,s)` | `NUMERIC(p,s)` | Äquivalente Typen |
| `DOUBLE` | `DOUBLE PRECISION` | Äquivalente Typen |
| `CHAR(n)` | `CHAR(n)` | Identisch |
| `VARCHAR(n)` | `VARCHAR(n)` | Identisch |
| `BOOLEAN` | `BOOLEAN` | Identisch |
| `DATE` | `DATE` | Identisch |
| `TIMESTAMP` | `TIMESTAMP` | Identisch |
| `TIMESTAMP WITH LOCAL TIME ZONE` | `TIMESTAMP WITH TIME ZONE` | Semantischer Unterschied - erfordert besondere Behandlung |
| `INTERVAL` | `INTERVAL` | Ähnlich, aber Syntax unterscheidet sich |
| `GEOMETRY` | Benötigt PostGIS: `GEOMETRY` | Erfordert PostGIS-Extension |
| `HASHTYPE` | Kein direktes Äquivalent | Alternative: `BYTEA` mit Hash-Funktionen |

## Funktionen

### Datumsfunktionen

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `ADD_DAYS(datum, n)` | `datum + n * INTERVAL '1 day'` | Verfügbar in ExaPG-Kompatibilitätsschicht als `ADD_DAYS` |
| `ADD_MONTHS(datum, n)` | `datum + n * INTERVAL '1 month'` | Verfügbar in ExaPG-Kompatibilitätsschicht als `ADD_MONTHS` |
| `ADD_YEARS(datum, n)` | `datum + n * INTERVAL '1 year'` | Verfügbar in ExaPG-Kompatibilitätsschicht als `ADD_YEARS` |
| `CURRENT_DATE` | `CURRENT_DATE` | Identisch |
| `CURRENT_TIMESTAMP` | `CURRENT_TIMESTAMP` | Identisch |
| `EXTRACT(part FROM datum)` | `EXTRACT(part FROM datum)` | Identisch |
| `SECONDS_BETWEEN(dt1, dt2)` | `EXTRACT(EPOCH FROM (dt2 - dt1))` | Verfügbar in ExaPG-Kompatibilitätsschicht als `SECONDS_BETWEEN` |
| `DAYS_BETWEEN(dt1, dt2)` | `dt2::date - dt1::date` | Verfügbar in ExaPG-Kompatibilitätsschicht als `DAYS_BETWEEN` |
| `MONTHS_BETWEEN(dt1, dt2)` | Komplexere Berechnung | Verfügbar in ExaPG-Kompatibilitätsschicht als `MONTHS_BETWEEN` |

### Zeichenkettenfunktionen

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `LENGTH(str)` | `LENGTH(str)` | Identisch |
| `LOWER(str)` | `LOWER(str)` | Identisch |
| `UPPER(str)` | `UPPER(str)` | Identisch |
| `SUBSTRING(str, pos, len)` | `SUBSTRING(str FROM pos FOR len)` | Unterschiedliche Syntax |
| `TRIM(str)` | `TRIM(str)` | Identisch |
| `LTRIM(str)` | `LTRIM(str)` | Identisch |
| `RTRIM(str)` | `RTRIM(str)` | Identisch |
| `INSTR(str, substring)` | `POSITION(substring IN str)` | Unterschiedliche Syntax |
| `REGEXP_SUBSTR(str, pattern)` | `substring(str from pattern)` | Unterschiedliche Syntax |
| `REGEXP_REPLACE(str, pattern, repl)` | `regexp_replace(str, pattern, repl)` | Ähnlich, aber andere Regex-Syntax |

### Mathematische Funktionen

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `ABS(x)` | `ABS(x)` | Identisch |
| `CEIL(x)` | `CEIL(x)` | Identisch |
| `FLOOR(x)` | `FLOOR(x)` | Identisch |
| `ROUND(x, n)` | `ROUND(x, n)` | Identisch |
| `TRUNC(x, n)` | `TRUNC(x, n)` | Identisch |
| `POWER(x, y)` | `POWER(x, y)` | Identisch |
| `SQRT(x)` | `SQRT(x)` | Identisch |
| `MOD(x, y)` | `MOD(x, y)` | Identisch |
| `LN(x)` | `LN(x)` | Identisch |
| `EXP(x)` | `EXP(x)` | Identisch |
| `RANDOM()` | `RANDOM()` | Unterschiedlicher Wertebereich |

### NULL-Behandlung

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `NVL(expr1, expr2)` | `COALESCE(expr1, expr2)` | Verfügbar in ExaPG-Kompatibilitätsschicht als `NVL` |
| `NULLIFZERO(x)` | `NULLIF(x, 0)` | Verfügbar in ExaPG-Kompatibilitätsschicht als `NULLIFZERO` |
| `ZEROIFNULL(x)` | `COALESCE(x, 0)` | Verfügbar in ExaPG-Kompatibilitätsschicht als `ZEROIFNULL` |
| `ISNULL(x)` | `x IS NULL` | Unterschiedliche Syntax |

### Aggregatfunktionen

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `COUNT(*)` | `COUNT(*)` | Identisch |
| `COUNT(DISTINCT col)` | `COUNT(DISTINCT col)` | Identisch |
| `SUM(col)` | `SUM(col)` | Identisch |
| `MIN(col)` | `MIN(col)` | Identisch |
| `MAX(col)` | `MAX(col)` | Identisch |
| `AVG(col)` | `AVG(col)` | Identisch |
| `MEDIAN(col)` | `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY col)` | Unterschiedliche Syntax |
| `STDDEV(col)` | `STDDEV(col)` | Identisch |
| `VAR(col)` | `VARIANCE(col)` | Unterschiedliche Benennung |

### Typkonvertierungen

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `CAST(expr AS typ)` | `CAST(expr AS typ)` | Identisch |
| `TO_CHAR(datum, format)` | `TO_CHAR(datum, format)` | Ähnlich, aber unterschiedliche Formatierungszeichen |
| `TO_DATE(str, format)` | `TO_DATE(str, format)` | Ähnlich, aber unterschiedliche Formatierungszeichen |
| `TO_NUMBER(str, format)` | `TO_NUMBER(str, format)` | Ähnlich, aber unterschiedliche Formatierungszeichen |
| `TO_TIMESTAMP(str, format)` | `TO_TIMESTAMP(str, format)` | Ähnlich, aber unterschiedliche Formatierungszeichen |

## Systemansichten

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `EXA_ALL_TABLES` | `pg_tables` | Unterschiedliche Struktur |
| `EXA_ALL_COLUMNS` | `information_schema.columns` | Unterschiedliche Struktur |
| `EXA_DBA_USERS` | `pg_user` | Unterschiedliche Struktur |
| `EXA_USER_SESSIONS` | `pg_stat_activity` | Unterschiedliche Struktur |
| `EXA_ALL_LOCKS` | `pg_locks` | Unterschiedliche Struktur |

### System-Schemas in ExaPG

Für eine einfachere Migration haben wir in ExaPG ein spezielles Schema eingerichtet, das die wichtigsten Exasol-Systemansichten emuliert:

```sql
-- Kompatibilitätsschema aktivieren
CREATE EXTENSION exapg_compat_schema;

-- Beispielabfrage, die Exasol-kompatible Syntax verwendet
SELECT * FROM EXA_ALL_TABLES WHERE TABLE_SCHEMA = 'public';
```

## Besondere Konstrukte

### Analytische Funktionen

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `ROW_NUMBER() OVER(...)` | `ROW_NUMBER() OVER(...)` | Identisch |
| `RANK() OVER(...)` | `RANK() OVER(...)` | Identisch |
| `DENSE_RANK() OVER(...)` | `DENSE_RANK() OVER(...)` | Identisch |
| `LEAD(col, n) OVER(...)` | `LEAD(col, n) OVER(...)` | Identisch |
| `LAG(col, n) OVER(...)` | `LAG(col, n) OVER(...)` | Identisch |
| `FIRST_VALUE(col) OVER(...)` | `FIRST_VALUE(col) OVER(...)` | Identisch |
| `LAST_VALUE(col) OVER(...)` | `LAST_VALUE(col) OVER(...)` | Identisch |
| `RATIO_TO_REPORT(col) OVER(...)` | Komplexer Ausdruck | Verfügbar in ExaPG-Kompatibilitätsschicht |

### Hierarchische Abfragen

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| ```sql
SELECT ... FROM table
START WITH condition
CONNECT BY PRIOR parent_id = id
``` | ```sql
WITH RECURSIVE tree AS (
  SELECT * FROM table WHERE condition
  UNION ALL
  SELECT t.* FROM table t
  JOIN tree tr ON t.id = tr.parent_id
)
SELECT * FROM tree
``` | Unterschiedliche Syntax, aber äquivalentes Ergebnis |

### IMPORT/EXPORT

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| ```sql
IMPORT INTO table 
FROM CSV AT 'host:port' 
USER 'user' IDENTIFIED BY 'password'
FILE 'file.csv'
``` | ```sql
COPY table FROM 'file.csv' 
WITH (FORMAT csv, DELIMITER ',')
``` | In ExaPG wird COPY für Bulk-Operationen verwendet |
| ```sql
EXPORT table INTO CSV AT 'host:port' 
USER 'user' IDENTIFIED BY 'password'
FILE 'file.csv'
``` | ```sql
COPY table TO 'file.csv' 
WITH (FORMAT csv, DELIMITER ',')
``` | In ExaPG wird COPY für Bulk-Operationen verwendet |

## Performance-Hinweise

Für optimale Performance bei der Migration von Exasol zu ExaPG:

### Parallelisierung

```sql
-- Exasol: Parallelisierung ist automatisch
SELECT * FROM large_table WHERE condition;

-- ExaPG: Explizite Parallelisierung konfigurieren
SET max_parallel_workers_per_gather = 8;
SELECT * FROM large_table WHERE condition;

-- Tabelle für Parallelisierung optimieren
ALTER TABLE large_table SET (parallel_workers = 8);
```

### Partitionierung

```sql
-- Exasol: Distribution Keys
CREATE TABLE sales (
  id INT, 
  sale_date DATE,
  amount DECIMAL(10,2),
  customer_id INT
) DISTRIBUTE BY sale_date;

-- ExaPG: Deklarative Partitionierung
CREATE TABLE sales (
  id INT,
  sale_date DATE,
  amount NUMERIC(10,2),
  customer_id INT
) PARTITION BY RANGE (sale_date);

-- Partitionen anlegen
CREATE TABLE sales_202301 PARTITION OF sales
  FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');
CREATE TABLE sales_202302 PARTITION OF sales
  FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');
```

### Columnar Storage

```sql
-- ExaPG: Columnar Storage für analytische Tabellen
CREATE TABLE analytics_data (
  id INT,
  event_date TIMESTAMP,
  metrics JSONB,
  dimensions VARCHAR(255)
) USING columnar;

-- Kompressionseinstellungen optimieren
ALTER TABLE analytics_data 
SET (columnar.compression = 'zstd', columnar.compression_level = 3);
```

## Eingebaute Verfahren

| Exasol | ExaPG | Anmerkungen |
|--------|-------|-------------|
| `FLUSH STATISTICS` | `ANALYZE` | Unterschiedliche Syntax |
| `REORGANIZE` | `VACUUM FULL` | Unterschiedliche Syntax |
| `GRANT SYSTEM PRIVILEGE` | PostgreSQL-Rollenmodell | Unterschiedliches Berechtigungskonzept |
| `CREATE CONNECTION` | Foreign Data Wrapper | Unterschiedliches Konzept für externe Verbindungen |
| `GRANT CONNECTION` | `GRANT USAGE ON FOREIGN SERVER` | Unterschiedliche Syntax |

## Fehlercodes und -meldungen

Exasol und PostgreSQL verwenden unterschiedliche Fehlercodebereiche und -meldungen. Hier sind einige der häufigsten Mappings:

| Exasol-Fehler | PostgreSQL-Fehler | Anmerkungen |
|---------------|-------------------|-------------|
| 22000: Syntax error | 42601: syntax_error | Syntaxfehler |
| 42S22: Column not found | 42703: undefined_column | Spalte nicht gefunden |
| 42000: Invalid object name | 42P01: undefined_table | Objekt nicht gefunden |
| 23000: Integrity constraint violation | 23505: unique_violation | Verletzung einer Integritätsbedingung |
| HY000: Permission denied | 42501: insufficient_privilege | Berechtigungsfehler |

## Kompatibilitätsschicht installieren

Um die maximale Kompatibilität zwischen Exasol und ExaPG zu gewährleisten, installieren Sie unsere Kompatibilitätserweiterung:

```sql
-- Als Superuser ausführen
CREATE EXTENSION exapg_compat;

-- Funktionskatalog anzeigen
SELECT function_name, description 
FROM exapg_compat_functions
ORDER BY function_name;
```

Die Kompatibilitätsschicht umfasst:
- Exasol-kompatible Funktionsnamen
- Emulation von Exasol-spezifischen Systemansichten
- Spezielle Behandlung von Exasol-spezifischen SQL-Konstrukten

## Skript zur Umwandlung von Exasol-SQL

Unser Automatisierungstool kann die meisten Exasol-SQL-Abfragen automatisch in ExaPG-kompatiblen SQL-Code umwandeln:

```bash
# Beispiel zur Umwandlung einer SQL-Datei
scripts/migration/convert_sql.py --input exasol_query.sql --output exapg_query.sql

# Beispiel zur Umwandlung eines ganzen Verzeichnisses
scripts/migration/convert_sql.py --input-dir exasol_scripts/ --output-dir exapg_scripts/
```

Der Konverter behandelt die gängigsten Kompatibilitätsprobleme, einschließlich:
- Syntax-Anpassungen
- Funktionsnamen-Umwandlung
- Anpassung von Systemtabellen und -views
- Hinzufügen von notwendigen CTEs oder WITH-Klauseln 