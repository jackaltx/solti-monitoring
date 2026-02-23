# Molecule Testing Architecture

## Overview

Solti-Monitoring uses Ansible Molecule for integration testing across multiple distributions and platforms. The testing architecture is **capability-driven**, meaning tests are organized around functional capabilities (logs, metrics) rather than individual roles.

## Core Concepts

### Capabilities-Based Testing

Instead of testing roles in isolation, we test **capabilities** - complete functional systems that involve multiple roles working together:

- **logs**: Log collection and forwarding (Loki + Alloy)
- **metrics**: Metrics collection and storage (InfluxDB + InfluxDB v3 + Telegraf)

This approach validates:
1. Individual service functionality (role-level verification)
2. Inter-service communication (integration verification)
3. Real-world deployment scenarios

### Two-Level Verification

Each capability uses **two levels of verification**:

1. **Role-level verification** (`verify_role_tasks`)
   - Tests individual service operation
   - Runs tasks within role context (access to all role variables)
   - Examples: Service running, API responding, configuration valid

2. **Integration verification** (`verify_tasks`)
   - Tests interaction between services
   - Validates data flow across components
   - Examples: Telegraf → InfluxDB data transfer, Alloy → Loki log forwarding

## Configuration File Structure

### `molecule/vars/capabilities.yml`

Central definition of all testable capabilities:

```yaml
monitoring_capabilities:
  logs:
    roles:
      - loki      # Log storage
      - alloy     # Log collection/forwarding

    required_packages:
      Debian: &debian_logs_deps
        - gpg
        - ca-certificates
        - lsof
      Rocky: *redhat_logs_deps

    verify_role_tasks:
      loki:
        - verify.yml       # Loki service health check
      alloy:
        - verify.yml       # Alloy service health check

    verify_tasks:
      - verify-logs.yml    # End-to-end log flow verification

    service_names:
      - loki
      - alloy

    service_ports:
      - 3100   # Loki HTTP
      - 12345  # Alloy metrics

  metrics:
    roles:
      - influxdb      # InfluxDB v2
      - influxdb3     # InfluxDB v3
      - telegraf      # Metrics collection

    verify_role_tasks:
      influxdb:
        - verify.yml               # Service health, API
      influxdb3:
        - verify.yml               # Service health, API
        - verify-collecting.yml    # Data collection validation

    verify_tasks:
      - verify-metrics.yml         # InfluxDB v2 integration
      - verify-metrics-v3.yml      # InfluxDB v3 integration

    service_names:
      - influxdb
      - influxdb3-core
      - telegraf

    service_ports:
      - 8086   # InfluxDB v2
      - 8181   # InfluxDB v3
```

### Key Fields

- **`roles`**: List of roles to deploy for this capability
- **`required_packages`**: Distribution-specific dependencies
- **`verify_role_tasks`**: Per-role verification tasks (run from role context)
- **`verify_tasks`**: Integration tests (run after all roles deployed)
- **`service_names`**: Systemd services to manage
- **`service_ports`**: Network ports to validate

## Test Platforms

### Podman (Container Testing)

**Location**: `molecule/podman/`

**Purpose**: Fast integration tests using systemd-enabled containers

**Characteristics**:
- Local execution (no external infrastructure needed)
- Multiple distributions tested in parallel
- Full systemd support (services, journald)
- Network isolation via podman network
- Fast iteration (containers start in seconds)

**Supported Distributions**:
- debian12 (Debian 12)
- debian13 (Debian 13)
- rocky9 (Rocky Linux 9)
- rocky10 (Rocky Linux 10)
- ubuntu24 (Ubuntu 24.04)

**Container Requirements**:
- Systemd as init (`/sbin/init`)
- SSH server running
- Python 3 installed
- Privileged mode for systemd
- `/sys/fs/cgroup` mounted

**Network Configuration**:
```yaml
network: "monitoring-net"
```

All test containers share a podman network, enabling inter-container communication for integration tests.

### Proxmox (VM Testing)

**Location**: `molecule/proxmox/`

**Purpose**: Production-like testing on full VMs

