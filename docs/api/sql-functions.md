# ExaPG SQL Functions Reference

**Version:** 1.0.0  
**Datum:** 2024-12-28  
**Status:** Production Ready  

---

## 📋 Übersicht

ExaPG stellt erweiterte SQL-Funktionen für analytische Workloads, Partitionierung, UDF-Framework und Citus-Integration bereit. Diese Referenz dokumentiert alle verfügbaren SQL-Funktionen und deren Verwendung.

## 🔧 Analytics Functions

### **Aggregation & Window Functions**

#### `exapg_percentile(column_name, percentile_value)`
**Beschreibung:** Berechnet Perzentile für numerische Spalten  
**Parameter:**
- `column_name` (NUMERIC): Spalte für Berechnung
- `percentile_value` (FLOAT): Perzentil (0.0-1.0)
**Rückgabe:** NUMERIC  
**Beispiel:**
```sql
SELECT exapg_percentile(sales_amount, 0.95) AS p95_sales
FROM sales_data;
```

#### `exapg_moving_average(column_name, window_size)`
**Beschreibung:** Berechnet gleitenden Durchschnitt  
**Parameter:**
- `column_name` (NUMERIC): Spalte für Berechnung
- `window_size` (INTEGER): Fenster-Größe
**Rückgabe:** NUMERIC  
**Beispiel:**
```sql
SELECT date, value, 
       exapg_moving_average(value, 7) OVER (ORDER BY date) AS ma_7day
FROM time_series;
```

#### `exapg_stddev_rolling(column_name, window_size)`
**Beschreibung:** Rolling Standard Deviation  
**Parameter:**
- `column_name` (NUMERIC): Spalte für Berechnung
- `window_size` (INTEGER): Fenster-Größe
**Rückgabe:** NUMERIC  

### **Time Series Functions**

#### `exapg_time_bucket(interval_text, timestamp_column)`
**Beschreibung:** Zeitbasierte Bucketing (TimescaleDB-erweitert)  
**Parameter:**
- `interval_text` (TEXT): Intervall ('1 hour', '1 day', etc.)
- `timestamp_column` (TIMESTAMP): Zeitstempel-Spalte
**Rückgabe:** TIMESTAMP  
**Beispiel:**
```sql
SELECT exapg_time_bucket('1 hour', created_at) AS hour_bucket,
       COUNT(*) AS events_per_hour
FROM events
GROUP BY hour_bucket
ORDER BY hour_bucket;
```

#### `exapg_interpolate(value_column, time_column, interpolation_time)`
**Beschreibung:** Lineare Interpolation für Zeitserien  
**Parameter:**
- `value_column` (NUMERIC): Werte-Spalte
- `time_column` (TIMESTAMP): Zeit-Spalte
- `interpolation_time` (TIMESTAMP): Ziel-Zeit
**Rückgabe:** NUMERIC  

## 🔄 Partitioning Functions

### **Dynamic Partitioning**

#### `exapg_create_time_partition(table_name, partition_column, interval_type)`
**Beschreibung:** Erstellt zeitbasierte Partitionierung  
**Parameter:**
- `table_name` (TEXT): Tabellen-Name
- `partition_column` (TEXT): Partitionierungs-Spalte
- `interval_type` (TEXT): 'monthly', 'weekly', 'daily'
**Rückgabe:** BOOLEAN  
**Beispiel:**
```sql
SELECT exapg_create_time_partition('sales_data', 'sale_date', 'monthly');
```

#### `exapg_create_hash_partition(table_name, partition_column, partition_count)`
**Beschreibung:** Erstellt Hash-basierte Partitionierung  
**Parameter:**
- `table_name` (TEXT): Tabellen-Name
- `partition_column` (TEXT): Partitionierungs-Spalte
- `partition_count` (INTEGER): Anzahl Partitionen
**Rückgabe:** BOOLEAN  

#### `exapg_maintenance_partition(table_name, action)`
**Beschreibung:** Partition-Wartung (cleanup, reorganize, etc.)  
**Parameter:**
- `table_name` (TEXT): Tabellen-Name
- `action` (TEXT): 'cleanup', 'reorganize', 'stats'
**Rückgabe:** TEXT (Wartungs-Report)  

### **Partition Management**

#### `exapg_list_partitions(table_name)`
**Beschreibung:** Listet alle Partitionen einer Tabelle  
**Parameter:**
- `table_name` (TEXT): Tabellen-Name
**Rückgabe:** TABLE (partition_name, partition_size, row_count)  
**Beispiel:**
```sql
SELECT * FROM exapg_list_partitions('sales_data');
```

