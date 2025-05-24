
**Version:** 1.0.0  
**Datum:** 2024-12-28  
**Status:** Production Ready  

---

## 📋 Übersicht

Das ExaPG CLI stellt eine umfassende Sammlung von Funktionen zur Verwaltung und Interaktion mit ExaPG-Clustern bereit. Diese API-Referenz dokumentiert alle verfügbaren Funktionen, Parameter und Rückgabewerte.

## 🔧 Core Functions

### **Environment & Configuration**

#### `validate_environment()`
**Beschreibung:** Validiert die ExaPG-Umgebung und Abhängigkeiten  
**Parameter:** Keine  
**Rückgabe:** `0` bei Erfolg, `1` bei Fehlern  
**Beispiel:**
```bash
if validate_environment; then
    echo "Environment ist bereit"
fi
```

#### `load_config(config_file)`
**Beschreibung:** Lädt Konfigurationsdatei und setzt Umgebungsvariablen  
**Parameter:**
- `config_file` (string): Pfad zur Konfigurationsdatei
**Rückgabe:** `0` bei Erfolg, `1` bei Fehlern  

### **Logging & Output**

#### `log_info(message)` / `log_error(message)` / `log_warning(message)` / `log_success(message)`
**Beschreibung:** Schreibt formatierte Nachrichten ins Log  
**Parameter:**
- `message` (string): Log-Nachricht
**Rückgabe:** `0` (außer log_error: `1`)  

### **Docker & Container Management**

#### `docker_available()` / `docker_compose_available()` / `docker_running()`
**Beschreibung:** Prüft Docker-System-Verfügbarkeit  
**Parameter:** Keine  
**Rückgabe:** `0` wenn verfügbar, `1` sonst  

#### `get_container_status(container_name)`
**Beschreibung:** Ermittelt Status eines Containers  
**Parameter:**
- `container_name` (string): Name des Containers
**Rückgabe:** Status-String ("running", "stopped", "not_found")  

#### `wait_for_container(container_name, timeout)`
**Beschreibung:** Wartet bis Container läuft  
**Parameter:**
- `container_name` (string): Name des Containers
- `timeout` (int, optional): Timeout in Sekunden (default: 60)
**Rückgabe:** `0` wenn Container läuft, `1` bei Timeout  

### **Deployment & Cluster Management**

#### `deploy_exapg(mode, env_file)`
**Beschreibung:** Deployed ExaPG in spezifiziertem Modus  
**Parameter:**
- `mode` (string): Deployment-Modus ("standalone", "cluster", "ha")
- `env_file` (string, optional): Pfad zur Environment-Datei
**Rückgabe:** `0` bei Erfolg, `1` bei Fehlern  

#### `stop_exapg()` / `restart_exapg()`
**Beschreibung:** Stoppt/Startet ExaPG-Services  
**Parameter:** Keine  
**Rückgabe:** `0` bei Erfolg, `1` bei Fehlern  

### **Database Operations**

#### `test_database_connection(host, port, database, user)`
**Beschreibung:** Testet Datenbankverbindung  
**Parameter:**
- `host` (string): Hostname/IP
- `port` (int): Port-Nummer
- `database` (string): Datenbank-Name
- `user` (string): Benutzername
**Rückgabe:** `0` bei erfolgreicher Verbindung, `1` bei Fehlern  

#### `execute_sql(query, database)`
**Beschreibung:** Führt SQL-Query aus  
**Parameter:**
- `query` (string): SQL-Query
- `database` (string, optional): Datenbank-Name
**Rückgabe:** `0` bei Erfolg, `1` bei Fehlern  

### **Validation Functions**

#### `validate_email(email)` / `validate_ip_address(ip)` / `validate_port(port)`
**Beschreibung:** Validiert spezifische Datentypen  
**Parameter:** Entsprechender Datentyp als String  
**Rückgabe:** `0` bei gültigen Daten, `1` sonst  

#### `validate_password_strength(password, min_length)`
**Beschreibung:** Validiert Passwort-Stärke  
**Parameter:**
- `password` (string): Passwort
- `min_length` (int, optional): Mindestlänge (default: 8)
**Rückgabe:** `0` bei starkem Passwort, `1` sonst  

## 📊 Return Codes

| Code | Bedeutung |
|------|-----------|
| `0` | Erfolg |
| `1` | Allgemeiner Fehler |
| `2` | Ungültige Parameter |
| `3` | Timeout |
| `4` | Abhängigkeiten fehlen |
| `5` | Konfigurationsfehler |

## 🚀 Beispiel-Workflow

```bash
#!/bin/bash
# Komplettes Deployment

# 1. Environment validieren
validate_environment || exit 1

# 2. Konfiguration laden  
load_config ".env.production"

# 3. ExaPG deployen
deploy_exapg "cluster" || exit 1

# 4. Datenbankverbindung testen
test_database_connection "$DB_HOST" "$DB_PORT" "$DB_NAME" "$DB_USER"
```

---

**© 2024 ExaPG Project - CLI Functions API Reference v1.0.0** 
# ExaPG CLI Functions API Reference
 