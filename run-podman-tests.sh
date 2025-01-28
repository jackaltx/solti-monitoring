#!/usr/bin/env bash

# Default values
CAPABILITIES="logs,metrics"
TEST_NAME="integration"
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
LOG_FILE="${OUTPUT_DIR}/${TEST_NAME}_test_${DATE_STAMP}.out"

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

# Create a symlink to latest log
ln -sf "${LOG_FILE}" "${OUTPUT_DIR}/latest_test.out"

# Exit with the correct status
if [ "$TEST_EXIT_CODE" -eq 0 ]; then
    echo "Tests completed successfully. Log saved to $LOG_FILE"
    exit 0
else
    echo "Tests failed. Log saved to $LOG_FILE"
    exit 1
fi
