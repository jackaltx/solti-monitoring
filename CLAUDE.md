# CLAUDE.md - solti-monitoring Collection

Ansible collection for monitoring infrastructure (jackaltx.solti_monitoring). Provides metrics and log collection using Telegraf, InfluxDB, Alloy, and Loki, with fail2ban and WAZUH support.

## Repository Structure

**Nested Git Repository:** This is a standalone git repository within the parent jackaltx/ coordination repo.
- Parent: `/home/lavender/sandbox/ansible/jackaltx/` (multi-collection suite)
- This repo: `/home/lavender/sandbox/ansible/jackaltx/solti-monitoring/` (independent git history)
- Git operations here only affect solti-monitoring, not the parent coordination layer
- See `../CLAUDE.md` for parent repo context and integration points between collections

## Quick Start Workflow

### 1. Environment Setup
```bash
# Create and activate Python virtual environment
./prepare-solti-env.sh && source solti-venv/bin/activate
```

### 2. Development Testing (Podman - Fast)
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

### 3. Integration Testing (Proxmox - Full VMs)

**VM Template Requirements:**
- Minimum 8 CPU cores
- Minimum 16GB RAM
- Note: Cloning process does not modify template resource allocation

```bash
# All distros (Rocky, Debian)
./run-proxmox-tests.sh

# Single distro testing
PROXMOX_DISTRO=debian12 ./run-proxmox-tests.sh
PROXMOX_DISTRO=rocky9 ./run-proxmox-tests.sh
```

### 4. Iterative Development Cycle
```bash
source solti-venv/bin/activate

molecule create -s podman        # Create test containers once
molecule converge -s podman      # Apply changes (repeat as needed)
molecule verify -s podman        # Run verification
molecule destroy -s podman       # Clean up when done
```

## Git Checkpoint Workflow

**Create checkpoint commits before every test run.** This creates an audit trail of your debugging process and allows easy rollback to any working state.

### Recommended: Keep Checkpoints, Squash Before PR
```bash
# Development cycle - commit freely before each test
git add -A && git commit -m "checkpoint: add telegraf output config"
./run-podman-tests.sh  # Fails

git add -A && git commit -m "checkpoint: fix telegraf systemd path"
./run-podman-tests.sh  # Fails

git add -A && git commit -m "checkpoint: add missing telegraf plugin dep"
./run-podman-tests.sh  # Pass!

# Before PR: squash all checkpoints into clean commit
git rebase -i HEAD~3
# Mark commits as 'squash', write final message: "feat: add telegraf multi-output support"
```

**Why this approach:**
- Complete audit trail of what failed and why
- Easy rollback to any checkpoint: `git checkout HEAD~2`
- No pressure to get it right before committing
- Claude Code can analyze failure patterns across checkpoints
- Natural for complex molecule integration debugging

**Alternative (cleanup as you go):**
```bash
git commit -m "checkpoint: change"
./run-podman-tests.sh
# Pass: git commit --amend -m "feat: proper message"
# Fail: git reset --soft HEAD~1, continue fixing
```

## Test-Then-Deploy Workflow

**For orchestrator deployments, always test before deploying to production.**

This pattern uses test mode to validate configuration changes without disrupting the running service, then deploys only after successful validation.

### Example: Deploying Alloy Config Changes

From your orchestrator directory (e.g., `mylab/`):

```bash
# Step 1: Test configuration (writes to /tmp, no service restart)
ansible-playbook --become-password-file ~/.secrets/lavender.pass \
  ./playbooks/fleur/91-fleur-alloy-test.yml

# Review validation output:
# - ✓ VALIDATION: PASSED/FAILED
# - Configuration diff shows changes
# - Test config location displayed

# Step 2: Deploy to production (only if test passed)
ansible-playbook --become-password-file ~/.secrets/lavender.pass \
  ./playbooks/fleur/22-fleur-alloy.yml

# Service will restart with new configuration
```

### Creating Test Playbooks

Test playbooks set `alloy_test_mode: true` and include validation post-tasks:

```yaml
# playbooks/91-service-test.yml
- hosts: target_host
  vars:
    alloy_test_mode: true  # Config to /tmp, no restart
  roles:
    - jackaltx.solti_monitoring.alloy
  post_tasks:
    - name: Validate test config
      command: "alloy validate {{ alloy_test_config_path }}"
      register: validation
      failed_when: false

    - name: Compare with production
      command: "diff -u /etc/alloy/config.alloy {{ alloy_test_config_path }}"
      register: config_diff
      failed_when: false

    - name: Display results
      debug:
        msg: |
          {% if validation.rc == 0 %}✓ VALIDATION: PASSED{% else %}✗ VALIDATION: FAILED{% endif %}

          Config differs: {{ 'YES' if config_diff.rc != 0 else 'NO' }}

          Next: Deploy with playbooks/22-service-deploy.yml
```

