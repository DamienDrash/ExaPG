# ExaPG CLI Reference

An interactive terminal interface for managing the ExaPG environment.

## Overview

The ExaPG CLI replaces the multitude of separate start and stop scripts in the root directory with a unified, user-friendly interface. It provides an interactive menu for managing all ExaPG components and functions.

## Features

- **Unified Interface**: One central script for all operations instead of many separate scripts
- **Interactive Menu**: Easy navigation through various ExaPG functions
- **Component Management**: Start and stop individual components or the entire environment
- **Status Control**: Clear display of runtime status for all components
- **Configuration Management**: Direct access to configuration files
- **Modern UI**: Visually appealing terminal interface with colors and frames
- **System Information**: Display of relevant system information and current configuration
- **Component-specific Menus**: Simple management of individual components

## Getting Started

### Quick Start

```bash
# Start the interactive CLI
./scripts/cli/exapg-cli.sh

# Or use the symbolic link (if created)
./exapg
```

### First Launch

The CLI displays a modern interface showing:
- ExaPG ASCII logo
- Current system status
- Available components and their states
- Interactive menu options

## Main Menu Options

### Core Components

1. **ExaPG Standard** - Start/stop the standard ExaPG environment
2. **ExaPG Citus** - Start/stop distributed database with Citus extension
3. **ExaPG HA** - Start/stop high availability configuration
4. **Monitoring Stack** - Start/stop Prometheus/Grafana monitoring
5. **Management UI** - Start/stop web-based administration interface

### Specialized Components

6. **UDF Framework** - Start/stop environment for user-defined functions
7. **Virtual Schemas** - Start/stop Foreign Data Wrappers
8. **ETL Tools** - Start/stop ETL processing environment
9. **Backup Tools** - Start/stop backup environment

### Utility Options

- **c**: Configure system (system-wide configuration)
- **s**: Show detailed status
- **e**: Edit configuration settings (.env file)
- **x**: Stop all components
- **q**: Quit

## Component Menus

When a component is selected, a context-sensitive menu is displayed:

### For Active Components
- **Stop**: Stops the component
- **Restart**: Stops and restarts the component
- **Configure**: Opens configuration wizard for the component

### For Inactive Components
- **Start**: Starts the component
- **Configure and Start**: Configures the component and then starts it

## Enhanced Features

The modernized CLI offers the following improvements over the original version:

### 1. Improved User Interface
- Colored output for better readability
- Frames and tables for structured display
- ASCII art logo for professional appearance

### 2. Component Status at a Glance
- Automatically shows which components are active at startup
- Colored status indicators (green for active, red for inactive)

### 3. Extended Configuration Options
- Interactive wizards for configuring each component
- Ability to change configurations and restart components

### 4. Detailed System Information
- Shows CPU, RAM, and disk usage
- Current configuration settings at a glance

### 5. Improved Startup Behavior
- Interface shows current status before executing actions
- Options to start/stop based on current state

## Usage Examples

### Starting ExaPG for Development

```bash
./scripts/cli/exapg-cli.sh
# Select option 1: ExaPG Standard
# Choose "Start" if not running
```

### Setting up Monitoring

```bash
./scripts/cli/exapg-cli.sh
# Select option 4: Monitoring Stack
# Choose "Configure and Start" for first-time setup
```

### Checking System Status

```bash
./scripts/cli/exapg-cli.sh
# Select option "s": Show detailed status
# View comprehensive system information
```

## Configuration Management

### Environment Variables

The CLI provides easy access to configuration:

```bash
# Edit .env file through CLI
./scripts/cli/exapg-cli.sh
# Select option "e": Edit configuration settings
```

### Component-Specific Configuration

Each component can be configured individually:

1. Select the component from the main menu
2. Choose "Configure" option
3. Follow the interactive wizard
4. Restart the component to apply changes

## Benefits

1. **Simplified Operation**: No need to remember multiple script names
2. **Reduced Error Potential**: Guided user interaction instead of manual script execution
3. **Better Overview**: Clear overview of all component statuses
4. **Easier Maintenance**: One central script instead of many separate files

## Technical Details

### Architecture

The CLI uses the existing Docker Compose configurations in the background but provides a unified interface for their management. It automatically checks prerequisites and displays detailed error and status messages.

### File Structure

```
scripts/cli/
├── exapg-cli.sh              # Main CLI script
├── exapg-cli-functions.sh    # CLI helper functions
├── terminal-ui.sh            # Terminal UI framework
├── migration.sh              # Migration from old scripts
└── install-completion.sh     # Bash completion installer
```

## Migration from Old Scripts

### Replaced Scripts

This CLI replaces the following scripts in the root directory:

**Start Scripts:**
- `start-exapg.sh`
- `start-exapg-citus.sh`
- `start-exapg-fdw.sh`
- `start-exapg-ha.sh`
- `start-exapg-udf-framework.sh`
- `start-exapg-virtual-schemas.sh`
- `start-exapg-etl.sh`
- `start-backup.sh`
- `start-cluster-management.sh`
- `start-management-ui.sh`
- `start-monitoring.sh`

**Stop Scripts:**
- `stop-backup.sh`
- `stop-cluster-management.sh`
- `stop-exapg-etl.sh`
- `stop-exapg-ha.sh`
- `stop-exapg-udf-framework.sh`
- `stop-exapg-virtual-schemas.sh`
- `stop-management-ui.sh`
- `stop-monitoring.sh`

### Migration Process

For a smooth migration from old start and stop scripts, ExaPG provides a migration script:

```bash
./scripts/cli/migration.sh
```

This script:
1. Backs up all existing start and stop scripts to `scripts/setup/`
2. Replaces scripts with symbolic links to the new CLI
3. Redirects users to the new CLI if they accidentally use old script names

## Installation

### Standard Installation

Set the CLI scripts executable:

```bash
chmod +x scripts/cli/exapg-cli.sh
chmod +x scripts/cli/exapg-cli-functions.sh
```

Optionally create a symbolic link for easy access:

```bash
ln -sf scripts/cli/exapg-cli.sh exapg
```

### Bash Completion

For an improved user experience, Bash completion for ExaPG commands can be activated:

```bash
./scripts/cli/install-completion.sh
```

After installation, you can use TAB completion for ExaPG commands.

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   chmod +x scripts/cli/exapg-cli.sh
   ```

2. **Docker Not Running**
   - Start Docker Desktop or Docker daemon
   - Verify with `docker ps`

3. **Port Conflicts**
   - Check which ports are in use
   - Modify configuration in `.env` file

### Getting Help

- Use option "s" in the CLI for detailed status
- Check logs through the CLI's log viewing options
- Refer to the main [README.md](README.md) for comprehensive documentation

## Advanced Usage

### Scripting with CLI

The CLI can be used in scripts by providing environment variables:

```bash
# Non-interactive mode
EXAPG_COMPONENT=standard EXAPG_ACTION=start ./scripts/cli/exapg-cli.sh
```

### Custom Configurations

Create component-specific configuration files:

```bash
config/
├── exapg-standard.env
├── exapg-citus.env
└── exapg-monitoring.env
```

The CLI will automatically detect and use these configurations.

---

**Related Documentation:**
- [Main README](../../README.md) - Complete project overview
- [Architecture Guide](../technical/architecture.md) - System architecture
- [Contributing Guide](../../CONTRIBUTING.md) - Development guidelines 