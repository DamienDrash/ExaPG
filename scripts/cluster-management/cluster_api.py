#!/usr/bin/env python3
# ExaPG Cluster Management API
# REST-API für die automatische Cluster-Erweiterung und -Verwaltung

import os
import json
import time
import logging
import subprocess
import psycopg2
import docker
from flask import Flask, request, jsonify
from flask_cors import CORS
from threading import Thread
from dotenv import load_dotenv

# Konfiguration
app = Flask(__name__)
CORS(app)  # Cross-Origin Resource Sharing erlauben

# Logging einrichten
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.FileHandler("cluster_api.log"), logging.StreamHandler()]
)
logger = logging.getLogger('cluster_api')

# Umgebungsvariablen aus .env laden
load_dotenv()

# Postgres Verbindungsparameter
POSTGRES_HOST = os.getenv("POSTGRES_HOST", "coordinator")
POSTGRES_PORT = os.getenv("POSTGRES_PORT", "5432")
POSTGRES_USER = os.getenv("POSTGRES_USER", "postgres")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "postgres")
POSTGRES_DB = os.getenv("POSTGRES_DB", "postgres")

# Docker-Konfiguration
DOCKER_NETWORK = os.getenv("DOCKER_NETWORK", "exapg-network")
WORKER_IMAGE = os.getenv("WORKER_IMAGE", "exapg-worker")
BASE_WORKER_NAME = "exapg-worker"
CONFIG_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../config/postgresql'))

# Docker-Client initialisieren
docker_client = docker.from_env()

def get_db_connection():
    """Datenbankverbindung herstellen"""
    try:
        conn = psycopg2.connect(
            host=POSTGRES_HOST,
            port=POSTGRES_PORT,
            user=POSTGRES_USER,
            password=POSTGRES_PASSWORD,
            dbname=POSTGRES_DB
        )
        conn.autocommit = True
        return conn
    except Exception as e:
        logger.error(f"Datenbankverbindungsfehler: {e}")
        return None

def execute_sql(sql, params=None):
    """SQL-Anweisung ausführen"""
    conn = get_db_connection()
    if not conn:
        return False, "Verbindung zur Datenbank konnte nicht hergestellt werden"
    
    try:
        cursor = conn.cursor()
        if params:
            cursor.execute(sql, params)
        else:
            cursor.execute(sql)
        
        # Wenn es ein SELECT ist, Ergebnisse zurückgeben
        if sql.strip().upper().startswith("SELECT"):
            result = cursor.fetchall()
            cursor.close()
            conn.close()
            return True, result
        
        cursor.close()
        conn.close()
        return True, "SQL-Anweisung erfolgreich ausgeführt"
    except Exception as e:
        logger.error(f"SQL-Ausführungsfehler: {e}")
        if conn:
            conn.close()
        return False, str(e)

def get_worker_count():
    """Aktuelle Anzahl der Worker-Knoten abrufen"""
    success, result = execute_sql("SELECT COUNT(*) FROM pg_dist_node WHERE nodeport=5432 AND noderole='primary'")
    if success:
        return result[0][0]
    return 0

def get_active_workers():
    """Liste der aktiven Worker-Knoten abrufen"""
    success, result = execute_sql("SELECT nodeid, nodename FROM pg_dist_node WHERE nodeport=5432 AND noderole='primary'")
    if success:
        return result
    return []

def add_worker_to_citus(worker_name):
    """Worker-Knoten zu Citus hinzufügen"""
    try:
        # Warten bis Worker bereit ist
        for _ in range(30):  # 30 Sekunden Timeout
            try:
                result = subprocess.run(
                    ["pg_isready", "-h", worker_name, "-U", POSTGRES_USER],
                    capture_output=True, text=True, timeout=2
                )
                if "accepting connections" in result.stdout or result.returncode == 0:
                    logger.info(f"Worker {worker_name} ist bereit für Verbindungen.")
                    break
            except subprocess.TimeoutExpired:
                pass
            time.sleep(1)
        else:
            return False, f"Timeout: Worker {worker_name} ist nicht bereit"

        # Worker zum Cluster hinzufügen
        sql = f"SELECT * FROM citus_add_node('{worker_name}', 5432);"
        success, result = execute_sql(sql)
        
        if success:
            logger.info(f"Worker {worker_name} erfolgreich zu Citus hinzugefügt")
            
            # Datenumverteilung automatisch starten
            rebalance_thread = Thread(target=rebalance_cluster)
            rebalance_thread.daemon = True
            rebalance_thread.start()
            
            return True, f"Worker {worker_name} erfolgreich hinzugefügt"
        else:
            logger.error(f"Fehler beim Hinzufügen des Workers {worker_name}: {result}")
            return False, result
    except Exception as e:
        logger.error(f"Unerwarteter Fehler beim Hinzufügen des Workers: {e}")
        return False, str(e)

