-- ExaPG - UDF-Framework Beispiel-UDFs
-- SQL-Skript mit Beispiel-UDFs für Python, R, Lua und SQL

-- =============== PYTHON UDFs ===============

-- Python UDF: Einfache Textanalyse
SELECT udf_framework.create_python_udf(
    'analytics', -- Schema
    'text_analysis', -- Name
    'text_input TEXT', -- Parameter
    'JSONB', -- Rückgabetyp
    $$
import json
import re
from collections import Counter

def text_analysis(text_input):
    if text_input is None:
        return json.dumps({})
        
    # Text in Kleinbuchstaben umwandeln und Sonderzeichen entfernen
    clean_text = re.sub(r'[^\w\s]', '', text_input.lower())
    
    # Wörter zählen
    words = clean_text.split()
    word_count = len(words)
    
    # Wörter und ihre Häufigkeit berechnen
    word_frequency = Counter(words)
    top_words = dict(word_frequency.most_common(10))
    
    # Durchschnittliche Wortlänge berechnen
    avg_word_length = sum(len(word) for word in words) / word_count if word_count > 0 else 0
    
    # Rückgabe als JSON
    result = {
        "word_count": word_count,
        "char_count": len(text_input),
        "avg_word_length": round(avg_word_length, 2),
        "top_words": top_words
    }
    
    return json.dumps(result)
    $$,
    'Python-UDF zur Analyse von Texteingaben. Berechnet Wortanzahl, Buchstabenanzahl, durchschnittliche Wortlänge und häufigste Wörter.',
    ARRAY['text', 'nlp', 'analytics']
);

-- Python UDF: Machine Learning Klassifikation
SELECT udf_framework.create_python_udf(
    'analytics', -- Schema
    'predict_category', -- Name
    'features FLOAT[]', -- Parameter
    'TEXT', -- Rückgabetyp
    $$
import numpy as np
from sklearn.ensemble import RandomForestClassifier

def predict_category(features):
    if features is None or len(features) == 0:
        return "undefined"
    
    # Simulierte Trainingsdaten (würde normalerweise aus einer Tabelle geladen werden)
    X_train = np.array([
        [1.2, 0.5, 3.1, 1.0],
        [0.8, 1.5, 2.5, 2.3],
        [2.5, 0.8, 1.2, 0.5],
        [1.9, 1.9, 1.9, 1.9],
        [0.1, 0.2, 0.3, 0.4]
    ])
    
    y_train = np.array(['Kategorie A', 'Kategorie B', 'Kategorie A', 'Kategorie C', 'Kategorie B'])
    
    # Erstelle und trainiere ein Random Forest Modell
    model = RandomForestClassifier(n_estimators=10, random_state=42)
    model.fit(X_train, y_train)
    
    # Führe eine Vorhersage mit den übergebenen Features durch
    features_array = np.array(features).reshape(1, -1)
    
    # Passe die Features-Dimensionen an, falls notwendig
    if features_array.shape[1] < X_train.shape[1]:
        # Fülle fehlende Features mit 0 auf
        padding = np.zeros((1, X_train.shape[1] - features_array.shape[1]))
        features_array = np.hstack((features_array, padding))
    elif features_array.shape[1] > X_train.shape[1]:
        # Kürze überschüssige Features
        features_array = features_array[:, :X_train.shape[1]]
    
    # Führe die Vorhersage durch
    prediction = model.predict(features_array)[0]
    
    return prediction
    $$,
    'Python-UDF für Machine Learning Klassifikation mit RandomForest. Diese Funktion demonstriert, wie ML-Modelle in UDFs verwendet werden können.',
    ARRAY['ml', 'sklearn', 'classification']
);

-- =============== R UDFs ===============