**Characteristics**:
- Real VMs cloned from cloud-init templates
- Complete OS environment (kernel, hardware)
- Slower but higher fidelity
- Tests VM provisioning workflow
- Validates cloud-init integration

**VM Creation Flow**:
1. Use `solti-platforms.proxmox_vm` role
2. Clone from distribution-specific template
3. Apply cloud-init configuration
4. Wait for cloud-init completion
5. Run capability deployment and verification

**Template Mapping**:
```yaml
ALL_DISTRIBUTIONS:
  - "rocky9:rocky9-template"
  - "rocky10:rocky10-template"
  - "debian12:debian-12-template"
  - "debian13:debian-13-template"
```

Templates are discovered dynamically using smart VMID ranges:
- Rocky templates: 7000-7999
- Debian templates: 8000-8999

## Molecule Scenarios

### Podman Scenario

**Run Command**:
```bash
cd solti-monitoring
molecule test -s podman
```

**Sequence**:
1. **destroy**: Clean up any existing containers
2. **create**: Launch systemd containers via podman
3. **prepare**: Install required packages, configure SSH
4. **converge**: Deploy roles based on `testing_capabilities`
5. **verify**: Run role-level and integration verification
6. **destroy**: Clean up containers

**Environment Variables**:
```bash
# Test specific capability
MOLECULE_CAPABILITIES=metrics molecule test -s podman

# Test specific distribution
MOLECULE_PLATFORM_NAME=debian12 molecule test -s podman

# Disable secure logging (show credentials in output)
MOLECULE_SECURE_LOGGING=false molecule test -s podman
```

### Proxmox Scenario

**Run Command**:
```bash
cd solti-monitoring
PROXMOX_DISTRO=debian12 ./run-proxmox-tests.sh
```

**Sequence**:
1. **destroy**: Delete test VMs if they exist
2. **create**: Clone VMs from templates
3. **prepare**: Wait for cloud-init, verify SSH
4. **converge**: Deploy roles
5. **verify**: Run verification tests
6. **destroy**: Delete test VMs

**Required Environment Variables**:
```bash
export PROXMOX_URL="https://proxmox.example.com:8006"
export PROXMOX_USER="root@pam"
export PROXMOX_TOKEN_ID="terraform"
export PROXMOX_TOKEN_SECRET="your-secret-here"
export PROXMOX_NODE="pve"
```

## Verification Architecture

### Phase 1: Role-Level Verification

Executed via `verify_role_tasks` - runs tasks from within role context.

**Example**: `roles/influxdb3/tasks/verify.yml`

```yaml
---
# Has access to all influxdb3 role variables
- name: Check InfluxDB v3 service status
  ansible.builtin.service_facts:

- name: Verify service is running
  ansible.builtin.assert:
    that:
      - "'influxdb3-core.service' in ansible_facts.services"
      - "ansible_facts.services['influxdb3-core.service'].state == 'running'"

- name: Test API health endpoint
  ansible.builtin.uri:
    url: "http://localhost:8181/health"
    status_code: 200
```

**Characteristics**:
- Access to role defaults and vars
- Tests service-specific functionality
- No assumptions about other services

### Phase 2: Integration Verification

Executed via `verify_tasks` - runs from molecule playbook context.

**Example**: `molecule/shared/verify/verify-metrics-v3.yml`

```yaml
---
# Tests data flow: Telegraf → InfluxDB v3
- name: Verify InfluxDB v3 system components
  block:
    - name: Check Telegraf connection to InfluxDB v3
      ansible.builtin.shell: "ss -tunp | grep ':8181.*telegraf'"
      register: connection_check

    - name: Write test data via InfluxDB v3 CLI
      ansible.builtin.shell: |
        export INFLUXDB3_AUTH_TOKEN="{{ admin_token }}"
        influxdb3 write --database telegraf "test,tag=molecule value=1.0"

    - name: Query test data back
      ansible.builtin.shell: |
        export INFLUXDB3_AUTH_TOKEN="{{ admin_token }}"
        influxdb3 query --database telegraf "SELECT * FROM test WHERE time > now() - INTERVAL '1 minute'"
      register: query_result

    - name: Verify data was stored
      ansible.builtin.assert:
        that:
          - query_result.rc == 0
          - query_result.stdout | length > 0
```

