#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
ExaPG UDF Helpers für Python
Diese Bibliothek bietet Exasol-kompatible Funktionen für Python-UDFs in PostgreSQL
"""

import json
import datetime
import pandas as pd
import numpy as np
import plpy  # PostgreSQL-Python-Schnittstelle
import re

# Exasol-Kompatibilitätsschicht
class Exasol:
    """
    Exasol-Kompatibilitätsschicht für PostgreSQL Python UDFs
    """
    
    class Connection:
        """Simuliert eine Exasol-Datenbankverbindung in PostgreSQL"""
        
        def __init__(self, connection_name):
            self.connection_name = connection_name
        
        def execute(self, query, *args):
            """Führt eine SQL-Query aus mit Exasol-ähnlicher Parameterisierung"""
            # Konvertiere Exasol-Style (?)-Parameter zu PostgreSQL $-Parameter
            param_counter = 1
            converted_query = ""
            for char in query:
                if char == '?':
                    converted_query += f"${param_counter}"
                    param_counter += 1
                else:
                    converted_query += char
            
            # Führe die Query aus
            result = plpy.execute(converted_query, args)
            return [[col for col in row.values()] for row in result]
        
        def commit(self):
            """Commit-Operation (in PostgreSQL UDFs implizit)"""
            # In PostgreSQL PL/Python wird automatisch committed
            pass
        
        def rollback(self):
            """Rollback-Operation (limitiert in UDFs)"""
            # In PostgreSQL PL/Python sind Rollbacks begrenzt möglich
            plpy.execute("ROLLBACK")
        
        def close(self):
            """Schließt die Verbindung (in PostgreSQL UDFs implizit)"""
            # In PostgreSQL PL/Python sind Verbindungen Teil der Session
            pass
    
    def __init__(self):
        """Initialisiert die Exasol-Kompatibilitätsschicht"""
        pass
    
    def get_connection(self, connection_name="default"):
        """Gibt ein Connection-Objekt zurück"""
        return self.Connection(connection_name)
    
    # Logging-Funktionen
    def error_msg(self, message):
        """Log eine Fehlermeldung"""
        plpy.error(message)
    
    def info_msg(self, message):
        """Log eine Informationsmeldung"""
        plpy.notice(message)
    
    def debug_msg(self, message):
        """Log eine Debug-Meldung"""
        plpy.notice(f"[DEBUG] {message}")
    
    # Datentyp-Konvertierung
    def to_timestamp(self, date_str):
        """Konvertiert einen String zu einem Timestamp"""
        if date_str is None:
            return None
        try:
            # Wenn es bereits ein Datetime-Objekt ist
            if isinstance(date_str, (datetime.datetime, datetime.date)):
                return date_str
            # Versuche verschiedene Formate
            for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%d', '%d.%m.%Y %H:%M:%S', '%d.%m.%Y'):
                try:
                    return datetime.datetime.strptime(date_str, fmt)
                except ValueError:
                    continue
            raise ValueError(f"Ungültiges Datumsformat: {date_str}")
        except Exception as e:
            self.error_msg(f"Fehler bei der Konvertierung zu Timestamp: {e}")
            return None
    
    def to_date(self, date_str):
        """Konvertiert einen String zu einem Date"""
        if date_str is None:
            return None
        try:
            # Wenn es bereits ein Date-Objekt ist
            if isinstance(date_str, datetime.date):
                return date_str
            # Versuche verschiedene Formate
            for fmt in ('%Y-%m-%d', '%d.%m.%Y'):
                try:
                    return datetime.datetime.strptime(date_str, fmt).date()
                except ValueError:
                    continue
            raise ValueError(f"Ungültiges Datumsformat: {date_str}")
        except Exception as e:
            self.error_msg(f"Fehler bei der Konvertierung zu Date: {e}")
            return None
    
    def to_number(self, value):
        """Konvertiert einen Wert zu einer Zahl"""
        if value is None:
            return None
        try:
            return float(value)
        except Exception as e:
            self.error_msg(f"Fehler bei der Konvertierung zu Number: {e}")
            return None
    
    def to_char(self, value):
        """Konvertiert einen Wert zu einem String"""
        if value is None:
            return None
        return str(value)
    
    # JSON-Verarbeitung
    class Json:
        @staticmethod
        def encode(value):
            """Konvertiert einen Python-Wert zu einem JSON-String"""
            try:
                return json.dumps(value)
            except Exception as e:
                plpy.error(f"JSON-Enkodierungsfehler: {e}")
                return None
        
        @staticmethod
        def decode(json_str):
            """Konvertiert einen JSON-String zu einem Python-Wert"""
            try:
                return json.loads(json_str)
            except Exception as e:
                plpy.error(f"JSON-Dekodierungsfehler: {e}")
                return None
    
    # Mathematische Funktionen
    class Math:
        @staticmethod
        def round(value, digits=0):
            """Rundet einen Wert auf die angegebene Anzahl von Dezimalstellen"""
            if value is None:
                return None
            return round(value, digits)
        
        @staticmethod
        def floor(value):
            """Rundet einen Wert ab"""
            if value is None:
                return None
            return np.floor(value)
        
        @staticmethod
        def ceil(value):
            """Rundet einen Wert auf"""
            if value is None:
                return None
            return np.ceil(value)
        
        @staticmethod
        def abs(value):
            """Gibt den Absolutwert zurück"""
            if value is None:
                return None
            return abs(value)
        
        @staticmethod
        def sqrt(value):
            """Gibt die Quadratwurzel zurück"""
            if value is None or value < 0:
                return None
            return np.sqrt(value)
        
        @staticmethod
        def mean(values):
            """Berechnet den Mittelwert einer Liste von Werten"""
            if not values:
                return None
            return np.mean(values)
        
        @staticmethod
        def median(values):
            """Berechnet den Median einer Liste von Werten"""
            if not values:
                return None
            return np.median(values)
        
        @staticmethod
        def stdev(values):
            """Berechnet die Standardabweichung einer Liste von Werten"""
            if not values or len(values) < 2:
                return None
            return np.std(values, ddof=1)  # ddof=1 für Stichproben-Standardabweichung
    
    # String-Funktionen
    class Text:
        @staticmethod
        def lower(text):
            """Konvertiert einen String zu Kleinbuchstaben"""
            if text is None:
                return None
            return text.lower()
        
        @staticmethod
        def upper(text):
            """Konvertiert einen String zu Großbuchstaben"""
            if text is None:
                return None
            return text.upper()
        
        @staticmethod
        def substring(text, start, length=None):
            """Extrahiert einen Teilstring"""
            if text is None:
                return None
            # Exasol verwendet 1-basierte Indizierung, Python verwendet 0-basierte
            start_idx = start - 1
            if length is None:
                return text[start_idx:]
            else:
                return text[start_idx:start_idx + length]
        
        @staticmethod
        def replace(text, search, replace):
            """Ersetzt alle Vorkommen eines Substrings"""
            if text is None:
                return None
            return text.replace(search, replace)
        
        @staticmethod
        def trim(text):
            """Entfernt Leerzeichen am Anfang und Ende"""
            if text is None:
                return None
            return text.strip()
        
        @staticmethod
        def left(text, n):
            """Gibt die ersten n Zeichen zurück"""
            if text is None:
                return None
            return text[:n]
        
        @staticmethod
        def right(text, n):
            """Gibt die letzten n Zeichen zurück"""
            if text is None:
                return None
            return text[-n:]
        
        @staticmethod
        def length(text):
            """Gibt die Länge eines Strings zurück"""
            if text is None:
                return None
            return len(text)
        
        @staticmethod
        def regex_replace(text, pattern, replacement, flags=0):
            """Ersetzt Text basierend auf einem regulären Ausdruck"""
            if text is None:
                return None
            return re.sub(pattern, replacement, text, flags=flags)
    
    # Datum/Zeit-Funktionen
    class Date:
        @staticmethod
        def now():
            """Gibt den aktuellen Zeitstempel zurück"""
            return datetime.datetime.now()
        
        @staticmethod
        def today():
            """Gibt das aktuelle Datum zurück"""
            return datetime.date.today()
        
        @staticmethod
        def add_days(date, days):
            """Fügt Tage zu einem Datum hinzu"""
            if date is None:
                return None
            return date + datetime.timedelta(days=days)
        
        @staticmethod
        def add_months(date, months):
            """Fügt Monate zu einem Datum hinzu"""
            if date is None:
                return None
            
            # Berechne das neue Jahr und den neuen Monat
            year = date.year + (date.month + months - 1) // 12
            month = (date.month + months - 1) % 12 + 1
            
            # Behalte den gleichen Tag, wenn möglich, ansonsten letzter Tag des Monats
            day = min(date.day, [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28, 
                               31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month-1])
            
            if isinstance(date, datetime.datetime):
                return datetime.datetime(year, month, day, date.hour, date.minute, date.second, date.microsecond)
            else:
                return datetime.date(year, month, day)
        
        @staticmethod
        def add_years(date, years):
            """Fügt Jahre zu einem Datum hinzu"""
            if date is None:
                return None
            
            # Beachte Schaltjahre
            new_year = date.year + years
            new_month = date.month
            
            # Wenn es der 29. Februar ist und das neue Jahr kein Schaltjahr ist
            if date.month == 2 and date.day == 29 and not (new_year % 4 == 0 and (new_year % 100 != 0 or new_year % 400 == 0)):
                new_day = 28
            else:
                new_day = date.day
            
            if isinstance(date, datetime.datetime):
                return datetime.datetime(new_year, new_month, new_day, date.hour, date.minute, date.second, date.microsecond)
            else:
                return datetime.date(new_year, new_month, new_day)
        
        @staticmethod
        def diff_days(date1, date2):
            """Berechnet die Differenz in Tagen zwischen zwei Daten"""
            if date1 is None or date2 is None:
                return None
            delta = date1 - date2
            return delta.days
        
        @staticmethod
        def diff_months(date1, date2):
            """Berechnet die Differenz in Monaten zwischen zwei Daten"""
            if date1 is None or date2 is None:
                return None
            return (date1.year - date2.year) * 12 + (date1.month - date2.month)
        
        @staticmethod
        def diff_years(date1, date2):
            """Berechnet die Differenz in Jahren zwischen zwei Daten"""
            if date1 is None or date2 is None:
                return None
            return date1.year - date2.year
    
    # Metadaten-Funktionen
    class Meta:
        @staticmethod
        def schema_name():
            """Gibt den aktuellen Schema-Namen zurück"""
            try:
                result = plpy.execute("SELECT current_schema() AS schema")[0]
                return result["schema"]
            except Exception as e:
                plpy.error(f"Fehler beim Abrufen des Schema-Namens: {e}")
                return None
        
        @staticmethod
        def current_user():
            """Gibt den aktuellen Benutzernamen zurück"""
            try:
                result = plpy.execute("SELECT current_user AS user")[0]
                return result["user"]
            except Exception as e:
                plpy.error(f"Fehler beim Abrufen des Benutzernamens: {e}")
                return None
        
        @staticmethod
        def current_session():
            """Gibt die aktuelle Session-ID zurück"""
            try:
                result = plpy.execute("SELECT pg_backend_pid() AS pid")[0]
                return result["pid"]
            except Exception as e:
                plpy.error(f"Fehler beim Abrufen der Session-ID: {e}")
                return None
    
    # DataFrame-Unterstützung für Pandas
    class DataFrame:
        @staticmethod
        def from_query(query, conn, *params):
            """Erstellt einen Pandas-DataFrame aus einer SQL-Abfrage"""
            try:
                # Führe die Abfrage aus
                result = conn.execute(query, *params)
                
                # Wenn keine Daten zurückgegeben wurden
                if not result:
                    return pd.DataFrame()
                
                # Erstelle einen DataFrame
                return pd.DataFrame(result)
            except Exception as e:
                plpy.error(f"Fehler beim Erstellen des DataFrame: {e}")
                return pd.DataFrame()
        
        @staticmethod
        def to_query(df, table_name, conn, if_exists='replace'):
            """Schreibt einen Pandas-DataFrame in eine Tabelle"""
            try:
                # Konvertiere DataFrame zu einer Liste von Tupeln
                records = df.to_records(index=False)
                
                # Erstelle die Tabelle, falls sie nicht existiert
                if if_exists == 'replace':
                    # Erzeuge SQL für Tabellen-Drop
                    conn.execute(f"DROP TABLE IF EXISTS {table_name}")
                
                # Erzeuge Tabelle mit passenden Spaltentypen
                columns = []
                for col_name, dtype in zip(df.columns, df.dtypes):
                    pg_type = "TEXT"  # Standard-Typ
                    
                    # Mapping von Pandas-Typen zu PostgreSQL-Typen
                    if np.issubdtype(dtype, np.integer):
                        pg_type = "INTEGER"
                    elif np.issubdtype(dtype, np.floating):
                        pg_type = "DOUBLE PRECISION"
                    elif np.issubdtype(dtype, np.datetime64):
                        pg_type = "TIMESTAMP"
                    elif np.issubdtype(dtype, np.bool_):
                        pg_type = "BOOLEAN"
                    
                    columns.append(f"{col_name} {pg_type}")
                
                # Erstelle die Tabelle
                create_query = f"CREATE TABLE {table_name} ({', '.join(columns)})"
                conn.execute(create_query)
                
                # Füge Daten ein
                for record in records:
                    placeholders = ", ".join(["?"] * len(record))
                    insert_query = f"INSERT INTO {table_name} VALUES ({placeholders})"
                    conn.execute(insert_query, *record)
                
                return True
            except Exception as e:
                plpy.error(f"Fehler beim Schreiben des DataFrame: {e}")
                return False

# Erstelle eine globale Instanz der Exasol-Klasse
exa = Exasol()

# Setze Komponenten als direkte Attribute für einfacheren Zugriff
exa.json = exa.Json
exa.math = exa.Math
exa.text = exa.Text
exa.date = exa.Date
exa.meta = exa.Meta
exa.df = exa.DataFrame

# Exportiere das Exasol-Objekt
__all__ = ['exa'] 