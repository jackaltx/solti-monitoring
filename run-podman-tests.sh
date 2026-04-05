#!/usr/bin/env bash

# Source lab secrets if available (for LAB_TLD, etc.)
if [ -f ~/.secrets/LabProvision ]; then
    source ~/.secrets/LabProvision
fi

# Default values
CAPABILITIES="logs,metrics"
TEST_NAME="podman"
OUTPUT_DIR="./verify_output"
DATE_STAMP=$(date +%Y%m%d-%H%M%S)

# Help function
show_help() {
    cat << EOF
Usage: ${0##*/} [OPTIONS]
Run molecule tests for specified capabilities.

Options:
    -h, --help              Display this help and exit
    -t, --tests CAPS       Specify capabilities to test (comma-separated)
                           Default: logs,metrics
    -n, --name NAME        Specify test name
                           Default: integration

Example:
    ${0##*/} --tests logs,metrics --name custom_test
    ${0##*/} -t logs -n logging_test
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--tests)
            CAPABILITIES="$2"
            shift 2
            ;;
        -n|--name)
            TEST_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate capabilities
valid_capabilities=("logs" "metrics")
IFS=',' read -ra CAPS_ARRAY <<< "$CAPABILITIES"
for cap in "${CAPS_ARRAY[@]}"; do
    found=0
    for valid_cap in "${valid_capabilities[@]}"; do
        if [ "$cap" = "$valid_cap" ]; then
            found=1
            break
        fi
    done
    if [ $found -eq 0 ]; then
        echo "Error: Invalid capability '$cap'"
        echo "Valid capabilities are: ${valid_capabilities[*]}"
        exit 1
    fi
done

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Generate log filename
LOG_FILE="${OUTPUT_DIR}/${TEST_NAME}-test-${DATE_STAMP}.out"

# Export environment variables
export MOLECULE_CAPABILITIES="$CAPABILITIES"
export MOLECULE_TEST_NAME="$TEST_NAME"

# Print test configuration
{
    echo "=== Molecule Test Configuration ==="
    echo "Date: $(date)"
    echo "Capabilities: $CAPABILITIES"
    echo "Test name: $TEST_NAME"
    echo "Output file: $LOG_FILE"
    echo "=================================="
    echo
} | tee "$LOG_FILE"

# Activate virtual environment if it exists
if [ -d "solti-venv" ]; then
    source solti-venv/bin/activate
elif [ -d "../solti-venv" ]; then
    source ../solti-venv/bin/activate
fi

# Source development secrets (development environment only)
# Long-term: migrate to HashiCorp Vault when key env vars are not set
source ~/.secrets/LabProvision 2>/dev/null || true
source ~/.secrets/LabGiteaToken 2>/dev/null || true

# Run the tests and capture output
# Using a temporary file to capture the exit code
TEMP_OUTPUT=$(mktemp)
{
    molecule test -s podman 2>&1
    echo $? > "$TEMP_OUTPUT"
} | tee -a "$LOG_FILE"

# Read the exit code
TEST_EXIT_CODE=$(cat "$TEMP_OUTPUT")
rm -f "$TEMP_OUTPUT"

# Append test summary to log
{
    echo
    echo "=== Test Summary ==="
    echo "Completed at: $(date)"
    if [ "$TEST_EXIT_CODE" -eq 0 ]; then
        echo "Status: SUCCESS"
    else
        echo "Status: FAILED - Exit code $TEST_EXIT_CODE"
    fi
} | tee -a "$LOG_FILE"

# Create a symlink to latest log (use basename to avoid nested paths)
ln -sf "$(basename "${LOG_FILE}")" "${OUTPUT_DIR}/latest_test.out"

# Regenerate Obsidian indices from immutable run records
if [ -d "${OUTPUT_DIR}/obsidian/runs" ]; then
    echo
    echo "=== Regenerating Obsidian indices ==="
    ./bin/regenerate-obsidian-indices.sh "${OUTPUT_DIR}/obsidian"
    echo "==================================="
fi

# Optional Obsidian sync to TrueNAS
if [ "${OBSIDIAN_SYNC_ENABLED:-false}" = "true" ]; then
    echo
    echo "=== Syncing Obsidian files to TrueNAS ==="

    # Check if using NFS mount or SSH rsync
    if [ -n "${OBSIDIAN_NFS_MOUNT:-}" ]; then
        # NFS mount path provided (e.g., /mnt/SoltiMonitorTesting)
        OBSIDIAN_NFS_UID="${OBSIDIAN_NFS_UID:-568}"
        OBSIDIAN_NFS_GID="${OBSIDIAN_NFS_GID:-568}"
        OBSIDIAN_SSH_HOST="${OBSIDIAN_SSH_HOST:-root@truenas.jackaltx.com}"
        OBSIDIAN_REMOTE_PATH="${OBSIDIAN_REMOTE_PATH:-/mnt/zpool/Docker/Stacks/obsidian/SoltiMonitorTesting}"

        echo "Syncing to NFS mount: ${OBSIDIAN_NFS_MOUNT}"
        echo "Target ownership: ${OBSIDIAN_NFS_UID}:${OBSIDIAN_NFS_GID}"

        # Sync files normally (no sudo needed)
        if rsync -av --delete "${OUTPUT_DIR}/obsidian/" "${OBSIDIAN_NFS_MOUNT}/"; then
            echo "Files synced, fixing ownership via SSH..."

            # Fix ownership remotely via SSH (two-hop: lavadmin -> sudo chown)
            # This avoids needing root SSH access
            if ssh "${OBSIDIAN_SSH_HOST}" "sudo chown -R ${OBSIDIAN_NFS_UID}:${OBSIDIAN_NFS_GID} ${OBSIDIAN_REMOTE_PATH}"; then
                echo "Successfully synced and set ownership"
            else
                echo "Warning: Files synced but ownership fix failed (exit code $?)"
                echo "Files may not be readable by Obsidian container."
            fi
        else
            echo "Warning: Failed to sync Obsidian files to NFS (exit code $?)"
            echo "This does not affect test results."
        fi
    else
        # SSH rsync to remote server (original behavior)
        OBSIDIAN_SYNC_TARGET="${OBSIDIAN_SYNC_TARGET:-root@truenas.jackaltx.com:/mnt/zpool/Docker/Stacks/obsidian/SoltiMonitorTesting/}"

        echo "Syncing via SSH to: ${OBSIDIAN_SYNC_TARGET}"

        # Rsync Obsidian directory to TrueNAS via SSH
        if rsync -avz --progress "${OUTPUT_DIR}/obsidian/" "${OBSIDIAN_SYNC_TARGET}"; then
            echo "Successfully synced Obsidian files to ${OBSIDIAN_SYNC_TARGET}"
        else
            echo "Warning: Failed to sync Obsidian files (exit code $?)"
            echo "This does not affect test results."
        fi
    fi

    echo "==================================="
fi

# Exit with the correct status
if [ "$TEST_EXIT_CODE" -eq 0 ]; then
    echo "Tests completed successfully. Log saved to $LOG_FILE"
    exit 0
else
    echo "Tests failed. Log saved to $LOG_FILE"
    exit 1
fi