**Characteristics**:
- Tests interaction between services
- Validates complete data flow
- Uses real authentication tokens
- Checks network connectivity

### Verification Output

All verification results are saved to `verify_output/`:

```
verify_output/
├── debian12/
│   ├── influxdb3-verify-uut-ct0-1234567890.yml
│   ├── influxdb3-collecting-uut-ct0-1234567890.yml
│   ├── verify-metrics-v3-status-1234567890.yml
│   └── metrics-v3-collection-1234567890.yml
├── rocky9/
│   └── ...
└── debian12-consolidated-test-report.md
```

**Report Structure**:
- Per-role verification results (YAML)
- Integration test results (YAML)
- Consolidated markdown report (generated)
- Timestamped for test run tracking

## Capability Selection

Tests can be filtered by capability using `MOLECULE_CAPABILITIES`:

```bash
# Test only logs capability (Loki + Alloy)
MOLECULE_CAPABILITIES=logs molecule test -s podman

# Test only metrics capability (InfluxDB + Telegraf)
MOLECULE_CAPABILITIES=metrics molecule test -s podman

# Test both (default)
MOLECULE_CAPABILITIES=logs,metrics molecule test -s podman
```

This is controlled in `molecule.yml`:

```yaml
provisioner:
  inventory:
    group_vars:
      all:
        testing_capabilities: "{{ lookup('env', 'MOLECULE_CAPABILITIES', default='logs,metrics') | split(',') }}"
```

The converge playbook uses this to selectively deploy roles:

```yaml
# molecule/shared/converge.yml
- name: Deploy monitoring capabilities
  hosts: all
  tasks:
    - name: Include capability-specific roles
      include_role:
        name: "{{ role_item }}"
      loop: "{{ monitoring_capabilities[capability].roles }}"
      loop_control:
        loop_var: role_item
      when: capability in testing_capabilities
      vars:
        capability: "{{ item }}"
      with_items: "{{ testing_capabilities }}"
```

## Authentication in Tests

### Testing Mode vs Production

**Testing Mode** (`telegraf_testing: true`):
- Tokens auto-discovered from filesystem
- No pre-configuration needed
- InfluxDB v2: Read from `influx auth list`
- InfluxDB v3: Read from `/root/.influxdb3-credentials`

**Production Mode** (`telegraf_testing: false`):
- Tokens must be pre-configured in inventory
- Uses `telgraf2influxdb_configs` from group_vars
- No auto-discovery

### Secure Logging

All token operations use `secure_logging` variable:

```yaml
- name: Read admin token
  ansible.builtin.slurp:
    path: "/root/.influxdb3-credentials"
  register: admin_token_file
  no_log: "{{ secure_logging | default(true) }}"
```

**Default**: `true` (tokens hidden in logs)

**Debug Mode**:
```bash
MOLECULE_SECURE_LOGGING=false molecule test -s podman
```

Shows credential values in output for troubleshooting auth issues.

## InfluxDB v2 + v3 Dual Testing

The metrics capability tests **both** InfluxDB versions simultaneously:

**Why?**
- Tests migration/coexistence scenario
- Validates Telegraf can write to both
- Ensures no port/resource conflicts
- Real-world use case during transition

**Architecture**:
```
[Telegraf]
    ├─→ localhost (port 8086) → [InfluxDB v2]
    └─→ localhost_v3 (port 8181) → [InfluxDB v3]
```

**Configuration** (in `molecule/podman/molecule.yml`):
```yaml
telegraf_outputs: ['localhost', 'localhost_v3']

telgraf2influxdb_configs:
  localhost:  # InfluxDB v2
    url: "http://127.0.0.1"
    port: 8086
    token: ""  # Auto-discovered in testing mode
    bucket: "telegraf"
    org: "lavnet"

  localhost_v3:  # InfluxDB v3
    url: "http://127.0.0.1"
    port: 8181
    token: ""  # Auto-discovered in testing mode
    bucket: "telegraf"
    org: "lavnet"
```

