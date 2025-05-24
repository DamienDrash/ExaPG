# ExaPG Kubernetes Integration

## Übersicht

Diese Kubernetes-Integration bietet eine vollständige, produktionsreife Bereitstellung von ExaPG (High-Performance PostgreSQL Analytical Database) in Kubernetes-Clustern. Die Lösung umfasst automatisierte Bereitstellung, Monitoring, Management-Tools und Backup-Infrastruktur.

## 🏗️ Architektur

### Core-Komponenten
- **PostgreSQL Coordinator**: Citus-Koordinator für verteilte Abfragen
- **PostgreSQL Workers**: 2x Worker-Nodes für parallele Verarbeitung
- **Citus Cluster**: Automatische Worker-Registrierung und Setup
- **Health Monitoring**: Cluster-Gesundheitsüberwachung

### Monitoring Stack
- **Prometheus**: Metriken-Sammlung und -Speicherung
- **Grafana**: Visualisierung und Dashboards
- **Alertmanager**: Benachrichtigungen und Alerting
- **PostgreSQL Exporter**: Datenbankspezifische Metriken
- **Node Exporter**: System-Metriken

### Management Tools
- **pgAdmin**: Vollständige Datenbank-Administration
- **Adminer**: Leichtgewichtige DB-Administration
- **File Browser**: Log- und Datei-Management
- **Backup UI**: Backup-Management-Interface

### Networking & Security
- **Ingress Controller**: Externer Zugriff mit SSL/TLS
- **Network Policies**: Netzwerk-Segmentierung
- **SSL/TLS**: Ende-zu-Ende-Verschlüsselung
- **RBAC**: Rollenbasierte Zugriffskontrolle

## 🚀 Schnellstart

### Voraussetzungen

1. **Kubernetes Cluster** (v1.24+)
2. **kubectl** konfiguriert und verbunden
3. **Ingress Controller** (nginx empfohlen)
4. **Storage Class** für persistente Volumes
5. **cert-manager** (optional, für automatische SSL-Zertifikate)

### Installation

```bash
# Repository klonen
git clone https://github.com/exapg/exapg.git
cd exapg/k8s

# Vollständige Bereitstellung (Development)
./deploy.sh dev --all

# Produktionsbereitstellung
./deploy.sh prod --all

# Nur Monitoring-Stack
./deploy.sh prod --monitoring

# Dry-Run (zeigt was bereitgestellt würde)
./deploy.sh prod --all --dry-run
```

### Umgebungen

| Umgebung | Beschreibung | Ressourcen |
|----------|--------------|------------|
| `dev` | Entwicklung | Minimal (1GB RAM, 1 CPU) |
| `staging` | Test/Staging | Medium (2GB RAM, 2 CPU) |
| `prod` | Produktion | Vollständig (4GB RAM, 4 CPU) |

## 📋 Deployment-Optionen

### Vollständige Bereitstellung
```bash
./deploy.sh prod --all
```
Bereitstellt:
- PostgreSQL Cluster (Coordinator + 2 Workers)
- Citus-Setup und -Konfiguration
- Monitoring Stack (Prometheus, Grafana, Alertmanager)
- Management UI (pgAdmin, Adminer, File Browser)
- Backup-Infrastruktur
- Ingress und Networking

### Modulare Bereitstellung
```bash
# Nur Core-Datenbank
./deploy.sh prod

# Nur Monitoring
./deploy.sh prod --monitoring

# Nur Management-Tools
./deploy.sh prod --management

# Nur Backup-Infrastruktur
./deploy.sh prod --backup
```

### Cleanup und Neubereitstellung
```bash
# Bestehende Bereitstellung entfernen und neu bereitstellen
./deploy.sh prod --cleanup --all
```

## 🌐 Zugriff

### Web-Interfaces

| Service | URL | Beschreibung |
|---------|-----|--------------|
| **Hauptdashboard** | http://exapg.local | ExaPG Management Interface |
| **Grafana** | http://grafana.exapg.local | Monitoring Dashboards |
| **pgAdmin** | http://pgadmin.exapg.local | Datenbank-Administration |
| **Prometheus** | http://prometheus.exapg.local | Metriken und Queries |
| **Alertmanager** | http://alertmanager.exapg.local | Alert-Management |

### Datenbank-Zugriff

```bash
# Direkte Verbindung zum Coordinator
psql -h db.exapg.local -p 5432 -U postgres -d exadb

# Port-Forward für lokalen Zugriff
kubectl port-forward -n exapg svc/exapg-coordinator 5432:5432
psql -h localhost -p 5432 -U postgres -d exadb
```

### Standard-Anmeldedaten