#### `exapg_drop_old_partitions(table_name, retention_days)`
**Beschreibung:** Löscht alte Partitionen basierend auf Aufbewahrungszeit  
**Parameter:**
- `table_name` (TEXT): Tabellen-Name
- `retention_days` (INTEGER): Aufbewahrungszeit in Tagen
**Rückgabe:** INTEGER (Anzahl gelöschte Partitionen)  

## 🧮 UDF Framework Functions

### **Python UDFs**

#### `exapg_py_exec(python_code, input_data)`
**Beschreibung:** Führt Python-Code mit Input-Daten aus  
**Parameter:**
- `python_code` (TEXT): Python-Code
- `input_data` (JSONB): Input-Daten als JSON
**Rückgabe:** JSONB  
**Beispiel:**
```sql
SELECT exapg_py_exec(
  'import pandas as pd; df = pd.DataFrame(data); return df.mean().to_dict()',
  '{"data": [[1,2,3], [4,5,6]]}'::jsonb
);
```

#### `exapg_py_ml_predict(model_name, features)`
**Beschreibung:** ML-Prediction mit vortrainiertem Modell  
**Parameter:**
- `model_name` (TEXT): Modell-Name
- `features` (FLOAT[]): Feature-Array
**Rückgabe:** FLOAT (Prediction)  

### **R UDFs**

#### `exapg_r_exec(r_code, input_data)`
**Beschreibung:** Führt R-Code aus  
**Parameter:**
- `r_code` (TEXT): R-Code
- `input_data` (JSONB): Input-Daten
**Rückgabe:** JSONB  
**Beispiel:**
```sql
SELECT exapg_r_exec(
  'data <- fromJSON(input_data); summary(data)',
  '{"values": [1,2,3,4,5]}'::jsonb
);
```

#### `exapg_r_statistical_test(test_type, data_array)`
**Beschreibung:** Statistische Tests in R  
**Parameter:**
- `test_type` (TEXT): 't_test', 'chi_square', 'anova'
- `data_array` (FLOAT[]): Daten-Array
**Rückgabe:** JSONB (Test-Ergebnisse)  

### **Lua UDFs**

#### `exapg_lua_exec(lua_code, input_params)`
**Beschreibung:** Führt Lua-Code aus (High Performance)  
**Parameter:**
- `lua_code` (TEXT): Lua-Code
- `input_params` (JSONB): Input-Parameter
**Rückgabe:** TEXT  

## 🌐 Citus Distributed Functions

### **Distributed Query Functions**

#### `exapg_distribute_table(table_name, distribution_column)`
**Beschreibung:** Verteilt Tabelle im Citus-Cluster  
**Parameter:**
- `table_name` (TEXT): Tabellen-Name
- `distribution_column` (TEXT): Verteilungs-Spalte
**Rückgabe:** BOOLEAN  
**Beispiel:**
```sql
SELECT exapg_distribute_table('user_events', 'user_id');
```

#### `exapg_create_reference_table(table_name)`
**Beschreibung:** Erstellt Referenz-Tabelle (repliziert auf alle Nodes)  
**Parameter:**
- `table_name` (TEXT): Tabellen-Name
**Rückgabe:** BOOLEAN  

#### `exapg_rebalance_shards()`
**Beschreibung:** Rebalanciert Shards im Cluster  
**Parameter:** Keine  
**Rückgabe:** TEXT (Rebalancing-Report)  

### **Cluster Management**

#### `exapg_add_worker_node(hostname, port)`
**Beschreibung:** Fügt Worker-Node hinzu  
**Parameter:**
- `hostname` (TEXT): Worker-Hostname
- `port` (INTEGER): Worker-Port
**Rückgabe:** BOOLEAN  

#### `exapg_remove_worker_node(hostname, port)`
**Beschreibung:** Entfernt Worker-Node  
**Parameter:**
- `hostname` (TEXT): Worker-Hostname
- `port` (INTEGER): Worker-Port
**Rückgabe:** BOOLEAN  

#### `exapg_cluster_status()`
**Beschreibung:** Zeigt Cluster-Status  
**Parameter:** Keine  
**Rückgabe:** TABLE (node_name, status, shard_count, cpu_usage, memory_usage)  

## 📊 Performance & Monitoring Functions

### **Query Performance**

#### `exapg_explain_analyze_json(query_text)`
**Beschreibung:** EXPLAIN ANALYZE als JSON  
**Parameter:**
- `query_text` (TEXT): SQL-Query
**Rückgabe:** JSONB (Execution Plan)  