**Separate Verification**:
- `verify-metrics.yml` - Tests InfluxDB v2 integration
- `verify-metrics-v3.yml` - Tests InfluxDB v3 integration

Each runs independently and reports success/failure separately.

## Test Execution Scripts

### `run-podman-tests.sh`

**Purpose**: Run podman molecule tests with capability selection

**Usage**:
```bash
cd solti-monitoring

# Test all capabilities (default)
./run-podman-tests.sh

# Test specific capability
./run-podman-tests.sh --tests logs
./run-podman-tests.sh --tests metrics
./run-podman-tests.sh -t logs,metrics

# Named test run
./run-podman-tests.sh --name my_test
```

**Options**:
- `-h, --help` - Display help
- `-t, --tests CAPS` - Specify capabilities (comma-separated, default: `logs,metrics`)
- `-n, --name NAME` - Specify test name (default: `podman`)

**What it does**:
1. Sources lab secrets (`~/.secrets/LabProvision`, `~/.secrets/LabGiteaToken`)
2. Validates capability names (must be `logs` or `metrics`)
3. Creates `verify_output/` directory
4. Exports `MOLECULE_CAPABILITIES` and `MOLECULE_TEST_NAME` environment variables
5. Activates Python venv (`solti-venv/` if present)
6. Runs `molecule test -s podman`
7. Logs all output to timestamped file: `verify_output/{test_name}-test-{timestamp}.out`
8. Creates symlink `verify_output/latest_test.out` to most recent log
9. Returns exit code 0 (success) or 1 (failure)

**Example Logs**:
```
verify_output/
├── podman-test-20250128-143022.out
├── logs-test-20250128-150315.out
├── latest_test.out -> podman-test-20250128-143022.out
└── debian12/
    └── ... (verification reports)
```

### `run-proxmox-tests.sh`

**Purpose**: Run Proxmox VM tests

**Usage**:
```bash
cd solti-monitoring
PROXMOX_DISTRO=debian12 ./run-proxmox-tests.sh
```

**Features**:
- Validates required environment variables
- Ensures clean state between runs
- Exports template variables for VM creation
- Logs to timestamped files
- Reports pass/fail summary

**Distribution Selection**:
```bash
# Test single distribution
PROXMOX_DISTRO=debian12 ./run-proxmox-tests.sh

# Test all distributions (default)
./run-proxmox-tests.sh
```

## GitHub Actions Integration

### Workflow: Podman Tests

**File**: `.github/workflows/podman-tests.yml`

**Triggers**:
- Push to `main` or `test` branch
- Pull requests
- Manual dispatch

**Matrix Strategy**:
```yaml
matrix:
  distribution: [debian12, rocky9, ubuntu24]
  capability: [logs, metrics]
```

Runs 6 test jobs (3 distros × 2 capabilities).

**Steps**:
1. Checkout code
2. Install podman
3. Install Python dependencies
4. Run molecule test
5. Upload verification reports as artifacts

### Workflow: Proxmox Tests

**File**: `.github/workflows/proxmox-tests.yml`

**Triggers**:
- Manual dispatch only (requires Proxmox access)
- Scheduled runs (nightly)

**Secrets Required**:
- `PROXMOX_URL`
- `PROXMOX_USER`
- `PROXMOX_TOKEN_ID`
- `PROXMOX_TOKEN_SECRET`
- `PROXMOX_NODE`

**Matrix Strategy**:
```yaml
matrix:
  distribution: [debian12, rocky9]
```

**Self-Hosted Runner**: Requires runner with Proxmox API access.

## Troubleshooting

### Common Issues

**1. Container fails to start with systemd errors**

```bash
# Check cgroup version
ls /sys/fs/cgroup/
# Should see: cgroup.controllers, cgroup.procs, etc.

# Verify podman version supports systemd
podman --version  # Need 3.0+
```

**Solution**: Use `cgroupns_mode: host` in molecule.yml

**2. SSH connection refused**