| Service | Benutzername | Passwort |
|---------|--------------|----------|
| **PostgreSQL** | postgres | exapg_secure_password_123 |
| **Grafana** | admin | exapg_grafana_admin_123 |
| **pgAdmin** | admin@exapg.local | admin123 |

⚠️ **Wichtig**: Ändern Sie alle Standard-Passwörter in der Produktion!

## 🔧 Konfiguration

### Environment-spezifische Anpassungen

Die Konfiguration wird automatisch basierend auf der gewählten Umgebung angepasst:

```yaml
# Development (dev)
shared_buffers: "1GB"
work_mem: "256MB"
max_parallel_workers: "4"

# Staging
shared_buffers: "2GB"
work_mem: "512MB"
max_parallel_workers: "8"

# Production (prod)
shared_buffers: "4GB"
work_mem: "1GB"
max_parallel_workers: "16"
```

### Secrets anpassen

```bash
# PostgreSQL-Passwörter ändern
kubectl edit secret exapg-postgres-secret -n exapg

# Monitoring-Credentials ändern
kubectl edit secret exapg-monitoring-secret -n exapg

# Management-UI-Credentials ändern
kubectl edit secret exapg-mgmt-secret -n exapg
```

### Storage Classes

Passen Sie die Storage Class in den Manifests an Ihre Umgebung an:

```yaml
# In allen PVC-Definitionen
storageClassName: fast-ssd  # Ändern Sie dies entsprechend
```

## 📊 Monitoring

### Verfügbare Metriken

- **PostgreSQL-Metriken**: Verbindungen, Transaktionen, Locks, etc.
- **Citus-Metriken**: Worker-Status, Shard-Verteilung, Cluster-Gesundheit
- **System-Metriken**: CPU, Memory, Disk, Network
- **Application-Metriken**: Query-Performance, Cache-Hit-Ratio

### Grafana Dashboards

Vorkonfigurierte Dashboards für:
- PostgreSQL Overview
- Citus Cluster Status
- System Resources
- Query Performance
- Backup Status

### Alerting

Vorkonfigurierte Alerts für:
- Hohe CPU/Memory-Nutzung
- Datenbankverbindungsprobleme
- Citus Worker-Ausfälle
- Backup-Fehler
- Disk-Space-Warnungen

## 🔒 Sicherheit

### Network Policies

```yaml
# Automatisch angewendete Netzwerk-Segmentierung
- Ingress nur von nginx-ingress
- Interne Cluster-Kommunikation erlaubt
- Monitoring-Zugriff beschränkt
```

### SSL/TLS

```yaml
# Automatische SSL-Zertifikate (mit cert-manager)
cert-manager.io/cluster-issuer: "letsencrypt-prod"

# Oder manuelle Zertifikate
tls:
  - hosts:
    - exapg.local
    secretName: exapg-tls-secret
```

### RBAC

```bash
# Service Accounts mit minimalen Berechtigungen
# Separate Rollen für verschiedene Komponenten
# Keine privilegierten Container
```

## 🔄 Backup & Recovery

### Automatische Backups

```bash
# Backup-Status prüfen
kubectl exec -n exapg deployment/exapg-backup-ui -- backup-manager.sh status

# Manuelles Backup
kubectl exec -n exapg deployment/exapg-backup-ui -- backup-manager.sh backup

# Disaster Recovery Test
kubectl exec -n exapg deployment/exapg-backup-ui -- backup-manager.sh test-dr
```

### Backup-Monitoring

- Web-Dashboard: http://exapg.local/backup
- Automatische Verifikation
- E-Mail/Slack-Benachrichtigungen
- Disaster Recovery Tests

## 📈 Skalierung

### Horizontale Skalierung

```bash
# Weitere Worker hinzufügen
kubectl scale statefulset exapg-worker3 --replicas=1 -n exapg

# Management-UI skalieren
kubectl scale deployment exapg-management-ui --replicas=3 -n exapg
```

### Vertikale Skalierung

```bash
# Ressourcen für PostgreSQL erhöhen
kubectl patch statefulset exapg-coordinator -n exapg -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "postgres",
          "resources": {
            "limits": {"memory": "16Gi", "cpu": "8000m"},
            "requests": {"memory": "8Gi", "cpu": "4000m"}
          }
        }]
      }
    }
  }
}'
```

### Auto-Scaling

HorizontalPodAutoscaler ist für Management-Komponenten konfiguriert:

```yaml
# Automatische Skalierung basierend auf CPU/Memory
minReplicas: 1
maxReplicas: 5
targetCPUUtilizationPercentage: 70
```

## 🛠️ Wartung

### Updates

