# Ansible Collection - jackaltx.solti_monitoring

A comprehensive monitoring ecosystem for modern infrastructure, integrating metrics and log collection using Telegraf, InfluxDB3, Alloy, and Loki. This collection is organized to be tested via Molecule using containers and virtual machines.

Roles are tested in three environments on RHEL and Debian distributions: locally with Podman containers for fast iteration, on Proxmox-hosted virtual machines for full-stack validation, and via GitHub Actions CI for automated regression testing.

This project demonstrates how to:

- reuse molecule framework for multiple distribution on containers and VMs
- build a dynamic ansible playbooks using bash scripts
- integrate reusable testing inside of a role  during development
- build and navigate a testing dictionary which can be used inside of a mind-map tool

## What is SOLTI?

**S**ystems **O**riented **L**aboratory **T**esting & **I**ntegration (SOLTI) is a suite of Ansible collections designed for defining and testing networked laboratory environments. The project emphasizes methodical testing, system behavior analysis, and component integration to combat entropy and maintain reliable systems.

```
solti/
├── solti-monitoring/   # System monitoring and metrics collection (this project)
├── solti-conductor/    # Proxmox management and orchestration
├── solti-ensemble/     # Security and service hardening
├── solti-podman/       # Rootless Podman service deployment
├── solti-docker/       # Docker Compose service deployment
├── solti-platforms/    # Proxmox VM and template management
├── solti-matrix-mgr/   # Matrix user/room provisioning
└── solti-matrix-bots/  # Matrix bot deployment
```

## Architecture Overview

The collection is built around parallel monitoring pipelines with comprehensive testing frameworks.

Recently the project started to focus on "active response" technologies.

### Monitoring Pipelines

#### Metrics Pipeline

- **[Telegraf](roles/telegraf/README.md)** (Client): Collects system and application metrics
- **[InfluxDB3](roles/influxdb3/README.md)** (Server): Stores time-series metrics data
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

## Getting Started

### Prerequisites

- Ansible 2.15 or higher
- Python 3.9 or higher
- For local testing:
  - Podman (primary) or Docker (for container-based testing)
  - Proxmox environment (for VM-based testing)
- Supported platforms:
  - Debian 12/13 (primary support)
  - Rocky Linux 9/10 (supported)
  - Ubuntu 24.04 (supported)

### Installation

```bash
ansible-galaxy collection install jackaltx.solti_monitoring
```

## Core Roles

### Server Components

#### [InfluxDB3](roles/influxdb3/README.md)

**Time Series Database for Metrics Storage** - Automated InfluxDB v3.x installation with bucket management, token-based authentication, and S3-compatible object storage backend. The active metrics server role; supersedes the v2.x `influxdb` role.

#### [InfluxDB](roles/influxdb/README.md)

**Time Series Database (v2.x, legacy)** - InfluxDB v2.x installation with local disk and NFS storage options. Not actively maintained; new installations should use `influxdb3`.

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

## Deployment Patterns

### Quick Deploy with Utility Scripts

This builds a dynamic playbook to manage a service.

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

- **GitHub**: CI-focused testing with Docker containers (3-platform matrix: Debian 12, Rocky 9, Ubuntu 24)
- **Podman**: Local container-based testing
- **Proxmox**: Full stack VM-based testing (4 distributions: Debian 12/13, Rocky 9/10)

Container images are factory-default SSH containers sourced from the
[`testing-containers`](https://github.com/jackaltx/testing-containers) repo
(Debian 12/13, Rocky 9/10, Ubuntu 24) and published to GHCR. They are minimal
by design — just enough for Ansible to connect and test against.

### CI Notifications

Lint and syntax check results post to the `#solti-ci` Matrix room via the shared
`notify-matrix` workflow from `solti-matrix-mgr`. On main-branch CI failures, an
`analyze-failure` workflow sends logs to Claude for root-cause analysis and posts
the result to Matrix.

### Test Results as Obsidian Vault

Test results are automatically organized into an Obsidian-compatible knowledge graph structure at `verify_output/obsidian/`. This provides:

**Why Obsidian?**

- **Cross-linked Navigation**: Jump between test runs, capabilities, and diagnostics
- **Distribution Tracking**: Separate indexes for Debian, Rocky, Ubuntu test histories
- **Chronological Index**: All test runs in time order with pass/fail status
- **Rich Metadata**: YAML frontmatter enables filtering and searching in Obsidian
- **Collapsible Details**: Full raw data preserved in expandable sections
- **Version Control Ready**: Plain markdown files track in git

**Structure:**

```text
verify_output/obsidian/
├── index.md                              # Chronological index (all runs)
├── Debian12-Index.md                     # Distribution-specific indexes
├── Rocky9-Index.md
└── runs/
    └── 2026-03-28-debian12-204137/       # Each test run
        ├── index.md                      # Run overview with links
        ├── preverify-diagnostics.md      # Pre-test system state
        ├── logs-capability.md            # Loki/Alloy results
        ├── metrics-capability.md         # InfluxDB/Telegraf results
        └── postverify-diagnostics.md     # Post-test system state
```

**Usage:**

1. Open `verify_output/obsidian/` as an Obsidian vault
2. Start at `index.md` for chronological view
3. Or use distribution indexes (e.g., `Debian12-Index.md`)
4. Click wiki-style links to navigate between related documents
5. Use Obsidian's graph view to visualize test relationships

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
# All distros (Rocky9, Rocky10, Debian12, Debian13)
./run-proxmox-tests.sh

# Single distro testing
PROXMOX_DISTRO=rocky9 ./run-proxmox-tests.sh
PROXMOX_DISTRO=rocky10 ./run-proxmox-tests.sh
PROXMOX_DISTRO=debian12 ./run-proxmox-tests.sh
PROXMOX_DISTRO=debian13 ./run-proxmox-tests.sh
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

## License

MIT License - see the [LICENSE](LICENSE) file for details

## Authors

- **Jack Lavender** - Infrastructure automation and testing specialist
- **Claude AI** - AI-powered development assistant

This project represents a collaborative effort combining practical infrastructure expertise with systematic documentation and architectural design.
