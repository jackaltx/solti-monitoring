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

# Configuration
DISTRIBUTIONS=(
    "debian:debian-12-template"
    "rocky:rocky9-template"
)
INTEGRATIONS=(
    "proxmox-logs"
    "proxmox-metrics"
)
OUTPUT_DIR="$(pwd)/verify_output"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${OUTPUT_DIR}/integration_tests_${TIMESTAMP}.log"
}

error() {
    log "${RED}ERROR: $*${NC}"
    exit 1
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
        
    export PROXMOX_TEMPLATE="${template}"
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