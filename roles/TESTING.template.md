# [ROLE_NAME] Role Testing Guide

## Quick Test Commands

### 1. Deploy Service

```bash
cd mylab
./manage-svc.sh [SERVICE_NAME] deploy
```

**Expected Results:**
- [List expected deployment outcomes]
- Service running and enabled
- Configuration files created
- Verification checks pass

### 2. Verify Deployment

```bash
# Automated verification
cd mylab
./svc-exec.sh [SERVICE_NAME] verify

# Manual checks
systemctl status [SERVICE_NAME]
[SERVICE_NAME] --version
```

**Expected Results:**
- Service status: `active (running)`
- Service enabled: `enabled`
- No errors in logs

### 3. Check Service Health

```bash
# Service-specific health checks
[Add service-specific commands]

# Check logs
journalctl -u [SERVICE_NAME] -n 100 | grep -i error
```

**Expected Results:**
- Health endpoints responding
- No errors in logs
- Service functioning as expected

## Configuration Architecture

### Configuration Files

```
/etc/[SERVICE_NAME]/
├── [SERVICE_NAME].yml           # Main configuration
├── [OTHER_CONFIGS]              # Additional config files
└── /var/lib/[SERVICE_NAME]/     # Data directory
```

### How Role Variables Map to Configuration

```yaml
# In inventory or playbook vars:
[variable_name]: [value]
  ↓
# Generates configuration:
  - [resulting_config_file_or_setting]
```

### Key Configuration Variables

**Core Variables:**
```yaml
[SERVICE_NAME]_state: present              # Install/remove control
[SERVICE_NAME]_version: latest             # Version to install
[SERVICE_NAME]_config_path: /etc/[...]     # Config file location
```

**Service-Specific Variables:**
```yaml
# Document critical variables here
[variable]: [description]
```

## Molecule Testing Scenarios

### Proxmox Scenario

```bash
cd solti-monitoring/roles/[ROLE_NAME]
molecule test -s proxmox
```

**Test Sequence:**
1. `destroy` - Remove any existing test VM
2. `create` - Clone Proxmox template, assign IP
3. `prepare` - Install dependencies, configure SSH
4. `converge` - Run [ROLE_NAME] role
5. `verify` - Check service status, config files, permissions
6. `destroy` - Cleanup test VM

**Environment Variables Required:**
```bash
export PROXMOX_VMID=9000          # Unique VM ID
export PROXMOX_TEMPLATE=rocky9    # rocky9, debian12, ubuntu24
export MOLECULE_IP=10.0.50.100    # Static IP for test VM
```

**What Gets Verified** ([molecule/proxmox/verify.yml](molecule/proxmox/verify.yml)):
- [ ] Service running and enabled
- [ ] Configuration files exist with correct permissions
- [ ] No errors in service startup
- [ ] Service responding to health checks
- [ ] Git commit information captured
- [ ] Test report generated in `verify_output/<distro>/`

## Service-Specific Testing

### Feature 1: [Feature Name]

**Enable in inventory:**
```yaml
[feature_variable]: true
```

**Creates/Configures:**
- [List what gets created or configured]

**Requirements:**
- [Prerequisites for this feature]

**Verification:**
```bash
# Commands to verify this feature works
[verification_commands]
```

**Expected Results:**
- [What should happen when working correctly]

### Feature 2: [Feature Name]

[Repeat structure for each major feature]

## Common Test Scenarios

### Scenario 1: Basic Deployment (localhost)

```yaml
# In inventory
[SERVICE_NAME]_[config]: [value]
```

**Deploy:**
```bash
cd mylab
./manage-svc.sh [SERVICE_NAME] deploy
```

**Verify:**
```bash
# Service running
systemctl is-active [SERVICE_NAME]

# Config generated
ls /etc/[SERVICE_NAME]/

# Service functioning
[service-specific checks]
```

### Scenario 2: [Another Common Scenario]

```yaml
# Configuration
[relevant_variables]
```

**Deploy:**
```bash
[deployment_commands]
```

**Verify:**
```bash
[verification_commands]
```

## Troubleshooting Tests

### Test 1: Configuration Validation

```bash
# Validate configuration
[command_to_validate_config]

# Expected: [what indicates valid config]
# Error example: [common error message]
```

### Test 2: Service Startup

```bash
# Check service status
systemctl status [SERVICE_NAME]

# If failed, check logs
journalctl -u [SERVICE_NAME] -n 50 --no-pager

# Common errors:
# - [error message]: [cause and fix]
```

### Test 3: [Service-Specific Test]

```bash
# Test commands
[test_commands]
```

**Expected:** [expected_results]

## Integration Testing

### With [Related Service]

```bash
# Deploy both services
./manage-svc.sh [related_service] deploy
./manage-svc.sh [SERVICE_NAME] deploy

# Verify integration
[integration_verification_commands]
```

**Expected:** [expected_integration_behavior]

## Verification Checklist

After deployment, verify:

- [ ] Service running: `systemctl is-active [SERVICE_NAME]`
- [ ] Service enabled: `systemctl is-enabled [SERVICE_NAME]`
- [ ] Config files exist with correct permissions
- [ ] No errors in logs: `journalctl -u [SERVICE_NAME] -n 50`
- [ ] Health endpoints responding
- [ ] [Service-specific checks]

## Performance Testing

### [Performance Metric 1]

```bash
# Commands to measure performance
[performance_test_commands]

# Expected: [acceptable_performance_range]
```

### Resource Usage

```bash
# Check service memory/CPU usage
ps aux | grep [SERVICE_NAME]
systemctl status [SERVICE_NAME] | grep Memory

# Expected: [expected_resource_usage]
```

## Debugging Tips

### Enable Debug Logging

```bash
# Method to enable debug logging for this service
[debug_enable_commands]

# Watch debug logs
journalctl -u [SERVICE_NAME] -f
```

### [Service-Specific Debug Technique]

```bash
# Debug commands
[debug_commands]
```

## Common Errors

### "[Common Error Message]"

**Cause:** [why this happens]

**Fix:**
```bash
# Commands to fix
[fix_commands]
```

### "[Another Common Error]"

**Cause:** [explanation]

**Fix:**
```bash
# Fix commands
[fix_commands]
```

## References

- [Service Documentation](https://example.com/docs)
- [Configuration Reference](https://example.com/config)
- [Role README](README.md)

## Notes

- [Important notes about this service]
- [Known limitations]
- [Special considerations for testing]
