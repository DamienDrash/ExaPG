#!/bin/bash
set -e

# Warten auf PostgreSQL
until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
  echo "Warte auf PostgreSQL..."
  sleep 1
done

echo "PostgreSQL ist bereit - führe Initialisierung durch"

# SQL-Befehle ausführen
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
  -- Erstelle einen Testbenutzer
  CREATE USER testuser WITH PASSWORD 'testpassword';
  
  -- Erstelle eine Testdatenbank
  CREATE DATABASE testdb;
  GRANT ALL PRIVILEGES ON DATABASE testdb TO testuser;
  
  -- Gehe zur Testdatenbank
  \c testdb
  
  -- Erstelle eine Testtabelle
  CREATE TABLE testtabelle (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    wert NUMERIC(10,2),
    datum TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  
  -- Füge Testdaten ein
  INSERT INTO testtabelle (name, wert) VALUES 
    ('Test 1', 123.45),
    ('Test 2', 678.90),
    ('Test 3', 246.80);
EOSQL

echo "Initialisierung abgeschlossen" 