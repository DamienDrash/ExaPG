# ===================================================================
# ExaPG Multi-Stage Production Dockerfile
# ===================================================================
# DOCKER FIXES: DOCK-001 (Security Hardening) + DOCK-002 (Multi-Stage)
# Date: 2024-05-24
# Version: 2.0.0 (Multi-Stage + Security Hardened)
# ===================================================================

# ===================================================================
# BUILD STAGE - Extensions and Tools Compilation
# ===================================================================
FROM postgres:15 AS builder

# Install build dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    postgresql-server-dev-15 \
    libpq-dev \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    && rm -rf /var/lib/apt/lists/*

# ===================================================================
# BUILD: Install Citus 13.0 (Single-Node optimiert)
# ===================================================================
RUN curl -fsSL https://repos.citusdata.com/community/gpg.key | gpg --dearmor -o /usr/share/keyrings/citus.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/citus.gpg] https://repos.citusdata.com/community/debian/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/citus.list \
    && apt-get update \
    && apt-get install -y postgresql-15-citus-13.0 \
    && rm -rf /var/lib/apt/lists/*

# ===================================================================
# BUILD: Install TimescaleDB
# ===================================================================
RUN curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /usr/share/keyrings/timescaledb.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/timescaledb.list \
    && apt-get update \
    && apt-get install -y timescaledb-2-postgresql-15 \
    && rm -rf /var/lib/apt/lists/*

# ===================================================================
# BUILD: Install PostGIS
# ===================================================================
RUN apt-get update \
    && apt-get install -y postgresql-15-postgis-3 \
    && rm -rf /var/lib/apt/lists/*

# ===================================================================
# BUILD: Compile pgvector (latest stable)
# ===================================================================
RUN cd /tmp \
    && git clone --branch v0.7.4 --depth 1 https://github.com/pgvector/pgvector.git \
    && cd pgvector \
    && make clean \
    && make OPTFLAGS="" \
    && make install \
    && cd / \
    && rm -rf /tmp/pgvector

# ===================================================================
# BUILD: Install additional extensions
# ===================================================================
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    postgresql-15-pg-stat-kcache \
    postgresql-15-pgaudit \
    postgresql-15-pglogical \
    postgresql-15-hypopg \
    postgresql-15-plr \
    postgresql-15-pllua \
    && rm -rf /var/lib/apt/lists/*

# ===================================================================
# BUILD: Custom extensions compilation
# ===================================================================
RUN cd /tmp \
    && git clone --depth 1 https://github.com/citusdata/cstore_fdw.git \
    && cd cstore_fdw \
    && make \
    && make install \
    && cd / \
    && rm -rf /tmp/cstore_fdw

# ===================================================================
# RUNTIME STAGE - Production Image
# ===================================================================
FROM postgres:15 AS runtime

# ===================================================================
# SECURITY: Create non-root application user (Fixed GID conflict)
# ===================================================================
RUN groupadd -r exapg --gid=1001 \
    && useradd -r -g exapg --uid=1001 --home-dir=/var/lib/postgresql --shell=/bin/bash exapg \
    && mkdir -p /var/lib/postgresql \
    && chown -R exapg:exapg /var/lib/postgresql

# ===================================================================
# SECURITY: Install minimal runtime dependencies only
# ===================================================================
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    locales \
    postgresql-contrib \
    python3 \
    python3-pip \
    gosu \
    dumb-init \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# ===================================================================
# SECURITY: Copy compiled extensions from builder
# ===================================================================
COPY --from=builder /usr/lib/postgresql/15/lib/ /usr/lib/postgresql/15/lib/
COPY --from=builder /usr/share/postgresql/15/extension/ /usr/share/postgresql/15/extension/
COPY --from=builder /usr/lib/postgresql/15/bin/ /usr/lib/postgresql/15/bin/

# ===================================================================
# SECURITY: Configure shared_preload_libraries (Single-Node optimiert)
# ===================================================================
RUN echo "shared_preload_libraries = 'citus,pg_stat_statements'" >> /usr/share/postgresql/postgresql.conf.sample

# ===================================================================
# SECURITY: Flexible locale configuration
# ===================================================================
# I18N FIX: I18N-001 - Support multiple locales

# Install and generate common locales
RUN apt-get update \
    && apt-get install -y --no-install-recommends locales \
    && rm -rf /var/lib/apt/lists/* \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "de_DE.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "es_ES.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && localedef -i de_DE -c -f UTF-8 -A /usr/share/locale/locale.alias de_DE.UTF-8

# Set default locale (can be overridden via environment)
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Support for locale override via environment variables
# Usage: docker run -e EXAPG_LOCALE=de_DE.UTF-8 -e EXAPG_TIMEZONE=Europe/Berlin exapg:latest

# ===================================================================
# SECURITY: Directory structure with proper permissions
# ===================================================================
RUN mkdir -p /etc/postgresql/conf.d \
    && mkdir -p /var/log/postgresql \
    && mkdir -p /scripts \
    && mkdir -p /docker-entrypoint-initdb.d \
    && mkdir -p /var/run/postgresql \
    && chown -R postgres:postgres /etc/postgresql \
    && chown -R postgres:postgres /var/log/postgresql \
    && chown -R postgres:postgres /scripts \
    && chown -R postgres:postgres /docker-entrypoint-initdb.d \
    && chown -R postgres:postgres /var/run/postgresql \
    && chmod 755 /etc/postgresql/conf.d \
    && chmod 755 /var/log/postgresql \
    && chmod 755 /scripts

# ===================================================================
# SECURITY: Copy application files with proper ownership
# ===================================================================
COPY --chown=postgres:postgres scripts/init/ /docker-entrypoint-initdb.d/
COPY --chown=postgres:postgres scripts/cluster-management/ /scripts/cluster/
COPY --chown=postgres:postgres config/postgresql/ /etc/postgresql/

# ===================================================================
# SECURITY: Create secure entrypoint wrapper
# ===================================================================
COPY --chmod=755 <<EOF /usr/local/bin/docker-entrypoint-secure.sh
#!/bin/bash
set -e

# Security: Drop privileges if running as root
if [ "\$(id -u)" = '0' ]; then
    mkdir -p /var/run/postgresql
    chown -R postgres:postgres /var/run/postgresql
    chmod 2775 /var/run/postgresql
    
    # Initialize data directory with proper ownership
    if [ ! -s "\$PGDATA/PG_VERSION" ]; then
        gosu postgres initdb --locale=en_US.UTF-8 --encoding=UTF8 --data-checksums
        chown -R postgres:postgres "\$PGDATA"
        chmod 700 "\$PGDATA"
    fi
    
    # Execute as postgres user
    exec gosu postgres "\$@"
fi

# If already running as postgres user, execute directly
exec "\$@"
EOF

# ===================================================================
# SECURITY: Runtime security configurations
# ===================================================================

# Remove unnecessary packages and clean up
RUN apt-get autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/* \
    && rm -rf /root/.cache

# Security: Remove sensitive files and set secure permissions
RUN find /usr -type f -perm /u+s -exec chmod u-s {} \; \
    && find /usr -type f -perm /g+s -exec chmod g-s {} \; \
    && rm -f /usr/bin/passwd /usr/bin/chsh /usr/bin/chfn /usr/bin/newgrp

# Security: Create restricted shell environment
RUN echo 'PS1="exapg@\h:\w\$ "' >> /home/postgres/.bashrc \
    && echo 'umask 027' >> /home/postgres/.bashrc

# ===================================================================
# SECURITY: Container metadata and labels
# ===================================================================
LABEL maintainer="ExaPG Team" \
    version="2.0.0" \
    description="ExaPG - Secure PostgreSQL Analytical Database" \
    security.multi-stage="true" \
    security.non-root="true" \
    security.hardened="true"

# ===================================================================
# RUNTIME CONFIGURATION
# ===================================================================

# Security: Use non-root user by default
USER postgres

# Security: Set secure working directory
WORKDIR /var/lib/postgresql

# Expose PostgreSQL port only
EXPOSE 5432

# Security: Set resource limits
ENV POSTGRES_INITDB_ARGS="--data-checksums --locale=en_US.UTF-8"
ENV POSTGRES_HOST_AUTH_METHOD=md5

# Security: Advanced healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pg_isready -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-postgres} -h localhost || exit 1

# Security: Use dumb-init and secure entrypoint
ENTRYPOINT ["dumb-init", "--", "/usr/local/bin/docker-entrypoint-secure.sh"]

# Default command with security options
CMD ["postgres", \
    "-c", "config_file=/etc/postgresql/postgresql.conf", \
    "-c", "hba_file=/etc/postgresql/pg_hba.conf", \
    "-c", "shared_preload_libraries=citus,pg_stat_statements", \
    "-c", "log_destination=stderr", \
    "-c", "logging_collector=off", \
    "-c", "log_min_messages=warning", \
    "-c", "log_error_verbosity=default"]

# ===================================================================
# BUILD: Install additional PostgreSQL extensions
# ===================================================================
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    postgresql-contrib-15 \
    postgresql-15-pg-stat-kcache \
    && rm -rf /var/lib/apt/lists/*