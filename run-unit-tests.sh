#!/usr/bin/env bash
#
# Molecule Unit Test Runner
#
#  Ansible role unit tests must be run in their root directory.
#  All script and run outputs will to be at  ./verify_output
#  In verify ouput each role will write it's results in disribution directories
#  This will clone linked templates of debian 12 and rocky 9 on my proxmox server.
#  These test clones (units-under-test VM or uut-vm) are cloud-init instances (slow to start)
#
#  I want so use LXC containers on proxmox for this, but the command exec interface does 
#  not work at this time.  I will likely preserve this capability, but move onto podman container 
#  due to the slow clone speed.
#
#  Cloud init is ok, but slow. It may be the only reliable way to set the ip address. 
#
# Authors: Claude (Anthropic) & jackaltx
# License: MIT
# Date: 2024-12-18

set -euo pipefail
IFS=$'\n\t'

# might be needed for the proxmox cloning. claude: default this if the molecule_ip is set
# ssh-keygen -R 192.168.101.90

# Configuration
DISTRIBUTIONS=(
    "debian:debian-12-template"
    "rocky:rocky9-template"
)
ROLES=(
    "telegraf"
    "influxdb"
    "loki"
    "alloy"
)
OUTPUT_DIR="$(pwd)/verify_output"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${OUTPUT_DIR}/unit_tests_${TIMESTAMP}.log"
}

error() {
    log "${RED}ERROR: $*${NC}"
    exit 1
}

setup() {
    mkdir -p "${OUTPUT_DIR}"
    for role in "${ROLES[@]}"; do
        [[ -d "roles/${role}" ]] || error "Role '${role}' not found"
    done
}

run_tests() {
    local role=$1
    local distro_name=$2
    local template=$3
    local test_log="${OUTPUT_DIR}/${role}_${distro_name}_${TIMESTAMP}.log"

    log "${YELLOW}Testing ${role} on ${distro_name}${NC}"
    
    cd "roles/${role}" || error "Failed to change to role directory: ${role}"
    
    export PROXMOX_TEMPLATE="${template}"
    if molecule test -s proxmox > "${test_log}" 2>&1; then
        log "${GREEN}✓ ${role} tests passed on ${distro_name}${NC}"
        cd - > /dev/null
        return 0
    else
        log "${RED}✗ ${role} tests failed on ${distro_name}${NC}"
        log "See detailed log: ${test_log}"
        cd - > /dev/null
        return 1
    fi
}

main() {
    setup
    
    local failed_tests=()
    
    for role in "${ROLES[@]}"; do
        [[ -f "roles/${role}/molecule/proxmox/molecule.yml" ]] || continue
        
        for dist in "${DISTRIBUTIONS[@]}"; do
            IFS=: read -r distro_name template <<< "${dist}"
            
            if ! run_tests "${role}" "${distro_name}" "${template}"; then
                failed_tests+=("${role} on ${distro_name}")
            fi
        done
    done
    
    log "\nTest Summary:"
    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        log "${GREEN}All tests passed successfully${NC}"
    else
        log "${RED}Failed tests:${NC}"
        printf '%s\n' "${failed_tests[@]}" | tee -a "${OUTPUT_DIR}/unit_tests_${TIMESTAMP}.log"
        exit 1
    fi
}

main "$@"