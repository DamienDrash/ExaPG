-- ExaPG UDF Helpers für Lua
-- Diese Bibliothek bietet Exasol-kompatible Funktionen für Lua-UDFs in PostgreSQL

-- Globales Objekt für PostgreSQL-Funktionalität
pg = pg or {}

-- Exasol-Kompatibilitätsschicht
exasol = {}

-- Logging-Funktionen
exasol.error_msg = function(message)
    pg.error(message)
end

exasol.info_msg = function(message)
    pg.notice(message)
end

exasol.debug_msg = function(message)
    -- In PostgreSQL ist debug-level-logging nicht direkt verfügbar,
    -- daher verwenden wir notice mit Präfix
    pg.notice("[DEBUG] " .. message)
end

-- Datenbankfunktionen
exasol.get_connection = function(connection_name)
    -- Simuliert Exasols Verbindungsverwaltung
    return {
        name = connection_name,
        -- Ausführen einer SQL-Query mit parametrisierten Statements
        execute = function(self, query, ...)
            -- Konvertiere Exasol-Style-SQL zu PostgreSQL-kompatiblem SQL
            local converted_query = query:gsub(":%d+", function(match)
                local param_num = tonumber(match:sub(2))
                return "$" .. param_num
            end)
            
            -- Führe die Query aus
            return pg.execute(converted_query, {...})
        end,
        -- Schließt die Verbindung
        close = function(self)
            -- In PostgreSQL benötigen wir kein explizites Schließen
            return true
        end
    }
end

-- Datentyp-Konvertierung
exasol.to_timestamp = function(date_str)
    return pg.execute("SELECT TO_TIMESTAMP($1, 'YYYY-MM-DD HH24:MI:SS')", {date_str})[1][1]
end

exasol.to_date = function(date_str)
    return pg.execute("SELECT TO_DATE($1, 'YYYY-MM-DD')", {date_str})[1][1]
end

exasol.to_number = function(value)
    if value == nil then return nil end
    return tonumber(value)
end

exasol.to_char = function(value)
    if value == nil then return nil end
    return tostring(value)
end

-- JSON-Verarbeitung
exasol.json = {
    encode = function(value)
        -- Nutze die json-Bibliothek von Lua
        local json = require("json")
        return json.encode(value)
    end,
    
    decode = function(json_str)
        local json = require("json")
        local status, result = pcall(json.decode, json_str)
        if status then
            return result
        else
            exasol.error_msg("JSON Decode-Fehler: " .. result)
            return nil
        end
    end
}

-- Mathematische Funktionen
exasol.math = {
    round = function(value, digits)
        digits = digits or 0
        local factor = 10 ^ digits
        return math.floor(value * factor + 0.5) / factor
    end,
    
    floor = math.floor,
    ceil = math.ceil,
    abs = math.abs,
    sqrt = math.sqrt,
    
    -- Statistische Funktionen
    mean = function(values)
        if #values == 0 then return nil end
        local sum = 0
        for _, v in ipairs(values) do
            sum = sum + v
        end
        return sum / #values
    end,
    
    median = function(values)
        if #values == 0 then return nil end
        
        -- Kopiere die Tabelle, um die Originalwerte nicht zu verändern
        local sorted = {}
        for i, v in ipairs(values) do
            sorted[i] = v
        end
        table.sort(sorted)
        
        local n = #sorted
        if n % 2 == 0 then
            return (sorted[n/2] + sorted[n/2 + 1]) / 2
        else
            return sorted[math.ceil(n/2)]
        end
    end,
    
    stdev = function(values)
        if #values < 2 then return nil end
        
        -- Berechne Mittelwert
        local mean = exasol.math.mean(values)
        
        -- Berechne Summe der quadratischen Abweichungen
        local sum_sq_diff = 0
        for _, v in ipairs(values) do
            sum_sq_diff = sum_sq_diff + (v - mean)^2
        end
        
        -- Berechne Standardabweichung
        return math.sqrt(sum_sq_diff / (#values - 1))
    end
}

-- String-Funktionen
exasol.text = {
    lower = string.lower,
    upper = string.upper,
    
    substring = function(str, start_pos, length)
        if str == nil then return nil end
        
        -- Exasol-Indizierung beginnt bei 1, wie in Lua
        if length then
            return string.sub(str, start_pos, start_pos + length - 1)
        else
            return string.sub(str, start_pos)
        end
    end,
    
    replace = function(str, search, replace)
        if str == nil then return nil end
        return string.gsub(str, search, replace)
    end,
    
    trim = function(str)
        if str == nil then return nil end
        return string.match(str, "^%s*(.-)%s*$")
    end,
    
    left = function(str, n)
        if str == nil then return nil end
        return string.sub(str, 1, n)
    end,
    
    right = function(str, n)
        if str == nil then return nil end
        return string.sub(str, -n)
    end,
    
    length = function(str)
        if str == nil then return nil end
        return string.len(str)
    end
}

-- Datum/Zeit-Funktionen
exasol.date = {
    now = function()
        return pg.execute("SELECT NOW()")[1][1]
    end,
    
    add_days = function(date, days)
        return pg.execute("SELECT $1 + INTERVAL '$2 days'", {date, days})[1][1]
    end,
    
    add_months = function(date, months)
        return pg.execute("SELECT $1 + INTERVAL '$2 months'", {date, months})[1][1]
    end,
    
    add_years = function(date, years)
        return pg.execute("SELECT $1 + INTERVAL '$2 years'", {date, years})[1][1]
    end,
    
    diff_days = function(date1, date2)
        return pg.execute("SELECT DATE_PART('day', $1 - $2)", {date1, date2})[1][1]
    end,
    
    diff_months = function(date1, date2)
        return pg.execute("SELECT (DATE_PART('year', $1) - DATE_PART('year', $2)) * 12 + (DATE_PART('month', $1) - DATE_PART('month', $2))", {date1, date2})[1][1]
    end,
    
    diff_years = function(date1, date2)
        return pg.execute("SELECT DATE_PART('year', $1) - DATE_PART('year', $2)", {date1, date2})[1][1]
    end,
    
    extract = function(part, date)
        return pg.execute("SELECT DATE_PART($1, $2)", {part, date})[1][1]
    end
}

-- Metadaten-Funktionen
exasol.meta = {
    -- Simuliert Exasols Funktionen zur Abfrage von Metadaten
    schema_name = function()
        return pg.execute("SELECT CURRENT_SCHEMA()")[1][1]
    end,
    
    script_name = function()
        -- In PostgreSQL gibt es kein direktes Äquivalent zu script_name
        -- Verwende den Funktionsnamen als Ersatz
        return pg.execute("SELECT pg_proc.proname FROM pg_proc WHERE pg_proc.oid = pg_proc.oid")[1][1]
    end,
    
    current_user = function()
        return pg.execute("SELECT CURRENT_USER")[1][1]
    end,
    
    current_session = function()
        -- Simulierte Session-ID in PostgreSQL
        return pg.execute("SELECT pg_backend_pid()")[1][1]
    end
}

-- Tabellenfunktionen
exasol.table = {
    new = function()
        return {}
    end,
    
    insert = function(tbl, row)
        table.insert(tbl, row)
        return true
    end,
    
    column = function(tbl, col_idx)
        local result = {}
        for i, row in ipairs(tbl) do
            result[i] = row[col_idx]
        end
        return result
    end,
    
    row_count = function(tbl)
        return #tbl
    end
}

-- Exportiere Exasol-Namespace für Kompatibilität
return exasol 