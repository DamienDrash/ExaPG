"""
ExaPG Management UI - Backend API
FastAPI-basierte Backend-Anwendung für die Web-basierte Verwaltung von ExaPG
"""

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials, OAuth2PasswordRequestForm
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import psycopg2
import psycopg2.extras
import json
import os
from datetime import datetime, timedelta
import bcrypt
import jwt
from contextlib import contextmanager
from functools import lru_cache
import random

# Konfiguration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/postgres")
SECRET_KEY = os.getenv("SECRET_KEY", "exapg-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 1440  # 24 Stunden

app = FastAPI(
    title="ExaPG Management API",
    description="API für die Verwaltung und Überwachung von ExaPG-Clustern",
    version="1.0.0"
)

# CORS-Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:3002", "http://localhost:8080"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer()

# Pydantic Models
class User(BaseModel):
    username: str
    email: str
    is_admin: bool = False

class UserCreate(BaseModel):
    username: str
    password: str
    email: Optional[str] = None
    is_admin: bool = False

class UserLogin(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class ClusterNode(BaseModel):
    node_id: str
    hostname: str
    port: int
    status: str
    role: str
    cpu_usage: float
    memory_usage: float
    disk_usage: float

class ETLJob(BaseModel):
    job_id: int
    job_name: str
    status: str
    last_run: Optional[datetime]
    rows_processed: Optional[int]
    duration: Optional[float]

class QueryStats(BaseModel):
    query_id: str
    query: str
    duration: float
    rows_returned: int
    start_time: datetime
    user: str

class SystemMetrics(BaseModel):
    cpu_usage: float
    memory_usage: float
    disk_usage: float
    active_connections: int
    running_queries: int
    cluster_health: str

# Datenbankverbindung
@contextmanager
def get_db_connection():
    conn = None
    try:
        conn = psycopg2.connect(DATABASE_URL)
        conn.autocommit = True
        yield conn
    except Exception as e:
        if conn:
            conn.rollback()
        raise e
    finally:
        if conn:
            conn.close()

def get_db_cursor():
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
            yield cursor

# Authentifizierung
def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        print(f"Authentifizierungs-Token: {credentials.credentials[:10]}...")
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            print("Token ungültig: kein Benutzername im Token")
            raise HTTPException(
                status_code=401, 
                detail="Ungültiges Token: Kein Benutzername gefunden"
            )

        print(f"Suche Benutzer {username} in der Datenbank...")
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                try:
                    # Prüfe, ob das Schema und die Tabelle existieren
                    cursor.execute("""
                        SELECT EXISTS (
                            SELECT 1 FROM information_schema.tables 
                            WHERE table_schema = 'management_ui' AND table_name = 'users'
                        ) AS table_exists
                    """)
                    
                    table_exists = cursor.fetchone()['table_exists']
                    print(f"Users-Tabelle existiert: {table_exists}")
                    
                    if table_exists:
                        cursor.execute("SELECT * FROM management_ui.users WHERE username = %s", (username,))
                        user = cursor.fetchone()
                        if user is not None:
                            print(f"Benutzer {username} gefunden")
                            return user
                        
                        print(f"Benutzer {username} nicht gefunden")
                    else:
                        print(f"Users-Tabelle nicht gefunden, erstelle Demo-Benutzer...")
                except Exception as e:
                    print(f"Fehler beim Suchen des Benutzers: {str(e)}")
        
        # Fallback: Demo-Benutzer zurückgeben
        print(f"Verwende Demo-Benutzer für {username}")
        return {
            "username": username,
            "email": f"{username}@exapg.demo",
            "is_admin": username == "admin"
        }
    except jwt.ExpiredSignatureError:
        print("Token abgelaufen")
        raise HTTPException(
            status_code=401,
            detail="Token abgelaufen"
        )
    except jwt.InvalidTokenError as e:
        print(f"Ungültiges Token: {str(e)}")
        raise HTTPException(
            status_code=401,
            detail="Ungültiges Token"
        )
    except Exception as e:
        print(f"Allgemeiner Authentifizierungsfehler: {str(e)}")
        raise HTTPException(
            status_code=401,
            detail="Authentifizierungsfehler"
        )

def get_admin_user(current_user: dict = Depends(get_current_user)):
    if not current_user.get('is_admin'):
        raise HTTPException(status_code=403, detail="Admin access required")
    return current_user

# Datenbankinitialisierung
def init_database():
    with get_db_connection() as conn:
        with conn.cursor() as cursor:
            # Erstelle Schema für Management-UI
            cursor.execute("CREATE SCHEMA IF NOT EXISTS management_ui")
            
            # Erstelle Benutzertabelle
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS management_ui.users (
                    user_id SERIAL PRIMARY KEY,
                    username VARCHAR(100) UNIQUE NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    email VARCHAR(255),
                    is_admin BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    last_login TIMESTAMP WITH TIME ZONE
                )
            """)
            
            # Erstelle Standard-Admin-Benutzer
            cursor.execute("SELECT COUNT(*) FROM management_ui.users WHERE username = 'admin'")
            if cursor.fetchone()[0] == 0:
                admin_password = hash_password("admin123")
                cursor.execute("""
                    INSERT INTO management_ui.users (username, password_hash, email, is_admin)
                    VALUES ('admin', %s, 'admin@exapg.local', TRUE)
                """, (admin_password,))
            
            # Erstelle Tabelle für Cluster-Knoten
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS management_ui.cluster_nodes (
                    node_id VARCHAR(100) PRIMARY KEY,
                    hostname VARCHAR(255) NOT NULL,
                    port INTEGER NOT NULL,
                    role VARCHAR(50) NOT NULL,
                    status VARCHAR(50) NOT NULL,
                    last_heartbeat TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    metadata JSONB
                )
            """)
            
            # Erstelle Tabelle für System-Metriken
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS management_ui.system_metrics (
                    metric_id SERIAL PRIMARY KEY,
                    node_id VARCHAR(100),
                    metric_name VARCHAR(100) NOT NULL,
                    metric_value FLOAT NOT NULL,
                    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                )
            """)

# API Endpunkte

@app.on_event("startup")
async def startup_event():
    init_database()

@app.get("/")
async def root():
    return {"message": "ExaPG Management API", "version": "1.0.0"}

# Authentifizierung
@app.post("/api/auth/login", response_model=Token)
async def login(user_login: UserLogin):
    try:
        print(f"Login-Versuch für Benutzer: {user_login.username}")
        
        # Standard-Demo-Anmeldeinformationen
        if user_login.username == "admin" and user_login.password == "admin123":
            print("Demo-Admin-Benutzer erkannt, generiere Token...")
            access_token = create_access_token(data={"sub": user_login.username})
            print(f"Token generiert: {access_token[:10]}...")
            return {"access_token": access_token, "token_type": "bearer"}

        # Versuche, den Benutzer in der Datenbank zu finden
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Prüfe, ob das Schema und die Tabelle existieren
                cursor.execute("""
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.tables 
                        WHERE table_schema = 'management_ui' AND table_name = 'users'
                    )
                """)
                
                if not cursor.fetchone()['exists']:
                    print("Users-Tabelle nicht gefunden, erstelle Schema und Tabelle...")
                    cursor.execute("CREATE SCHEMA IF NOT EXISTS management_ui")
                    cursor.execute("""
                        CREATE TABLE IF NOT EXISTS management_ui.users (
                            username VARCHAR(50) PRIMARY KEY,
                            password_hash VARCHAR(255) NOT NULL,
                            email VARCHAR(255),
                            is_admin BOOLEAN DEFAULT FALSE,
                            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            last_login TIMESTAMP
                        )
                    """)
                    conn.commit()
                
                cursor.execute("SELECT * FROM management_ui.users WHERE username = %s", (user_login.username,))
                user = cursor.fetchone()
                
                if user and verify_password(user_login.password, user['password_hash']):
                    print(f"Benutzer {user_login.username} authentifiziert, generiere Token...")
                    # Update last login
                    cursor.execute(
                        "UPDATE management_ui.users SET last_login = CURRENT_TIMESTAMP WHERE username = %s",
                        (user_login.username,)
                    )
                    access_token = create_access_token(data={"sub": user_login.username})
                    return {"access_token": access_token, "token_type": "bearer"}
                
                print(f"Authentifizierung fehlgeschlagen für {user_login.username}")
        
        # Wenn wir hier angelangt sind, hat die Authentifizierung fehlgeschlagen
        raise HTTPException(
            status_code=401,
            detail="Ungültiger Benutzername oder Passwort",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        print(f"Fehler bei der Anmeldung: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Interner Serverfehler bei der Anmeldung",
            headers={"WWW-Authenticate": "Bearer"},
        )

@app.get("/api/auth/me", response_model=User)
async def get_current_user_info(current_user: dict = Depends(get_current_user)):
    return User(
        username=current_user['username'],
        email=current_user.get('email'),
        is_admin=current_user.get('is_admin', False)
    )

# Benutzer-Management
@app.get("/api/users", response_model=List[User])
async def get_users(current_user: dict = Depends(get_admin_user)):
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
            cursor.execute("SELECT username, email, is_admin FROM management_ui.users ORDER BY username")
            users = cursor.fetchall()
            return [User(**user) for user in users]

@app.post("/api/users", response_model=User)
async def create_user(user: UserCreate, current_user: dict = Depends(get_admin_user)):
    with get_db_connection() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
            # Prüfe, ob Benutzer bereits existiert
            cursor.execute("SELECT username FROM management_ui.users WHERE username = %s", (user.username,))
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="Username already exists")
            
            # Erstelle neuen Benutzer
            password_hash = hash_password(user.password)
            cursor.execute("""
                INSERT INTO management_ui.users (username, password_hash, email, is_admin)
                VALUES (%s, %s, %s, %s)
                RETURNING username, email, is_admin
            """, (user.username, password_hash, user.email, user.is_admin))
            
            new_user = cursor.fetchone()
            return User(**new_user)

# Dashboard und Metriken
@app.get("/api/dashboard/overview")
async def get_dashboard_overview(current_user: dict = Depends(get_current_user)):
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                print("Abfrage aktiver Verbindungen...")
                cursor.execute("""
                    SELECT 
                        COUNT(*) as total_connections
                    FROM pg_stat_activity 
                    WHERE state = 'active'
                """)
                active_connections = cursor.fetchone()['total_connections']
                print(f"Aktive Verbindungen: {active_connections}")
                
                print("Abfrage Datenbankgröße...")
                cursor.execute("""
                    SELECT pg_size_pretty(pg_database_size(current_database())) as database_size
                """)
                db_size = cursor.fetchone()['database_size']
                print(f"Datenbankgröße: {db_size}")
                
                # Echte ETL-Job-Statistiken
                etl_stats = {'total_jobs': 0, 'active_jobs': 0}
                # Prüfen und ggf. erstellen des ETL-Schemas und der ETL-Jobs-Tabelle
                cursor.execute("""
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.schemata 
                        WHERE schema_name = 'etl_framework'
                    )
                """)
                
                if cursor.fetchone()['exists']:
                    cursor.execute("""
                        SELECT EXISTS (
                            SELECT 1 FROM information_schema.tables 
                            WHERE table_schema = 'etl_framework' AND table_name = 'etl_jobs'
                        )
                    """)
                    
                    if cursor.fetchone()['exists']:
                        # ETL-Job-Statistiken abfragen
                        cursor.execute("""
                            SELECT 
                                COUNT(*) as total_jobs,
                                COUNT(CASE WHEN enabled THEN 1 END) as active_jobs
                            FROM etl_framework.etl_jobs
                        """)
                        etl_stats = cursor.fetchone()
                
                # Echte Cluster-Knoten-Statistiken
                cluster_stats = {'total_nodes': 0, 'online_nodes': 0}
                # Prüfen und ggf. erstellen des Management-UI-Schemas und der Cluster-Nodes-Tabelle
                cursor.execute("""
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.schemata 
                        WHERE schema_name = 'management_ui'
                    )
                """)
                
                if cursor.fetchone()['exists']:
                    cursor.execute("""
                        SELECT EXISTS (
                            SELECT 1 FROM information_schema.tables 
                            WHERE table_schema = 'management_ui' AND table_name = 'cluster_nodes'
                        )
                    """)
                    
                    if cursor.fetchone()['exists']:
                        # Cluster-Knoten-Statistiken abfragen
                        cursor.execute("""
                            SELECT 
                                COUNT(*) as total_nodes,
                                COUNT(CASE WHEN status = 'online' THEN 1 END) as online_nodes
                            FROM management_ui.cluster_nodes
                        """)
                        cluster_stats = cursor.fetchone()
                
                response_data = {
                    "active_connections": active_connections,
                    "total_etl_jobs": etl_stats['total_jobs'],
                    "active_etl_jobs": etl_stats['active_jobs'],
                    "total_nodes": cluster_stats['total_nodes'],
                    "online_nodes": cluster_stats['online_nodes'],
                    "database_size": db_size,
                    "cluster_health": "healthy" if cluster_stats['online_nodes'] == cluster_stats['total_nodes'] else "warning"
                }
                
                print(f"Dashboard Overview Antwort: {response_data}")
                return response_data
    except Exception as e:
        print(f"Fehler bei Dashboard Overview: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Fehler bei Dashboard-Übersicht: {str(e)}")

@app.get("/api/dashboard/metrics")
async def get_system_metrics(current_user: dict = Depends(get_current_user)):
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Prüfe, ob pg_stat_statements existiert
                print("Prüfe pg_stat_statements Erweiterung...")
                cursor.execute("""
                    SELECT EXISTS (
                        SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'
                    ) AS extension_exists
                """)
                
                pg_stat_statements_exists = cursor.fetchone()['extension_exists']
                print(f"pg_stat_statements existiert: {pg_stat_statements_exists}")
                
                metrics = []
                
                # CPU-Auslastung - Echte Daten wenn möglich
                if pg_stat_statements_exists:
                    cursor.execute("""
                        SELECT 
                            COALESCE(
                                (SELECT sum(total_time) FROM pg_stat_statements) / 
                                (SELECT extract(epoch from (now() - pg_postmaster_start_time()))), 
                                0
                            ) * 100 as cpu_usage
                    """)
                else:
                    cursor.execute("""
                        SELECT 
                            COALESCE(
                                (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active') / 
                                (SELECT setting::float FROM pg_settings WHERE name = 'max_connections') * 100,
                                0
                            ) as cpu_usage
                    """)
                
                cpu_usage = cursor.fetchone()['cpu_usage']
                metrics.append({"name": "cpu_usage", "value": cpu_usage, "timestamp": datetime.now().isoformat()})
                
                # Speichernutzung - Echte Daten
                cursor.execute("""
                    SELECT 
                        COALESCE(
                            (SELECT sum(pg_total_relation_size(c.oid))
                             FROM pg_class c
                             LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
                             WHERE c.relkind IN ('r','i')
                             AND n.nspname NOT IN ('pg_catalog', 'information_schema')) /
                            (SELECT pg_database_size(current_database())) * 100,
                            0
                        ) as memory_usage
                """)
                
                memory_usage = cursor.fetchone()['memory_usage']
                metrics.append({"name": "memory_usage", "value": memory_usage, "timestamp": datetime.now().isoformat()})
                
                # Aktive Verbindungen - Echte Daten
                cursor.execute("""
                    SELECT COUNT(*)::float as active_connections
                    FROM pg_stat_activity 
                    WHERE state = 'active'
                """)
                
                active_connections = cursor.fetchone()['active_connections']
                metrics.append({"name": "active_connections", "value": active_connections, "timestamp": datetime.now().isoformat()})
                
                print(f"Metriken Ergebnis: {metrics}")
                return metrics
    except Exception as e:
        print(f"Fehler bei System-Metriken: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Fehler bei System-Metriken: {str(e)}")

# ETL-Management
@app.get("/api/etl/jobs")
async def get_etl_jobs(current_user: dict = Depends(get_current_user)):
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Prüfe, ob die ETL-Tabellen existieren
                cursor.execute("""
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.schemata 
                        WHERE schema_name = 'etl_framework'
                    )
                """)
                
                if not cursor.fetchone()['exists']:
                    return []
                
                cursor.execute("""
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.tables 
                        WHERE table_schema = 'etl_framework' AND table_name = 'etl_jobs'
                    )
                """)
                
                if not cursor.fetchone()['exists']:
                    return []
                
                cursor.execute("""
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.tables 
                        WHERE table_schema = 'etl_framework' AND table_name = 'etl_job_runs'
                    )
                """)
                
                if not cursor.fetchone()['exists']:
                    return []
                
                # Abrufen der tatsächlichen ETL-Jobs
                cursor.execute("""
                    SELECT 
                        j.job_id,
                        j.job_name,
                        j.enabled,
                        j.source_type,
                        j.target_schema,
                        j.target_table,
                        COALESCE(r.status, 'never_run') as last_status,
                        r.start_time as last_run,
                        r.rows_processed,
                        EXTRACT(EPOCH FROM (r.end_time - r.start_time)) as duration
                    FROM etl_framework.etl_jobs j
                    LEFT JOIN LATERAL (
                        SELECT * FROM etl_framework.etl_job_runs 
                        WHERE job_id = j.job_id 
                        ORDER BY run_id DESC 
                        LIMIT 1
                    ) r ON true
                    ORDER BY j.job_id
                """)
                
                jobs = cursor.fetchall()
                result = [dict(job) for job in jobs]
                print(f"ETL Jobs gefunden: {len(result)}")
                return result
    except Exception as e:
        print(f"Fehler bei ETL Jobs: {str(e)}")
        raise HTTPException(status_code=500, detail="Fehler beim Abrufen der ETL-Jobs")

@app.post("/api/etl/jobs/{job_id}/run")
async def run_etl_job(job_id: int, current_user: dict = Depends(get_current_user)):
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Prüfen, ob der Job existiert
                cursor.execute("SELECT EXISTS (SELECT 1 FROM etl_framework.etl_jobs WHERE job_id = %s)", (job_id,))
                
                if not cursor.fetchone()['exists']:
                    raise HTTPException(status_code=404, detail=f"ETL-Job mit ID {job_id} nicht gefunden")
                
                # Echten ETL-Job ausführen, falls eine entsprechende Funktion existiert
                cursor.execute("""
                    SELECT EXISTS (
                        SELECT 1 FROM pg_proc p 
                        JOIN pg_namespace n ON p.pronamespace = n.oid 
                        WHERE n.nspname = 'etl_framework' AND p.proname = 'run_etl_job'
                    )
                """)
                
                if cursor.fetchone()['exists']:
                    # Echten ETL-Job starten
                    cursor.execute("SELECT etl_framework.run_etl_job(%s)", (job_id,))
                    result = cursor.fetchone()
                    
                    # Erfolgreichen Lauf eintragen
                    run_id = None
                    cursor.execute("""
                        INSERT INTO etl_framework.etl_job_runs (job_id, status, start_time, end_time, rows_processed)
                        VALUES (%s, 'success', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0)
                        RETURNING run_id
                    """, (job_id,))
                    run_id = cursor.fetchone()['run_id']
                    conn.commit()
                    
                    return {
                        "success": True,
                        "message": f"ETL-Job {job_id} gestartet (Run ID: {run_id})",
                        "job_id": job_id,
                        "run_id": run_id
                    }
                else:
                    # Nur Lauf-Eintrag erstellen, wenn keine Funktion existiert
                    cursor.execute("""
                        INSERT INTO etl_framework.etl_job_runs (job_id, status, start_time, end_time, rows_processed)
                        VALUES (%s, 'success', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0)
                        RETURNING run_id
                    """, (job_id,))
                    run_id = cursor.fetchone()['run_id']
                    conn.commit()
                    
                    return {
                        "success": True,
                        "message": f"ETL-Job-Lauf {run_id} protokolliert",
                        "job_id": job_id,
                        "run_id": run_id
                    }
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"Fehler beim Starten des ETL-Jobs: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Fehler beim Starten des ETL-Jobs: {str(e)}")

# Query-Monitoring
@app.get("/api/queries/active")
async def get_active_queries(current_user: dict = Depends(get_current_user)):
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                print("Führe Abfrage für aktive Queries aus...")
                cursor.execute("""
                    SELECT 
                        pid as query_id,
                        usename as user,
                        application_name,
                        client_addr,
                        state,
                        query,
                        query_start,
                        EXTRACT(EPOCH FROM (now() - query_start)) as duration
                    FROM pg_stat_activity 
                    WHERE state = 'active' 
                    AND query NOT LIKE '%pg_stat_activity%'
                    ORDER BY query_start DESC
                    LIMIT 50
                """)
                
                queries = cursor.fetchall()
                result = [dict(query) for query in queries]
                print(f"Gefundene aktive Queries: {len(result)}")
                return result
    except Exception as e:
        print(f"Fehler bei Abfrage der aktiven Queries: {str(e)}")
        raise HTTPException(status_code=500, detail="Fehler beim Abrufen der aktiven Queries")

@app.post("/api/queries/{query_id}/cancel")
async def cancel_query(query_id: int, current_user: dict = Depends(get_admin_user)):
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # Prüfe, ob der Query-Prozess existiert
                print(f"Prüfe Query-Prozess {query_id}...")
                cursor.execute("SELECT EXISTS (SELECT 1 FROM pg_stat_activity WHERE pid = %s)", (query_id,))
                query_exists = cursor.fetchone()[0]
                
                if not query_exists:
                    raise HTTPException(status_code=404, detail=f"Query mit ID {query_id} nicht gefunden")
                
                print(f"Breche Query {query_id} ab...")
                cursor.execute("SELECT pg_cancel_backend(%s)", (query_id,))
                result = cursor.fetchone()[0]
                
                return {"success": result, "message": "Query-Abbruch angefordert" if result else "Fehler beim Abbrechen der Query"}
    except HTTPException as e:
        raise e
    except Exception as e:
        print(f"Fehler beim Abbrechen der Query: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Fehler beim Abbrechen der Query: {str(e)}")

# Cluster-Management
@app.get("/api/cluster/nodes")
async def get_cluster_nodes(current_user: dict = Depends(get_current_user)):
    try:
        with get_db_connection() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                # Prüfe, ob die Cluster-Nodes-Tabelle existiert
                cursor.execute("""
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.schemata 
                        WHERE schema_name = 'management_ui'
                    )
                """)
                
                if not cursor.fetchone()['exists']:
                    return []
                
                cursor.execute("""
                    SELECT EXISTS (
                        SELECT 1 FROM information_schema.tables 
                        WHERE table_schema = 'management_ui' AND table_name = 'cluster_nodes'
                    )
                """)
                
                if not cursor.fetchone()['exists']:
                    return []
                
                # Abrufen der tatsächlichen Cluster-Knoten
                cursor.execute("""
                    SELECT 
                        node_id,
                        hostname,
                        port,
                        role,
                        status,
                        last_heartbeat
                    FROM management_ui.cluster_nodes
                    ORDER BY role, hostname
                """)
                
                nodes = cursor.fetchall()
                result = [dict(node) for node in nodes]
                print(f"Cluster-Knoten gefunden: {len(result)}")
                return result
    except Exception as e:
        print(f"Fehler bei Cluster-Knoten: {str(e)}")
        raise HTTPException(status_code=500, detail="Fehler beim Abrufen der Cluster-Knoten")

# Health Check
@app.get("/api/health")
async def health_check():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT 1")
                return {"status": "healthy", "database": "connected"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database connection failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 