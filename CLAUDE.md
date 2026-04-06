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

### 2. Testing Strategy: Unit vs Integration

**Unit Testing (Single Role):**

- Tests one role in isolation (e.g., influxdb3 deploy + verify)
- Uses orchestrator scripts (`manage-svc.sh`, `svc-exec.sh`)
- Fast iteration cycle
- Single target host (Podman container or VM)

**Integration Testing (Multiple Roles):**

- Tests role interactions (e.g., telegraf → influxdb3 end-to-end)
- Uses molecule scenarios
- Tests across multiple distributions
- Validates complete monitoring stack

**Development Workflow:**

```text
Phase 1 (Unit):     influxdb3 role → deploy → verify → iterate
Phase 2 (Integration): telegraf + influxdb3 → full stack test
```

### 3. Unit Testing with Orchestrator (Preferred for Role Development)

**For developing individual roles, use the orchestrator scripts directly instead of molecule.**

From the parent orchestrator directory (`/home/lavender/sandbox/ansible/jackaltx/mylab/`):

```bash
# Deploy a service role
./manage-svc.sh -h <target_host> <service> deploy

# Verify a service role
./svc-exec.sh -h <target_host> <service> verify

# Example: Test influxdb3 role on a Podman container or VM
./manage-svc.sh -h test-container influxdb3 deploy
./svc-exec.sh -h test-container influxdb3 verify
```

**Benefits of orchestrator-based unit testing:**

- Tests in your actual deployment environment
- Uses real inventory and secrets management
- No molecule overhead
- Same workflow you'll use in production
- Faster iteration cycle
- Single role focus (unit test)

**Setup requirements:**

1. Add service to `SUPPORTED_SERVICES` in `manage-svc.sh` and `svc-exec.sh`
2. Add `<service>_svc` host group to `mylab/inventory.yml`
3. Create role in `solti-monitoring/roles/<service>/`
4. Role must have `tasks/verify.yml` for verification

**When to use molecule instead:**

- Integration testing (multiple roles working together)
- Full stack testing (telegraf + influxdb + loki + alloy)
- Multi-distribution testing (Debian + Rocky + Ubuntu)
- CI/CD pipeline testing

### 3. Development Testing (Podman - Fast)

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
PROXMOX_DISTRO=rocky10 ./run-proxmox-tests.sh
PROXMOX_DISTRO=debian13 ./run-proxmox-tests.sh
```

**Recent Fixes (2026-04-01):**

- ✅ **Proxmox Obsidian Output:** Updated `molecule/proxmox/molecule.yml` to use shared verify playbook (`../shared/verify/main.yml`), enabling Obsidian vault output for Proxmox tests (matches podman behavior)
- ✅ **Test Failure Detection:** Fixed verify pipeline to properly fail tests when fatal errors occur (was silently passing despite errors in rescue block)
- ✅ **Template Selection:** Fixed `solti_platforms.proxmox_template` role to filter templates by name, ensuring correct OS version is cloned (e.g., debian12 now clones debian12-template, not debian13-template)
- ✅ **Metrics Verification:** Fixed `cpu_metric_count` undefined error in InfluxDB3 verify tasks by adding `| default(0)` filter to success message

**Architecture Notes:**

- Proxmox scenario uses **local playbooks** (create.yml, converge.yml, prepare.yml, destroy.yml) with newer template discovery logic
- **Shared verify playbook** used across all scenarios (podman, github, proxmox) for consistency
- Template discovery uses **unified VMID range 9000-9999** for all distributions, filtered by template name pattern

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

## Matrix Synapse and Caddy Log Collection (2026-02-08)

**Deployment:** matrix-web.jackaltx.com (manually provisioned server)

### Implementation

Added Alloy collection for Matrix Synapse homeserver and Caddy reverse proxy logs:

**Templates Created:**

- `roles/alloy/templates/caddy.alloy.j2` - File-based JSON access log collection (external + internal)
- `roles/alloy/templates/matrix-synapse.alloy.j2` - File-based text log collection with regex parsing
- `roles/alloy/templates/classifiers/caddy-journal-classifier.alloy.j2` - Journald TLS event collection

**Playbooks:**

- `mylab/playbooks/matrix-web/91-matrix-web-alloy-test.yml` - Test mode validation
- `mylab/playbooks/matrix-web/22-matrix-web-alloy.yml` - Production deployment

**Configuration:**

```yaml
# mylab/inventory.yml (matrix-web host)
alloy_monitor_caddy: true              # File-based Caddy access logs
alloy_monitor_caddy_journal: true      # Journald Caddy TLS/system logs
alloy_monitor_matrix_synapse: true     # File-based Matrix Synapse logs
alloy_additional_groups: [caddy, adm]  # Required for log file access
```

### Issues Encountered and Fixed

#### Issue 1: Loki Selector Syntax - Numeric Comparisons Not Supported

Initial implementation attempted to use numeric comparisons in selectors:

```hcl
stage.match {
  selector = "{duration>=1, duration<5}"  # ❌ Syntax error
}
```

**Error:** `parse error at line 1, col 10: syntax error: unexpected IDENTIFIER, expecting = or != or =~ or !~`

**Resolution:** Removed performance classification stages. Duration kept in logs for LogQL queries:

```logql
{service_type="caddy"} | json | duration > 1  # ✓ Works in query
```

#### Issue 2: Regex Escaping in Selectors

Initial regex patterns used single-escaped dots:

```hcl
selector = "{module=~\"synapse\\.storage\\..*\"}"  # ❌ Invalid char escape
```

**Error:** `parse error at line 1, col 10: invalid char escape`

**Resolution:** Double-escape backslashes in selectors:

```hcl
selector = "{module=~\"synapse\\\\.storage\\\\..*\"}"  # ✓ Correct escaping
```

**Lesson Learned:** Alloy selectors require different escaping than stage.regex expressions.

### Current Status

✅ **Working:**

- Alloy service running on matrix-web
- Tailing 3 log files: Caddy external, Caddy internal, Matrix Synapse homeserver
- Logs appearing in Loki with labels:
  - `service_type="caddy"`
  - `service_type="matrix_synapse"`
- Caddy path categorization working
- Status classification working (2xx, 3xx, 4xx, 5xx)
- Security event detection working

⚠️ **Known Issue (Low Priority):**

Matrix Synapse module grouping regexes not matching correctly - all logs classified as `module_group="other"` instead of proper categories (storage, federation, handlers, http, api, auth, util, app).

**Tracking:** GitHub issue created in solti-monitoring repository

**Priority:** Low - core log collection working, classification is enhancement

**Future:** Will address after automated Matrix chat integration

### Deployment Commands

```bash
cd /home/lavender/sandbox/ansible/jackaltx/mylab

