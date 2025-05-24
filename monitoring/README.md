# Monitoring Stack - ExaPG

## Overview

The ExaPG Monitoring Stack provides comprehensive monitoring and alerting for your ExaPG deployment using industry-standard tools. It includes Prometheus for metrics collection, Grafana for visualization, and Alertmanager for alert handling.

## Features

- **Real-time Metrics**: Collect and store performance metrics from all ExaPG components
- **Pre-built Dashboards**: Professional Grafana dashboards for immediate insights
- **Automated Alerting**: Proactive alerts for performance issues and failures
- **Historical Analysis**: Long-term metric storage for trend analysis
- **Multi-node Support**: Monitor single-node and cluster deployments
- **Custom Metrics**: Extensible framework for application-specific metrics

## Installation

### Prerequisites

- ExaPG core installation
- Docker and Docker Compose
- 2GB+ RAM for monitoring stack
- 10GB+ disk space for metric storage

### Quick Start

1. **Using ExaPG CLI**:
   ```bash
   ./scripts/cli/exapg-cli.sh
   # Select option 4: Monitoring Stack
   # Choose "Start"
   ```

2. **Direct Start**:
   ```bash
   ./start-monitoring.sh
   ```

3. **Access Dashboards**:
   - Grafana: http://localhost:3000 (admin/exapg_admin)
   - Prometheus: http://localhost:9090
   - Alertmanager: http://localhost:9093

## Configuration

### Environment Variables

Configure monitoring through `.env`:

```env
# Grafana Configuration
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=exapg_admin
GRAFANA_ALLOW_ANONYMOUS=false

# Prometheus Configuration
PROMETHEUS_PORT=9090
PROMETHEUS_RETENTION_TIME=15d
PROMETHEUS_RETENTION_SIZE=10GB

# Alertmanager Configuration
ALERTMANAGER_PORT=9093
ALERTMANAGER_SMTP_HOST=smtp.gmail.com:587
ALERTMANAGER_SMTP_FROM=exapg-alerts@example.com
```

### Prometheus Configuration

Edit `monitoring/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres_exporter:9187']
    
  - job_name: 'node'
    static_configs:
      - targets: ['node_exporter:9100']
```

### Alert Rules

Configure alerts in `monitoring/prometheus/alert_rules.yml`:

```yaml
groups:
  - name: database
    rules:
      - alert: HighConnectionCount
        expr: pg_stat_database_numbackends > 100
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High connection count on {{ $labels.instance }}"
```

## Usage

### Accessing Grafana

1. Navigate to http://localhost:3000
2. Login with admin credentials
3. Select from pre-built dashboards:
   - **ExaPG Overview**: System health and resource usage
   - **ExaPG Analytics**: Query performance and workload analysis
   - **ExaPG Cluster**: Multi-node cluster monitoring

### Dashboard Features

**ExaPG Overview Dashboard**:
- Database connections and activity
- CPU, memory, and disk usage
- Transaction rates and query performance
- Cache hit ratios and buffer usage

**ExaPG Analytics Dashboard**:
- Query execution times
- Top queries by duration
- Index usage statistics
- Table size and growth trends

**ExaPG Cluster Dashboard**:
- Node health status
- Data distribution across nodes
- Replication lag monitoring
- Network traffic between nodes

### Creating Custom Dashboards

1. Click "+" → "Create Dashboard"
2. Add panels with PostgreSQL metrics:
   ```
   # Example queries
   rate(pg_stat_database_xact_commit[5m])
   pg_stat_database_numbackends
   pg_stat_user_tables_n_tup_ins
   ```

### Setting Up Alerts

1. **Email Notifications**:
   ```yaml
   # alertmanager/alertmanager.yml
   global:
     smtp_smarthost: 'smtp.gmail.com:587'
     smtp_from: 'exapg@example.com'
     smtp_auth_username: 'username'
     smtp_auth_password: 'password'
   ```

2. **Webhook Integration**:
   ```yaml
   receivers:
     - name: 'webhook'
       webhook_configs:
         - url: 'http://example.com/alerts'
   ```

## API/Interface

### Prometheus API

Query metrics programmatically:

```bash
# Instant query
curl 'http://localhost:9090/api/v1/query?query=up'

# Range query
curl 'http://localhost:9090/api/v1/query_range?query=rate(pg_stat_database_xact_commit[5m])&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z&step=15s'
```

### Grafana API

Manage dashboards and alerts:

```bash
# Get all dashboards
curl -H "Authorization: Bearer $API_KEY" http://localhost:3000/api/search

# Export dashboard
curl -H "Authorization: Bearer $API_KEY" http://localhost:3000/api/dashboards/uid/exapg-overview
```

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   PostgreSQL    │────▶│ Postgres        │
│   Cluster       │     │ Exporter        │
└─────────────────┘     └────────┬────────┘
                                 │
┌─────────────────┐     ┌────────▼────────┐     ┌─────────────────┐
│   Node          │────▶│   Prometheus    │────▶│    Grafana      │
│   Exporter      │     │                 │     │                 │
└─────────────────┘     └────────┬────────┘     └─────────────────┘
                                 │
                        ┌────────▼────────┐
                        │  Alertmanager   │
                        └─────────────────┘
```

## Troubleshooting

### Common Issues

1. **Grafana Login Failed**:
   ```bash
   # Reset admin password
   docker exec -it exapg-grafana grafana-cli admin reset-admin-password newpassword
   ```

2. **No Metrics in Prometheus**:
   ```bash
   # Check exporter status
   curl http://localhost:9187/metrics  # postgres_exporter
   curl http://localhost:9100/metrics  # node_exporter
   
   # Verify Prometheus targets
   curl http://localhost:9090/api/v1/targets
   ```

3. **Dashboards Not Loading**:
   ```bash
   # Check Grafana logs
   docker logs exapg-grafana
   
   # Verify data source connection
   docker exec -it exapg-grafana curl http://prometheus:9090/api/v1/query?query=up
   ```

### Performance Optimization

1. **Reduce Metric Retention**:
   ```env
   PROMETHEUS_RETENTION_TIME=7d
   ```

2. **Adjust Scrape Intervals**:
   ```yaml
   global:
     scrape_interval: 30s  # Increase for lower load
   ```

3. **Optimize Queries**:
   - Use recording rules for complex queries
   - Limit time ranges in dashboards
   - Use appropriate aggregation functions

## Development

### Adding Custom Exporters

```yaml
# docker-compose.monitoring.yml
services:
  custom_exporter:
    image: custom/exporter:latest
    ports:
      - "9999:9999"
    networks:
      - exapg_monitoring
```

### Creating Custom Dashboards

```json
{
  "dashboard": {
    "title": "Custom ExaPG Dashboard",
    "panels": [
      {
        "title": "Custom Metric",
        "targets": [
          {
            "expr": "custom_metric_name"
          }
        ]
      }
    ]
  }
}
```

## Security Considerations

1. **Change Default Passwords**: Update all default credentials
2. **Network Security**: Restrict access to monitoring ports
3. **HTTPS Configuration**: Enable SSL for Grafana
4. **API Key Management**: Use API keys instead of basic auth
5. **Data Retention**: Configure appropriate retention policies

## References

- [ExaPG Documentation](../docs/INDEX.md)
- [Monitoring Guide](../docs/monitoring.md)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/) 