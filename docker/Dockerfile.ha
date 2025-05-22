FROM postgres:15

# Metadaten
LABEL maintainer="ExaPG Team"
LABEL description="PostgreSQL mit Citus und Patroni für ExaPG Hochverfügbarkeit"
LABEL version="1.0"

# Umgebungsvariablen
ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_USER=postgres
ENV POSTGRES_DB=postgres

# Installiere benötigte Pakete
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        python3 \
        python3-pip \
        python3-dev \
        libpq-dev \
        jq \
        etcd \
    && curl https://install.citusdata.com/community/deb.sh | bash \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-15-citus-12 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Installiere Patroni und pgBouncer
RUN pip3 install --no-cache-dir patroni[etcd] psycopg2-binary

# Erstelle Verzeichnisse für Patroni
RUN mkdir -p /etc/patroni /var/lib/patroni /var/log/patroni

# Aktiviere die Citus-Erweiterung
RUN echo "shared_preload_libraries = 'citus'" >> /usr/share/postgresql/postgresql.conf.sample

# Citus-Konfiguration optimieren
RUN echo "citus.shard_count = 32" >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "citus.shard_replication_factor = 2" >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "citus.enable_repartition_joins = on" >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "max_prepared_transactions = 100" >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "wal_level = logical" >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "max_wal_senders = 10" >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "max_replication_slots = 10" >> /usr/share/postgresql/postgresql.conf.sample \
    && echo "hot_standby = on" >> /usr/share/postgresql/postgresql.conf.sample

# Kopiere das Citus-SQL-Skript
COPY sql/distribution/create_distribution_strategies.sql /docker-entrypoint-initdb.d/

# Healthcheck
HEALTHCHECK --interval=10s --timeout=5s --retries=5 CMD pg_isready -U postgres || exit 1

EXPOSE 5432 8008

# Einstiegspunkt wird durch Docker-Compose überschrieben
CMD ["postgres"] 