# Development Workflow Guide

Guide for evolving the solti-monitoring collection while maintaining stability. Covers adding new features, testing incremental changes, and integrating new capabilities.

## The Challenge

You're working on a mature Ansible collection that needs to:
- Keep existing functionality working (logs, metrics collection)
- Add new features (InfluxDB v3 S3 storage, SSL configurations)
- Develop complex integrations (Alloy-Fail2ban feedback)
- Test intermediate "broken" states before reaching "working" state

**Core principle**: Don't break what works while developing what's new.

## Development Patterns

### Pattern 1: Adding New Capabilities

New features should be added as new capabilities in the molecule test framework.

**Example: InfluxDB S3 Tiered Storage**

1. **Add capability definition** to `molecule/vars/capabilities.yml`:
```yaml
monitoring_capabilities:
  # Existing capabilities
  metrics:
    roles: [influxdb, telegraf]
    # ...

  # New capability for S3 testing
  influxdb_s3:
    roles: [influxdb]
    required_packages:
      - name: s3cmd
        state: present
    verify_tasks:
      - verify-influxdb-s3.yml
    service_names: [influxdb]
    service_ports: [8086]
```

2. **Create verification tasks** in `molecule/shared/verify/verify-influxdb-s3.yml`:
```yaml
---
- name: Check S3 bucket configuration
  command: influx bucket list --json
  register: bucket_list

- name: Verify S3 backend is configured
  assert:
    that:
      - "'s3' in bucket_list.stdout"
    fail_msg: "S3 backend not configured"
```

3. **Add role variables** for the new feature:
```yaml
# roles/influxdb/defaults/main.yml
influxdb_s3_enabled: false  # Default: disabled
influxdb_s3_bucket: ""
influxdb_s3_endpoint: ""
influxdb_s3_retention_days: 90
```

4. **Test the new capability independently**:
```bash
# Test only S3 capability
MOLECULE_CAPABILITIES=influxdb_s3 molecule converge -s podman
MOLECULE_CAPABILITIES=influxdb_s3 molecule verify -s podman

# Test S3 + standard metrics together
MOLECULE_CAPABILITIES=metrics,influxdb_s3 molecule test -s podman
```

**Benefits:**
- Existing `metrics` capability continues to work
- S3 functionality is tested separately
- Can be combined with other capabilities when ready
- Easy to enable/disable via environment variable

### Pattern 2: Iterative "Broken → Working" Development

Some features require multiple steps to become functional. SSL is a perfect example - you need certs, configuration, and client setup, but intermediate states don't work.

**Example: InfluxDB SSL Configuration**

**The Problem**: SSL requires:
1. Certificate generation
2. InfluxDB SSL configuration
3. Client-side SSL verification
4. Testing with actual SSL connections

None of these work independently - you need all pieces before verification passes.

**The Solution**: Progressive testing with checkpoint commits

```bash
# Start with clean state
molecule create -s podman

# Step 1: Add certificate generation
# Edit roles/influxdb/tasks/certificates.yml
git add -A && git commit -m "checkpoint: add SSL cert generation"

MOLECULE_CAPABILITIES=influxdb_ssl molecule converge -s podman
# EXPECTED TO FAIL - certs exist but influxdb not configured

# Debug: Shell into container to examine state
podman exec -it uut-ct0 /bin/bash
ls -la /etc/influxdb/certs/
# Document what you find, what's missing

# Step 2: Configure InfluxDB for SSL
# Edit roles/influxdb/templates/config.toml.j2
git add -A && git commit -m "checkpoint: influxdb SSL config"

molecule converge -s podman
# Still may fail - need client configuration

# Step 3: Update client configurations (telegraf, etc)
# Edit roles/telegraf/templates/telegraf.conf.j2
git add -A && git commit -m "checkpoint: telegraf SSL client config"

molecule converge -s podman
# Should work now!

# Step 4: Verify everything works
molecule verify -s podman
# If passes: squash the checkpoint commits

git rebase -i HEAD~3  # Squash 3 commits
# Final commit: "feat: add SSL support for InfluxDB and clients"
```

**Key practices:**
- Checkpoint commit before EVERY test run
- Container preserved on failure for debugging
- Document what you learn in commit messages
- Squash checkpoints only after verify passes
- Each checkpoint represents a hypothesis about what's needed

### Pattern 3: Component Integration Testing

When developing features that bridge existing components, test each component separately first, then test the integration.

