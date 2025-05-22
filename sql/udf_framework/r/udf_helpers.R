# ExaPG UDF Helpers für R
# Diese Bibliothek bietet Exasol-kompatible Funktionen für R-UDFs in PostgreSQL

# Lade benötigte Pakete
library(jsonlite)
library(DBI)
library(RPostgres)

# Exasol-Kompatibilitätsnamespace
exasol <- list()

# Logging-Funktionen
exasol$error_msg <- function(message) {
  stop(message)
}

exasol$info_msg <- function(message) {
  pg.spi.exec(paste0("DO $$ BEGIN RAISE NOTICE '", message, "'; END $$;"))
}

exasol$debug_msg <- function(message) {
  pg.spi.exec(paste0("DO $$ BEGIN RAISE NOTICE '[DEBUG] ", message, "'; END $$;"))
}

# Datenbankfunktionen
exasol$get_connection <- function(connection_name = "default") {
  conn <- list(
    name = connection_name,
    
    # Ausführen einer SQL-Query
    execute = function(query, ...) {
      # Konvertiere Exasol-Style-Parameter (?) zu PostgreSQL-Style ($n)
      params <- list(...)
      for (i in seq_along(params)) {
        placeholder <- paste0("\\?")
        replacement <- paste0("$", i)
        query <- gsub(placeholder, replacement, query, fixed = FALSE)
      }
      
      # Führe die Query aus
      result <- tryCatch({
        pg.spi.exec(query, params)
      }, error = function(e) {
        exasol$error_msg(paste("Fehler bei der Ausführung der Abfrage:", e$message))
        return(NULL)
      })
      
      return(result)
    },
    
    # Schließt die Verbindung (in PostgreSQL nicht notwendig)
    close = function() {
      return(TRUE)
    }
  )
  
  return(conn)
}

# Datentyp-Konvertierung
exasol$to_timestamp <- function(date_str) {
  if (is.null(date_str)) return(NULL)
  
  # Wenn bereits ein Datum/Zeitstempel
  if (inherits(date_str, "POSIXt") || inherits(date_str, "Date")) {
    return(date_str)
  }
  
  # Versuche verschiedene Formate
  result <- tryCatch({
    # Zuerst ISO-Format versuchen
    as.POSIXct(date_str, format = "%Y-%m-%d %H:%M:%S")
  }, error = function(e) {
    tryCatch({
      # Dann nur Datum versuchen
      as.POSIXct(date_str, format = "%Y-%m-%d")
    }, error = function(e) {
      tryCatch({
        # Deutsches Format versuchen
        as.POSIXct(date_str, format = "%d.%m.%Y %H:%M:%S")
      }, error = function(e) {
        tryCatch({
          # Deutsches Datumsformat versuchen
          as.POSIXct(date_str, format = "%d.%m.%Y")
        }, error = function(e) {
          exasol$error_msg(paste("Ungültiges Datumsformat:", date_str))
          return(NULL)
        })
      })
    })
  })
  
  return(result)
}

exasol$to_date <- function(date_str) {
  if (is.null(date_str)) return(NULL)
  
  # Wenn bereits ein Datum
  if (inherits(date_str, "Date")) {
    return(date_str)
  }
  
  # Wenn ein Zeitstempel, konvertiere zu Datum
  if (inherits(date_str, "POSIXt")) {
    return(as.Date(date_str))
  }
  
  # Versuche verschiedene Formate
  result <- tryCatch({
    # Zuerst ISO-Format versuchen
    as.Date(date_str, format = "%Y-%m-%d")
  }, error = function(e) {
    tryCatch({
      # Deutsches Format versuchen
      as.Date(date_str, format = "%d.%m.%Y")
    }, error = function(e) {
      exasol$error_msg(paste("Ungültiges Datumsformat:", date_str))
      return(NULL)
    })
  })
  
  return(result)
}

exasol$to_number <- function(value) {
  if (is.null(value)) return(NULL)
  
  result <- tryCatch({
    as.numeric(value)
  }, warning = function(w) {
    exasol$error_msg(paste("Warnung bei Konvertierung zu Zahl:", w$message))
    return(NA)
  }, error = function(e) {
    exasol$error_msg(paste("Fehler bei Konvertierung zu Zahl:", e$message))
    return(NULL)
  })
  
  return(result)
}

exasol$to_char <- function(value) {
  if (is.null(value)) return(NULL)
  return(as.character(value))
}

# JSON-Verarbeitung
exasol$json <- list(
  encode = function(value) {
    if (is.null(value)) return("{}")
    
    result <- tryCatch({
      toJSON(value, auto_unbox = TRUE)
    }, error = function(e) {
      exasol$error_msg(paste("JSON-Enkodierungsfehler:", e$message))
      return("{}")
    })
    
    return(result)
  },
  
  decode = function(json_str) {
    if (is.null(json_str) || json_str == "") return(NULL)
    
    result <- tryCatch({
      fromJSON(json_str)
    }, error = function(e) {
      exasol$error_msg(paste("JSON-Dekodierungsfehler:", e$message))
      return(NULL)
    })
    
    return(result)
  }
)

