#!/bin/bash
# ExaPG - Start Cluster Management
# Skript zum Starten des Cluster-Management-Systems mit automatischer Clustererweiterung

set -e

# Prüfen, ob Docker und Docker Compose installiert sind
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker ist nicht installiert. Bitte installieren Sie Docker und versuchen Sie es erneut."
    exit 1
fi

if ! docker compose version >/dev/null 2>&1 && ! docker-compose version >/dev/null 2>&1; then
    echo "Docker Compose ist nicht installiert. Bitte installieren Sie Docker Compose und versuchen Sie es erneut."
    exit 1
fi

# Einstellen des Projektverzeichnisses
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Erstellen der PostgreSQL-Konfigurationsdateien, falls nicht vorhanden
if [ ! -f config/postgresql/postgresql-coordinator.conf ] || [ ! -f config/postgresql/postgresql-worker.conf ] || [ ! -f config/postgresql/pg_hba.conf ]; then
    echo "PostgreSQL-Konfigurationsdateien werden erstellt..."
    mkdir -p config/postgresql
    
    # Konfigurationsdateien erstellen
    ./start-exapg-citus.sh --only-config
    
    if [ $? -ne 0 ]; then
        echo "Fehler beim Erstellen der PostgreSQL-Konfigurationsdateien."
        exit 1
    fi
fi

# Einfaches UI für das Cluster-Management erstellen
UI_DIR="scripts/cluster-management/ui"
mkdir -p "$UI_DIR"