**Example: Alloy-Fail2ban Log Filtering Integration**

**Scenario**: You want Alloy to send fail2ban logs to Loki with specific filtering/labels.

```bash
# Phase 1: Test components independently
# Verify alloy works with current configuration
MOLECULE_CAPABILITIES=logs molecule converge -s podman
MOLECULE_CAPABILITIES=logs molecule verify -s podman

# Verify fail2ban works (if you have a fail2ban role)
MOLECULE_CAPABILITIES=fail2ban molecule converge -s podman
MOLECULE_CAPABILITIES=fail2ban molecule verify -s podman

# Phase 2: Add integration capability
# Edit molecule/vars/capabilities.yml
```

Add new capability:
```yaml
monitoring_capabilities:
  logs_fail2ban:
    roles: [loki, alloy, fail2ban_config]
    verify_tasks:
      - verify-logs.yml
      - verify-fail2ban-integration.yml
    service_names: [loki, alloy, fail2ban]
    service_ports: [3100, 12345]
```

Create integration verification:
```yaml
# molecule/shared/verify/verify-fail2ban-integration.yml
---
- name: Trigger fail2ban event
  command: fail2ban-client set sshd banip 192.0.2.1

- name: Wait for log propagation
  pause:
    seconds: 5

- name: Query Loki for fail2ban logs
  uri:
    url: "http://localhost:3100/loki/api/v1/query"
    method: GET
    body_format: json
    body:
      query: '{job="fail2ban"} |= "192.0.2.1"'
  register: loki_query

- name: Verify fail2ban log was received
  assert:
    that:
      - loki_query.json.data.result | length > 0
    fail_msg: "Fail2ban logs not found in Loki"
```

Test the integration:
```bash
# Test full integration
MOLECULE_CAPABILITIES=logs_fail2ban molecule converge -s podman
MOLECULE_CAPABILITIES=logs_fail2ban molecule verify -s podman

# Test all logging capabilities together
MOLECULE_CAPABILITIES=logs,logs_fail2ban molecule test -s podman
```

**Benefits:**
- Components tested separately first (reduces debugging surface)
- Integration testing is explicit and repeatable
- Verification codifies expected behavior
- Can test with/without integration easily

### Pattern 4: Test-Driven Development with Molecule

Write verification tasks FIRST, then implement the feature. The verify tasks document expected behavior and give you a clear target.

**Example: S3 Tiered Storage**

```bash
# Step 1: Write verification tasks (RED)
# Create molecule/shared/verify/verify-influxdb-s3.yml
# Even though feature doesn't exist yet

molecule verify -s podman
# FAILS - Expected! This is your todo list

# Step 2: Implement feature (GREEN)
# Edit roles/influxdb/tasks/s3-storage.yml
# Edit roles/influxdb/templates/config.toml.j2

molecule converge -s podman
molecule verify -s podman
# PASSES - Feature complete

# Step 3: Refactor (if needed)
# Clean up code, improve error handling
# Tests keep passing throughout
```

**Benefits:**
- Verification tasks serve as specification
- Clear definition of "done"
- Catches regressions immediately
- Forces you to think about testability upfront

## Feature Stability Strategies

### Strategy 1: Feature Flags (Recommended)

Use Ansible variables to control new/experimental features.

```yaml
# roles/influxdb/defaults/main.yml
influxdb_s3_enabled: false        # Default: stable path
influxdb_ssl_enabled: false       # Default: no SSL
influxdb_v3_features: false       # Default: v2 behavior
```

In molecule testing:
```yaml
# molecule/podman/molecule.yml - stable tests
provisioner:
  inventory:
    group_vars:
      all:
        influxdb_s3_enabled: false  # Test stable path

# molecule/experimental/molecule.yml - new features
provisioner:
  inventory:
    group_vars:
      all:
        influxdb_s3_enabled: true   # Test experimental
```

**Benefits:**
- Main branch always has working code
- Features can be developed incrementally
- Easy to enable for testing
- Production defaults to stable

### Strategy 2: Separate Capabilities

Keep experimental features as separate capabilities that don't run by default.

```yaml
# molecule/vars/capabilities.yml
monitoring_capabilities:
  metrics:           # Stable, always tested
    roles: [influxdb, telegraf]

  metrics_experimental:  # Experimental, opt-in
    roles: [influxdb, telegraf]
    # ... different config for testing new features
```

