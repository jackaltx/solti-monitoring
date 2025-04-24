# Loki Ansible Role

## Overview

This role installs and configures [Grafana Loki](https://grafana.com/oss/loki/), a horizontally-scalable, highly-available log aggregation system inspired by Prometheus. Loki is designed to be cost-effective and easy to operate, as it does not index the contents of the logs, but rather a set of labels for each log stream.

## Features

- Installs and configures Loki from official Grafana repositories
- Manages Loki service lifecycle (start/stop/restart)
- Supports flexible storage backends:
  - Local filesystem storage (default)
  - Network File System (NFS) mounts
  - S3-compatible object storage (MinIO, QNAP QuObject, AWS S3)
- Configurable retention and compaction settings
- Includes utility scripts for easy deployment and verification
- Works seamlessly with Grafana Alloy as a log collector

## Requirements

### Platform Support

- Debian/Ubuntu systems (using `apt` package manager)
- RedHat-based systems (Rocky Linux, RHEL) via shared configuration
- Systemd-based systems

### Prerequisites

- Systemd-based operating system
- Network connectivity for client access
- Grafana package repository access
- S3 credentials (if using object storage)

## Role Variables

### Main Control Variables

```yaml
# Installation state
loki_state: present              # Use 'absent' to remove Loki

# Storage selection
loki_local_storage: true         # Use local filesystem storage

# Uninstallation options
loki_force_reload: false         # Force reinstallation
loki_delete_config: false        # Remove config files on uninstall
loki_delete_data: false          # Remove data files on uninstall
```

### S3 Storage Configuration

When `loki_local_storage` is set to `false`, these variables configure S3 storage:

```yaml
# S3 configuration (only needed when loki_local_storage: false)
loki_endpoint: ""                # S3 endpoint URL
loki_s3_bucket: ""               # S3 bucket name
loki_key_id: ""                  # S3 access key ID
loki_access_key: ""              # S3 secret access key
```

## Installation

The role uses the official Grafana package repositories to install Loki. It also configures the systemd service and manages necessary directories with appropriate permissions.

## Storage Configuration

### Local Storage (Default)

By default, Loki is configured to use local filesystem storage:

```yaml
loki_local_storage: true
```

This setting:

- Stores chunks in `/var/lib/loki/chunks`
- Stores rules in `/var/lib/loki/rules`
- Provides best performance for single-node deployments
- Simplifies setup with no additional dependencies

### S3-Compatible Object Storage

For distributed deployments or long-term storage, configure S3-compatible storage:

```yaml
loki_local_storage: false
loki_endpoint: "s3.example.com"
loki_s3_bucket: "loki-logs"
loki_key_id: "ACCESS_KEY_ID"
loki_access_key: "SECRET_ACCESS_KEY"
```

This configuration works with:

- AWS S3
- MinIO
- QNAP QuObject
- Any S3-compatible storage service

### NFS Storage Considerations

When using NFS for storage:

1. Mount the NFS share before installing Loki
2. Configure local storage to use the NFS mount point
3. Ensure proper permissions on the NFS mount

## Usage Examples

### Basic Installation with Local Storage

```yaml
- hosts: log_servers
  roles:
    - role: loki
      vars:
        loki_local_storage: true
```

### Using the Utility Scripts

The included utility scripts make deploying and managing Loki simpler:

```bash
# Deploy Loki using the management script
./manage-svc loki deploy

# Verify Loki is working correctly
./svc-exec loki verify

# Deploy to a specific host
./manage-svc -h logserver01 loki deploy
```

### Configuration with S3 Storage

```yaml
- hosts: log_servers
  roles:
    - role: loki
      vars:
        loki_local_storage: false
        loki_endpoint: "minio.example.com"
        loki_s3_bucket: "loki-logs"
        loki_key_id: "{{ vault_loki_key_id }}"
        loki_access_key: "{{ vault_loki_access_key }}"
```

### Removal Configuration

```yaml
- hosts: log_servers
  roles:
    - role: loki
      vars:
        loki_state: 'absent'
        loki_delete_config: true
        loki_delete_data: true
```

## Directory Structure

```
loki/
├── defaults/
│   └── main.yml                 # Default variables
├── files/
│   └── config-working.yml       # Reference configuration
├── handlers/
│   └── main.yml                # Service handlers
├── meta/
│   └── main.yml               # Role metadata
├── molecule/                  # Testing configuration
├── tasks/
│   ├── main.yml              # Main tasks
│   └── verify.yml            # Verification tasks
├── templates/
│   └── config.yml.j2         # Configuration template
└── README.md                  # This file
```

## Integration with Grafana and Alloy

Loki serves as the central log storage component in the monitoring stack:

1. **Grafana Alloy** collects and forwards logs to Loki
2. **Grafana** provides visualization and search capabilities
3. **Loki** stores and indexes logs by their labels

The role is designed to work seamlessly with these components, creating a complete observability solution.

## Advanced Configuration

### Schema Configuration

The role configures Loki with a TSDB schema that provides:

- Efficient storage and querying
- Label indexing for fast searches
- Configurable retention periods

### Query Performance

The configuration includes:

- Results caching for faster repeat queries
- Split queries for improved concurrency
- Query scheduler limits to prevent overload

## Troubleshooting

Common issues and solutions:

1. **Service fails to start**
   - Check logs with `journalctl -u loki`
   - Verify configuration with `loki -config.file /etc/loki/config.yml -print-config-stderr`
   - Use the verification script: `./svc-exec loki verify`

2. **Storage connectivity issues**
   - For S3: verify endpoint, credentials, and bucket existence
   - For local storage: check directory permissions
   - For NFS: verify mount points and network connectivity

3. **Query performance problems**
   - Check system resources (CPU, memory, disk I/O)
   - Verify index configuration is appropriate for your workload
   - Consider adjusting query limits in configuration

4. **Need to quickly reinstall the service**
   - Use the management script: `./manage-svc loki remove && ./manage-svc loki deploy`

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
# Deploy Loki to default hosts
./manage-svc loki deploy

# Remove Loki from a specific host
./manage-svc -h logserver01 loki remove
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
# Run verification tasks for Loki on default hosts
./svc-exec loki verify

# Run specific verification task on a particular host
./svc-exec -h logserver01 loki verify1
```

## Performance Considerations

### Storage Backend Performance

Storage backend selection impacts performance:

- **Local disk**: Fastest performance, but limited scalability
- **NFS**: Good compromise between performance and simplicity for small clusters
- **S3**: Best for distributed deployments, scalability, and durability

### Resource Requirements

Minimum recommended specifications:

- 2 CPU cores
- 2GB RAM
- Fast disk for local storage (SSD preferred)
- Network with minimal latency to storage backend

## Security Considerations

- The role configures Loki with appropriate file permissions
- Service runs as its own user
- S3 credentials can be secured using Ansible Vault
- Default configuration doesn't enable authentication (configure external auth)

## License

MIT

## Author Information

Created and maintained by Jack Lavender.
