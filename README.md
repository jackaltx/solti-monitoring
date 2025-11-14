# Ansible Collection - jackaltx.solti_monitoring

A comprehensive monitoring ecosystem for modern infrastructure, integrating metrics and log collection using Telegraf, InfluxDB, Alloy, and Loki. It adds in fail2ban for stand-alone detection/response. There is preliminary work on a WAZUH client for cluster monitoring.

This goal of this collection is to provided tested, deployment-ready roles with advanced testing frameworks and utility scripts for seamless operations.

Developers Note:  I developed in this folder initially. I have left some of the development
artifacts to help anyone interested.  A sanitized set of reference files: inventory.yml, group_vars, and playbooks.

The github molecule testing is too slow to be useful. Proxmox is ok for thoroughness.
Podman works ok.   This is an example of how to reuse your molecule code on multiple testing
platforms.

## What is SOLTI?

**S**ystems **O**riented **L**aboratory **T**esting & **I**ntegration (SOLTI) is a suite of Ansible collections designed for defining and testing networked laboratory environments. The project emphasizes methodical testing, system behavior analysis, and component integration to combat entropy and maintain reliable systems.

```
solti/
├── solti-monitor/      # System monitoring and metrics collection (this project)
├── solti-conductor/    # Proxmox management and orchestration
├── solti-ensemble/     # Support tools and shared utilities
├── solti-containers/   # Support containers for testing (Minio, Vault, Mattermost, ...)
└── solti-score/        # Documentation and playbooks (private only for now)
```

## Architecture Overview

The collection is built around parallel monitoring pipelines with comprehensive testing frameworks.

Recently the project started to focus on "active response" technologies.

### Monitoring Pipelines

#### Metrics Pipeline

- **[Telegraf](roles/telegraf/README.md)** (Client): Collects system and application metrics
- **[InfluxDB](roles/influxdb/README.md)** (Server): Stores time-series metrics data
- Supports customizable input plugins and multiple output configurations

#### Logging Pipeline

- **[Alloy](roles/alloy/README.md)** (Client): Collects and forwards system and application logs
- **[Loki](roles/loki/README.md)** (Server): Stores and indexes log data
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

### Active Response

- ** Fail2Ban
  - xxx
  -

- ** Wazuh Client
  - xxx

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

```bash
ansible-galaxy collection install jackaltx.solti_monitoring
```

## Core Roles

### Server Components

#### [InfluxDB](roles/influxdb/README.md)

**Time Series Database for Metrics Storage** - Automated InfluxDB v2.x installation with bucket management, token-based authentication, and support for both local disk and S3-compatible storage. Includes initial setup, organization configuration, and integration preparation for Telegraf clients.

#### [Loki](roles/loki/README.md)

**Log Aggregation System** - Horizontally-scalable log storage with label-based indexing. Supports local filesystem, NFS mounts, and S3-compatible object storage. Designed for cost-effective operation without full-text indexing, focusing on efficient label-based queries.

### Client Components

#### [Telegraf](roles/telegraf/README.md)

**Metrics Collection Agent** - Collects system and application metrics with support for multiple input plugins (CPU, memory, disk, network, Apache, MySQL, Redis, Memcached). Configurable outputs to multiple InfluxDB instances with automatic token discovery for local installations.

#### [Alloy](roles/alloy/README.md)

**Log Collection Agent** - Modern log collector based on Grafana Alloy. Supports systemd journal, file sources, and application-specific log parsing for Apache, Bind9, Fail2ban, mail services, WireGuard, and Gitea. Includes multi-line log support and label enrichment.

### Support Components

#### [NFS Client](roles/nfs-client/README.md)

**NFS Storage Support** - Manages NFS client installation and mount configuration with optimized mount options for monitoring components. Supports multiple shares and cross-platform compatibility.

### Testing & Verification

#### [Log Tests](roles/log_tests/README.md)

**Log Pipeline Verification** - Comprehensive testing for the Loki-Alloy log collection stack. Validates service connectivity, data flow, query capabilities, and generates detailed integration reports.

#### [Metrics Tests](roles/metrics_tests/README.md)

**Metrics Pipeline Verification** - Integration testing for the InfluxDB-Telegraf metrics collection stack. Verifies data ingestion, query functionality, bucket configuration, and health status.

### Security & Configuration Management

#### [Fail2Ban Config](roles/fail2ban_config/README.md)

**Fail2Ban with Git Versioning** - Manages Fail2Ban with integrated Git-based configuration tracking. Provides complete version control of security configurations with automatic commits, rollback capabilities, and compliance audit trails.

