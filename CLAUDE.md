# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is an Ansible collection for comprehensive monitoring infrastructure (jackaltx.solti_monitoring). It provides a complete monitoring ecosystem integrating metrics and log collection using Telegraf, InfluxDB, Alloy, and Loki, with fail2ban for security response and WAZUH client support.

## Common Commands

### Service Management
- `./manage-svc.sh <service> <action>` - Manage services with dynamic playbook generation
  - Services: loki, alloy, influxdb, telegraf
  - Actions: install, remove
  - Example: `./manage-svc.sh -h monitor3 loki install`

- `./svc-exec.sh [-K] [-h HOST] <service> [entry]` - Execute specific tasks
  - Entry points: verify, verify1, configure, backup, restore
  - Example: `./svc-exec.sh loki verify`

### Testing
- `./run-podman-tests.sh` - Quick local container-based testing
- `./run-proxmox-tests.sh` - Full VM-based integration testing
- `./run-integration-tests.sh` - Cross-component integration tests
- `molecule test -s <scenario>` - Run specific molecule test scenarios

### Direct Ansible Usage
- `ansible-playbook -i inventory.yml <playbook>` - Standard playbook execution
- `ansible-playbook -K -i inventory.yml <playbook>` - With sudo prompt

## Architecture

### Core Components

#### Server Components
- **InfluxDB** (`roles/influxdb/`) - Time-series database for metrics storage with S3/NFS support
- **Loki** (`roles/loki/`) - Log aggregation system with label-based indexing

#### Client Components  
- **Telegraf** (`roles/telegraf/`) - Metrics collection agent with multi-output support
- **Alloy** (`roles/alloy/`) - Modern log collector (Grafana Alloy) with systemd journal support

#### Security & Response
- **Fail2Ban** (`roles/fail2ban_config/`) - Intrusion detection with Git-based config versioning
- **Wazuh Agent** (`roles/wazuh_agent/`) - Security monitoring with deployment profiles

### Key Directories
- `roles/` - Ansible roles for each component
- `molecule/` - Multi-environment testing scenarios (github, podman, proxmox)
- `plugins/vars/` - Custom Ansible variables plugin for project_root
- `verify_output/` - Test results and verification reports
- `tmp/` - Generated playbooks from utility scripts

### Configuration Files
- `inventory.yml` - Infrastructure inventory with service groups
- `ansible.cfg` - Ansible configuration with custom plugins and logging
- `group_vars/all/` - Global configuration variables

## State Management

All roles use a consistent state pattern:
- `<service>_state: present` - Install and configure
- `<service>_state: absent` - Remove service
- `<service>_delete_config: true/false` - Remove configuration on removal
- `<service>_delete_data: true/false` - Remove data on removal

## Key Variables

### Storage Configuration
- `influxdb_data_path` - InfluxDB data directory (supports NFS)
- `loki_local_storage` - Enable local vs S3 storage for Loki
- `mount_nfs_share` - Enable NFS mounting for shared storage

### Multi-Output Support
- `telegraf_outputs: []` - List of InfluxDB outputs for Telegraf
- `telgraf2influxdb_configs` - Configuration for each output endpoint
- `alloy_loki_endpoints` - Loki endpoints for log forwarding

## Testing Framework

### Environment Setup

Before running tests, set up the Python virtual environment:

```bash
# Create and configure virtual environment
./prepare-solti-env.sh

# Activate the environment
source solti-venv/bin/activate
```

### Environment Variables

- `LAB_DOMAIN` - Domain for container registry (default: `example.com`)
  - Set in `~/.secrets/LabProvision` or export before testing
  - Used to resolve container images: `gitea.${LAB_DOMAIN}:3001/jackaltx/testing-containers/`

- `MOLECULE_CAPABILITIES` - Comma-separated list of capabilities to test
  - Valid options: `logs`, `metrics`
  - Default: `logs,metrics`
  - Examples:
    - `MOLECULE_CAPABILITIES=logs` - Test only Loki/Alloy
    - `MOLECULE_CAPABILITIES=metrics` - Test only InfluxDB/Telegraf
    - `MOLECULE_CAPABILITIES=logs,metrics` - Test all components

### Running Molecule Tests

#### Quick Start (Recommended)
```bash
# Run all tests with default capabilities (logs,metrics)
./run-podman-tests.sh

# Test only log collection
MOLECULE_CAPABILITIES=logs ./run-podman-tests.sh

# Test only metrics collection
MOLECULE_CAPABILITIES=metrics ./run-podman-tests.sh
```

#### Direct Molecule Commands
```bash
# Activate virtual environment first
source solti-venv/bin/activate

# Full test cycle (destroy → create → prepare → converge → verify → destroy)
molecule test -s podman

# Individual test phases
molecule create -s podman       # Create test containers
molecule converge -s podman     # Apply roles
molecule verify -s podman       # Run verification tasks
molecule destroy -s podman      # Clean up containers

# Other scenarios
molecule test -s github         # GitHub CI scenario
molecule test -s proxmox        # Proxmox VM testing (requires env vars)
```

### Molecule Scenarios
- `github/` - CI testing with Podman containers (automated)
- `podman/` - Local container testing (default for development)
- `proxmox/` - Full VM testing on Proxmox infrastructure (integration)

### Verification System
Multi-level verification tasks in each role:
- `verify` - Basic service functionality
- `verify1` - Extended verification with integration tests
- Verification results stored in `verify_output/<distribution>/`

## Development Patterns

### Role Structure
Each role follows standard Ansible structure with additional verification tasks:
- `tasks/main.yml` - Primary installation/removal logic
- `tasks/verify.yml` - Basic verification tasks
- `tasks/verify1.yml` - Extended verification (where applicable)
- `templates/` - Jinja2 templates for configuration files

### Shared Components
- `roles/shared/` - Common tasks for package installation across distributions
- `roles/shared/grafana/tasks/` - Grafana package installation helpers
- `roles/shared/influxdb/tasks/` - InfluxDB package installation helpers

### Inventory Groups
- `<service>_svc` - Default host groups for each service
- `metric_collectors` - Hosts running Telegraf
- `clients` - Hosts running Alloy
- `wazuh_agents` - Hosts running Wazuh agent

## Environment Requirements

### Required for Proxmox Testing
- `PROXMOX_URL`
- `PROXMOX_USER`
- `PROXMOX_TOKEN_ID`
- `PROXMOX_TOKEN_SECRET`
- `PROXMOX_NODE`

### Supported Platforms
- Debian 11/12 (primary)
- Rocky Linux 9 (experimental)
- Ubuntu (via shared installation tasks)