# Test configuration
ansible-playbook --become-password-file ~/.secrets/lavender.pass \
  playbooks/matrix-web/91-matrix-web-alloy-test.yml

# Deploy to production
ansible-playbook --become-password-file ~/.secrets/lavender.pass \
  playbooks/matrix-web/22-matrix-web-alloy.yml
```

### Verification

```bash
# Check service status
ssh matrix-web.jackaltx.com 'systemctl status alloy'

# Verify labels in Loki
curl -s "http://monitor11.a0a0.org:3100/loki/api/v1/label/service_type/values" | jq -r '.data[]'

# Query logs
{service_type="caddy", path_category="static"}
{service_type="matrix_synapse", module_group="other"}
```

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

- `LAB_TLD` - Container registry domain (set in `~/.secrets/LabProvision`)
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

## Test Results as Obsidian Vault (Event-Sourced Architecture)

### Overview

Test results are automatically published to an Obsidian-compatible knowledge vault. This creates a browsable wiki of test history with cross-linked navigation by time, distribution, and capability.

**Architecture Pattern: Event Sourcing**

- **Test runs are immutable events** (source of truth)
- **Indices are derived views** (regenerated post-test)
- **No concurrent writes** (eliminates race conditions)
- **Self-healing** (indices always reflect actual runs)

### File Structure

```text
verify_output/obsidian/
├── README.md                    # Map of Content (navigation hub)
├── index.md                     # Chronological index (newest first)
├── Debian-12-Index.md           # Distribution-specific index
├── Rocky-9-Index.md             # Distribution-specific index
├── Ubuntu-24-Index.md           # Distribution-specific index
├── Logs-Capability.md           # Capability-specific index
├── Metrics-Capability.md        # Capability-specific index
└── runs/                        # Immutable test run records
    ├── 2026-03-29-debian12-190008/
    │   ├── run-2026-03-29T190008Z.md       # Test run overview
    │   ├── logs-capability.md               # Logs verification detail
    │   ├── metrics-capability.md            # Metrics verification detail
    │   ├── preverify-diagnostics.md         # Pre-test system state
    │   └── postverify-diagnostics.md        # Post-test system state
    └── 2026-03-29-rocky9-190008/
        └── ...
