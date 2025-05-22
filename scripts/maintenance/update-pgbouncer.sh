#!/bin/bash
# ExaPG - Update pgBouncer
# Aktualisiert die pgBouncer-Konfiguration basierend auf dem aktuellen Patroni-Status

set -e

# Konfiguration
ETCD_HOST=${ETCD_HOST:-etcd}
ETCD_PORT=${ETCD_PORT:-2379}
PGBOUNCER_CONFIG=/etc/pgbouncer/pgbouncer.ini
TEMP_CONFIG=/tmp/pgbouncer.ini.tmp

# Holt den aktuellen Leader für einen Cluster
get_leader() {
    local scope=$1
    /scripts/get-primary.sh $scope
}

# Aktualisiere pgBouncer-Konfiguration mit aktuellen Koordinatoren
update_pgbouncer_config() {
    # Sichere die aktuelle Konfiguration
    cp $PGBOUNCER_CONFIG $TEMP_CONFIG
    
    # Koordinator-Leader ermitteln
    COORDINATOR_LEADER=$(get_leader exapg-coordinator)
    if [ -z "$COORDINATOR_LEADER" ]; then
        echo "WARNUNG: Kein Koordinator-Leader gefunden, behalte aktuelle Konfiguration bei"
        return 1
    fi
    echo "Koordinator-Leader: $COORDINATOR_LEADER"
    
    # Worker-Leader ermitteln
    WORKER1_LEADER=$(get_leader exapg-worker-1)
    WORKER2_LEADER=$(get_leader exapg-worker-2)
    echo "Worker-Leader: $WORKER1_LEADER, $WORKER2_LEADER"
    
    # Aktualisiere die [databases] Sektion
    sed -i '/\[databases\]/,/\[/c\[databases\]\n* = host='$COORDINATOR_LEADER' port=5432 dbname=postgres' $TEMP_CONFIG
    
    # Füge Routing-Hinweise hinzu
    cat << EOF >> $TEMP_CONFIG

# Automatisch generiert am $(date)
# Primäre Knoten für Routing:
# Coordinator: $COORDINATOR_LEADER
# Worker 1: $WORKER1_LEADER
# Worker 2: $WORKER2_LEADER
EOF
    
    # Prüfe, ob sich die Konfiguration geändert hat
    if ! diff -q $PGBOUNCER_CONFIG $TEMP_CONFIG > /dev/null; then
        echo "Konfiguration hat sich geändert, aktualisiere pgBouncer..."
        mv $TEMP_CONFIG $PGBOUNCER_CONFIG
        # pgBouncer neu laden
        if [ -S /var/run/pgbouncer/pgbouncer.sock ]; then
            psql -h /var/run/pgbouncer -p 6432 -U postgres pgbouncer -c "RELOAD;"
            echo "pgBouncer neu geladen."
        else
            echo "pgBouncer-Socket nicht gefunden, überspringe Reload."
        fi
    else
        echo "Keine Änderungen an der Konfiguration erforderlich."
        rm $TEMP_CONFIG
    fi
}

# Führe die Aktualisierung sofort aus
update_pgbouncer_config

# Optionale kontinuierliche Überwachung
if [ "$1" == "--watch" ]; then
    echo "Starte kontinuierliche Überwachung..."
    while true; do
        update_pgbouncer_config
        sleep 10
    done
fi 