-- R UDF: Statistische Analyse
SELECT udf_framework.create_r_udf(
    'analytics', -- Schema
    'calculate_statistics', -- Name
    'values FLOAT[]', -- Parameter
    'JSONB', -- Rückgabetyp
    $$
library(jsonlite)

calculate_statistics <- function(values) {
    if (is.null(values) || length(values) == 0) {
        return('{}')
    }
    
    # Grundlegende Statistiken berechnen
    stats <- list(
        mean = mean(values),
        median = median(values),
        std_dev = sd(values),
        min = min(values),
        max = max(values),
        range = max(values) - min(values),
        q1 = quantile(values, 0.25),
        q3 = quantile(values, 0.75),
        iqr = IQR(values),
        n = length(values)
    )
    
    # Shapiro-Wilk-Test für Normalverteilung
    if (length(values) >= 3 && length(values) <= 5000) {
        sw_test <- shapiro.test(values)
        stats$normal_distribution <- list(
            test = "shapiro-wilk",
            p_value = sw_test$p.value,
            is_normal = sw_test$p.value > 0.05
        )
    }
    
    # Konvertiere nach JSON
    return(toJSON(stats, auto_unbox = TRUE))
}
    $$,
    'R-UDF zur statistischen Analyse von numerischen Werten. Berechnet grundlegende statistische Kennzahlen und prüft auf Normalverteilung.',
    ARRAY['statistics', 'analytics', 'r']
);

-- R UDF: Zeitreihenanalyse
SELECT udf_framework.create_r_udf(
    'analytics', -- Schema
    'forecast_timeseries', -- Name
    'timestamps TIMESTAMP[], values FLOAT[]', -- Parameter
    'JSONB', -- Rückgabetyp
    $$
library(jsonlite)
library(forecast)
library(zoo)

forecast_timeseries <- function(timestamps, values) {
    if (is.null(timestamps) || is.null(values) || length(timestamps) == 0 || length(values) == 0) {
        return('{"error": "Keine Eingabedaten vorhanden"}')
    }
    
    if (length(timestamps) != length(values)) {
        return('{"error": "Länge von timestamps und values stimmt nicht überein"}')
    }
    
    # Erstelle eine Zeitreihe
    # Konvertiere Timestamps zu Date-Objekten
    dates <- as.Date(timestamps)
    
    # Erstelle eine Zoo-Zeitreihe
    ts_data <- zoo(values, order.by = dates)
    
    # Erstelle eine reguläre Zeitreihe für die Vorhersage
    # Als Frequenz verwenden wir 12 für monatliche Daten (Annahme)
    # Dies sollte basierend auf den tatsächlichen Daten angepasst werden
    frequency <- 12
    if (length(values) >= 2) {
        time_diff <- as.numeric(diff(dates)[1], units = "days")
        if (time_diff <= 1) {
            frequency <- 365  # Tägliche Daten
        } else if (time_diff <= 7) {
            frequency <- 52   # Wöchentliche Daten
        }
    }
    
    # Konvertiere zu ts-Objekt
    ts_obj <- ts(values, frequency = frequency)
    
    # ARIMA-Modell anpassen und Vorhersage treffen
    model <- auto.arima(ts_obj)
    forecast_periods <- min(ceiling(length(values) * 0.3), 12)  # 30% der Datenlänge, max. 12 Perioden
    fc <- forecast(model, h = forecast_periods)
    
    # Ergebnisse zusammenstellen
    result <- list(
        model = list(
            type = "ARIMA",
            order = paste(model$arma[1], model$arma[2], model$arma[3], sep=","),
            aic = model$aic
        ),
        forecast = list(
            point_forecast = as.numeric(fc$mean),
            lower_80 = as.numeric(fc$lower[,1]),
            upper_80 = as.numeric(fc$upper[,1]),
            lower_95 = as.numeric(fc$lower[,2]),
            upper_95 = as.numeric(fc$upper[,2])
        ),
        accuracy = list(
            mape = accuracy(fc)[1, "MAPE"],
            mae = accuracy(fc)[1, "MAE"],
            rmse = accuracy(fc)[1, "RMSE"]
        )
    )
    
    # Konvertiere nach JSON
    return(toJSON(result, auto_unbox = TRUE))
}
    $$,
    'R-UDF zur Zeitreihenanalyse und -prognose mit ARIMA-Modellen. Diese Funktion macht eine automatische Modellanpassung und Vorhersage für Zeitreihendaten.',
    ARRAY['timeseries', 'forecast', 'arima']
);

-- =============== LUA UDFs ===============