if [ ! -f "$UI_DIR/index.html" ]; then
    cat > "$UI_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ExaPG Cluster Management</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css">
    <style>
        body { padding-top: 20px; }
        .node-card { margin-bottom: 15px; }
        .status-badge { float: right; }
        .node-card.coordinator { border-color: #28a745; }
        .node-card.worker { border-color: #007bff; }
    </style>
</head>
<body>
    <div class="container">
        <header class="mb-4">
            <h1>ExaPG Cluster Management</h1>
            <p class="lead">Automatische Cluster-Erweiterung und -Verwaltung</p>
        </header>

        <div class="row">
            <div class="col-md-8">
                <div class="card mb-4">
                    <div class="card-header">
                        <h2 class="h5 mb-0">Cluster-Status</h2>
                    </div>
                    <div class="card-body">
                        <div id="cluster-nodes">
                            <p>Lade Cluster-Informationen...</p>
                        </div>
                    </div>
                </div>

                <div class="card mb-4">
                    <div class="card-header">
                        <h2 class="h5 mb-0">Datenbank-Statistiken</h2>
                    </div>
                    <div class="card-body">
                        <div id="db-stats">
                            <p>Lade Datenbank-Statistiken...</p>
                        </div>
                    </div>
                </div>
            </div>

            <div class="col-md-4">
                <div class="card mb-4">
                    <div class="card-header">
                        <h2 class="h5 mb-0">Aktionen</h2>
                    </div>
                    <div class="card-body">
                        <button id="add-worker-btn" class="btn btn-primary mb-2 w-100">Worker hinzufügen</button>
                        <button id="rebalance-btn" class="btn btn-secondary mb-2 w-100">Cluster rebalancieren</button>
                        <div id="remove-worker-container" class="d-none">
                            <select id="worker-select" class="form-select mb-2">
                                <option value="">Worker auswählen...</option>
                            </select>
                            <button id="remove-worker-btn" class="btn btn-danger mb-2 w-100">Worker entfernen</button>
                        </div>
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <h2 class="h5 mb-0">Status</h2>
                    </div>
                    <div class="card-body">
                        <div id="status-messages" class="alert alert-info">
                            Bereit.
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        const API_URL = 'http://localhost:5000/api';

        // Cluster-Status abrufen
        function fetchClusterStatus() {
            fetch(`${API_URL}/cluster/status`)
                .then(response => response.json())
                .then(data => {
                    if (data.status === 'ok') {
                        // Cluster-Knoten anzeigen
                        displayClusterNodes(data.cluster, data.containers);
                        
                        // Datenbank-Statistiken anzeigen
                        displayDatabaseStats(data.database_stats);
                        
                        // Worker-Liste für Dropdown aktualisieren
                        updateWorkerSelect(data.cluster.workers);
                    } else {
                        showStatus('Fehler beim Abrufen des Cluster-Status', 'danger');
                    }
                })
                .catch(error => {
                    console.error('Fehler:', error);
                    showStatus('Verbindungsfehler zur API', 'danger');
                });
        }

        // Cluster-Knoten anzeigen
        function displayClusterNodes(cluster, containers) {
            const nodesContainer = document.getElementById('cluster-nodes');
            nodesContainer.innerHTML = '';
            
            // Coordinator-Knoten anzeigen
            const coordinatorContainer = containers.find(c => c.name === 'exapg-coordinator');
            const coordinatorStatus = coordinatorContainer ? coordinatorContainer.status : 'unbekannt';
            const coordinatorCard = createNodeCard('Coordinator', cluster.coordinator, coordinatorStatus, 'coordinator');
            nodesContainer.appendChild(coordinatorCard);
            
            // Worker-Knoten anzeigen
            if (cluster.workers.length === 0) {
                const noWorkersMessage = document.createElement('p');
                noWorkersMessage.textContent = 'Keine Worker-Knoten im Cluster.';
                nodesContainer.appendChild(noWorkersMessage);
            } else {
                const workersHeading = document.createElement('h3');
                workersHeading.className = 'h6 mt-3 mb-2';
                workersHeading.textContent = `Worker-Knoten (${cluster.workers.length})`;
                nodesContainer.appendChild(workersHeading);
                
                cluster.workers.forEach(worker => {
                    const workerContainer = containers.find(c => c.name === worker.name);
                    const workerStatus = workerContainer ? workerContainer.status : 'unbekannt';
                    const workerCard = createNodeCard(`Worker ${worker.id}`, worker.name, workerStatus, 'worker');
                    nodesContainer.appendChild(workerCard);
                });
            }
        }

        // Knotencard erstellen
        function createNodeCard(title, name, status, type) {
            const card = document.createElement('div');
            card.className = `card node-card ${type}`;
            
            const cardBody = document.createElement('div');
            cardBody.className = 'card-body';
            
            const statusBadge = document.createElement('span');
            statusBadge.className = `badge status-badge bg-${status === 'running' ? 'success' : 'warning'}`;
            statusBadge.textContent = status;
            
            const cardTitle = document.createElement('h5');
            cardTitle.className = 'card-title';
            cardTitle.textContent = title;
            cardTitle.appendChild(statusBadge);
            
            const cardText = document.createElement('p');
            cardText.className = 'card-text';
            cardText.textContent = `Name: ${name}`;
            
            cardBody.appendChild(cardTitle);
            cardBody.appendChild(cardText);
            card.appendChild(cardBody);
            
            return card;
        }

        // Datenbank-Statistiken anzeigen
        function displayDatabaseStats(stats) {
            const statsContainer = document.getElementById('db-stats');
            
            if (!stats || Object.keys(stats).length === 0) {
                statsContainer.innerHTML = '<p>Keine Datenbank-Statistiken verfügbar.</p>';
                return;
            }
            
            statsContainer.innerHTML = `
                <ul class="list-group">
                    <li class="list-group-item">Tabellen gesamt: ${stats.total_tables}</li>
                    <li class="list-group-item">Verteilte Tabellen: ${stats.distributed_tables}</li>
                    <li class="list-group-item">Shards: ${stats.total_shards}</li>
                </ul>
            `;
        }

        // Worker-Auswahl aktualisieren
        function updateWorkerSelect(workers) {
            const select = document.getElementById('worker-select');
            const container = document.getElementById('remove-worker-container');
            
            // Option-Elemente löschen
            while (select.options.length > 1) {
                select.remove(1);
            }
            
            if (workers.length > 0) {
                container.classList.remove('d-none');
                
                // Neue Worker-Optionen hinzufügen
                workers.forEach(worker => {
                    const option = document.createElement('option');
                    option.value = JSON.stringify({ name: worker.name, id: worker.id });
                    option.textContent = `${worker.name} (ID: ${worker.id})`;
                    select.appendChild(option);
                });
            } else {
                container.classList.add('d-none');
            }
        }

        // Status-Meldung anzeigen
        function showStatus(message, type = 'info') {
            const statusContainer = document.getElementById('status-messages');
            statusContainer.className = `alert alert-${type}`;
            statusContainer.textContent = message;
        }

        // Worker hinzufügen
        document.getElementById('add-worker-btn').addEventListener('click', () => {
            showStatus('Füge Worker zum Cluster hinzu...', 'info');
            
            fetch(`${API_URL}/cluster/add-worker`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                }
            })
            .then(response => response.json())
            .then(data => {
                if (data.status === 'ok') {
                    showStatus(`${data.message}`, 'success');
                    setTimeout(fetchClusterStatus, 2000);
                } else {
                    showStatus(`Fehler: ${data.message}`, 'danger');
                }
            })
            .catch(error => {
                console.error('Fehler:', error);
                showStatus('Verbindungsfehler zur API', 'danger');
            });
        });

        // Worker entfernen
        document.getElementById('remove-worker-btn').addEventListener('click', () => {
            const select = document.getElementById('worker-select');
            if (select.value === '') {
                showStatus('Bitte wählen Sie einen Worker aus', 'warning');
                return;
            }
            
            const workerData = JSON.parse(select.value);
            showStatus(`Entferne Worker ${workerData.name}...`, 'info');
            
            fetch(`${API_URL}/cluster/remove-worker`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    worker_name: workerData.name,
                    node_id: workerData.id
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.status === 'ok') {
                    showStatus(`${data.message}`, 'success');
                    setTimeout(fetchClusterStatus, 2000);
                } else {
                    showStatus(`Fehler: ${data.message}`, 'danger');
                }
            })
            .catch(error => {
                console.error('Fehler:', error);
                showStatus('Verbindungsfehler zur API', 'danger');
            });
        });

        // Cluster rebalancieren
        document.getElementById('rebalance-btn').addEventListener('click', () => {
            showStatus('Rebalanciere Cluster...', 'info');
            
            fetch(`${API_URL}/cluster/rebalance`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                }
            })
            .then(response => response.json())
            .then(data => {
                if (data.status === 'ok') {
                    showStatus(`${data.message}`, 'success');
                } else {
                    showStatus(`Fehler: ${data.message}`, 'danger');
                }
            })
            .catch(error => {
                console.error('Fehler:', error);
                showStatus('Verbindungsfehler zur API', 'danger');
            });
        });

        // Initialer Aufruf
        fetchClusterStatus();
        
        // Regelmäßige Aktualisierung
        setInterval(fetchClusterStatus, 5000);
    </script>