#### [Wazuh Agent](roles/wazuh_agent/README.md)

**Security Monitoring Agent** - Comprehensive Wazuh agent management with deployment profiles (isolated, internal, internet_facing, ispconfig), intelligent service detection, Git-based configuration versioning, and container environment support.

## Deployment Patterns

### Quick Deploy with Utility Scripts

```bash
$ ./manage-svc.sh 
Usage: manage-svc.sh [-h HOST] <service> <action>

Services: loki, alloy, influxdb, telegraf
Actions: remove, install, deploy, prepare
```

Deploy using inventory default groups:

```bash
# Deploy a metrics server
./manage-svc.sh influxdb deploy

# Deploy a log server
./manage-svc.sh loki deploy
```

Or target specific hosts:

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
        loki_local_storage: true

- name: Deploy Monitoring Agents
  hosts: all_servers
  roles:
    - role: telegraf
      vars:
        telegraf_outputs: ['central']
        telgraf2influxdb_configs:
          central:
            url: "http://monitoring.example.com:8086"
            token: "{{ influxdb_token }}"
            bucket: "telegraf"
            org: "myorg"
            
    - role: alloy
      vars:
        alloy_loki_endpoints:
          - label: main
            endpoint: "monitoring.example.com"
        alloy_monitor_apache: true
```

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
alloy_loki_endpoints:
  - label: main
    endpoint: "loki.example.com"
alloy_monitor_apache: true
alloy_monitor_fail2ban: true
alloy_monitor_mail: true
alloy_monitor_bind9: true
```

## Testing Infrastructure

### Molecule Framework

Multiple test scenarios are available for comprehensive verification:

- **GitHub**: CI-focused testing with Podman containers
- **Podman**: Local container-based testing  
- **Proxmox**: Full stack VM-based testing

### Running Tests

#### Podman Tests (Fast, Local)

```bash
# All platforms (Debian, Rocky, Ubuntu)
./run-podman-tests.sh

# Single platform testing
MOLECULE_PLATFORM_NAME=uut-ct0 ./run-podman-tests.sh  # Debian
MOLECULE_PLATFORM_NAME=uut-ct1 ./run-podman-tests.sh  # Rocky
MOLECULE_PLATFORM_NAME=uut-ct2 ./run-podman-tests.sh  # Ubuntu

# Test specific capabilities
MOLECULE_CAPABILITIES=logs ./run-podman-tests.sh      # Loki/Alloy only
MOLECULE_CAPABILITIES=metrics ./run-podman-tests.sh   # InfluxDB/Telegraf only
```

#### Proxmox Tests (Full VMs)

**VM Template Requirements:**
- Minimum 8 CPU cores
- Minimum 16GB RAM
- Note: Cloning process does not modify template resource allocation

```bash
# All distros (Rocky9, Debian12)
./run-proxmox-tests.sh

# Single distro testing
PROXMOX_DISTRO=debian12 ./run-proxmox-tests.sh
PROXMOX_DISTRO=rocky9 ./run-proxmox-tests.sh
```

#### Integration Tests

```bash
# Integration tests across components
./run-integration-tests.sh
```

### Verification System

The multi-layered verification system provides confidence in deployment:

1. **Level 0**: Core service functionality
2. **Level 1**: Component interaction  
3. **Level 2**: Advanced functionality

```bash
# Run verification for Loki
./svc-exec.sh loki verify

# Run extended verification
./svc-exec.sh loki verify1

# Run specific tasks
./svc-exec.sh influxdb backup
```

## Utility Scripts

### manage-svc.sh

Service lifecycle management with dynamically generated playbooks.

### svc-exec.sh  

Task-oriented service operations for verification and maintenance.

Both scripts provide convenient ways to manage the monitoring stack without manually creating playbooks.

## Installation

```bash
ansible-galaxy collection install jackaltx.solti_monitoring
```

## Usage

```yaml
- hosts: monitoring_servers
  roles:
    - jackaltx.solti_monitoring.influxdb
    - jackaltx.solti_monitoring.loki

- hosts: monitored_servers  
  roles:
    - jackaltx.solti_monitoring.telegraf
    - jackaltx.solti_monitoring.alloy
```

## License

MIT License - see the [LICENSE](LICENSE) file for details

## Authors

- **Jack Lavender** - Infrastructure automation and testing specialist
- **Claude AI** - AI-powered development assistant

This project represents a collaborative effort combining practical infrastructure expertise with systematic documentation and architectural design.
