# Spaltenorientierte Speicherung in ExaPG

Dieses Dokument beschreibt die Integration und Verwendung der spaltenorientierten Speicherung in ExaPG, unserer PostgreSQL-basierten Exasol-Alternative.

## Überblick

Die spaltenorientierte Speicherung (Columnar Storage) ist eine Speichertechnik, die Daten spaltenweise anstatt zeilenweise speichert. Dies bietet erhebliche Vorteile für analytische Workloads:

- Verbesserte Abfrageperformance für Spaltenoperationen
- Höhere Kompressionsrate
- Reduzierter I/O-Bedarf für analytische Abfragen
- Effizientere Aggregationen

ExaPG nutzt die Citus Columnar-Erweiterung, die eine native Integration in PostgreSQL bietet und gut mit unserem verteilten Citus-Setup zusammenarbeitet.

## Vorteile gegenüber Exasol

Im Vergleich zu Exasol bietet unsere Lösung:

1. **Flexible Speicheroptionen**: Mischung aus zeilen- und spaltenorientierten Tabellen im selben System
2. **Anpassbare Kompression**: Verschiedene Kompressionsalgorithmen und -stufen
3. **Skalierbarkeit**: Kombination von Columnar Storage mit verteilten Tabellen über Citus
4. **Open-Source-Basis**: Keine proprietären Abhängigkeiten

## Konfiguration

Die Konfiguration der spaltenorientierten Speicherung kann durch folgende Parameter angepasst werden:

| Parameter | Beschreibung | Standard | Optimiert |
|-----------|--------------|----------|-----------|
| columnar.stripe_row_limit | Zeilen pro Stripe | 150000 | 250000 |
| columnar.chunk_group_row_limit | Zeilen pro Chunk-Gruppe | 10000 | 15000 |
| columnar.compression | Kompressionsalgorithmus | pglz | zstd |
| columnar.compression_level | Kompressionsstufe für zstd | 3 | 9 |

## Kompressionsleistung

Unsere Tests haben folgende Kompressionsraten im Vergleich zu zeilenorientierter Speicherung ergeben:

| Tabelle | Spaltenorientiert | Zeilenorientiert | Kompressionsverhältnis |
|---------|-------------------|------------------|------------------------|
| system_logs | 96 kB | 792 kB | 8.25x |
| sales_fact | 200 kB | 1208 kB | 6.04x |
| sensor_measurements | 848 kB | 2312 kB | 2.73x |

Die Kompressionsrate variiert je nach Datentyp und -struktur. Text- und Log-Daten (system_logs) erreichen die höchste Kompression, während Messungen mit vielen numerischen Werten (sensor_measurements) weniger stark komprimiert werden.

## Performance-Vergleich

Unsere Benchmarks zeigen die Leistungsunterschiede zwischen spalten- und zeilenorientierter Speicherung:

### Abfrage einzelner Spalten (Aggregation)

```sql
SELECT AVG(temperature), MIN(temperature), MAX(temperature) FROM sensor_measurements;
```

| Format | Ausführungszeit |
|--------|-----------------|
| Spaltenorientiert | 2.849 ms |
| Zeilenorientiert | 3.155 ms |

Hier ist die spaltenorientierte Speicherung leicht schneller.

### Abfrage aller Spalten

```sql
SELECT * FROM sensor_measurements LIMIT 1000;
```

| Format | Ausführungszeit |
|--------|-----------------|
| Spaltenorientiert | 3.484 ms |
| Zeilenorientiert | 0.158 ms |

Bei Abfrage aller Spalten ist die zeilenorientierte Speicherung deutlich schneller.

### Aggregation mit Gruppierung

```sql
SELECT service_name, log_level, DATE_TRUNC('day', timestamp) AS day,
       COUNT(*) AS log_count, AVG(execution_time_ms) AS avg_execution_time
FROM system_logs
GROUP BY service_name, log_level, DATE_TRUNC('day', timestamp)
ORDER BY day, service_name, log_level;
```

| Format | Ausführungszeit |
|--------|-----------------|
| Spaltenorientiert | 2.204 ms |
| Zeilenorientiert | 3.040 ms |

Bei komplexen Aggregationen bietet die spaltenorientierte Speicherung Vorteile.

## Empfohlene Anwendungsfälle

Spaltenorientierte Tabellen eignen sich besonders für:

1. **Faktentabellen** in Data Warehouses
2. **Logdaten** mit vielen Spalten, die selten vollständig abgefragt werden
3. **Zeitreihendaten** mit häufigen Aggregationen
4. **Archivdaten** mit Fokus auf Speichereffizienz

Zeilenorientierte Tabellen bleiben besser für:

1. **Dimensionstabellen** mit häufigen Komplett-Lesezugriffen
2. **Transaktionale Daten** mit hoher Schreibfrequenz
3. **Tabellen mit vielen Einfüge-/Aktualisierungsvorgängen**

## Verwendung

Spaltenorientierte Tabellen können mit der Syntax `USING columnar` erstellt werden:

```sql
CREATE TABLE facts (
    id BIGSERIAL,
    time TIMESTAMPTZ NOT NULL,
    dimension_1 INTEGER,
    dimension_2 INTEGER,
    measure_1 NUMERIC(10,2),
    measure_2 NUMERIC(10,2)
) USING columnar;
```

Bestehende Tabellen können konvertiert werden:

```sql
-- Von zeilenorientiert zu spaltenorientiert
ALTER TABLE facts SET ACCESS METHOD columnar;

-- Von spaltenorientiert zu zeilenorientiert
ALTER TABLE facts SET ACCESS METHOD heap;
```

## Integration mit Citus

Spaltenorientierte Tabellen können verteilt werden, indem sie als Referenztabellen oder verteilte Tabellen in Citus definiert werden:

```sql
-- Spaltenorientierte verteilte Tabelle
CREATE TABLE columnar_distributed_facts (
    id BIGSERIAL,
    time TIMESTAMPTZ NOT NULL,
    dimension_1 INTEGER,
    dimension_2 INTEGER,
    measure_1 NUMERIC(10,2),
    measure_2 NUMERIC(10,2)
) USING columnar;

-- Tabelle auf Citus verteilen
SELECT create_distributed_table('columnar_distributed_facts', 'time');
```

## Fazit

Die spaltenorientierte Speicherung ist ein wesentlicher Bestandteil von ExaPG, der analytische Abfrageleistung und Speichereffizienz verbessert. Durch die Kombination mit Citus für verteilte Verarbeitung bietet ExaPG eine leistungsstarke Alternative zu proprietären Lösungen wie Exasol für analytische Workloads. 