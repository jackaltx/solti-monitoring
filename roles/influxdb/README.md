# InfluxDB Ansible Role

This role manages the installation and configuration of InfluxDB v2.x, a modern time series database optimized for fast, high-availability storage and retrieval of time series data.

## Overview

The role handles:
- Installation of InfluxDB v2.x package
- Initial database setup and user configuration
- Token management and access control
- SSL/TLS configuration
- Integration with NFS storage
- Monitoring configuration
- Complete lifecycle management (install, configure, remove)

## Requirements

### Platform Support
- Debian/Ubuntu systems
- Systemd-based systems

### Prerequisites
- Systemd
- NFS client (if using NFS storage)
- Valid SSL certificates (if using HTTPS)

## Role Variables

### Required Variables

```yaml
influxdb_data_path: ''          # Path to store InfluxDB data
influxdb_org: 'lavnet'          # Organization name
influxdb_bucket: 'telegraf'     # Default bucket name
influxdb_username: 'username'   # Admin username
```

### Optional Variables

```yaml
# Installation control
influxdb_state: 'present'       # Use 'absent' to remove InfluxDB
influxdb_level: 'info'          # Logging level
influxdb_force_reload: false    # Force reinstallation
influxdb_force_configure: false # Force reconfiguration

# Security
influxdb_password: "generated"  # Admin password (will be randomly generated if set to "generated")
influxdb_cert: ""              # Path to SSL certificate
influxdb_key: ""               # Path to SSL private key

# Cleanup options
influxdb_delete_config: false   # Remove config files on uninstall
influxdb_delete_data: false     # Remove data directory on uninstall

# Integration
influxdb_operators_token: ""    # Token for operator access
```

## Features

### Storage Configuration
- Configurable data path
- NFS storage support
- Tiered storage capability (configurable via templates)
- Bolt DB path configuration

### Security
- SSL/TLS support
- Token-based authentication
- Operator and admin token management
- Password generation
- Access control lists

### Monitoring
- OSS metrics collection
- Integration with Telegraf
- Custom bucket creation for metrics
- Configurable logging levels

### High Availability
- Multiple instance support
- Cross-node replication (configurable)
- Backup/restore capabilities

## Dependencies

This role has no direct dependencies on other Ansible roles, but works well with:
- `nfs-client` role (for NFS storage)
- `telegraf` role (for metrics collection)

## Example Playbook

Basic usage:

```yaml
- hosts: influxdb_servers
  roles:
    - role: influxdb
      vars:
        influxdb_data_path: "/opt/influxdb"
        influxdb_org: "myorg"
        influxdb_bucket: "metrics"
```

Advanced configuration with SSL:

```yaml
- hosts: influxdb_servers
  roles:
    - role: influxdb
      vars:
        influxdb_data_path: "/opt/influxdb"
        influxdb_org: "myorg"
        influxdb_bucket: "metrics"
        influxdb_cert: "/etc/ssl/certs/influxdb.crt"
        influxdb_key: "/etc/ssl/private/influxdb.key"
        influxdb_level: "debug"
```

Removal configuration:

```yaml
- hosts: influxdb_servers
  roles:
    - role: influxdb
      vars:
        influxdb_state: 'absent'
        influxdb_delete_config: true
        influxdb_delete_data: true
```

## File Structure

```
influxdb/
├── defaults/
│   └── main.yml              # Default variables
├── files/
│   └── certs/                # SSL certificates
├── handlers/
│   └── main.yml             # Service handlers
├── tasks/
│   ├── main.yml            # Main tasks
│   └── initializedb.yml    # Database initialization
├── templates/
│   ├── config.toml.j2     # Main config template
│   └── etc-default-influxdb.j2  # Environment config
└── vars/
    └── main.yml           # Role variables
```

## Generated Files

The role creates several files in the playbook's data directory:
- `influx-tokens-{hostname}.yml`: Contains authentication tokens
- `influx-webui-access-{hostname}.txt`: Contains UI access credentials

## Handlers

The role includes the following handlers:
- `restart influxd`: Restarts the InfluxDB service

## Security Considerations

- Certificates and keys are stored in `/etc/ssl/`
- Tokens are stored securely with restricted permissions
- Passwords are generated with high entropy
- Access logs are configurable
- SSL/TLS can be enabled for secure communication

## License

BSD

## Author Information

Originally created by Anthropic. Extended by the community.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Notes

- The role automatically handles service restarts when configuration changes
- Supports both basic and advanced authentication mechanisms
- Includes comprehensive token management
- Provides flexible storage options
- Supports monitoring and metrics collection