```bash
# Rolling Update für Management-Komponenten
kubectl set image deployment/exapg-grafana grafana=grafana/grafana:10.3.0 -n exapg

# PostgreSQL-Updates (mit Downtime)
kubectl delete statefulset exapg-coordinator -n exapg --cascade=false
# Manifest mit neuer Version anwenden
kubectl apply -f postgres-statefulset.yaml
```

### Logs

```bash
# PostgreSQL Logs
kubectl logs -n exapg statefulset/exapg-coordinator -f

# Monitoring Logs
kubectl logs -n exapg deployment/exapg-prometheus -f

# Alle Logs
kubectl logs -n exapg --all-containers=true -f
```

### Debugging

```bash
# Pod-Status prüfen
kubectl get pods -n exapg -o wide

# Events anzeigen
kubectl get events -n exapg --sort-by='.lastTimestamp'

# In Pod einsteigen
kubectl exec -it -n exapg exapg-coordinator-0 -- bash

# Port-Forward für direkten Zugriff
kubectl port-forward -n exapg svc/exapg-coordinator 5432:5432
```

## 🔧 Troubleshooting

### Häufige Probleme

#### PostgreSQL startet nicht
```bash
# Logs prüfen
kubectl logs -n exapg exapg-coordinator-0

# PVC-Status prüfen
kubectl get pvc -n exapg

# Storage-Probleme
kubectl describe pv
```

#### Citus Worker nicht erreichbar
```bash
# Worker-Status prüfen
kubectl exec -n exapg exapg-coordinator-0 -- psql -U postgres -d exadb -c "SELECT * FROM citus_get_active_worker_nodes();"

# Netzwerk-Konnektivität testen
kubectl exec -n exapg exapg-coordinator-0 -- pg_isready -h exapg-worker1.exapg.svc.cluster.local
```

#### Ingress funktioniert nicht
```bash
# Ingress-Status prüfen
kubectl get ingress -n exapg
kubectl describe ingress exapg-ingress -n exapg

# DNS-Auflösung testen
nslookup exapg.local

# Hosts-Datei aktualisieren (lokal)
echo "$(kubectl get ingress exapg-ingress -n exapg -o jsonpath='{.status.loadBalancer.ingress[0].ip}') exapg.local" >> /etc/hosts
```

#### Monitoring-Metriken fehlen
```bash
# Exporter-Status prüfen
kubectl get pods -n exapg -l app.kubernetes.io/component=postgres-exporter

# Prometheus-Targets prüfen
# Öffnen Sie http://prometheus.exapg.local/targets
```

### Performance-Tuning

#### PostgreSQL-Optimierung
```bash
# Aktuelle Konfiguration prüfen
kubectl exec -n exapg exapg-coordinator-0 -- psql -U postgres -c "SHOW ALL;"

# Konfiguration anpassen
kubectl edit configmap exapg-config -n exapg

# Pods neu starten
kubectl rollout restart statefulset/exapg-coordinator -n exapg
```

#### Storage-Performance
```bash
# I/O-Performance testen
kubectl exec -n exapg exapg-coordinator-0 -- fio --name=test --ioengine=libaio --rw=randrw --bs=4k --numjobs=1 --size=1G --runtime=60 --time_based --filename=/var/lib/postgresql/data/test
```

## 📚 Weitere Ressourcen

### Dokumentation
- [ExaPG Hauptdokumentation](../README.md)
- [Citus Dokumentation](https://docs.citusdata.com/)
- [PostgreSQL Dokumentation](https://www.postgresql.org/docs/)
- [Kubernetes Dokumentation](https://kubernetes.io/docs/)

### Monitoring & Observability
- [Prometheus Dokumentation](https://prometheus.io/docs/)
- [Grafana Dokumentation](https://grafana.com/docs/)
- [PostgreSQL Exporter](https://github.com/prometheus-community/postgres_exporter)

### Support
- GitHub Issues: https://github.com/exapg/exapg/issues
- Community Forum: https://github.com/exapg/exapg/discussions
- Enterprise Support: enterprise@exapg.com

## 🤝 Beitragen

Beiträge zur Kubernetes-Integration sind willkommen! Bitte lesen Sie unsere [Contribution Guidelines](../CONTRIBUTING.md).

### Entwicklung

```bash
# Lokale Entwicklung mit minikube
minikube start --memory=8192 --cpus=4
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
# ... weitere Manifests

# Testen
./deploy.sh dev --dry-run
```

## 📄 Lizenz

Dieses Projekt steht unter der [MIT Lizenz](../LICENSE).

---

**ExaPG Kubernetes Integration** - Hochperformante PostgreSQL-Analytik in der Cloud 🚀 