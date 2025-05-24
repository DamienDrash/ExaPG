# Getting Started with ExaPG

This guide will help you get ExaPG up and running quickly for development, testing, or production use.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [First Steps](#first-steps)
- [Basic Usage](#basic-usage)
- [Next Steps](#next-steps)
- [Common Use Cases](#common-use-cases)
- [Getting Help](#getting-help)

## Prerequisites

Before installing ExaPG, ensure your system meets these requirements:

### Hardware Requirements

- **CPU**: 4+ cores recommended
- **Memory**: 
  - Minimum: 8GB RAM (single-node)
  - Recommended: 16GB+ RAM (cluster mode)
- **Storage**: 
  - 50GB+ free space
  - SSD recommended for optimal performance

### Software Requirements

- **Operating System**: Linux, macOS, or Windows with WSL2
- **Docker**: Version 19.03 or higher
- **Docker Compose**: Version 1.27 or higher
- **Git**: For cloning the repository

### Network Requirements

Ensure these ports are available:
- `5432`: PostgreSQL
- `8080`: Management UI
- `3000`: Grafana
- `9090`: Prometheus

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/DamienDrash/ExaPG.git
cd ExaPG
```

### 2. Configure Your Environment

```bash
# Copy the example configuration
cp .env.example .env

# Edit configuration as needed
nano .env  # or use your preferred editor
```

### 3. Start ExaPG

The easiest way is using the interactive CLI:

```bash
./scripts/cli/exapg-cli.sh
```

Select option 1 for "ExaPG Standard" to start with a single-node deployment.

### 4. Verify Installation

Connect to the database:

```bash
docker exec -it exapg-coordinator psql -U postgres -d exadb
```

Run a test query:

```sql
SELECT version();
SELECT * FROM analytics.sensor_data LIMIT 5;
```

## First Steps

### Understanding the Interface

When you start the CLI, you'll see:

```
>>> E x a P G   v2.0.0 <<<

System Status:
- ExaPG Standard: ✗ Stopped
- Monitoring: ✗ Stopped
- Management UI: ✗ Stopped

Main Menu:
1) ExaPG Standard
2) ExaPG Citus
3) ExaPG HA
...
```

### Starting Your First Deployment

1. **For Development**: Choose "ExaPG Standard" (option 1)
   - Single PostgreSQL instance
   - All extensions included
   - Perfect for testing and development

2. **For Production Testing**: Choose "ExaPG Citus" (option 2)
   - Distributed architecture
   - 1 coordinator + 2 workers
   - Horizontal scaling capabilities

3. **For High Availability**: Choose "ExaPG HA" (option 3)
   - Primary/standby configuration
   - Automatic failover
   - Zero-downtime maintenance

### Monitoring Your Deployment

Enable monitoring to track performance:

```bash
# In the CLI, select option 4: Monitoring Stack
# Then choose "Start"
```

Access the dashboards:
- Grafana: http://localhost:3000 (admin/exapg_admin)
- Prometheus: http://localhost:9090

## Basic Usage

### Connecting to the Database

**Using psql:**
```bash
docker exec -it exapg-coordinator psql -U postgres -d exadb
```

**Using a GUI client:**
- Host: `localhost`
- Port: `5432`
- Username: `postgres`
- Password: `postgres`
- Database: `exadb`

### Running Your First Queries

ExaPG comes with sample data to explore:

```sql
-- Check available schemas
\dn

-- Explore time-series data
SELECT 
    date_trunc('hour', timestamp) as hour,
    AVG(value) as avg_value
FROM analytics.sensor_data
WHERE timestamp >= NOW() - INTERVAL '24 hours'
GROUP BY 1
ORDER BY 1;

-- Test columnar storage performance
SELECT 
    COUNT(*),
    SUM(amount),
    AVG(amount)
FROM analytics.sales
WHERE sale_date >= '2024-01-01';
```

### Creating Your First Table

```sql
-- Create a columnar table for analytics
CREATE TABLE my_analytics (
    id BIGSERIAL,
    event_time TIMESTAMPTZ NOT NULL,
    user_id INT,
    event_type TEXT,
    properties JSONB
) USING columnar;

-- Distribute it in cluster mode
SELECT create_distributed_table('my_analytics', 'user_id');
```

## Next Steps

### 1. Explore the Features

- **Columnar Storage**: [Learn about columnar tables](../columnar-storage.md)
- **Time-Series**: [Working with TimescaleDB](../data-integration.md)
- **Geospatial**: [Using PostGIS features](../data-integration.md)
- **Vector Search**: [ML with pgvector](../data-integration.md)

### 2. Run Performance Tests

```bash
# Run the benchmark suite
./benchmark-suite

# Or specific tests
./scripts/test-performance.sh medium
```

### 3. Set Up Production Features

- **Backups**: Configure pgBackRest
- **Monitoring**: Set up alerts in Grafana
- **Security**: Change default passwords
- **Optimization**: Tune for your workload

## Common Use Cases

### Data Warehousing

```sql
-- Create fact and dimension tables
CREATE TABLE fact_sales (...) USING columnar;
CREATE TABLE dim_customer (...);
CREATE TABLE dim_product (...);

-- Distribute for optimal joins
SELECT create_distributed_table('fact_sales', 'customer_id');
SELECT create_reference_table('dim_product');
```

### Real-Time Analytics

```sql
-- Create time-series hypertable
CREATE TABLE metrics (
    time TIMESTAMPTZ NOT NULL,
    device_id INT,
    metric NUMERIC
);

SELECT create_hypertable('metrics', 'time');
```

### Geospatial Analysis

```sql
-- Store location data
CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    name TEXT,
    location GEOMETRY(Point, 4326)
);

-- Find nearby points
SELECT name, ST_Distance(location, ST_MakePoint(-122.4, 37.8)) 
FROM locations 
ORDER BY location <-> ST_MakePoint(-122.4, 37.8) 
LIMIT 10;
```

## Getting Help

### Resources

- **Documentation**: [Complete docs index](../INDEX.md)
- **CLI Help**: Run with `--help` flag
- **Logs**: Check `docker-compose logs`

### Troubleshooting

**Container won't start:**
```bash
# Check Docker status
docker ps
systemctl status docker

# Check ports
netstat -tulpn | grep -E '5432|8080|3000|9090'
```

**Connection refused:**
```bash
# Verify container is running
docker-compose ps

# Check logs
docker-compose logs coordinator
```

**Performance issues:**
- Check resource allocation in `.env`
- Monitor with Grafana dashboards
- Review [Performance Tuning Guide](../performance-tuning.md)

### Community Support

- **Issues**: [GitHub Issues](https://github.com/DamienDrash/ExaPG/issues)
- **Discussions**: [GitHub Discussions](https://github.com/DamienDrash/ExaPG/discussions)
- **Contributing**: [Contribution Guide](../../CONTRIBUTING.md)

---

**Ready to dive deeper?** Check out our [Installation Guide](installation.md) for detailed setup options or explore the [Architecture Guide](../technical/architecture.md) to understand how ExaPG works under the hood. 