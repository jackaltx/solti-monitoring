# InfluxDB Ansible Role

## Overview

This role installs and configures [InfluxDB v2.x](https://www.influxdata.com/products/influxdb/), a purpose-built time series database optimized for fast, high-availability storage and retrieval of time series data. InfluxDB serves as the metrics storage component in the monitoring stack, providing a powerful query engine and efficient storage mechanism.

InfluxDB v2.x features a new storage engine and completely redesigned API compared to v1.x, with built-in authentication, bucket-based organization, and the powerful Flux query language.

## Features

- Installs and configures InfluxDB v2.x from official InfluxData repositories
- Manages InfluxDB service lifecycle (start/stop/restart)
- Configures storage paths and engine options
- Handles initial database setup and user configuration
- Sets up buckets, tokens, and organizations
- Supports both local disk and S3-compatible object storage
- Includes utility scripts for easy deployment and verification
- Prepares for future upgrade path to InfluxDB v3.x with tiered storage

## Requirements

### Platform Support

- Debian/Ubuntu systems (using `apt` package manager)
- RedHat-based systems (Rocky Linux, RHEL)
- Systemd-based systems

### Prerequisites

- Systemd-based operating system
- Network connectivity for client access
- InfluxData package repository access
- S3 credentials (if using object storage)

## Role Variables

### Main Control Variables

```yaml
# Installation state
influxdb_state: "present"          # Use 'absent' to remove InfluxDB

# Logging level
influxdb_level: info               # Logging level

# Database organization and bucket
influxdb_org: "myorg"              # Organization name
influxdb_bucket: "telegraf"        # Default bucket name
influxdb_username: "username"      # Admin username
influxdb_password: "generated"     # Admin password (will be randomly generated if set to "generated")

# Storage configuration 
influxdb_data_path: "/var/lib/influxdb"   # Path to store InfluxDB data

# Reinstallation flags
influxdb_force_reload: false       # Force reinstallation
influxdb_force_configure: false    # Force reconfiguration

# Security configuration
influxdb_cert: ""                  # Path to SSL certificate
influxdb_key: ""                   # Path to SSL private key

# Uninstallation options
influxdb_delete_config: false      # Remove config files on uninstall
influxdb_delete_data: false        # Remove data directory on uninstall

# Integration with Telegraf
influxdb_operators_token: ""       # Token for operator access
```

### S3 Storage Variables

For S3 storage configuration (using environment variables):

```yaml
# S3 storage configuration
influxdb_s3: false                 # Enable S3 storage
influxdb_s3_access_key: ""         # S3 access key
influxdb_s3_secret_key: ""         # S3 secret key
influxdb_s3_bucket: ""             # S3 bucket name
```

## Installation and Initialization

The role performs these key setup tasks:

1. **Package Installation**: Installs InfluxDB v2.x from official repositories
2. **Storage Configuration**: Sets up the storage engine paths
3. **Initial Setup**: Initializes the database with organization, user, and bucket
4. **Token Management**: Creates and stores authentication tokens
5. **Bucket Creation**: Sets up configured buckets with appropriate retention policies

## Storage Configuration

### Local Disk Storage (Default)

By default, InfluxDB uses local filesystem storage:

```yaml
influxdb_data_path: "/var/lib/influxdb"
```

The role configures these key storage components:

- BoltDB path: `{{influxdb_data_path}}/influxd.bolt` (metadata)
- Engine path: `{{influxdb_data_path}}/engine` (time series data)

### S3 Configuration

For S3-compatible object storage, configure:

```yaml
influxdb_s3: true
influxdb_s3_access_key: "ACCESS_KEY"
influxdb_s3_secret_key: "SECRET_KEY"
influxdb_s3_bucket: "influxdb-data"
```

These settings are passed to InfluxDB via environment variables for secure credentials management.

### Future v3.x Tiered Storage Support

This role is designed with the upgrade path to InfluxDB v3.x in mind, which will support tiered storage:

- **Hot Tier**: Local disk for recent, frequently accessed data
- **Cold Tier**: S3 storage for historical, less frequently accessed data

When v3.x becomes available, this role will be updated to support configuring tiered storage policies while maintaining backward compatibility.

## Usage Examples

### Basic Installation with Disk Storage

```yaml
- hosts: metrics_servers
  roles:
    - role: influxdb
      vars:
        influxdb_org: "mycompany"
        influxdb_bucket: "metrics"
        influxdb_username: "admin"
```

### Using the Utility Scripts

The included utility scripts make deploying and managing InfluxDB simpler:

```bash
# Deploy InfluxDB using the management script
./manage-svc influxdb deploy

# Verify InfluxDB is working correctly
./svc-exec influxdb verify

# Deploy to a specific host
./manage-svc -h dbserver01 influxdb deploy
```

### Configuration with S3 Storage

```yaml
- hosts: metrics_servers
  roles:
    - role: influxdb
      vars:
        influxdb_org: "mycompany"
        influxdb_bucket: "metrics"
        influxdb_s3: true
        influxdb_s3_access_key: "{{ vault_influxdb_s3_access_key }}"
        influxdb_s3_secret_key: "{{ vault_influxdb_s3_secret_key }}"
        influxdb_s3_bucket: "influxdb-storage"
```

### Removal Configuration

```yaml
- hosts: metrics_servers
  roles:
    - role: influxdb
      vars:
        influxdb_state: 'absent'
        influxdb_delete_config: true
        influxdb_delete_data: true
```

## Integration with the Monitoring Stack

InfluxDB serves as the metrics storage component in a complete monitoring stack:

1. **Telegraf** collects and forwards metrics to InfluxDB
2. **InfluxDB** stores and provides query capabilities for metrics
3. **Grafana** provides visualization and dashboard capabilities

The role automatically creates tokens for integration with Telegraf, making setup seamless.

## Generated Configuration Files

The role creates several important files:

- **Configuration**: `/etc/influxdb/config.toml`
- **Environment Variables**: `/etc/default/influxdb2`
- **Tokens File**: `influx-tokens-{hostname}.yml` in the playbook's data directory
- **Web UI Credentials**: `influx-webui-access-{hostname}.txt` in the playbook's data directory

## Accessing InfluxDB

The role generates credentials for accessing InfluxDB:

- **Web UI**: Available at `http://<server>:8086`
- **CLI**: Use the generated token with `influx` commands
- **API Access**: Use the operator token for programmatic access

## Directory Structure

```
influxdb/
├── defaults/
│   └── main.yml                 # Default variables
├── handlers/
│   └── main.yml                # Service handlers
├── meta/
│   └── main.yml               # Role metadata
├── molecule/                  # Testing configuration
├── tasks/
│   ├── main.yml              # Main tasks
│   ├── initializedb.yml      # Database initialization
│   └── influxdb-setup-systemd.yml # Systemd configuration
├── templates/
│   ├── config.toml.j2        # Configuration template
│   └── etc-default-influxdb.j2 # Environment configuration
└── README.md                  # This file
```

## Troubleshooting

Common issues and solutions:

1. **Service fails to start**
   - Check logs with `journalctl -u influxdb`
   - Verify configuration with `influxd config`
   - Use the verification script: `./svc-exec influxdb verify`

2. **Cannot connect to database**
   - Verify the service is running: `systemctl status influxdb`
   - Check firewall rules for port 8086
   - Verify TLS configuration if using HTTPS

3. **Authentication issues**
   - Check token validity with `influx auth list`
   - Verify you're using the correct organization
   - Review the generated credentials file

4. **Storage problems**
   - For disk storage: check disk space and permissions
   - For S3: verify endpoint, credentials, and bucket existence

5. **Need to quickly reinstall the service**
   - Use the management script: `./manage-svc influxdb remove && ./manage-svc influxdb deploy`

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
# Deploy InfluxDB to default hosts
./manage-svc influxdb deploy

# Remove InfluxDB from a specific host
./manage-svc -h dbserver01 influxdb remove
```

### svc-exec.sh

This script executes specific tasks within a role for targeted operations like verification or configuration.

```bash
Usage: svc-exec [-K] [-h HOST] <service> [entry]

Options:
  -K        - Prompt for sudo password (needed for some operations)
  -h HOST   - Target specific host from inventory

Parameters:
  service   - The service to manage
  entry     - The entry point task (default: verify)
```

**Examples:**

```bash
# Run verification tasks for InfluxDB on default hosts
./svc-exec influxdb verify

# Initialize the database on a particular host
./svc-exec -K -h dbserver01 influxdb initializedb
```

## Performance Considerations

### Hardware Recommendations

Minimum recommended specifications:

- 4 CPU cores
- 8GB RAM
- Fast disk for local storage (SSD preferred)
- High-throughput network for remote clients

### Scaling Considerations

InfluxDB v2.x is designed as a single-node solution. For horizontal scaling:

- Use multiple buckets with different retention policies
- Consider using InfluxDB Cloud for truly distributed deployments
- Plan for future migration to InfluxDB v3.x for improved clustering support

## Security Considerations

- The role configures InfluxDB with appropriate file permissions
- Tokens are generated with least-privilege access
- SSL/TLS can be enabled for secure communication
- S3 credentials are managed via environment variables
- Passwords can be generated or specified securely
- Token files are stored with restricted permissions

## Upgrade Path to v3.x

InfluxDB v3.x is expected to introduce:

- Improved clustering and high availability
- Tiered storage (hot/cold) for optimized storage economics
- Enhanced query performance and capabilities

This role is designed with future upgradability in mind, creating configuration that can be easily migrated to v3.x when it becomes available.

## License

MIT

## Author Information

Created and maintained by Jack Lavender.