Default testing uses stable capabilities:
```bash
# CI/CD runs this (stable only)
./run-podman-tests.sh  # Uses MOLECULE_CAPABILITIES=logs,metrics

# Developer tests experimental
MOLECULE_CAPABILITIES=metrics_experimental ./run-podman-tests.sh
```

### Strategy 3: Branch Discipline

- `main` branch: All tests must pass
- Feature branches: Tests can fail during development
- Use checkpoint commits freely on feature branches
- Squash before merging to main

```bash
# On feature branch
git checkout -b feature/influxdb-ssl
# Checkpoint commits, failing tests OK
git commit -m "checkpoint: trying cert generation approach"
molecule converge  # May fail, that's OK

# Before merging
git rebase -i main  # Squash checkpoints
molecule test      # Must pass now
git checkout main && git merge feature/influxdb-ssl
```

## Slash Command Workflows

Use the slash commands for different development stages:

### `/test-quick` - Rapid Iteration (30-60 sec)
**Use when:**
- Making small changes to role tasks
- Fixing syntax errors
- Testing if code installs

**What it does:**
- Creates container (first time only)
- Runs converge only (no verify)
- Auto-destroys on success
- Keeps container on failure for debugging

**Example workflow:**
```bash
# 1. Edit role
vim roles/influxdb/tasks/main.yml

# 2. Quick smoke test
/test-quick
# If fails: container kept for debugging
podman exec -it uut-ct0 /bin/bash

# 3. Fix and repeat
vim roles/influxdb/tasks/main.yml
/test-quick
```

### `/test-podman` - Full Testing (5-15 min)
**Use when:**
- Ready for full verification
- Testing specific capability/distro
- Before pushing code

**Examples:**
```bash
# Test specific capability on one distro
/test-podman debian logs

# Test all distros with metrics
/test-podman all metrics

# Test everything (full integration)
/test-podman
```

### `/test-proxmox` - Final Validation (10-20 min)
**Use when:**
- Final validation before PR
- Testing on actual VMs
- Verifying distro-specific behavior

**Example:**
```bash
# Test on Proxmox VMs (closer to production)
/test-proxmox debian
```

## Real-World Examples

### Example 1: Adding InfluxDB v3 S3 Storage

```bash
# 1. Create feature branch
git checkout -b feature/influxdb-v3-s3

# 2. Add capability to molecule/vars/capabilities.yml
# Add influxdb_s3 capability

# 3. Write verification tasks (TDD)
# Create molecule/shared/verify/verify-influxdb-s3.yml

# 4. Implement feature with checkpoints
vim roles/influxdb/tasks/s3-storage.yml
git commit -m "checkpoint: add s3 configuration tasks"
MOLECULE_CAPABILITIES=influxdb_s3 /test-quick

# 5. Iterate until converge passes
vim roles/influxdb/templates/config.toml.j2
git commit -m "checkpoint: add s3 config template"
MOLECULE_CAPABILITIES=influxdb_s3 /test-quick

# 6. Run verification
MOLECULE_CAPABILITIES=influxdb_s3 molecule verify -s podman

# 7. Test with existing capabilities
MOLECULE_CAPABILITIES=metrics,influxdb_s3 /test-podman debian

# 8. Squash and merge
git rebase -i main
/test-podman  # All tests pass
git checkout main && git merge feature/influxdb-v3-s3
```

### Example 2: Debugging SSL Configuration

```bash
# SSL requires multiple components - expect failures

# 1. Start development
git checkout -b feature/influxdb-ssl
molecule create -s podman

# 2. Add cert generation
vim roles/influxdb/tasks/certificates.yml
git commit -m "checkpoint: add cert generation"
MOLECULE_CAPABILITIES=influxdb_ssl molecule converge -s podman
# FAILS - expected

# 3. Debug in container
podman exec -it uut-ct0 /bin/bash
ls -la /etc/influxdb/certs/
openssl x509 -in /etc/influxdb/certs/server.crt -text -noout
# Take notes on what's missing

# 4. Fix influxdb config
vim roles/influxdb/templates/config.toml.j2
git commit -m "checkpoint: enable SSL in influxdb config"
molecule converge -s podman
# Still fails, but different error - progress!

# 5. Update client (telegraf)
vim roles/telegraf/templates/telegraf.conf.j2
git commit -m "checkpoint: telegraf SSL client config"
molecule converge -s podman
# SUCCESS!

# 6. Verify
molecule verify -s podman

# 7. Clean up and merge
git rebase -i HEAD~3  # Squash 3 checkpoints
# Final commit: "feat: add SSL support for InfluxDB"
```

