# SOLTI Monitoring Collection

A comprehensive monitoring ecosystem for modern infrastructure, integrating metrics and log collection using Telegraf, InfluxDB, Alloy, and Loki. This collection provides tested, deployment-ready roles with advanced testing frameworks and utility scripts for seamless operations.

## What is SOLTI?

**S**ystems **O**riented **L**aboratory **T**esting & **I**ntegration (SOLTI) is a suite of Ansible collections designed for defining and testing networked laboratory environments. The project emphasizes methodical testing, system behavior analysis, and component integration to combat entropy and maintain reliable systems.

```
solti/
├── solti-monitor/      # System monitoring and metrics collection (this project)
├── solti-conductor/    # Proxmox management and orchestration
├── solti-ensemble/     # Support tools and shared utilities
├── solti-containers/   # Support containers for testing
└── solti-score/        # Documentation and playbooks
```

## Architecture Overview

The collection is built around two parallel monitoring pipelines with comprehensive testing frameworks:

### Monitoring Pipelines

#### Metrics Pipeline

- **Telegraf** (Client): Collects system and application metrics
- **InfluxDB** (Server): Stores time-series metrics data
- Supports customizable input plugins and multiple output configurations

#### Logging Pipeline

- **Alloy** (Client): Collects and forwards system and application logs
- **Loki** (Server): Stores and indexes log data
- Flexible configuration for various log sources and filtering

### Testing Framework

- **Molecule Testing**: Multiple test scenarios for different environments
  - GitHub CI integration with Podman containers
  - Proxmox VM testing for full-stack verification
  - Local development testing with quick feedback loops

- **Verification System**: Multi-level verification tasks for deep testing
  - Component-level verification
  - Integration verification across components
  - System-level verification of the entire stack

- **Utility Scripts**: Purpose-built scripts for efficient operations
  - `manage-svc.sh`: Service lifecycle management
  - `svc-exec.sh`: Task-oriented service operations
  - Integration test runners and reporting tools

## Getting Started

### Prerequisites

- Ansible 2.9 or higher
- Python 3.6 or higher
- For local testing:
  - Podman or Docker (for container-based testing)
  - Proxmox environment (for VM-based testing)
- Supported platforms:
  - Debian 11/12 (primary support)
  - Rocky Linux 9 (experimental support)

### Installation

1. Clone the repository:

```bash
git clone https://github.com/your-org/solti-monitoring.git
cd solti-monitoring
```

2. Install collection dependencies:

```bash
ansible-galaxy collection install -r requirements.yml
```

3. Set up testing environment (optional):

```bash
# For Proxmox testing
source ./solti-init.sh
```

## Deployment Patterns

### Quick Deploy with Utility Scripts

This pattern is very repetitive, so using a geneator to create and execute a playbook
is relatively easy.

```bash
$ ./manage-svc.sh 
Error: Incorrect number of arguments
Usage: manage-svc.sh [-h HOST] <service> <action>

Options:
  -h HOST    Target host from inventory (default: uses hosts defined in role)

Services:
  - loki
  - alloy
  - influxdb
  - telegraf

Actions:
  - remove
  - install
```

There are two ways to deploy, either use the inventory
default file groups: "ServiceNmae"_svc.

```bash
# Deploy a metrics server
./manage-svc.sh influxdb deploy

# Deploy a log server
./manage-svc.sh loki deploy
```

Or designate a host or inventory group using -h option

```bash
# Deploy clients to specific hosts
./manage-svc.sh -h client01 telegraf deploy
./manage-svc.sh -h client01 alloy deploy
```

### Complete Stack Deployment

```yaml
- name: Deploy Monitoring Server
  hosts: monitoring_servers
  roles:
    - role: influxdb
      vars:
        influxdb_org: "myorg"
        influxdb_bucket: "metrics"
        
    - role: loki
      vars:
        loki_local_storage: true  # For testing/development

- name: Deploy Monitoring Agents
  hosts: all_servers
  roles:
    - role: telegraf
      vars:
        telgraf2influxdb_configs:
          central:
            url: "http://monitoring.example.com:8086"
            token: "{{ influxdb_token }}"
            bucket: "telegraf"
            org: "myorg"
            
    - role: alloy
      vars:
        alloy_loki_endpoint: "monitoring.example.com:3100"
        alloy_monitor_apache: true  # Enable Apache log collection
```

## Role Documentation

### Server Components

- [InfluxDB](roles/influxdb/README.md) - Time series database for metrics storage
  - Local and NFS storage options
  - Token-based authentication
  - Bucket management

- [Loki](roles/loki/README.md) - Horizontally-scalable log aggregation system
  - Local filesystem or S3-compatible storage
  - Label-based indexing
  - Query optimization

### Client Components

- [Telegraf](roles/telegraf/README.md) - Agent for collecting, processing, and reporting metrics
  - Multiple input plugin support
  - Configurable outputs
  - Low overhead collection

- [Alloy](roles/alloy/README.md) - Log collection agent based on Grafana Alloy
  - Journal and file source support
  - Preprocessing and filtering
  - Multi-target forwarding

### Support Components

