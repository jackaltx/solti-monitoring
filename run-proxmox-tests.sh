#!/usr/bin/env bash
#
# Molecule Unit Test Runner
#
#  Ansible Role integration tests must be run from the project root directory
#  All script and run outputs will to be at  ./verify_output
#  In verify ouput each Role will write it's results in disribution directories  (TODO overwite good/bad)
#  This will clone linked templates of debian 12 and rocky 9 on my proxmox server.
#  These test clones (units-under-test VM or uut-vm) are cloud-init instances (slow to start)
#
# Authors: Claude (Anthropic) & jackaltx
# License: MIT
# Date: 2024-12-18

set -euo pipefail
IFS=$'\n\t'

# Activate virtual environment if it exists
if [ -f "solti-venv/bin/activate" ]; then
    source solti-venv/bin/activate
else
    echo "Warning: solti-venv not found. Run ./prepare-solti-env.sh first"
    exit 1
fi

# Source development secrets (development environment only)
# Long-term: migrate to HashiCorp Vault when key env vars are not set
source ~/.secrets/LabProvision 2>/dev/null || true
source ~/.secrets/proxmox-exports 2>/dev/null || true
source ~/.secrets/LabGiteaToken 2>/dev/null || true

# Configuration
# Override with: PROXMOX_DISTRO=rocky ./run-proxmox-tests.sh
ALL_DISTRIBUTIONS=(
    "rocky:rocky9-template"
    "debian:debian-12-template"
)

# Use specific distro if PROXMOX_DISTRO is set, otherwise test all
if [[ -n "${PROXMOX_DISTRO:-}" ]]; then
    DISTRIBUTIONS=()
    for dist in "${ALL_DISTRIBUTIONS[@]}"; do
        if [[ "${dist}" == "${PROXMOX_DISTRO}:"* ]]; then
            DISTRIBUTIONS+=("${dist}")
        fi
    done
    if [[ ${#DISTRIBUTIONS[@]} -eq 0 ]]; then
        echo "Error: Unknown distro '${PROXMOX_DISTRO}'. Valid: rocky, debian"
        exit 1
    fi
else
    DISTRIBUTIONS=("${ALL_DISTRIBUTIONS[@]}")
fi

INTEGRATIONS=(
    "proxmox"
)
OUTPUT_DIR="$(pwd)/verify_output"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'


# Required environment variables check
REQUIRED_ENV_VARS=(
    "PROXMOX_URL"
    "PROXMOX_USER"
    "PROXMOX_TOKEN_ID"
    "PROXMOX_TOKEN_SECRET"
    "PROXMOX_NODE"
)


log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${OUTPUT_DIR}/integration_tests_${TIMESTAMP}.log"
}

error() {
    log "${RED}ERROR: $*${NC}"
    exit 1
}

ensure_clean_state() {
    local scenario=$1
    log "${YELLOW}Ensuring clean state for ${scenario}${NC}"
    
    # First, try regular molecule destroy
    molecule destroy -s "${scenario}" || true
    
    # Wait for any lingering processes
    sleep 5
    
    # Clean molecule cache/state files
    find .molecule -name "${scenario}" -type d -exec rm -rf {} + 2>/dev/null || true
    find molecule -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Final wait to ensure everything is settled
    sleep 5
}

check_environment() {
    local missing_vars=()
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -ne 0 ]]; then
        error "Missing required environment variables: ${missing_vars[*]}"
    fi
}

setup() {
    mkdir -p "${OUTPUT_DIR}"
    for integration_test in "${INTEGRATIONS[@]}"; do
        [[ -d "molecule/${integration_test}" ]] || error "Test '${integration_test}' not found"
    done
}

run_tests() {
    local integration_test=$1
    local distro_name=$2
    local template=$3
    local test_log="${OUTPUT_DIR}/${integration_test}_${distro_name}_${TIMESTAMP}.log"

    log "${YELLOW}Testing ${integration_test} on ${distro_name}${NC}"

    # Ensure clean state before test
    # ensure_clean_state "${integration_test}"
    sleep 10

    # Export template variable for this test run       
    export PROXMOX_TEMPLATE="${template}"

    # Run molecule test
    if molecule test -s "${integration_test}" > "${test_log}" 2>&1; then
        log "${GREEN}✓ ${integration_test} tests passed on ${distro_name}${NC}"
        cd - > /dev/null
        return 0
    else
        log "${RED}✗ ${integration_test} tests failed on ${distro_name}${NC}"
        log "See detailed log: ${test_log}"
        cd - > /dev/null
        return 1
    fi
}

main() {
    check_environment
    setup
    
    local failed_tests=()
    
    for integration_test in "${INTEGRATIONS[@]}"; do
        [[ -f "molecule/${integration_test}/molecule.yml" ]] || continue
        
        for dist in "${DISTRIBUTIONS[@]}"; do
            IFS=: read -r distro_name template <<< "${dist}"
            
            if ! run_tests "${integration_test}" "${distro_name}" "${template}"; then
                failed_tests+=("${integration_test} on ${distro_name}")
            fi
        done
    done
    
    log "\nTest Summary:"
    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        log "${GREEN}All tests passed successfully${NC}"
    else
        log "${RED}Failed tests:${NC}"
        printf '%s\n' "${failed_tests[@]}" | tee -a "${OUTPUT_DIR}/integration_tests_${TIMESTAMP}.log"
        exit 1
    fi
}

main "$@"