# Mathematische Funktionen
exasol$math <- list(
  round = function(value, digits = 0) {
    if (is.null(value)) return(NULL)
    return(round(value, digits))
  },
  
  floor = function(value) {
    if (is.null(value)) return(NULL)
    return(floor(value))
  },
  
  ceil = function(value) {
    if (is.null(value)) return(NULL)
    return(ceiling(value))
  },
  
  abs = function(value) {
    if (is.null(value)) return(NULL)
    return(abs(value))
  },
  
  sqrt = function(value) {
    if (is.null(value) || value < 0) return(NULL)
    return(sqrt(value))
  },
  
  # Statistische Funktionen
  mean = function(values) {
    if (is.null(values) || length(values) == 0) return(NULL)
    return(mean(values, na.rm = TRUE))
  },
  
  median = function(values) {
    if (is.null(values) || length(values) == 0) return(NULL)
    return(median(values, na.rm = TRUE))
  },
  
  stdev = function(values) {
    if (is.null(values) || length(values) < 2) return(NULL)
    return(sd(values, na.rm = TRUE))
  },
  
  var = function(values) {
    if (is.null(values) || length(values) < 2) return(NULL)
    return(var(values, na.rm = TRUE))
  },
  
  quantile = function(values, probs) {
    if (is.null(values) || length(values) == 0) return(NULL)
    return(quantile(values, probs = probs, na.rm = TRUE))
  }
)

# String-Funktionen
exasol$text <- list(
  lower = function(text) {
    if (is.null(text)) return(NULL)
    return(tolower(text))
  },
  
  upper = function(text) {
    if (is.null(text)) return(NULL)
    return(toupper(text))
  },
  
  substring = function(text, start, length = NULL) {
    if (is.null(text)) return(NULL)
    
    # In R beginnt substring bei 1 (wie in Exasol)
    if (is.null(length)) {
      return(substr(text, start, nchar(text)))
    } else {
      return(substr(text, start, start + length - 1))
    }
  },
  
  replace = function(text, pattern, replacement) {
    if (is.null(text)) return(NULL)
    return(gsub(pattern, replacement, text, fixed = TRUE))
  },
  
  trim = function(text) {
    if (is.null(text)) return(NULL)
    return(trimws(text))
  },
  
  left = function(text, n) {
    if (is.null(text)) return(NULL)
    return(substr(text, 1, n))
  },
  
  right = function(text, n) {
    if (is.null(text)) return(NULL)
    text_length <- nchar(text)
    return(substr(text, text_length - n + 1, text_length))
  },
  
  length = function(text) {
    if (is.null(text)) return(NULL)
    return(nchar(text))
  },
  
  regex_replace = function(text, pattern, replacement) {
    if (is.null(text)) return(NULL)
    return(gsub(pattern, replacement, text))
  }
)

# Datum/Zeit-Funktionen
exasol$date <- list(
  now = function() {
    return(Sys.time())
  },
  
  today = function() {
    return(Sys.Date())
  },
  
  add_days = function(date, days) {
    if (is.null(date)) return(NULL)
    return(date + days)
  },
  
  add_months = function(date, months) {
    if (is.null(date)) return(NULL)
    
    # Verwende seq.Date oder seq.POSIXt je nach Typ
    if (inherits(date, "Date")) {
      result <- seq.Date(date, by = paste(months, "months"), length.out = 2)[2]
    } else if (inherits(date, "POSIXt")) {
      result <- seq.POSIXt(date, by = paste(months, "months"), length.out = 2)[2]
    } else {
      exasol$error_msg("Ungültiger Datumstyp")
      return(NULL)
    }
    
    return(result)
  },
  
  add_years = function(date, years) {
    if (is.null(date)) return(NULL)
    
    # Verwende seq.Date oder seq.POSIXt je nach Typ
    if (inherits(date, "Date")) {
      result <- seq.Date(date, by = paste(years, "years"), length.out = 2)[2]
    } else if (inherits(date, "POSIXt")) {
      result <- seq.POSIXt(date, by = paste(years, "years"), length.out = 2)[2]
    } else {
      exasol$error_msg("Ungültiger Datumstyp")
      return(NULL)
    }
    
    return(result)
  },
  
  diff_days = function(date1, date2) {
    if (is.null(date1) || is.null(date2)) return(NULL)
    
    # Konvertiere zu Date, falls notwendig
    if (inherits(date1, "POSIXt")) date1 <- as.Date(date1)
    if (inherits(date2, "POSIXt")) date2 <- as.Date(date2)
    
    return(as.numeric(difftime(date1, date2, units = "days")))
  },
  
  diff_months = function(date1, date2) {
    if (is.null(date1) || is.null(date2)) return(NULL)
    
    # Extrahiere Jahr und Monat
    year1 <- as.numeric(format(date1, "%Y"))
    month1 <- as.numeric(format(date1, "%m"))
    year2 <- as.numeric(format(date2, "%Y"))
    month2 <- as.numeric(format(date2, "%m"))
    
    return((year1 - year2) * 12 + (month1 - month2))
  },
  
  diff_years = function(date1, date2) {
    if (is.null(date1) || is.null(date2)) return(NULL)
    
    # Extrahiere Jahr
    year1 <- as.numeric(format(date1, "%Y"))
    year2 <- as.numeric(format(date2, "%Y"))
    
    return(year1 - year2)
  },
  
  format = function(date, format_str) {
    if (is.null(date)) return(NULL)
    return(format(date, format_str))
  }
)