def remove_worker_from_citus(worker_name, node_id):
    """Worker-Knoten aus Citus entfernen"""
    try:
        # Daten auf andere Worker umverteilen
        sql = f"""
        SELECT nodeid, nodename INTO TEMPORARY drain_node 
        FROM pg_dist_node WHERE nodename = '{worker_name}';
        
        SELECT master_drain_node((SELECT nodeid FROM drain_node));
        """
        success, result = execute_sql(sql)
        
        if not success:
            logger.error(f"Fehler beim Umverteilen der Daten von Worker {worker_name}: {result}")
            return False, result
        
        # Knoten entfernen
        sql = f"SELECT citus_remove_node({node_id});"
        success, result = execute_sql(sql)
        
        if success:
            logger.info(f"Worker {worker_name} erfolgreich aus Citus entfernt")
            return True, f"Worker {worker_name} erfolgreich entfernt"
        else:
            logger.error(f"Fehler beim Entfernen des Workers {worker_name}: {result}")
            return False, result
    except Exception as e:
        logger.error(f"Unerwarteter Fehler beim Entfernen des Workers: {e}")
        return False, str(e)

def rebalance_cluster():
    """Daten im Cluster umverteilen für gleichmäßige Lastverteilung"""
    try:
        time.sleep(5)  # Kurze Pause, damit sich der Cluster stabilisieren kann
        logger.info("Starte automatische Datenumverteilung...")
        
        # Rebalancing-Funktion aufrufen
        sql = "SELECT admin.rebalance_shards('public', 0.1);"
        success, result = execute_sql(sql)
        
        if success:
            logger.info("Datenumverteilung erfolgreich abgeschlossen")
        else:
            logger.error(f"Fehler bei der Datenumverteilung: {result}")
    except Exception as e:
        logger.error(f"Unerwarteter Fehler bei der Datenumverteilung: {e}")

def create_worker_container(worker_num):
    """Neuen Worker-Container erstellen"""
    try:
        worker_name = f"{BASE_WORKER_NAME}-{worker_num}"
        
        # Prüfen, ob der Container bereits existiert
        try:
            existing = docker_client.containers.get(worker_name)
            if existing:
                logger.info(f"Container {worker_name} existiert bereits. Status: {existing.status}")
                if existing.status != 'running':
                    existing.start()
                    logger.info(f"Container {worker_name} gestartet")
                return True, worker_name
        except docker.errors.NotFound:
            pass
        
        # Volumes für den Worker
        volumes = {
            f"{worker_name}-data": {'bind': '/var/lib/postgresql/data', 'mode': 'rw'},
            f"{CONFIG_DIR}/pg_hba.conf": {'bind': '/etc/postgresql/pg_hba.conf', 'mode': 'ro'},
            f"{CONFIG_DIR}/postgresql-worker.conf": {'bind': '/etc/postgresql/postgresql.conf', 'mode': 'ro'}
        }
        
        # Container erstellen und starten
        container = docker_client.containers.run(
            image=WORKER_IMAGE,
            name=worker_name,
            detach=True,
            network=DOCKER_NETWORK,
            environment={
                "POSTGRES_USER": POSTGRES_USER,
                "POSTGRES_PASSWORD": POSTGRES_PASSWORD,
                "POSTGRES_DB": POSTGRES_DB
            },
            volumes=volumes,
            command="postgres -c config_file=/etc/postgresql/postgresql.conf -c hba_file=/etc/postgresql/pg_hba.conf",
            healthcheck={
                "test": ["CMD-SHELL", "pg_isready -U postgres"],
                "interval": 10000000000,  # 10 Sekunden in Nanosekunden
                "timeout": 5000000000,    # 5 Sekunden in Nanosekunden
                "retries": 5
            }
        )
        
        logger.info(f"Worker-Container {worker_name} erfolgreich erstellt")
        return True, worker_name
    except Exception as e:
        logger.error(f"Fehler beim Erstellen des Worker-Containers: {e}")
        return False, str(e)

