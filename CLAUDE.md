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
```bash
# All distros (Rocky, Debian)
./run-proxmox-tests.sh

# Single distro testing
PROXMOX_DISTRO=debian ./run-proxmox-tests.sh
PROXMOX_DISTRO=rocky ./run-proxmox-tests.sh
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

## Verification System

Each role includes verification tasks:
- `verify` - Basic service functionality checks
- `verify1` - Extended integration verification
- Results stored in `verify_output/<distribution>/`

## Key Directories

- `roles/` - Service roles and shared components
- `molecule/` - Test scenarios (github, podman, proxmox)
- `verify_output/` - Test results and verification reports
- `plugins/vars/` - Custom Ansible variables plugin

## Supported Platforms

- Debian 11/12 (primary)
- Rocky Linux 9 (experimental)
- Ubuntu 24.04 (via shared tasks)