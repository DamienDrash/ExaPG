#!/bin/bash
# ExaPG - Start Patroni
# Skript zum Starten von Patroni mit dynamischer Konfiguration

set -e

# Patroni-Konfiguration aus Umgebungsvariablen generieren
echo "Erstelle Patroni-Konfiguration..."

# Standard-Werte für fehlende Umgebungsvariablen
PATRONI_SCOPE=${PATRONI_SCOPE:-exapg-cluster}
PATRONI_NAME=${PATRONI_NAME:-$(hostname)}
PATRONI_ETCD_HOST=${PATRONI_ETCD_HOST:-etcd}
PATRONI_ETCD_PORT=${PATRONI_ETCD_PORT:-2379}
PATRONI_POSTGRES_LISTEN=${PATRONI_POSTGRES_LISTEN:-0.0.0.0:5432}
PATRONI_POSTGRES_CONNECT_ADDRESS=${PATRONI_POSTGRES_CONNECT_ADDRESS:-$(hostname):5432}
PATRONI_RESTAPI_LISTEN=${PATRONI_RESTAPI_LISTEN:-0.0.0.0:8008}
PATRONI_RESTAPI_CONNECT_ADDRESS=${PATRONI_RESTAPI_CONNECT_ADDRESS:-$(hostname):8008}
PATRONI_RESTAPI_USERNAME=${PATRONI_RESTAPI_USERNAME:-admin}
PATRONI_RESTAPI_PASSWORD=${PATRONI_RESTAPI_PASSWORD:-admin}
POSTGRES_USER=${POSTGRES_USER:-postgres}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
NODE_ROLE=${NODE_ROLE:-database}
CITUS_NODE_ROLE=${CITUS_NODE_ROLE:-none}

# Template-Datei kopieren und anpassen
cp /etc/patroni/patroni-template.yml /etc/patroni/patroni.yml

# Platzhalter ersetzen
sed -i "s/__SCOPE__/$PATRONI_SCOPE/g" /etc/patroni/patroni.yml
sed -i "s/__NAME__/$PATRONI_NAME/g" /etc/patroni/patroni.yml
sed -i "s/__PATRONI_ETCD_HOST__/$PATRONI_ETCD_HOST/g" /etc/patroni/patroni.yml
sed -i "s/__PATRONI_ETCD_PORT__/$PATRONI_ETCD_PORT/g" /etc/patroni/patroni.yml
sed -i "s/__PATRONI_POSTGRES_LISTEN__/$PATRONI_POSTGRES_LISTEN/g" /etc/patroni/patroni.yml
sed -i "s/__PATRONI_POSTGRES_CONNECT_ADDRESS__/$PATRONI_POSTGRES_CONNECT_ADDRESS/g" /etc/patroni/patroni.yml
sed -i "s/__PATRONI_RESTAPI_LISTEN__/$PATRONI_RESTAPI_LISTEN/g" /etc/patroni/patroni.yml
sed -i "s/__PATRONI_RESTAPI_CONNECT_ADDRESS__/$PATRONI_RESTAPI_CONNECT_ADDRESS/g" /etc/patroni/patroni.yml
sed -i "s/__PATRONI_RESTAPI_USERNAME__/$PATRONI_RESTAPI_USERNAME/g" /etc/patroni/patroni.yml
sed -i "s/__PATRONI_RESTAPI_PASSWORD__/$PATRONI_RESTAPI_PASSWORD/g" /etc/patroni/patroni.yml
sed -i "s/__POSTGRES_USER__/$POSTGRES_USER/g" /etc/patroni/patroni.yml
sed -i "s/__POSTGRES_PASSWORD__/$POSTGRES_PASSWORD/g" /etc/patroni/patroni.yml
sed -i "s/__NODE_ROLE__/$NODE_ROLE/g" /etc/patroni/patroni.yml
sed -i "s/__CITUS_NODE_ROLE__/$CITUS_NODE_ROLE/g" /etc/patroni/patroni.yml

# Spezielle Konfiguration basierend auf Knotenrolle
if [ "$CITUS_NODE_ROLE" == "coordinator" ]; then
    # Koordinator-spezifische Einstellungen
    echo "Konfiguriere Koordinator-spezifische Einstellungen..."
elif [ "$CITUS_NODE_ROLE" == "worker" ]; then
    # Worker-spezifische Einstellungen
    echo "Konfiguriere Worker-spezifische Einstellungen..."
    # Worker-ID für Citus konfigurieren
    if [ ! -z "$CITUS_WORKER_ID" ]; then
        echo "Setze Worker-ID auf $CITUS_WORKER_ID"
        echo "    citus.node_id: $CITUS_WORKER_ID" >> /etc/patroni/patroni.yml
    fi
fi

echo "Patroni-Konfiguration erstellt in /etc/patroni/patroni.yml"
echo "Starte Patroni..."

# Starte Patroni
exec patroni /etc/patroni/patroni.yml 