```bash
# Check if SSH is running in container
podman exec uut-ct0 systemctl status sshd

# Check SSH port mapping
podman port uut-ct0
```

**Solution**: Ensure container has SSH server installed and started.

**3. Authentication failures in tests**

```bash
# Enable debug logging
MOLECULE_SECURE_LOGGING=false molecule test -s podman
```

Check that tokens are being discovered:
- InfluxDB v2: `/usr/bin/influx auth list --json`
- InfluxDB v3: `/root/.influxdb3-credentials`

**4. Verification reports not generated**

Check `report_root` variable in molecule.yml:
```yaml
report_root: "{{ lookup('env', 'MOLECULE_PROJECT_DIRECTORY') }}/verify_output"
```

Ensure directory is created with correct permissions.

### Debug Mode

Run single phase for debugging:

```bash
# Just create and converge
molecule create -s podman
molecule converge -s podman

# Run verification manually
molecule verify -s podman

# Keep containers running for inspection
molecule converge -s podman
# (skips destroy)
podman exec -it uut-ct0 bash
```

## Best Practices

### 1. Idempotent Verification

Verification tasks should be idempotent - safe to run multiple times:

```yaml
# Good - idempotent check
- name: Query data
  command: influxdb3 query "SELECT COUNT(*) FROM cpu"
  changed_when: false

# Bad - creates data every run
- name: Write data
  command: influxdb3 write "test value=1"
```

### 2. Meaningful Assertions

Use descriptive failure messages:

```yaml
- name: Verify Telegraf connection
  assert:
    that:
      - connection_check.rc == 0
      - "'telegraf' in connection_check.stdout"
    fail_msg: "Telegraf not connected to InfluxDB v3 on port 8181"
    success_msg: "Telegraf successfully connected to InfluxDB v3"
```

### 3. Test Data Cleanup

Clean up test data in verification tasks:

```yaml
- name: Write test metric
  command: influxdb3 write "test value=1"

- name: Verify test metric exists
  command: influxdb3 query "SELECT * FROM test"

# Clean up not needed - molecules destroys everything
```

### 4. Distribution-Aware Tests

Use ansible facts for distribution-specific checks:

```yaml
- name: Check package manager
  assert:
    that:
      - "'apt' in ansible_facts.pkg_mgr"
  when: ansible_distribution == "Debian"
```

### 5. Report Structure

Save verification results with consistent naming:

```yaml
dest: "{{ report_root }}/{{ ansible_distribution | lower }}{{ ansible_distribution_major_version }}/{{ role_name }}-verify-{{ ansible_hostname }}-{{ ansible_date_time.epoch }}.yml"
```

Format: `{distro}{version}/{role}-{type}-{hostname}-{timestamp}.yml`

## Future Enhancements

### Planned Improvements

1. **Parallel Execution**: Run distribution tests concurrently
2. **Result Aggregation**: Unified test report across all platforms
3. **Performance Benchmarks**: Track metrics collection latency
4. **Chaos Testing**: Introduce failures, test recovery
5. **Extended Platforms**: Add Ubuntu, AlmaLinux support

### Under Consideration

- **Version Matrix**: Test multiple InfluxDB/Telegraf versions
- **Upgrade Testing**: Test version migration paths
- **Scale Testing**: Multi-host deployments in molecule
- **Notification Integration**: Mattermost alerts on test failures

## Related Documentation

- [METRICS_COLLECTION_STRATEGY.md](METRICS_COLLECTION_STRATEGY.md) - Overall monitoring architecture
- [molecule/vars/capabilities.yml](../molecule/vars/capabilities.yml) - Capability definitions
- [molecule/podman/molecule.yml](../molecule/podman/molecule.yml) - Podman scenario config
- [molecule/proxmox/molecule.yml](../molecule/proxmox/molecule.yml) - Proxmox scenario config

## References

- [Ansible Molecule](https://molecule.readthedocs.io/) - Testing framework
- [Podman](https://podman.io/) - Container runtime
- [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) - Virtualization platform
- [systemd in containers](https://systemd.io/CONTAINER_INTERFACE/) - Container requirements
