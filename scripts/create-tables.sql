-- Erstelle und verteilte eine Beispiel-Timeseries-Tabelle
CREATE TABLE analytics.sensor_data (
  time TIMESTAMPTZ NOT NULL,
  sensor_id INTEGER NOT NULL,
  temperature DOUBLE PRECISION,
  humidity DOUBLE PRECISION,
  pressure DOUBLE PRECISION
);

-- Verteilte die Tabelle nach sensor_id
SELECT create_distributed_table('analytics.sensor_data', 'sensor_id');

-- Erstelle eine verteilte Tabelle für Verkaufsdaten
CREATE TABLE analytics.sales (
  sale_id SERIAL,
  sale_date DATE NOT NULL,
  customer_id INTEGER,
  product_id INTEGER,
  quantity INTEGER,
  amount NUMERIC(10, 2)
);

-- Verteilte die Tabelle nach customer_id
SELECT create_distributed_table('analytics.sales', 'customer_id');

-- Beispiel für Vektor-Ähnlichkeitssuche mit pgvector
CREATE TABLE analytics.document_embeddings (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  content_embedding vector(384)  -- BERT embeddings haben 384 Dimensionen
);

-- Verteilte die Tabelle nach id
SELECT create_distributed_table('analytics.document_embeddings', 'id');

-- Erstelle GIS-Beispieltabelle
CREATE TABLE analytics.locations (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  position geometry(Point, 4326) NOT NULL
);

-- Verteilte die Tabelle nach id
SELECT create_distributed_table('analytics.locations', 'id'); 