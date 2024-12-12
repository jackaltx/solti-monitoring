# Monitoring Collection for Ansible

A comprehensive monitoring solution that integrates metrics and log collection using Telegraf, InfluxDB, Alloy, and Loki. This collection provides roles for deploying and managing a complete monitoring stack.

## Features

- Metrics collection and storage with Telegraf and InfluxDB
- Log aggregation using Loki
- Custom Alloy integration
- Shared configuration management
- NFS storage support for InfluxDB
- S3 storage support for Loki (production) with local file fallback (testing)

## Requirements

- Ansible 2.9 or higher
- Python 3.6 or higher
- Debian 11/12 (primary support)
- Rocky Linux 9 (future support planned)

## Roles

### Core Roles

- **telegraf**: Metrics collection agent
- **influxdb**: Time-series database for metrics storage
- **loki**: Log aggregation and storage
- **alloy**: Custom metrics processing
- **nfs-client**: NFS mount management for InfluxDB storage
- **shared**: Common tasks and configurations

## Installation

```bash
ansible-galaxy collection install <your-namespace>.monitoring
```

## Usage

### Basic Example

```yaml
---
- hosts: monitoring_servers
  roles:
    - role: monitoring.influxdb
    - role: monitoring.telegraf
    - role: monitoring.loki
```

### Advanced Configuration

Example playbook with custom configuration:

```yaml
---
- hosts: monitoring_servers
  roles:
    - role: monitoring.influxdb
      vars:
        influxdb_http_port: 8086
        influxdb_data_path: "/mnt/nfs/influxdb"
    
    - role: monitoring.telegraf
      vars:
        telegraf_agent_interval: "10s"
        
    - role: monitoring.loki
      vars:
        loki_storage_type: "s3"
        loki_s3_bucket: "my-logs"
```

## Testing

### Unit Testing

We use Molecule for unit testing individual roles. Example for testing the Telegraf role:

```bash
cd roles/telegraf
molecule test
```

### Integration Testing

Integration tests verify the interaction between roles:

```bash
molecule test -s integration
```

Current test environment:
- Proxmox for virtualization
- GitHub Actions support planned
- Debian 11/12 as primary test platform
- Rocky Linux 9 support in development

### Test Matrix

| Platform    | Unit Tests | Integration Tests |
|-------------|------------|-------------------|
| Debian 11   | ✓          | ✓                 |
| Debian 12   | In Progress| In Progress       |
| Rocky 9     | Planned    | Planned          |

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a new Pull Request

## License

MIT License - see the [LICENSE](LICENSE) file for details

## Recommended Additions

1. **Documentation**
   - Role-specific README files
   - Variable documentation
   - Architecture diagrams
   - Deployment guides
   - Troubleshooting guide

2. **Testing**
   - GitHub Actions workflows
   - Test coverage reports
   - Performance benchmarks
   - Rocky Linux 9 test cases

3. **Features**
   - Dashboard templates
   - Alert configuration examples
   - High availability setup guide
   - Backup and restore procedures

4. **Security**
   - Security hardening guide
   - TLS configuration examples
   - Authentication setup guide
   - Role-based access control templates

## Changelog

### [Unreleased]
- GitHub Actions integration
- Rocky Linux 9 support
- Extended test coverage

### [0.1.0] - YYYY-MM-DD
- Initial release
- Basic role functionality
- Debian 11 support
- Proxmox-based testing

## Documentation Standards

This README follows:
- [Keep a Changelog](https://keepachangelog.com/) format for version tracking
- [Linux Foundation's Core Infrastructure Best Practices](https://bestpractices.coreinfrastructure.org/) for OSS documentation
- [Ansible Collection README Requirements](https://docs.ansible.com/ansible/latest/dev_guide/developing_collections_structure.html#collection-structure)