### Example 3: Alloy-Fail2ban Integration

```bash
# 1. Test components separately
MOLECULE_CAPABILITIES=logs /test-podman debian
# Alloy works ✓

# 2. Add integration capability
# Edit molecule/vars/capabilities.yml
# Add logs_fail2ban capability

# 3. Write integration verification
# Create verify-fail2ban-integration.yml

# 4. Configure alloy for fail2ban logs
vim roles/alloy/templates/config.alloy.j2
git commit -m "checkpoint: add fail2ban log source"
MOLECULE_CAPABILITIES=logs_fail2ban /test-quick

# 5. Test integration
MOLECULE_CAPABILITIES=logs_fail2ban molecule verify -s podman

# 6. Full integration test
MOLECULE_CAPABILITIES=logs,logs_fail2ban /test-podman all
```

## Tips and Best Practices

### Checkpoint Commits
- Commit before EVERY test run
- Include what you're trying in the message
- Don't worry about commit quality during development
- Squash before PR

### Container Debugging
When converge fails, container is kept. Use:
```bash
# Shell into container
podman exec -it uut-ct0 /bin/bash

# Check service status
systemctl status influxdb

# View logs
journalctl -u influxdb -n 50

# Test connectivity
curl -v http://localhost:8086/health

# Check config files
cat /etc/influxdb/config.toml
```

### Molecule Commands
```bash
# Individual phases for maximum control
molecule create -s podman      # Create containers
molecule converge -s podman    # Apply roles
molecule verify -s podman      # Run verification
molecule destroy -s podman     # Clean up

# Full test cycle
molecule test -s podman        # All phases

# List container status
molecule list -s podman
```

### Environment Variables
```bash
# Test single platform
MOLECULE_PLATFORM_NAME=uut-ct0 molecule converge -s podman

# Test specific capabilities
MOLECULE_CAPABILITIES=logs molecule converge -s podman

# Combine
MOLECULE_PLATFORM_NAME=uut-ct0 \
  MOLECULE_CAPABILITIES=influxdb_s3 \
  molecule converge -s podman
```

## Summary

**For mature projects**, the key is maintaining stability while evolving:

1. **Use capabilities** to separate stable from experimental
2. **Feature flags** for gradual rollout
3. **Checkpoint commits** for debugging trail
4. **Progressive testing** - it's OK to fail during development
5. **TDD approach** - write verify tasks first
6. **Branch discipline** - main stays green

**The workflow:**
- New feature → new capability
- Write verify tasks → implement → iterate
- Use `/test-quick` for rapid feedback
- Use `/test-podman` for integration
- Checkpoint commits throughout
- Squash before merge

This keeps production code stable while giving you freedom to experiment and debug complex multi-step features.

---

## Development Helper Scripts

For rapid iteration during collection development, helper scripts are available in the parent repository.

### manage-svc.sh - Quick Role Deployment Testing

```bash
# Deploy a role to test host
../mylab/manage-svc.sh alloy deploy

# Remove role from test host
../mylab/manage-svc.sh alloy remove

# Target specific host
../mylab/manage-svc.sh -h testhost alloy deploy
```

### svc-exec.sh - Execute Specific Role Tasks

```bash
# Run verification tasks
../mylab/svc-exec.sh alloy verify

# Run extended verification
../mylab/svc-exec.sh alloy verify1

# Target specific host
../mylab/svc-exec.sh -h testhost alloy verify
```

### Purpose and Usage

**Note:** These scripts are development tools for building/testing the collection, not for end users.

**What these scripts do:**
- Generate temporary playbooks dynamically
- Invoke roles with specific `tasks_from` entries
- Quick iteration without writing full playbooks
- Useful during molecule development cycles
- Rapid testing of verify.yml and other task files

**When to use them:**
- Testing a role change on a real host quickly
- Invoking verify.yml tasks during development
- Iterating on role features without full playbook structure

**Production equivalent:**

End users should create their own orchestration playbooks using standard Ansible patterns.

Instead of `../mylab/svc-exec.sh alloy verify`, production users create:

```yaml
# your-lab/playbooks/verify-alloy.yml
- hosts: monitoring_servers
  tasks:
    - include_role:
        name: jackaltx.solti_monitoring.alloy
        tasks_from: verify.yml
```

This gives users control over inventory, variables, and integration with their existing Ansible infrastructure.