- [NFS Client](roles/nfs-client/README.md) - NFS storage support for monitoring components
  - Optimized mount configurations
  - Cross-platform support

### Testing Components

- [log_tests](roles/log_tests/README.md) - Verification for log collection stack
  - Connection testing
  - Log ingestion verification
  - Query validation

- [metrics_tests](roles/metrics_tests/README.md) - Verification for metrics collection stack
  - Service status verification
  - Data flow validation
  - Health checks

## Testing Infrastructure

### Molecule Framework

Multiple test scenarios are available for comprehensive verification:

- **GitHub**: CI-focused testing with Podman containers
  - Quick validation of core functionality
  - Parallelized component testing
  - Artifact generation

- **Podman**: Local container-based testing
  - Rapid development feedback
  - Multi-distribution testing
  - Network isolation testing

- **Proxmox**: Full stack VM-based testing
  - Real-world deployment simulation
  - Performance testing
  - Long-running stability tests

### Running Tests

```bash
# Quick local tests with Podman
./run-podman-tests.sh

# Complete environment tests with Proxmox
./run-proxmox-tests.sh

# Integration tests across components
./run-integration-tests.sh

# Unit tests for individual roles
./run-unit-tests.sh
```

### Verification System

The multi-layered verification system provides confidence in the deployment:

1. **Base Level (Level 0)**: Core service functionality
   - Service running status
   - Port accessibility
   - Basic configuration

2. **Integration Level (Level 1)**: Component interaction
   - Client-server communication
   - Data flow verification
   - Authentication validation

3. **Extended Level (Level 2)**: Advanced functionality
   - Performance metrics
   - Error handling
   - Edge case testing

```bash
# Run verification for Loki
./svc-exec.sh loki verify

# Run extended verification
./svc-exec.sh loki verify1

# Run specific tasks
./svc-exec.sh influxdb backup
```

Note:This patter is very handy for executing any yaml task file in the role's task directory.
So look inside each role for little handy surprises.

## Advanced Configuration

### Storage Configuration

#### InfluxDB Storage Options

```yaml
# Local storage (default)
influxdb_data_path: /var/lib/influxdb

# NFS storage
influxdb_data_path: /mnt/nfs/influxdb
mount_nfs_share: true
cluster_nfs_mounts:
  influxdb:
    src: "nfs.example.com:/storage/influxdb"
    path: "/mnt/nfs/influxdb"
    opts: "rw,noatime,bg"
    state: "mounted"
    fstype: "nfs4"
```

#### Loki Storage Options

```yaml
# Local storage
loki_local_storage: true

# S3 storage
loki_local_storage: false
loki_endpoint: "s3.example.com"
loki_s3_bucket: "loki-logs"
loki_key_id: "ACCESS_KEY_ID"
loki_access_key: "SECRET_ACCESS_KEY"
```

### Client Configuration Examples

#### Telegraf with Multiple Outputs

```yaml
telegraf_outputs: ['central', 'local']
telgraf2influxdb_configs:
  central:
    url: "https://central-monitoring.example.com"
    token: "{{ central_token }}"
    bucket: "telegraf"
    org: "central"
  local:
    url: "http://localhost"
    token: "{{ local_token }}"
    bucket: "local_metrics"
    org: "local"
```

#### Alloy with Advanced Log Collection

```yaml
alloy_loki_endpoint: "loki.example.com"
alloy_monitor_apache: true
alloy_monitor_fail2ban: true
alloy_monitor_mail: true
alloy_monitor_bind9: true
```

## Development and Contributing

### Development Workflow

1. Fork the repository
2. Set up local testing environment
3. Make changes and run tests:

   ```bash
   molecule test -s podman
   ```

4. Submit a pull request with test results

### Code Organization

```
solti-monitoring/
├── roles/                  # Core component roles
├── molecule/               # Test scenarios
│   ├── github/             # GitHub CI tests
│   ├── podman/             # Container tests
│   ├── proxmox/            # VM tests
│   └── shared/             # Shared test resources
├── playbooks/              # Example playbooks
├── group_vars/             # Variable definitions
├── *.sh                    # Utility scripts
└── verify_output/          # Test results
```

## Known Limitations

1. Operating System Support
   - Primary support for Debian 11/12
   - Experimental Rocky Linux 9 support
   - Other distributions may require adaptation

2. Storage Backends
   - InfluxDB: Local or NFS storage
   - Loki: Local or S3-compatible storage

3. Authentication
   - Basic token authentication implemented
   - External authentication requires manual configuration

## Troubleshooting

- **Service fails to start**:
  - Check logs with `journalctl -u <service-name>`
  - Run verification: `./svc-exec.sh <service-name> verify`

- **Connection issues between components**:
  - Verify network connectivity
  - Check port accessibility
  - Run integration tests: `./run-integration-tests.sh`

- **Data not appearing in queries**:
  - Verify client configuration
  - Check authentication tokens
  - Examine service logs for ingestion errors

## License

MIT License - see the [LICENSE](LICENSE) file for details

## Author Information

Created and maintained by Jack Lavender with significant contributions from Claude (Anthropic). This project represents a collaborative effort combining practical infrastructure expertise with systematic documentation and architectural design.
