# /test-podman - Fast Container Integration Testing

## Purpose
Run integration tests using Podman containers for rapid development and testing. Tests the solti-monitoring collection roles across multiple distributions.

## Parameters
The command accepts up to 3 parameters:
1. **Distro** (optional): `all` (default), `debian`, `rocky`, `ubuntu`
2. **Capabilities** (optional): `all` (default), `logs`, `metrics`
3. **Mode** (optional): `full` (default), `iterative`

## Process

### 1. Parse Parameters
- Extract distro, capabilities, and mode from user input
- Set defaults: distro=all, capabilities=all, mode=full
- Map distro names to platform names:
  - `debian` → `MOLECULE_PLATFORM_NAME=uut-ct0`
  - `rocky` → `MOLECULE_PLATFORM_NAME=uut-ct1`
  - `ubuntu` → `MOLECULE_PLATFORM_NAME=uut-ct2`
  - `all` → unset (tests all platforms)
- Map capabilities:
  - `logs` → `MOLECULE_CAPABILITIES=logs`
  - `metrics` → `MOLECULE_CAPABILITIES=metrics`
  - `all` → `MOLECULE_CAPABILITIES=logs,metrics`

### 2. Validate Environment
- Ensure we're in the solti-monitoring directory
- Check if `run-podman-tests.sh` exists
- Verify `~/.secrets/LabProvision` exists (required for LAB_DOMAIN)

### 3. Display Test Configuration
Show the user what will be tested:
```
Running Podman integration tests:
- Distro: [debian/rocky/ubuntu/all]
- Capabilities: [logs/metrics/logs,metrics]
- Mode: [full/iterative]
```

### 4. Execute Tests
**For full mode:**
- Run: `./run-podman-tests.sh` (or with env vars set)
- Script automatically activates venv, runs `molecule test -s podman`
- Test sequence: dependency → cleanup → destroy → syntax → create → prepare → converge → idempotence → side_effect → verify → cleanup → destroy

**For iterative mode:**
- Run molecule commands individually for faster development:
  - `molecule create -s podman` (if containers don't exist)
  - `molecule converge -s podman` (apply changes)
  - `molecule verify -s podman` (run verification)
- Skip destroy for faster iteration
- User can run converge multiple times as they make changes

### 5. Report Results
- Show test output summary
- Report log file location: `verify_output/integration_test_*.out`
- Show symlink to latest: `verify_output/latest_test.out`
- On failure: suggest examining the log file and verification output

## Usage Examples

```bash
# Test all distributions with all capabilities (full test)
/test-podman

# Test only Debian with logs and metrics
/test-podman debian

# Test only Rocky with metrics capability
/test-podman rocky metrics

# Test Ubuntu in iterative mode (no destroy)
/test-podman ubuntu all iterative

# Test all distros with logs only
/test-podman all logs
```

## Prerequisites
- Python virtual environment (solti-venv) with molecule installed
- LAB_DOMAIN set in `~/.secrets/LabProvision`
- Podman installed and accessible
- Testing container images available in registry

## Expected Behavior
- Full mode: Complete test cycle including cleanup (5-15 minutes)
- Iterative mode: Quick converge+verify for rapid changes (1-3 minutes)
- Creates detailed logs in `verify_output/` directory
- Returns success/failure status

## Notes
- The script `run-podman-tests.sh` handles venv activation automatically
- For iterative development, use iterative mode and run converge multiple times
- Containers persist in iterative mode - use `molecule destroy -s podman` to clean up
- Each platform runs on different SSH port: debian=2223, rocky=2222, ubuntu=2224