def remove_worker_container(worker_name):
    """Worker-Container entfernen"""
    try:
        container = docker_client.containers.get(worker_name)
        container.stop()
        container.remove()
        logger.info(f"Worker-Container {worker_name} erfolgreich entfernt")
        return True, f"Worker-Container {worker_name} erfolgreich entfernt"
    except docker.errors.NotFound:
        logger.warning(f"Container {worker_name} nicht gefunden")
        return True, f"Container {worker_name} existiert nicht"
    except Exception as e:
        logger.error(f"Fehler beim Entfernen des Worker-Containers {worker_name}: {e}")
        return False, str(e)

# API-Endpunkte

@app.route('/api/cluster/status', methods=['GET'])
def get_cluster_status():
    """Status des Clusters abrufen"""
    try:
        # Aktive Worker abrufen
        workers = get_active_workers()
        worker_count = len(workers)
        
        # Container-Informationen sammeln
        containers = []
        for container in docker_client.containers.list(all=True):
            if container.name.startswith(BASE_WORKER_NAME) or container.name == "exapg-coordinator":
                containers.append({
                    "name": container.name,
                    "status": container.status,
                    "id": container.id[:12]
                })
        
        # Datenbank-Statistiken
        success, stats = execute_sql("""
            SELECT * FROM (
                SELECT count(*) AS tables FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
            ) t1, (
                SELECT count(*) AS distributed_tables FROM pg_dist_partition
            ) t2, (
                SELECT count(*) AS shards FROM pg_dist_shard
            ) t3;
        """)
        
        db_stats = {}
        if success:
            db_stats = {
                "total_tables": stats[0][0],
                "distributed_tables": stats[0][1],
                "total_shards": stats[0][2]
            }
        
        return jsonify({
            "status": "ok",
            "cluster": {
                "coordinator": "exapg-coordinator",
                "worker_count": worker_count,
                "workers": [{"id": w[0], "name": w[1]} for w in workers]
            },
            "containers": containers,
            "database_stats": db_stats
        })
    except Exception as e:
        logger.error(f"Fehler beim Abrufen des Cluster-Status: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/api/cluster/add-worker', methods=['POST'])
def add_worker():
    """Neuen Worker zum Cluster hinzufügen"""
    try:
        # Nächste Worker-Nummer ermitteln
        worker_count = get_worker_count()
        next_worker_num = worker_count + 1
        
        # Neuen Worker-Container erstellen
        success, worker_name = create_worker_container(next_worker_num)
        if not success:
            return jsonify({"status": "error", "message": worker_name}), 500
        
        # Warten, bis Container hochgefahren ist (10 Sekunden)
        time.sleep(10)
        
        # Worker zu Citus hinzufügen
        success, message = add_worker_to_citus(worker_name)
        if not success:
            return jsonify({"status": "error", "message": message}), 500
        
        return jsonify({
            "status": "ok",
            "message": f"Worker {worker_name} erfolgreich zum Cluster hinzugefügt",
            "worker": {"name": worker_name, "number": next_worker_num}
        })
    except Exception as e:
        logger.error(f"Fehler beim Hinzufügen eines Workers: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/api/cluster/remove-worker', methods=['POST'])
def remove_worker():
    """Worker aus dem Cluster entfernen"""
    try:
        data = request.json
        if not data or 'worker_name' not in data or 'node_id' not in data:
            return jsonify({"status": "error", "message": "worker_name und node_id sind erforderlich"}), 400
        
        worker_name = data['worker_name']
        node_id = data['node_id']
        
        # Worker aus Citus entfernen
        success, message = remove_worker_from_citus(worker_name, node_id)
        if not success:
            return jsonify({"status": "error", "message": message}), 500
        
        # Worker-Container entfernen
        success, message = remove_worker_container(worker_name)
        if not success:
            return jsonify({"status": "error", "message": message}), 500
        
        return jsonify({
            "status": "ok",
            "message": f"Worker {worker_name} erfolgreich aus dem Cluster entfernt"
        })
    except Exception as e:
        logger.error(f"Fehler beim Entfernen eines Workers: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/api/cluster/rebalance', methods=['POST'])
def rebalance():
    """Daten im Cluster manuell umverteilen"""
    try:
        # Rebalancing in einem separaten Thread starten
        rebalance_thread = Thread(target=rebalance_cluster)
        rebalance_thread.daemon = True
        rebalance_thread.start()
        
        return jsonify({
            "status": "ok",
            "message": "Datenumverteilung gestartet"
        })
    except Exception as e:
        logger.error(f"Fehler beim Starten der Datenumverteilung: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/api/cluster/rolling-update', methods=['POST'])
def rolling_update():
    """Rolling-Update der Worker-Knoten durchführen"""
    try:
        data = request.json
        if not data or 'image' not in data:
            return jsonify({"status": "error", "message": "image ist erforderlich"}), 400
        
        new_image = data['image']
        
        # Thread für das Rolling-Update starten
        update_thread = Thread(target=perform_rolling_update, args=(new_image,))
        update_thread.daemon = True
        update_thread.start()
        
        return jsonify({
            "status": "ok",
            "message": f"Rolling-Update mit Image {new_image} gestartet"
        })
    except Exception as e:
        logger.error(f"Fehler beim Starten des Rolling-Updates: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

def perform_rolling_update(new_image):
    """Rolling-Update der Worker-Knoten durchführen"""
    try:
        logger.info(f"Starte Rolling-Update mit Image {new_image}")
        
        # Aktive Worker abrufen
        workers = get_active_workers()
        
        for worker_id, worker_name in workers:
            logger.info(f"Update von Worker {worker_name} (ID: {worker_id})")
            
            # Worker aus Citus entfernen
            success, message = remove_worker_from_citus(worker_name, worker_id)
            if not success:
                logger.error(f"Fehler beim Entfernen des Workers {worker_name}: {message}")
                continue
            
            # Worker-Container stoppen und entfernen
            success, message = remove_worker_container(worker_name)
            if not success:
                logger.error(f"Fehler beim Entfernen des Containers {worker_name}: {message}")
                continue
            
            # Docker-Image aktualisieren
            try:
                docker_client.images.pull(new_image)
                logger.info(f"Image {new_image} erfolgreich gezogen")
            except Exception as e:
                logger.error(f"Fehler beim Ziehen des Images {new_image}: {e}")
                continue
            
            # Neuen Worker mit aktualisiertem Image erstellen
            # Hier extrahieren wir die Nummer aus dem Worker-Namen
            worker_num = int(worker_name.split('-')[-1])
            success, worker_name = create_worker_container(worker_num)
            if not success:
                logger.error(f"Fehler beim Erstellen des neuen Containers: {worker_name}")
                continue
            
            # Warten, bis Container hochgefahren ist
            time.sleep(10)
            
            # Worker zu Citus hinzufügen
            success, message = add_worker_to_citus(worker_name)
            if not success:
                logger.error(f"Fehler beim Hinzufügen des Workers {worker_name}: {message}")
                continue
            
            logger.info(f"Worker {worker_name} erfolgreich aktualisiert")
            
            # Kurze Pause zwischen Worker-Updates
            time.sleep(5)
        
        logger.info("Rolling-Update abgeschlossen")
    except Exception as e:
        logger.error(f"Unerwarteter Fehler beim Rolling-Update: {e}")

# Hauptfunktion
if __name__ == '__main__':
    # Server-Port aus Umgebungsvariable oder Standard (5000)
    port = int(os.getenv('CLUSTER_API_PORT', 5000))
    
    logger.info(f"Starte ExaPG Cluster Management API auf Port {port}")
    app.run(host='0.0.0.0', port=port) 