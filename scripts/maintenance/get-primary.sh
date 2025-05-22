#!/bin/bash
# ExaPG - Get Primary
# Skript zum Abrufen des aktuellen primären Knotens für einen Patroni-Cluster

set -e

if [ $# -lt 1 ]; then
    echo "Verwendung: $0 <scope>"
    exit 1
fi

SCOPE=$1
ETCD_HOST=${ETCD_HOST:-etcd}
ETCD_PORT=${ETCD_PORT:-2379}

# Prüfen, ob etcdctl verfügbar ist
if ! command -v etcdctl &> /dev/null; then
    echo "etcdctl ist nicht installiert. Verwende Patroni REST API als Fallback."
    # Liste der potenziellen Patroni-Knoten
    if [ "$SCOPE" == "exapg-coordinator" ]; then
        NODES=("coordinator-1:8008" "coordinator-2:8008")
    elif [ "$SCOPE" == "exapg-worker-1" ]; then
        NODES=("worker-1a:8008" "worker-1b:8008")
    elif [ "$SCOPE" == "exapg-worker-2" ]; then
        NODES=("worker-2a:8008" "worker-2b:8008")
    else
        echo "Unbekannter Scope: $SCOPE"
        exit 1
    fi
    
    # Finde den primären Knoten
    for node in "${NODES[@]}"; do
        # Prüfe, ob der Knoten primär ist
        if curl -s "http://$node/leader" | grep -q "$node"; then
            echo "${node%:*}"
            exit 0
        fi
    done
    
    echo "Kein primärer Knoten gefunden für Scope: $SCOPE"
    exit 1
else
    # Verwende etcdctl, um den primären Knoten zu finden
    PRIMARY=$(etcdctl --endpoints="$ETCD_HOST:$ETCD_PORT" get "/service/$SCOPE/leader" --print-value-only)
    
    if [ -z "$PRIMARY" ]; then
        echo "Kein primärer Knoten gefunden für Scope: $SCOPE"
        exit 1
    fi
    
    # Extrahiere Hostnamen
    echo "$PRIMARY" | jq -r .name
fi 