-- Lua UDF: String-Verarbeitung
SELECT udf_framework.create_lua_udf(
    'utilities', -- Schema
    'format_string', -- Name
    'input_text TEXT, format_type TEXT', -- Parameter
    'TEXT', -- Rückgabetyp
    $$
local function format_string(input_text, format_type)
    if input_text == nil or format_type == nil then
        return input_text
    end
    
    -- Format-Typen
    if format_type == 'upper' then
        return string.upper(input_text)
    elseif format_type == 'lower' then
        return string.lower(input_text)
    elseif format_type == 'capitalize' then
        return input_text:gsub("(%a)([%w_']*)", function(first, rest)
            return first:upper() .. rest:lower()
        end)
    elseif format_type == 'title' then
        return input_text:gsub("(%a)([%w_']*)", function(first, rest)
            return first:upper() .. rest:lower()
        end):gsub("%s(%a)([%w_']*)", function(first, rest)
            return " " .. first:upper() .. rest:lower()
        end)
    elseif format_type == 'snake' then
        return input_text:gsub("%s+", "_"):lower()
    elseif format_type == 'camel' then
        return input_text:gsub("%s(%a)", function(letter)
            return letter:upper()
        end):gsub("^%a", string.lower)
    elseif format_type == 'pascal' then
        return input_text:gsub("%s(%a)", function(letter)
            return letter:upper()
        end):gsub("^%a", string.upper)
    else
        return input_text
    end
end

return format_string(input_text, format_type)
    $$,
    'Lua-UDF zur Textformatierung. Unterstützt verschiedene Formatierungstypen: upper, lower, capitalize, title, snake, camel, pascal.',
    ARRAY['string', 'format', 'utility']
);