```

### Navigation Patterns

**From README.md:**

- [[index|Chronological Index]] - All runs by time
- [[Debian-12-Index|Debian 12 Tests]] - Debian 12 history
- [[Logs-Capability|Logs Verification]] - Logs test history

**From index.md:**

- Links to individual test runs: [[runs/2026-03-29-debian12-190008/run-2026-03-29T190008Z|Debian 12]]

**From test run:**

- Links back to indices and to capability details

### How It Works (Event Sourcing)

**Step 1: Test Execution Creates Immutable Run Records**

During molecule verify phase, each test creates:

- `runs/{timestamp}/run-{timestamp}.md` - Test run metadata in YAML frontmatter
- `runs/{timestamp}/{capability}-capability.md` - Capability verification details
- `runs/{timestamp}/preverify-diagnostics.md` - Pre-test diagnostics
- `runs/{timestamp}/postverify-diagnostics.md` - Post-test diagnostics

**Step 2: Post-Test Index Regeneration**

After all tests complete, `bin/regenerate-obsidian-indices.sh` scans run records and generates:

- Chronological index (sorted by timestamp, newest first)
- Distribution-specific indices (grouped by distro)
- Capability-specific indices (grouped by capability, then by distro)

**Key Principle:** If an index file gets corrupted or out of sync, just regenerate from runs/.

### Integration with Test Runners

**Podman Tests (run-podman-tests.sh):**

```bash
./run-podman-tests.sh  # Runs 4 parallel containers

# After molecule completes:
# 1. Regenerates Obsidian indices from runs/
# 2. Optionally syncs to NFS mount for Obsidian server
```

**Proxmox Tests (run-proxmox-tests.sh):**

```bash
./run-proxmox-tests.sh  # Runs distros sequentially

# After all distros complete:
# 1. Regenerates Obsidian indices from runs/
```

**GitHub CI (.github/workflows/ci.yml):**

After test matrix completes, workflow regenerates indices before uploading artifacts.

### NFS Sync Configuration (Optional)

To sync results to an Obsidian vault on NFS:

```bash
# Configure NFS sync environment
source bin/setup-nfs-sync.sh

# Variables set:
export OBSIDIAN_SYNC_ENABLED=true
export OBSIDIAN_NFS_MOUNT=/mnt/SoltiMonitorTesting
export OBSIDIAN_NFS_UID=568
export OBSIDIAN_NFS_GID=568
export OBSIDIAN_SSH_HOST=lavadmin@truenas.jackaltx.com
export OBSIDIAN_REMOTE_PATH=/mnt/zpool/Docker/Stacks/obsidian/SoltiMonitorTesting

# Run tests with sync
./run-podman-tests.sh
```

**How sync works:**

1. Tests run and write to local `verify_output/obsidian/`
2. Indices regenerated via `bin/regenerate-obsidian-indices.sh`
3. Files synced to NFS mount via rsync (no sudo needed)
4. Ownership fixed remotely via SSH: `ssh lavadmin@truenas "sudo chown -R 568:568 ..."`

**Benefits:**

- No local sudo required
- NFS-safe atomic writes (temp file + mv)
- Obsidian server sees complete indices instantly
- Works with TrueNAS or any NFS share

### Manual Index Regeneration

If indices become corrupted or you prune old test runs:

```bash
# Regenerate all indices from immutable run records
./bin/regenerate-obsidian-indices.sh verify_output/obsidian

# Indices rebuilt from source of truth (runs/ directories)
```

**This is safe and idempotent.** Run it anytime to fix indices.

### Why Event Sourcing Eliminates Race Conditions

**Old Approach (Had Race Conditions):**

- 4 parallel tests all write to shared `index.md` during verify phase
- Used `flock` for locking, but still saw corruption
- Indices could get out of sync with reality

**New Approach (Event Sourced):**

- Each test writes only its own `runs/{timestamp}/` directory (no conflicts)
- Single writer regenerates indices **after** all tests complete (no races)
- Indices are views derived from immutable events

**Result:** Works reliably with 4+ parallel test executions.

### Viewing Results in Obsidian

1. Open Obsidian vault pointing to `verify_output/obsidian/`
2. Start with README.md (Map of Content)
3. Follow wiki-links to navigate by time, distribution, or capability
4. All test runs cross-linked with YAML frontmatter for Dataview queries

**Example Dataview Query (Future):**

```dataview
TABLE overall_status, duration_seconds
FROM "runs"
WHERE distribution = "Rocky 9"
SORT timestamp DESC
LIMIT 10
```

### Future Enhancements

**Pre-Event Metadata (Planned):**

- Capture CLI invocation (command line, environment vars)
- Record test parameters (MOLECULE_CAPABILITIES, MOLECULE_PLATFORM_NAME)
- Store start timestamp in YAML frontmatter

**Post-Event Metrics (Planned):**

- Test duration (total, converge, verify phases)
- Resource usage (peak memory, CPU)
- Exit codes and error counts

**Analytics (Future):**

- Success rate trends by distribution
- Performance regression detection
- Duration analysis and outlier identification

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
