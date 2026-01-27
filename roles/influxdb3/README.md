# InfluxDB v3 Core Ansible Role

## Overview

This role installs and configures [InfluxDB v3 Core](https://docs.influxdata.com/influxdb3/core/), the next-generation time-series database from InfluxData. InfluxDB v3 features a new architecture built on Apache Arrow and DataFusion, providing improved query performance and a simplified deployment model.

**Phase 1 Status:** Unit testing only - local filesystem storage, no telegraf integration

## Features

- Installs InfluxDB v3 Core from official InfluxData repositories (Debian/Ubuntu)
- Manages InfluxDB v3 systemd service lifecycle
- Configures local filesystem object store
- Handles initial database setup and admin token generation
- Includes comprehensive verification tasks for operational health checks
- Supports state management (present/absent) with optional data cleanup

## Requirements

### Platform Support

- Debian 12 (tested)
- Ubuntu 24.04 (expected to work)
- Systemd-based operating system

### Prerequisites

- Network connectivity for package repository access
- InfluxData package repository access
- Systemd service manager

## Role Variables

### Main Control Variables

```yaml
# Installation state
influxdb3_state: "present"  # Use 'absent' to remove

# Node configuration
influxdb3_node_id: "node0"  # Unique node identifier

# Storage configuration
influxdb3_data_dir: "/var/lib/influxdb3/data"
influxdb3_plugin_dir: "/var/lib/influxdb3/plugins"
influxdb3_object_store: "file"  # file, s3, or azure (Phase 1: file only)

# Service configuration
influxdb3_port: 8181
influxdb3_bind_address: "0.0.0.0"

# Database initialization
influxdb3_database: "telegraf"
influxdb3_admin_token: ""  # Auto-generated if empty

# Removal options
influxdb3_delete_config: false  # Remove config on uninstall
influxdb3_delete_data: false    # Remove data on uninstall

# Force operations
influxdb3_force_reload: false     # Force reinstall
influxdb3_force_configure: false  # Force reconfiguration
```

### Future Variables (Phase 2+)

```yaml
# S3 storage (not implemented in Phase 1)
influxdb3_s3_bucket: ""
influxdb3_s3_access_key_id: ""
influxdb3_s3_secret_access_key: ""
influxdb3_s3_endpoint: ""
influxdb3_s3_allow_http: false

# Azure storage (not implemented in Phase 1)
influxdb3_azure_endpoint: ""
```

## Quick Verification

After deployment, verify InfluxDB v3 is working:

```bash
# Check service status
systemctl status influxdb3-core

# Check HTTP API
curl http://localhost:8181/health

# View admin token
sudo cat /root/.influxdb3-credentials

# Test write
influxdb3 write --database telegraf "test,host=local value=1.0"

# Test query
influxdb3 query --database telegraf "SELECT * FROM test WHERE time > now() - INTERVAL '1 minute'"
```

## Usage Examples

### Basic Deployment

```yaml
# playbooks/deploy-influxdb3.yml
- hosts: monitoring_servers
  become: true
  roles:
    - jackaltx.solti_monitoring.influxdb3
```

### Custom Configuration

```yaml
- hosts: monitoring_servers
  become: true
  roles:
    - jackaltx.solti_monitoring.influxdb3
  vars:
    influxdb3_database: "metrics"
    influxdb3_node_id: "prod-node-01"
    influxdb3_port: 8181
```

### Verification

```yaml
# playbooks/verify-influxdb3.yml
- hosts: monitoring_servers
  become: true
  tasks:
    - include_role:
        name: jackaltx.solti_monitoring.influxdb3
        tasks_from: verify.yml
  vars:
    verify_timestamp: "{{ ansible_date_time.iso8601 }}"
    report_root: "./verify_output"
```

### Orchestrator Usage

From the `mylab/` orchestrator directory:

```bash
# Deploy
./manage-svc.sh -h test-host influxdb3 deploy

# Verify
./svc-exec.sh -h test-host influxdb3 verify
```

## Phase 1 Limitations

This is the initial unit test phase with the following scope:

- **Supported:** Local filesystem storage only
- **Supported:** Fresh installations on clean systems
- **Supported:** Deploy and verify operations
- **Not supported:** S3/Azure object stores
- **Not supported:** Data migration from InfluxDB v2
- **Not supported:** Telegraf integration (Phase 2)

## Token Management

Admin tokens are automatically generated on first installation and stored in:

```text
/root/.influxdb3-credentials
```

**Important:** Store this token securely. It provides full administrative access.

## Dependencies

None

## License

MIT-0

## Author Information

Part of the Solti Monitoring collection by jackaltx

## References

- [InfluxDB v3 Core Documentation](https://docs.influxdata.com/influxdb3/core/)
- [Install InfluxDB 3 Core](https://docs.influxdata.com/influxdb3/core/install/)
- [InfluxDB 3 Core Get Started](https://docs.influxdata.com/influxdb3/core/get-started/)