# Metadaten-Funktionen
exasol$meta <- list(
  # Simuliert Exasols Funktionen zur Abfrage von Metadaten
  schema_name = function() {
    result <- pg.spi.exec("SELECT current_schema() AS schema")
    return(result$schema[1])
  },
  
  current_user = function() {
    result <- pg.spi.exec("SELECT current_user AS username")
    return(result$username[1])
  },
  
  current_session = function() {
    result <- pg.spi.exec("SELECT pg_backend_pid() AS pid")
    return(result$pid[1])
  }
)

# DataFrame-Funktionen
exasol$df <- list(
  from_query = function(query, conn, ...) {
    result <- conn$execute(query, ...)
    if (is.null(result) || nrow(result) == 0) {
      return(data.frame())
    }
    return(result)
  },
  
  to_postgres = function(df, table_name, conn, if_exists = "replace") {
    if (is.null(df) || nrow(df) == 0) {
      exasol$info_msg("Leerer DataFrame, keine Aktion durchgeführt")
      return(FALSE)
    }
    
    # Drop Tabelle falls nötig
    if (if_exists == "replace") {
      conn$execute(paste0("DROP TABLE IF EXISTS ", table_name))
    }
    
    # Erzeuge Tabelle mit passenden Spaltentypen
    col_types <- sapply(df, function(col) {
      if (is.numeric(col)) {
        if (all(col == floor(col), na.rm = TRUE)) {
          return("INTEGER")
        } else {
          return("DOUBLE PRECISION")
        }
      } else if (inherits(col, "POSIXt")) {
        return("TIMESTAMP")
      } else if (inherits(col, "Date")) {
        return("DATE")
      } else if (is.logical(col)) {
        return("BOOLEAN")
      } else {
        return("TEXT")
      }
    })
    
    # Erstelle CREATE TABLE Statement
    col_defs <- paste(names(df), col_types, collapse = ", ")
    create_query <- paste0("CREATE TABLE ", table_name, " (", col_defs, ")")
    conn$execute(create_query)
    
    # Füge Daten ein
    for (i in 1:nrow(df)) {
      row_values <- paste(sapply(1:ncol(df), function(j) {
        value <- df[i, j]
        if (is.null(value) || is.na(value)) {
          return("NULL")
        } else if (is.character(value)) {
          return(paste0("'", gsub("'", "''", value), "'"))
        } else if (inherits(value, "POSIXt") || inherits(value, "Date")) {
          return(paste0("'", format(value, "%Y-%m-%d %H:%M:%S"), "'"))
        } else {
          return(as.character(value))
        }
      }), collapse = ", ")
      
      insert_query <- paste0("INSERT INTO ", table_name, " VALUES (", row_values, ")")
      conn$execute(insert_query)
    }
    
    return(TRUE)
  }
)

# Statistische Modellierung
exasol$model <- list(
  linear_regression = function(formula, data) {
    if (is.null(data) || nrow(data) == 0) {
      exasol$error_msg("Keine Daten für die Regression")
      return(NULL)
    }
    
    model <- tryCatch({
      lm(formula, data = data)
    }, error = function(e) {
      exasol$error_msg(paste("Fehler bei der linearen Regression:", e$message))
      return(NULL)
    })
    
    return(model)
  },
  
  predict = function(model, newdata) {
    if (is.null(model)) {
      exasol$error_msg("Kein Modell für die Vorhersage")
      return(NULL)
    }
    
    predictions <- tryCatch({
      predict(model, newdata = newdata)
    }, error = function(e) {
      exasol$error_msg(paste("Fehler bei der Vorhersage:", e$message))
      return(NULL)
    })
    
    return(predictions)
  },
  
  summarize = function(model) {
    if (is.null(model)) {
      exasol$error_msg("Kein Modell zum Zusammenfassen")
      return(NULL)
    }
    
    summary_result <- tryCatch({
      summary(model)
    }, error = function(e) {
      exasol$error_msg(paste("Fehler bei der Modellzusammenfassung:", e$message))
      return(NULL)
    })
    
    return(summary_result)
  }
)

# Setze das Exasol-Objekt als globale Variable
assign("exa", exasol, envir = .GlobalEnv)

# Rückgabe des Exasol-Objekts
exasol 