### Benefits

- Catch syntax errors before production deployment
- See exact config changes via diff
- No service disruption during testing
- Safe rollback (test file in /tmp)
- Confidence before production changes

## Components

**Server Roles:**
- `influxdb` - Time-series database for metrics (S3/NFS support)
- `loki` - Log aggregation with label-based indexing

**Client Roles:**
- `telegraf` - Metrics collection agent (multi-output support)
- `alloy` - Log collector with systemd journal integration

**Security Roles:**
- `fail2ban_config` - Intrusion detection (Git-based config)
- `wazuh_agent` - Security monitoring

## Key Environment Variables

**Testing Control:**
- `LAB_DOMAIN` - Container registry domain (set in `~/.secrets/LabProvision`)
- `MOLECULE_CAPABILITIES` - Test scope: `logs`, `metrics`, or `logs,metrics` (default)
- `MOLECULE_PLATFORM_NAME` - Single platform: `uut-ct0` (Debian), `uut-ct1` (Rocky), `uut-ct2` (Ubuntu)
- `PROXMOX_DISTRO` - Single distro: `rocky` or `debian`

**Proxmox Requirements:**
- `PROXMOX_URL`, `PROXMOX_USER`, `PROXMOX_TOKEN_ID`, `PROXMOX_TOKEN_SECRET`, `PROXMOX_NODE`

## Molecule Scenarios

- `podman/` - Fast local container testing (development default)
- `github/` - CI testing with Podman containers (automated)
- `proxmox/` - Full VM integration testing (requires Proxmox env vars)

## State Management Pattern

All roles support consistent state control:
- `<service>_state: present|absent` - Install/remove service
- `<service>_delete_config: true|false` - Remove config on removal
- `<service>_delete_data: true|false` - Remove data on removal

## Verification Systems

This collection uses two distinct verification approaches:

### Development Verification (Molecule)

**Location:** `molecule/shared/verify/*.yml`
**Purpose:** CI/CD testing during collection development
**Usage:** `molecule verify -s podman`
**Runs in:** Test containers/VMs during molecule test cycle

This verification tests the collection itself during development.

### Operational Verification (Role Tasks)

**Location:** `roles/*/tasks/verify.yml`
**Purpose:** Production health checks post-deployment
**Usage:** Include in your orchestrator playbooks
**Runs on:** Live production systems

Example orchestrator playbook:
```yaml
- name: Verify alloy deployment
  hosts: monitoring_servers
  tasks:
    - include_role:
        name: jackaltx.solti_monitoring.alloy
        tasks_from: verify.yml
```

**Roles with operational verification:**
- `alloy`: verify.yml - Service status, Loki connectivity
- `loki`: verify.yml, verify1.yml - API health, storage checks
- `influxdb`: verify.yml - Database connectivity, bucket checks
- `wazuh_agent`: verify.yml - Agent registration, manager connectivity

**Verification results:** Molecule tests store results in `verify_output/<distribution>/`

## Key Directories

- `roles/` - Service roles and shared components
- `molecule/` - Test scenarios (github, podman, proxmox)
- `verify_output/` - Test results and verification reports
- `plugins/vars/` - Custom Ansible variables plugin

## Supported Platforms

- Debian 11/12 (primary)
- Rocky Linux 9 (experimental)
- Ubuntu 24.04 (via shared tasks)

---

## Production Usage

This collection provides roles for integration into your site-specific orchestration.

### Collection Installation

```bash
ansible-galaxy collection install jackaltx.solti_monitoring
```

### Basic Usage in Playbooks

```yaml
- hosts: monitoring_servers
  roles:
    - jackaltx.solti_monitoring.alloy
  vars:
    alloy_loki_endpoints:
      - label: loki01
        endpoint: "10.0.0.11"
```

### Recommended Orchestration Structure

Create a separate directory for your lab orchestration:

```text
your-lab/
├── inventory.yml           # Your hosts
├── playbooks/
│   ├── deploy-alloy.yml   # Deploy role
│   ├── verify-alloy.yml   # Run verify.yml tasks
│   └── test-alloy.yml     # Test mode playbook
└── group_vars/
    └── monitoring.yml      # Your variables
```

### Invoking Verification Tasks

```yaml
# playbooks/verify-alloy.yml
- hosts: monitoring_servers
  tasks:
    - include_role:
        name: jackaltx.solti_monitoring.alloy
        tasks_from: verify.yml
```

### Test Mode Example

Some roles support test mode for safe configuration validation:

```yaml
# playbooks/test-alloy.yml
- hosts: monitoring_servers
  become: true
  vars:
    alloy_test_mode: true  # Config to /tmp, no service restart
  roles:
    - jackaltx.solti_monitoring.alloy
  post_tasks:
    - name: Validate test config
      command: "alloy validate {{ alloy_test_config_path }}"
```

See individual role READMEs for role-specific features and variables.