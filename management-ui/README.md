# Management UI - ExaPG

## Overview

The ExaPG Management UI provides a web-based interface for managing and monitoring your ExaPG deployment. It offers an intuitive dashboard for cluster management, performance monitoring, and administrative tasks.

## Features

- **Cluster Management**: Add, remove, and monitor nodes
- **Performance Dashboard**: Real-time metrics and statistics
- **User Management**: Create and manage database users and permissions
- **Query Monitor**: View active queries and performance statistics
- **Backup Management**: Schedule and monitor backups
- **Configuration Editor**: Modify database settings through the UI

## Installation

### Prerequisites

- ExaPG core installation
- Docker and Docker Compose
- Modern web browser (Chrome, Firefox, Safari, Edge)

### Quick Start

1. **Using ExaPG CLI**:
   ```bash
   ./scripts/cli/exapg-cli.sh
   # Select option 5: Management UI
   # Choose "Start"
   ```

2. **Direct Start**:
   ```bash
   ./start-management-ui.sh
   ```

3. **Access the UI**:
   - URL: http://localhost:8080
   - Default username: `admin`
   - Default password: `exapg_admin`

## Configuration

### Environment Variables

Configure the Management UI through `.env`:

```env
# Management UI Configuration
MANAGEMENT_UI_PORT=8080
MANAGEMENT_UI_HOST=0.0.0.0
MANAGEMENT_UI_ADMIN_USER=admin
MANAGEMENT_UI_ADMIN_PASSWORD=exapg_admin

# API Configuration
MANAGEMENT_API_PORT=8081
MANAGEMENT_API_TIMEOUT=30

# Security
MANAGEMENT_UI_SSL_ENABLED=false
MANAGEMENT_UI_SSL_CERT=/path/to/cert.pem
MANAGEMENT_UI_SSL_KEY=/path/to/key.pem
```

### Advanced Configuration

Create `config/management-ui.yml`:

```yaml
ui:
  theme: dark
  language: en
  session_timeout: 3600
  
api:
  rate_limit: 100
  cors_enabled: true
  allowed_origins:
    - http://localhost:3000
    
features:
  query_monitor: true
  backup_management: true
  user_management: true
  cluster_management: true
```

## Usage

### Dashboard Overview

The main dashboard displays:
- Cluster health status
- Resource utilization (CPU, memory, disk)
- Active connections
- Query performance metrics
- Recent alerts and notifications

### Cluster Management

1. **Add Worker Node**:
   - Navigate to Cluster → Nodes
   - Click "Add Node"
   - Enter node details
   - Click "Add to Cluster"

2. **Remove Worker Node**:
   - Select node from list
   - Click "Remove"
   - Confirm data migration

3. **Rebalance Cluster**:
   - Go to Cluster → Rebalance
   - Review shard distribution
   - Click "Start Rebalancing"

### User Management

1. **Create User**:
   ```sql
   -- Via UI: Users → Create New
   -- Enter username, password, permissions
   ```

2. **Manage Permissions**:
   - Select user
   - Choose database/schema
   - Assign permissions (SELECT, INSERT, UPDATE, DELETE)

### Query Monitor

View and manage active queries:
- Sort by duration, CPU usage, memory
- Kill long-running queries
- View query execution plans
- Export query statistics

### Backup Management

1. **Schedule Backup**:
   - Navigate to Backup → Schedule
   - Choose backup type (Full/Incremental)
   - Set schedule (cron format)
   - Configure retention policy

2. **Restore Database**:
   - Go to Backup → Restore
   - Select backup point
   - Choose restore options
   - Initiate restore process

## API/Interface

### REST API Endpoints

The Management UI exposes a REST API:

```bash
# Get cluster status
GET /api/v1/cluster/status

# Add worker node
POST /api/v1/cluster/nodes
{
  "hostname": "worker3",
  "port": 5432,
  "role": "worker"
}

# Get performance metrics
GET /api/v1/metrics/performance?period=1h

# User management
GET /api/v1/users
POST /api/v1/users
PUT /api/v1/users/{id}
DELETE /api/v1/users/{id}
```

### WebSocket Interface

Real-time updates via WebSocket:

```javascript
const ws = new WebSocket('ws://localhost:8080/api/v1/ws');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Metric update:', data);
};

// Subscribe to metrics
ws.send(JSON.stringify({
  action: 'subscribe',
  topics: ['metrics', 'alerts']
}));
```

## Architecture

```
┌─────────────────────┐
│   Web Browser       │
└──────────┬──────────┘
           │ HTTP/WS
┌──────────▼──────────┐
│   Frontend (React)  │
│  - Dashboard        │
│  - Components       │
│  - State Management │
└──────────┬──────────┘
           │ REST API
┌──────────▼──────────┐
│   Backend (Node.js) │
│  - Express Server   │
│  - WebSocket Server │
│  - Authentication   │
└──────────┬──────────┘
           │ SQL
┌──────────▼──────────┐
│   ExaPG Database    │
└─────────────────────┘
```

## Troubleshooting

### Common Issues

1. **Cannot Access UI**:
   ```bash
   # Check if container is running
   docker ps | grep management-ui
   
   # Check logs
   docker logs exapg-management-ui
   
   # Verify port binding
   netstat -tulpn | grep 8080
   ```

2. **Authentication Failed**:
   ```bash
   # Reset admin password
   docker exec -it exapg-management-ui npm run reset-password
   ```

3. **API Connection Error**:
   ```bash
   # Check API health
   curl http://localhost:8081/health
   
   # Verify database connection
   docker exec -it exapg-management-ui npm run test-db
   ```

### Debug Mode

Enable debug logging:

```env
# In .env
MANAGEMENT_UI_DEBUG=true
MANAGEMENT_UI_LOG_LEVEL=debug
```

### Performance Issues

1. **Slow Dashboard**:
   - Clear browser cache
   - Check network latency
   - Reduce metric update frequency

2. **High Memory Usage**:
   ```bash
   # Limit container memory
   docker update --memory=2g exapg-management-ui
   ```

## Development

### Local Development Setup

```bash
# Clone repository
git clone https://github.com/DamienDrash/ExaPG.git
cd ExaPG/management-ui

# Install dependencies
cd frontend && npm install
cd ../backend && npm install

# Start development servers
npm run dev
```

### Building from Source

```bash
# Build frontend
cd frontend
npm run build

# Build Docker image
docker build -t exapg/management-ui .
```

### Contributing

See [Contributing Guide](../CONTRIBUTING.md) for development guidelines.

## Security Considerations

1. **Change Default Credentials**: Always change default passwords
2. **Enable HTTPS**: Use SSL certificates in production
3. **Network Security**: Restrict access to management ports
4. **Authentication**: Enable two-factor authentication if available
5. **Audit Logging**: Review access logs regularly

## References

- [ExaPG Documentation](../docs/INDEX.md)
- [API Documentation](../docs/api/management-ui.md)
- [Security Guide](../docs/security.md)
- [Architecture Overview](../docs/technical/architecture.md) 