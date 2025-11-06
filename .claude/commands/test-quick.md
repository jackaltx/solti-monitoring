# /test-quick - Rapid Smoke Testing

## Purpose
Ultra-fast smoke testing for rapid development. Only runs converge (install/configure) on Podman/Debian - skips verification phase. Perfect for quick "does it install?" checks during active development.

## Parameters
None - uses sensible defaults for rapid iteration

## Process

### 1. Offer Checkpoint Commit
Before running tests, ask if the user wants to create a checkpoint commit:
```
Create checkpoint commit before testing? (recommended)
- Yes: git add -A && git commit -m "checkpoint: [description]"
- No: Skip and run tests
```

If yes, prompt for brief description of changes.

### 2. Check Container State
Verify if Podman containers already exist:
```bash
molecule list -s podman
```

If containers don't exist or are not created:
- Activate venv: `source solti-venv/bin/activate`
- Run: `MOLECULE_PLATFORM_NAME=uut-ct0 molecule create -s podman`
- Inform user containers are being created (one-time setup)

### 3. Display Test Configuration
Show fixed configuration:
```
Running quick smoke test:
- Platform: Podman (Debian uut-ct0)
- Capabilities: logs,metrics
- Mode: converge only (auto-cleanup on success)
- Speed: ~30-60 seconds
```

### 4. Activate Virtual Environment
```bash
source solti-venv/bin/activate
```

### 5. Run Converge Only
Apply current changes (install and configure):
```bash
MOLECULE_PLATFORM_NAME=uut-ct0 molecule converge -s podman
```

Show converge output summary. This tests:
- Ansible syntax is valid
- Roles install successfully
- Configuration is applied
- No verification tests run (use /test-podman for full verification)

### 6. Handle Results with Smart Cleanup

**On Success:**
- Display: "✓ Code installs and configures successfully"
- Auto-cleanup: Run `MOLECULE_PLATFORM_NAME=uut-ct0 molecule destroy -s podman`
- Clean exit, ready for next iteration

**On Failure:**
- Display error details from converge
- **Keep container running for troubleshooting**
- Show troubleshooting commands:
  ```bash
  # Shell into container for debugging
  podman exec -it uut-ct0 /bin/bash

  # Or use molecule login
  molecule login -s podman -h uut-ct0

  # Check container logs
  podman logs uut-ct0

  # When done debugging, clean up manually:
  molecule destroy -s podman
  ```
- Suggest fixes based on error
- Offer to run again after changes
- Remind about checkpoint commits for tracking attempts

## Usage Examples

```bash
# Quick smoke test after making changes
/test-quick

# Typical workflow:
# 1. Make code changes
# 2. /test-quick (checkpoint, converge only - 30-60 sec)
# 3. Fix issues if needed
# 4. /test-quick (repeat rapidly)
# 5. When it installs: run /test-podman debian for full verification
# 6. Before PR: squash checkpoints
```

## Prerequisites
- Python virtual environment (solti-venv) with molecule installed
- LAB_DOMAIN set in `~/.secrets/LabProvision`
- Podman installed and accessible
- Testing container images available in registry

## Expected Behavior
- First run: Creates containers (~2 min), then converge (~30-60 sec)
- Subsequent runs: Only converge (~30-60 sec)
- Skips all verification tests for maximum speed
- **Success**: Automatically destroys container (clean slate for next run)
- **Failure**: Keeps container running for debugging

## Cleanup
**Automatic**: On success, container is destroyed automatically

**Manual** (only needed after failures):
```bash
molecule destroy -s podman
```

For full test cycle with verification, use `/test-podman` in full mode.

## Notes
- Hardcoded to Debian (uut-ct0) for consistency and speed
- **Skips verification phase entirely** - only tests installation/configuration
- Skips idempotence check for faster iteration
- **Smart cleanup**: Success = auto-destroy, Failure = keep for debugging
- Perfect for rapid TDD-style development: edit → smoke test → fix → repeat
- Once converge passes, use `/test-podman debian` for full verification
- Containers run on SSH port 2223
- Use checkpoint commits to track your debugging attempts
- Before PR: squash all checkpoint commits into clean commits