</body>
</html>
EOF
    echo "UI für Cluster-Management erstellt in $UI_DIR"
fi

# Docker-Compose-Datei für Cluster-Management starten
echo "Starte ExaPG Cluster-Management-System..."

# Prüfen ob Docker Compose V2 oder V1 verwendet wird
if command -v docker compose >/dev/null 2>&1; then
    # Docker Compose V2
    docker compose -f docker/docker-compose/docker-compose.cluster-management.yml up -d
else
    # Docker Compose V1 (Fallback)
    docker-compose -f docker/docker-compose/docker-compose.cluster-management.yml up -d
fi

echo "Das ExaPG Cluster-Management-System wurde gestartet!"
echo "=========================================================="
echo "Folgende Dienste sind verfügbar:"
echo ""
echo "Cluster-API:     http://localhost:5000/api/cluster/status"
echo "Cluster-UI:      http://localhost:8080"
echo "PostgreSQL:      localhost:5432"
echo "Benutzer:        ${POSTGRES_USER:-postgres}"
echo "Passwort:        ${POSTGRES_PASSWORD:-postgres}"
echo "Datenbank:       ${POSTGRES_DB:-postgres}"
echo "=========================================================="
echo "Das Cluster-Management-System ermöglicht die folgenden Funktionen:"
echo "- Dynamisches Hinzufügen/Entfernen von Worker-Knoten"
echo "- Automatische Datenumverteilung bei Cluster-Änderungen"
echo "- Rolling-Updates des Clusters ohne Ausfallzeit"
echo "- Selbstheilende Cluster-Mechanismen"
echo ""
echo "Zum Stoppen des Cluster-Management-Systems führen Sie den folgenden Befehl aus:"
echo "docker compose -f docker/docker-compose/docker-compose.cluster-management.yml down"
echo ""
echo "Die Konfiguration bleibt auch nach einem Neustart oder einer neuen Installation erhalten." 