-- Lua UDF: JSON-Verarbeitung
SELECT udf_framework.create_lua_udf(
    'utilities', -- Schema
    'extract_json_value', -- Name
    'json_text TEXT, path TEXT', -- Parameter
    'TEXT', -- Rückgabetyp
    $$
local json = require("json")

local function extract_json_value(json_text, path)
    if json_text == nil or path == nil then
        return nil
    end
    
    -- Versuche, das JSON zu parsen
    local success, data = pcall(json.decode, json_text)
    if not success then
        return nil
    end
    
    -- Pfad aufteilen
    local path_parts = {}
    for part in string.gmatch(path, "[^.]+") do
        path_parts[#path_parts + 1] = part
    end
    
    -- Wert extrahieren
    local current = data
    for i = 1, #path_parts do
        local key = path_parts[i]
        
        -- Prüfe auf Array-Index (z.B. items[0])
        local array_key, array_index = string.match(key, "(.+)%[(%d+)%]")
        if array_key and array_index then
            current = current[array_key]
            if current == nil then
                return nil
            end
            
            array_index = tonumber(array_index)
            current = current[array_index + 1]  -- Lua-Arrays beginnen bei 1
        else
            current = current[key]
        end
        
        if current == nil then
            return nil
        end
    end
    
    -- Wenn der gefundene Wert ein Objekt oder Array ist, konvertiere es zurück zu JSON
    if type(current) == "table" then
        return json.encode(current)
    else
        return tostring(current)
    end
end

return extract_json_value(json_text, path)
    $$,
    'Lua-UDF zur Extraktion von Werten aus JSON-Daten. Ermöglicht den Zugriff auf verschachtelte Werte mittels Punktnotation (z.B. "user.address.city").',
    ARRAY['json', 'extract', 'utility']
);

-- =============== SQL UDFs ===============

-- SQL UDF: Datum und Zeitfunktionen
SELECT udf_framework.create_sql_udf(
    'utilities', -- Schema
    'date_difference', -- Name
    'start_date TIMESTAMP, end_date TIMESTAMP, unit TEXT', -- Parameter
    'INTEGER', -- Rückgabetyp
    $$
DECLARE
    diff INTEGER;
BEGIN
    IF start_date IS NULL OR end_date IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Berechne die Differenz basierend auf der angeforderten Einheit
    CASE lower(unit)
        WHEN 'years' THEN
            diff := DATE_PART('year', end_date) - DATE_PART('year', start_date);
        WHEN 'months' THEN
            diff := (DATE_PART('year', end_date) - DATE_PART('year', start_date)) * 12 +
                   (DATE_PART('month', end_date) - DATE_PART('month', start_date));
        WHEN 'days' THEN
            diff := DATE_PART('day', end_date - start_date);
        WHEN 'hours' THEN
            diff := DATE_PART('day', end_date - start_date) * 24 +
                   DATE_PART('hour', end_date - start_date);
        WHEN 'minutes' THEN
            diff := DATE_PART('day', end_date - start_date) * 24 * 60 +
                   DATE_PART('hour', end_date - start_date) * 60 +
                   DATE_PART('minute', end_date - start_date);
        WHEN 'seconds' THEN
            diff := DATE_PART('day', end_date - start_date) * 24 * 60 * 60 +
                   DATE_PART('hour', end_date - start_date) * 60 * 60 +
                   DATE_PART('minute', end_date - start_date) * 60 +
                   DATE_PART('second', end_date - start_date);
        ELSE
            -- Standardmäßig Tage zurückgeben
            diff := DATE_PART('day', end_date - start_date);
    END CASE;
    
    RETURN diff;
END;
    $$,
    'SQL-UDF zur Berechnung des Unterschieds zwischen zwei Datums-/Zeitwerten in verschiedenen Einheiten (years, months, days, hours, minutes, seconds).',
    ARRAY['date', 'time', 'utility']
);

-- SQL UDF: Analytische Funktion für Datenbereinigung
SELECT udf_framework.create_sql_udf(
    'analytics', -- Schema
    'remove_outliers', -- Name
    'values FLOAT[]', -- Parameter
    'FLOAT[]', -- Rückgabetyp
    $$
DECLARE
    q1 FLOAT;
    q3 FLOAT;
    iqr FLOAT;
    lower_bound FLOAT;
    upper_bound FLOAT;
    result FLOAT[] := '{}';
BEGIN
    -- Überprüfe auf leere oder NULL-Eingabe
    IF values IS NULL OR array_length(values, 1) IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Berechne Quartile und IQR
    WITH sorted AS (
        SELECT unnest(values) AS val
        ORDER BY 1
    ),
    quartiles AS (
        SELECT
            percentile_cont(0.25) WITHIN GROUP (ORDER BY val) AS q1,
            percentile_cont(0.75) WITHIN GROUP (ORDER BY val) AS q3
        FROM sorted
    )
    SELECT q1, q3, q3 - q1 AS iqr
    INTO q1, q3, iqr
    FROM quartiles;
    
    -- Berechne Grenzen für Ausreißer (1.5 * IQR)
    lower_bound := q1 - 1.5 * iqr;
    upper_bound := q3 + 1.5 * iqr;
    
    -- Filtere Ausreißer heraus
    SELECT array_agg(val)
    INTO result
    FROM unnest(values) AS val
    WHERE val BETWEEN lower_bound AND upper_bound;
    
    RETURN result;
END;
    $$,
    'SQL-UDF zur Entfernung von Ausreißern aus einem Datensatz mit der IQR-Methode. Werte außerhalb von q1-1.5*iqr und q3+1.5*iqr werden entfernt.',
    ARRAY['statistics', 'outliers', 'cleaning']
);

-- Erstelle ein Beispiel für die Verwendung der UDFs
DO $$
BEGIN
    -- Füge ein Beispiel für die Text-Analyse-UDF hinzu
    PERFORM udf_framework.add_udf_example(
        (SELECT udf_id FROM udf_framework.udf_catalog WHERE udf_name = 'text_analysis' AND udf_schema = 'analytics'),
        'Beispiel für eine Textanalyse',
        'Analyse eines einfachen Beispieltextes',
        'SELECT analytics.text_analysis(''Dies ist ein Beispieltext zur Demonstration der UDF-Funktionalität. Dieser Text enthält mehrere Wörter, und einige Wörter wiederholen sich in diesem Text.'')',
        '{"word_count": 21, "char_count": 152, "avg_word_length": 5.19, "top_words": {"text": 3, "dieser": 2, "dies": 1, "ist": 1, "ein": 1, "beispieltext": 1, "zur": 1, "demonstration": 1, "der": 1, "udffunktionalität": 1}}'
    );
    
    -- Füge ein Beispiel für die Datum-Differenz-UDF hinzu
    PERFORM udf_framework.add_udf_example(
        (SELECT udf_id FROM udf_framework.udf_catalog WHERE udf_name = 'date_difference' AND udf_schema = 'utilities'),
        'Beispiel für Datumsberechnung',
        'Berechnung des Unterschieds zwischen zwei Datumswerten in verschiedenen Einheiten',
        'SELECT utilities.date_difference(''2023-01-01 00:00:00'', ''2023-12-31 23:59:59'', ''days'')',
        '364'
    );
END $$; 