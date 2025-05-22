-- Grundlegende Einstellungen für Citus Columnar
-- Diese Einstellungen optimieren die spaltenorientierte Speicherung für analytische Workloads

-- Stripe-Größe: Anzahl der Zeilen pro Stripe (Standardwert ist 150000)
-- Erhöhung verbessert Bulk-Lade-Performance, erhöht aber auch den Speicherbedarf
ALTER SYSTEM SET columnar.stripe_row_limit = 250000;

-- Chunk-Gruppe: Anzahl der Zeilen pro Chunk-Gruppe (Standardwert ist 10000)
-- Größere Chunks verbessern die Kompression, aber erhöhen die RAM-Nutzung bei Schreibvorgängen
ALTER SYSTEM SET columnar.chunk_group_row_limit = 15000;

-- Kompressionseinstellungen
-- Verfügbare Kompressionsalgorithmen: pglz, zstd, lz4
ALTER SYSTEM SET columnar.compression = 'zstd';

-- Kompressionslevel: 1-19 für zstd (höher = mehr Kompression, langsamer)
ALTER SYSTEM SET columnar.compression_level = 9;

-- Laden der neuen Konfiguration
SELECT pg_reload_conf();

-- Informationen über die columnar-Einstellungen anzeigen
\echo 'Aktuelle Columnar-Einstellungen:'
SELECT name, setting, unit, context, short_desc 
FROM pg_settings 
WHERE name LIKE 'columnar.%'
ORDER BY name; 