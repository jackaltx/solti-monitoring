# Loki Ansible Role

This role manages the installation and configuration of Grafana Loki, a horizontally scalable, highly available log aggregation system.

## Overview

The role handles:
- Installation of Grafana Loki package
- Configuration of S3 storage backend
- Service management
- Security configuration
- Complete lifecycle management (install, configure, remove)

## Requirements

### Platform Support
- Debian/Ubuntu systems
- Systemd-based systems

### Prerequisites
- Systemd
- S3-compatible object storage
- Network access to S3 endpoint

## Role Variables

### Required Variables

```yaml
loki_endpoint: ''           # S3 endpoint URL
loki_s3_bucket: ''         # S3 bucket name
loki_key_id: ''           # S3 access key ID
loki_access_key: ''       # S3 secret access key
```

### Optional Variables

```yaml
# Installation control
loki_state: 'present'      # Use 'absent' to remove Loki
loki_force_reload: false   # Force reinstallation

# Cleanup options
loki_delete_config: false  # Remove config files on uninstall
loki_delete_data: false    # Remove data directory on uninstall
```

## Features

### Storage Configuration
- S3-compatible object storage support
- Local caching for improved performance
- Configurable retention periods
- TSDB storage schema

### Performance Tuning
- Embedded cache configuration
- Query scheduling parameters
- Ingestion rate limits
- Chunk store configuration
- Query range settings

### Security
- Optional TLS/SSL support
- Authentication configuration
- Rate limiting
- Tenant isolation

### Query Features
- Long-running query support
- Query caching
- Structured metadata support
- Query splitting configuration

## Dependencies

This role has no direct dependencies on other Ansible roles but works well with:
- `promtail` role for log collection
- `alloy` role for OpenTelemetry collection

## Example Playbook

Basic usage:

```yaml
- hosts: loki_servers
  roles:
    - role: loki
      vars:
        loki_endpoint: "s3.example.com"
        loki_s3_bucket: "logs"
        loki_key_id: "ACCESS_KEY"
        loki_access_key: "SECRET_KEY"
```

Advanced configuration:

```yaml
- hosts: loki_servers
  roles:
    - role: loki
      vars:
        loki_endpoint: "s3.example.com"
        loki_s3_bucket: "logs"
        loki_key_id: "ACCESS_KEY"
        loki_access_key: "SECRET_KEY"
        loki_force_reload: true
```

Removal configuration:

```yaml
- hosts: loki_servers
  roles:
    - role: loki
      vars:
        loki_state: 'absent'
        loki_delete_config: true
        loki_delete_data: true
```

## File Structure

```
loki/
├── defaults/
│   └── main.yml           # Default variables
├── handlers/
│   └── main.yml          # Service handlers
├── tasks/
│   └── main.yml         # Main tasks
└── templates/
    └── config.yml.j2    # Loki config template
```

## Configuration Details

### Server Configuration
- HTTP and gRPC listeners
- Read/write timeouts
- TLS settings
- Log levels

### Storage Schema
- TSDB storage engine
- S3 object store
- Index management
- Retention settings

### Query Configuration
- Results caching
- Query scheduling
- Rate limiting
- Query splitting

### Limits Configuration
- Sample age rejection
- Ingestion rates
- Burst sizes
- Query limits

## Handlers

The role includes the following handlers:
- `restart loki`: Restarts the Loki service and reloads systemd daemon

## Security Considerations

- S3 credentials management
- Optional TLS configuration
- Authentication settings
- Rate limiting for protection

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
- Provides flexible storage options
- Includes comprehensive monitoring capabilities
- Default configuration optimized for production use