#### `exapg_query_stats(time_range)`
**Beschreibung:** Query-Statistiken für Zeitraum  
**Parameter:**
- `time_range` (INTERVAL): Zeitraum ('1 hour', '1 day')
**Rückgabe:** TABLE (query_hash, calls, total_time, mean_time)  

### **System Monitoring**

#### `exapg_database_size_breakdown()`
**Beschreibung:** Detaillierte Datenbank-Größen-Aufschlüsselung  
**Parameter:** Keine  
**Rückgabe:** TABLE (schema_name, table_name, size_bytes, row_count)  

#### `exapg_connection_stats()`
**Beschreibung:** Aktuelle Verbindungs-Statistiken  
**Parameter:** Keine  
**Rückgabe:** TABLE (state, count, max_duration)  

## 🔧 Utility Functions

### **Data Validation**

#### `exapg_validate_json_schema(json_data, schema_definition)`
**Beschreibung:** Validiert JSON gegen Schema  
**Parameter:**
- `json_data` (JSONB): JSON-Daten
- `schema_definition` (JSONB): JSON-Schema
**Rückgabe:** BOOLEAN  

#### `exapg_data_quality_report(table_name)`
**Beschreibung:** Datenqualitäts-Report  
**Parameter:**
- `table_name` (TEXT): Tabellen-Name
**Rückgabe:** JSONB (Quality Metrics)  

### **Data Conversion**

#### `exapg_csv_to_table(csv_data, table_name, column_definitions)`
**Beschreibung:** Konvertiert CSV zu Tabelle  
**Parameter:**
- `csv_data` (TEXT): CSV-Daten
- `table_name` (TEXT): Ziel-Tabellen-Name
- `column_definitions` (TEXT): Spalten-Definitionen
**Rückgabe:** INTEGER (Anzahl eingefügte Zeilen)  

#### `exapg_json_flatten(json_column, prefix)`
**Beschreibung:** Flacht JSON-Objekt zu Spalten ab  
**Parameter:**
- `json_column` (JSONB): JSON-Spalte
- `prefix` (TEXT): Präfix für neue Spalten
**Rückgabe:** TABLE (Dynamic columns)  

## 📈 Analytics Examples

### **Time Series Analysis**
```sql
-- Rolling metrics mit ExaPG-Funktionen
WITH daily_metrics AS (
  SELECT 
    exapg_time_bucket('1 day', timestamp) AS day,
    COUNT(*) AS daily_count,
    AVG(value) AS daily_avg
  FROM sensor_data
  GROUP BY day
)
SELECT 
  day,
  daily_count,
  daily_avg,
  exapg_moving_average(daily_avg, 7) AS ma_7day,
  exapg_percentile(daily_count, 0.95) AS p95_count
FROM daily_metrics
ORDER BY day;
```

### **Distributed Analytics**
```sql
-- Multi-Node Aggregation mit Citus
SELECT 
  user_region,
  COUNT(*) AS total_events,
  AVG(session_duration) AS avg_duration,
  exapg_percentile(revenue, 0.99) AS p99_revenue
FROM user_events
WHERE event_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY user_region
ORDER BY total_events DESC;
```

### **Machine Learning Pipeline**
```sql
-- ML-Prediction mit Python UDF
WITH user_features AS (
  SELECT 
    user_id,
    ARRAY[age, income, purchase_count, days_since_last_purchase] AS features
  FROM user_profiles
)
SELECT 
  user_id,
  exapg_py_ml_predict('churn_model', features) AS churn_probability
FROM user_features
WHERE churn_probability > 0.8;
```

## 🔗 Function Categories

| Kategorie | Anzahl | Beschreibung |
|-----------|--------|--------------|
| **Analytics** | 15+ | Aggregation, Window Functions, Statistik |
| **Time Series** | 8+ | TimescaleDB-erweiterte Funktionen |
| **Partitioning** | 10+ | Dynamische Partitionierung & Management |
| **UDF Framework** | 12+ | Python, R, Lua Integration |
| **Citus Distributed** | 8+ | Cluster Management & Distribution |
| **Performance** | 6+ | Monitoring & Query Optimization |
| **Utilities** | 10+ | Datenvalidierung & Konvertierung |

## 📚 Siehe auch

- [CLI Functions API](cli-api.md)
- [Docker API Reference](docker-api.md)
- [Configuration Reference](configuration-reference.md)

---

**© 2024 ExaPG Project - SQL Functions Reference v1.0.0** 