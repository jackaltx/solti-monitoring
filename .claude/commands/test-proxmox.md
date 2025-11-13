# /test-proxmox - Full VM Integration Testing

## Purpose
Run integration tests using Proxmox VMs for full integration testing. Tests the solti-monitoring collection roles in actual virtual machines on Proxmox infrastructure.

## Parameters
The command accepts up to 2 parameters:
1. **Distro** (optional): `all` (default), `debian`, `rocky`
2. **Capabilities** (optional): `all` (default), `logs`, `metrics`

## Process

### 1. Parse Parameters
- Extract distro and capabilities from user input
- Set defaults: distro=all, capabilities=all
- Map distro names:
  - `debian` → `PROXMOX_DISTRO=debian` (uses debian-12-template)
  - `rocky` → `PROXMOX_DISTRO=rocky` (uses rocky9-template)
  - `all` → unset (tests both distros sequentially)
- Map capabilities:
  - `logs` → `MOLECULE_CAPABILITIES=logs`
  - `metrics` → `MOLECULE_CAPABILITIES=metrics`
  - `all` → `MOLECULE_CAPABILITIES=logs,metrics`

### 2. Validate Proxmox Environment
Check for required Proxmox environment variables:
- `PROXMOX_URL` - Proxmox API endpoint
- `PROXMOX_USER` - API user
- `PROXMOX_TOKEN_ID` - API token ID
- `PROXMOX_TOKEN_SECRET` - API token secret
- `PROXMOX_NODE` - Target Proxmox node

If any are missing:
- Show clear error message listing missing variables
- Suggest sourcing: `source ~/.secrets/proxmox-exports`
- Exit without running tests

### 3. Display Test Configuration
Show the user what will be tested:
```
Running Proxmox integration tests:
- Distro: [debian/rocky/all]
- Capabilities: [logs/metrics/logs,metrics]
- Proxmox Node: [node name]
- VM Name: uut-vm
```

### 4. Execute Tests
Run: `./run-proxmox-tests.sh` with environment variables set
- Script automatically activates venv
- Creates VM from template
- Runs `molecule test -s proxmox`
- Test sequence: dependency → cleanup → destroy → syntax → create → prepare → converge → idempotence → side_effect → verify → cleanup → destroy
- For `all` distros: runs both debian and rocky sequentially

### 5. Report Results
- Show test output summary for each distro
- Report log file locations: `verify_output/integration_{distro}_{timestamp}.log`
- On failure: suggest examining the log file and checking Proxmox console
- Warn if VMs weren't cleaned up (check Proxmox interface)

## Usage Examples

```bash
# Test all distributions with all capabilities
/test-proxmox

# Test only Debian
/test-proxmox debian

# Test only Rocky with metrics capability
/test-proxmox rocky metrics

# Test all distros with logs only
/test-proxmox all logs
```

## Prerequisites
- Python virtual environment (solti-venv) with molecule installed
- Proxmox environment variables configured (see step 2)
- LAB_DOMAIN set in `~/.secrets/LabProvision`
- Proxmox templates available:
  - `debian-12-template`
  - `rocky9-template`
- Network connectivity to Proxmox host
- Sufficient resources on target Proxmox node

## Expected Behavior
- Full test cycle per distro: 10-20 minutes
- Creates VMs, runs tests, destroys VMs
- Creates detailed logs per distro in `verify_output/` directory
- Returns success/failure status

## Notes
- VMs are created with name `uut-vm` (destroyed between distros)
- Default VM IP: `192.168.101.90` (configurable via `MOLECULE_IP`)
- The script `run-proxmox-tests.sh` handles venv activation and template selection
- If tests fail, check Proxmox console for VM state
- VMs should be automatically destroyed, but verify in Proxmox UI if tests abort
- More resource-intensive than Podman tests - use for final validation
