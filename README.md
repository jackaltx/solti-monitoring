# SOLTI Monitoring Collection

A comprehensive monitoring solution that integrates metrics and log collection using Telegraf, InfluxDB, Alloy, and Loki. This collection provides roles for deploying both logging and metrics collection infrastructure.

## What is solti ?

Systems Oriented Laboratory Testing & Integration (solti) is a suite
of ansible collections that can be used to define and test a networked
laboratory you would find in most small labs. Entropy is real. The project emphasizes methodical testing, system behavior analysis, and component integration.  

```
solti/
├── solti-monitor/      # System monitoring and metrics collection
├── solti-conductor/    # Proxmox management and orchestration
├── solti-ensemble/     # Support tools and shared utilities
├── solti-containers/   # Support containers for testing
└── solti-score/        # Documentation and playbooks
```

## Architecture Overview

The collection is built around two main monitoring pipelines:

### Metrics Pipeline

- **Telegraf** (Client): Collects system and application metrics
- **InfluxDB** (Server): Stores time-series metrics data
- Supports multiple Telegraf clients sending to a central InfluxDB server

### Logging Pipeline

- **Alloy** (Client): Collects and forwards system and application logs
- **Loki** (Server): Stores and indexes log data
- Supports multiple Alloy clients sending to a central Loki server

## Prerequisites

- Ansible 2.9 or higher
- Python 3.6 or higher
- Debian 11/12 (primary support)
- Proxmox environment for testing (optional)
- Rocky Linux 9 (future support planned)

## Quick Start

### Installation

1. Clone the repository:

```bash
git clone https://github.com/your-org/monitoring-collection.git
cd monitoring-collection
```

2. Install collection dependencies:

```bash
ansible-galaxy collection install -r requirements.yml
```

### Local Testing with Proxmox

1. Set up Proxmox environment variables:

```bash
export PROXMOX_URL="https://proxmox.example.com:8006"
export PROXMOX_USER="root@pam"
export PROXMOX_TOKEN_ID="your-token-id"
export PROXMOX_TOKEN_SECRET="your-token-secret"
export PROXMOX_NODE="your-node-name"
```

2. Run tests:

```bash
# Test individual roles
cd roles/influxdb
molecule test -s proxmox

# Test complete monitoring stack
molecule test -s integration
```

## Server Setup

### Metrics Server (InfluxDB)

```yaml
- hosts: monitoring_servers
  roles:
    - role: influxdb
      vars:
        influxdb_http_port: 8086
        influxdb_org: "myorg"
        influxdb_bucket: "metrics"
```

[InfluxDB Role Documentation](roles/influxdb/README.md)

### Log Server (Loki)

```yaml
- hosts: monitoring_servers
  roles:
    - role: loki
      vars:
        loki_local_storage: true  # For testing
        # Production S3 configuration
        # loki_endpoint: "s3.example.com"
        # loki_s3_bucket: "logs"
        # loki_key_id: "ACCESS_KEY"
        # loki_access_key: "SECRET_KEY"
```

[Loki Role Documentation](roles/loki/README.md)

## Client Setup

### Metrics Client (Telegraf)

```yaml
- hosts: client_servers
  roles:
    - role: telegraf
      vars:
        telgraf2influxdb_configs:
          localhost:
            url: "http://influxdb.example.com:8086"
            token: "your-token"
            bucket: "telegraf"
            org: "myorg"
```

[Telegraf Role Documentation](roles/telegraf/README.md)

### Log Client (Alloy)

```yaml
- hosts: client_servers
  roles:
    - role: alloy
      vars:
        alloy_loki_endpoint: "loki.example.com:3100"
```

[Alloy Role Documentation](roles/alloy/README.md)

## Role Documentation

- [InfluxDB](roles/influxdb/README.md) - Time series database for metrics
- [Loki](roles/loki/README.md) - Log aggregation and storage
- [Telegraf](roles/telegraf/README.md) - Metrics collection agent
- [Alloy](roles/alloy/README.md) - Log collection agent
- [NFS Client](roles/nfs-client/README.md) - NFS storage support

## Testing

### Molecule Test Scenarios

- **github**: Basic functionality tests in Docker containers
- **integration**: Full stack testing in Proxmox VMs
- **proxmox-logs**: Log collection testing
- **proxmox-metrics**: Metrics collection testing

### Running Tests

```bash
# Test metrics pipeline
molecule test -s proxmox-metrics

# Test logging pipeline
molecule test -s proxmox-logs
```

## Known Limitations

1. Operating System Support
   - Primary support for Debian 11/12
   - Rocky Linux 9 support in development
   - Other distributions not currently tested

2. Storage Backends
   - InfluxDB: Local or NFS storage only
   - Loki: Local or S3 storage only

3. Authentication
   - Basic token authentication only
   - No LDAP/OAuth support yet

## Development Status

Current focus areas:

- Rocky Linux 9 support
- Enhanced test coverage
- GitHub Actions integration
- Documentation improvements

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a new Pull Request

## License

MIT License - see the [LICENSE](LICENSE) file for details
