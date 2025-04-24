# Alloy Ansible Role

## Overview

This Ansible role installs and configures [Grafana Alloy](https://grafana.com/docs/alloy/latest/), a vendor-neutral distribution of the OpenTelemetry (OTel) Collector that provides a unified way to collect and process observability data from various sources and forward it to different backends.

Alloy streamlines the collection of logs, metrics, and traces with consistent configuration across multiple observability signals. This role primarily focuses on log collection and forwarding to Loki, but is extensible for other use cases.

## Features

- Installs and configures Alloy from official Grafana repositories
- Manages Alloy service lifecycle (start/stop/restart)
- Configures log sources including systemd journal, files, and application logs
- Configures multiple pipelines for custom log processing
- Supports sending data to multiple Loki endpoints
- Includes utility scripts for easy deployment and verification
- Includes pre-configured templates for common applications:
  - Apache web server
  - Fail2ban
  - Bind9 DNS server
  - Mail services (Postfix/Dovecot)
  - WireGuard VPN
  - Gitea
  - ISPConfig

## Requirements

### Platform Support

- Debian/Ubuntu systems (using `apt` package manager)
- RedHat-based systems (Rocky Linux, RHEL) via shared configuration
- Systemd-based systems

### Prerequisites

- Systemd-based operating system
- Network connectivity to Loki endpoint(s)
- Grafana package repository access

## Role Variables

### Main Control Variables

```yaml
# Installation state
alloy_state: "present"                # Use 'absent' to remove Alloy

# Service configuration
alloy_custom_args: "--disable-reporting --server.http.listen-addr=0.0.0.0:12345"

# Configuration path
alloy_config: "/etc/alloy/config.alloy"

# Uninstallation options
alloy_delete_config: false            # Remove config files on uninstall
alloy_delete_data: false              # Remove data files on uninstall
```

### Endpoint Configuration

```yaml
# Loki endpoints - REQUIRED
alloy_loki_endpoints:
  - label: localhost                  # Label for the endpoint (used in configuration)
    endpoint: "127.0.0.1"            # Loki server IP/hostname
```

### Log Source Configuration

```yaml
# Enable specific log collection modules
alloy_monitor_apache: false           # Apache logs
alloy_monitor_ispconfig: false        # ISPConfig logs
alloy_monitor_fail2ban: false         # Fail2ban logs
alloy_monitor_mail: false             # Mail server logs
alloy_monitor_bind9: false            # Bind9 logs
alloy_monitor_wg: false               # WireGuard logs
alloy_monitor_gitea: false            # Gitea logs
```

## Installation

The role uses the official Grafana package repositories to install Alloy. It also configures the systemd service and manages necessary directories with appropriate permissions.

## Configuration

The role takes a template-based approach to configuration, allowing you to easily enable or disable specific log collection modules based on your needs. The main configuration file is generated from templates that include:

1. Core configuration for log processing
2. Specific log sources based on enabled modules
3. Output configuration for Loki endpoints

## Usage Examples

### Basic Installation

```yaml
- hosts: servers
  roles:
    - role: alloy
      vars:
        alloy_loki_endpoints:
          - label: local_loki
            endpoint: "127.0.0.1"
```

### Using the Utility Scripts

The included utility scripts make deploying and managing Alloy simpler:

```bash
# Deploy Alloy using the management script
./manage-svc alloy deploy

# Verify Alloy is working correctly
./svc-exec alloy verify

# Deploy to a specific host
./manage-svc -h monitoring01 alloy deploy
```

### Comprehensive Configuration

```yaml
- hosts: web_servers
  roles:
    - role: alloy
      vars:
        alloy_loki_endpoints:
          - label: main_loki
            endpoint: "loki.example.com"
          - label: backup_loki
            endpoint: "backup-loki.example.com"
        
        # Enable specific log collection
        alloy_monitor_apache: true
        alloy_monitor_fail2ban: true
        
        # Custom listening address
        alloy_custom_args: "--disable-reporting --server.http.listen-addr=0.0.0.0:3100"
```

### Removal Configuration

```yaml
- hosts: servers
  roles:
    - role: alloy
      vars:
        alloy_state: 'absent'
        alloy_delete_config: true
        alloy_delete_data: true
```

## Log Processing Capabilities

### Journal Processing

Alloy is configured to collect logs from the systemd journal with enriched metadata:

- Priority levels
- Unit information
- Transport metadata
- Hostname labels

### File-Based Log Processing

The role can process various log files with specialized parsing:

**Apache Logs:**

- Access logs with detailed request information
- Error logs with enhanced error categorization
- ModSecurity integration
- PHP error parsing

**Bind9 DNS Logs:**

- Zone operations
- Query information
- DNSSEC operations
- Transfer logs
- Security events

**Fail2ban Logs:**

- Jail information
- Action categorization
- Ban/Unban events

**Mail Server Logs:**

- Authentication events
- Connection information
- Delivery status
- Error tracking

**WireGuard Logs:**

- Connection establishment
- Peer activity
- Handshake information
- Error tracking

### Advanced Parsing Features

- Multi-line log support
- Regular expression-based field extraction
- Label enrichment
- Filtering and dropping of noisy events
- Error categorization
- Security incident tracking

## Directory Structure

```
alloy/
├── defaults/
│   └── main.yml                 # Default variables
├── files/
│   ├── apache-error.alloy       # Example configurations
│   ├── claude-two-outputs.alloy
│   └── grafana.list
├── handlers/
│   └── main.yml                # Service handlers
├── meta/
│   └── main.yml               # Role metadata
├── molecule/                  # Testing configuration
├── tasks/
│   ├── main.yml              # Main tasks
│   └── verify.yml            # Verification tasks
├── templates/
│   ├── client-config-alloy.j2  # Main template
│   ├── etc-default-alloy.j2    # Environment configuration
│   ├── apache-logs.alloy.j2    # Module templates
│   ├── fail2ban.alloy.j2
│   └── ...                     # Other module templates
└── README.md                   # This file
```

## Handlers

The role includes the following handlers:

- `Restart alloy`: Restarts the Alloy service when configuration changes

## Testing

The role includes Molecule tests for:

- Basic installation
- Configuration verification
- Service status checks
- Log collection functionality

## Security Considerations

- The role configures Alloy with appropriate file permissions
- Service runs as its own user
- Configuration is validated before restarting the service
- Label filtering to remove sensitive information
- Optional dropping of connection data for privacy

## Troubleshooting

Common issues and solutions:

1. **Service fails to start**
   - Check logs with `journalctl -u alloy`
   - Verify configuration with `alloy --config.file /etc/alloy/config.alloy --config.expand-env --config.check`
   - Use the verification script: `./svc-exec alloy verify`

2. **No logs being collected**
   - Verify Loki endpoint is correct and accessible
   - Check network connectivity to Loki endpoint
   - Verify file paths and permissions
   - Use `./svc-exec alloy verify1` for deeper connection checks

3. **High CPU/memory usage**
   - Check for excessive log volume
   - Verify filtering is properly configured
   - Consider increasing system resources

4. **Need to quickly reinstall the service**
   - Use the management script: `./manage-svc alloy remove && ./manage-svc alloy deploy`

5. **Connection to Loki failing**
   - Verify network connectivity: `ss -ntp '( dst = :3100 )'`
   - Check Loki service is running properly
   - Use `./svc-exec -K alloy verify` to run comprehensive checks

## License

MIT

## Utility Scripts

This role can be easily managed using the following utility scripts included in the project:

### manage-svc.sh

This script helps manage service deployment states using dynamically generated Ansible playbooks.

```bash
Usage: manage-svc [-h HOST] <service> <action>

Options:
  -h HOST    Target host from inventory (default: uses hosts defined in role)

Services:
  - loki
  - alloy
  - influxdb
  - telegraf

Actions:
  - prepare
  - deploy
  - install  # Alias for deploy
  - remove
```

**Examples:**

```bash
# Deploy Alloy to default hosts
./manage-svc alloy deploy

# Remove Alloy from a specific host
./manage-svc -h monitoring01 alloy remove

# Install Influxdb on a specific host
./manage-svc -h dbserver01 influxdb install
```

### svc-exec.sh

This script executes specific tasks within a role for targeted operations like verification, configuration, or testing.

```bash
Usage: svc-exec [-K] [-h HOST] <service> [entry]

Options:
  -K        - Prompt for sudo password (needed for some operations)
  -h HOST   - Target specific host from inventory

Parameters:
  service   - The service to manage
  entry     - The entry point task (default: verify)

Services:
  - loki
  - alloy
  - influxdb
  - telegraf
  
Common Entry Points:
  - verify     - Basic service verification
  - configure  - Configure service
  - verify1    - Additional verification tasks
```

**Examples:**

```bash
# Run verification tasks for Alloy on default hosts
./svc-exec alloy verify

# Run specific verification task on a particular host
./svc-exec -h monitoring01 alloy verify1

# Configure Alloy with sudo privileges
./svc-exec -K alloy configure
```

These scripts provide a convenient way to manage the lifecycle and perform specific operations on the Alloy role and other related services without having to manually create playbooks.

## Author Information

Created by Jack Lavender with assistance from Anthropic's Claude. Extended by the community.
