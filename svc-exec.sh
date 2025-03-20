#!/bin/bash
#
# svc-exec.sh - Execute specific tasks for services using dynamically generated Ansible playbooks
#
# Usage: svc-exec [-K] [-h HOST] <service> [entry]
#
# Example:
#   svc-exec loki verify              # No sudo prompt, default hosts
#   svc-exec -h monitor01 loki verify1 # Specific host
#   svc-exec -K redis configure       # With sudo prompt
#

# Exit on error
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${SCRIPT_DIR}/inventory.yml"
TEMP_DIR="${SCRIPT_DIR}/tmp"

# Ensure temp directory exists
mkdir -p "${TEMP_DIR}"

# Supported services
SUPPORTED_SERVICES=(
    "loki"
    "alloy"
    "influxdb"
    "telegraf"
)



#  Claude no default entry, print help and exist

# Default entry point if not specified
DEFAULT_ENTRY="verify"

# Initialize variables
USE_SUDO=false
SERVICE=""
ENTRY=""
HOST=""

# Display usage information
usage() {
    echo "Usage: $(basename $0) [-K] [-h HOST] <service> [entry]"
    echo ""
    echo "Options:"
    echo "  -K        - Prompt for sudo password (needed for some operations)"
    echo "  -h HOST   - Target specific host from inventory"
    echo ""
    echo "Parameters:"
    echo "  service   - The service to manage"
    echo "  entry     - The entry point task (default: verify)"
    echo ""
    echo "Services:"
    for svc in "${SUPPORTED_SERVICES[@]}"; do
        echo "  - $svc"
    done
    echo ""
    echo "Common Entry Points:"
    echo "  - verify     - Basic service verification"
    echo "  - configure  - Configure service"
    echo "  - backup     - Backup service data"
    echo "  - restore    - Restore service data"
    echo ""
    echo "Examples:"
    echo "  $(basename $0) loki verify                # Default verification"
    echo "  $(basename $0) -h monitor01 loki verify1  # Additional verification on specific host"
    echo "  $(basename $0) -K redis configure         # Configure with sudo"
    echo "  $(basename $0) -h db01 influxdb backup    # Backup database on db01"
    exit 1
}

# Check if a service is supported
is_service_supported() {
    local service="$1"
    for svc in "${SUPPORTED_SERVICES[@]}"; do
        if [[ "$svc" == "$service" ]]; then
            return 0
        fi
    done
    return 1
}

# Generate task execution playbook 
generate_exec_playbook() {
    local service="$1"
    local entry="$2"
    local host_param=""
    
    # Add host specification if provided
    if [[ -n "$HOST" ]]; then
        host_param="hosts: $HOST"
    else
        host_param="hosts: ${service}_svc"
    fi
    
    # Create playbook directly with proper substitutions
    cat > "$TEMP_PLAYBOOK" << EOF
---
# Dynamic execution playbook for ${service}
- name: Execute ${entry} for ${service} Service
  $host_param
  become: true
  vars:
    verify_timestamp: "{{ ansible_date_time.iso8601 }}"
    report_root: "${SCRIPT_DIR}/verify_output"
    project_root: "${SCRIPT_DIR}"
    all_verify_results: {}
    all_verify_failed: {}
  pre_tasks:
    - name: Ensure verify output directory exists
      ansible.builtin.file:
        path: "{{ report_root }}/{{ ansible_distribution | lower }}"
        state: directory
        mode: "0755"
      delegate_to: localhost
      become: false
  tasks:
    - name: Include role tasks
      ansible.builtin.include_role:
        name: ${service}
        tasks_from: ${entry}
EOF
    
    echo "Generated ${entry} playbook for ${service}"
}

# Parse command line options
while getopts "Kh:" opt; do
    case ${opt} in
        K)
            USE_SUDO=true
            ;;
        h)
            HOST=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Shift past the options
shift $((OPTIND - 1))

# Validate remaining arguments
if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Error: Incorrect number of arguments"
    usage
fi

# Extract parameters
SERVICE="$1"
ENTRY="${2:-$DEFAULT_ENTRY}"  # Use default if not provided

# Validate service
if ! is_service_supported "$SERVICE"; then
    echo "Error: Unsupported service '$SERVICE'"
    usage
fi

# Generate timestamp for files
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
TEMP_PLAYBOOK="${TEMP_DIR}/${SERVICE}-${ENTRY}-${TIMESTAMP}.yml"

# Generate the playbook
generate_exec_playbook "$SERVICE" "$ENTRY"

# Display execution info
echo "Executing task: ${ENTRY} for service: ${SERVICE}"
if [[ -n "$HOST" ]]; then
    echo "Target host: $HOST"
else
    echo "Target hosts: ${SERVICE}_svc (from inventory)"
fi
echo "Using generated playbook: $TEMP_PLAYBOOK"
if $USE_SUDO; then
    echo "Using sudo: Yes (will prompt for password)"
else
    echo "Using sudo: No"
fi
echo ""

# Display playbook content
echo "Playbook content:"
echo "----------------"
cat "${TEMP_PLAYBOOK}"
echo "----------------"
echo ""

# Ask for confirmation
read -p "Execute this playbook? [Y/n]: " confirm
if [[ "$confirm" =~ ^[Nn] ]]; then
    echo "Operation cancelled"
    exit 0
fi

# Execute the playbook with or without sudo prompt
if $USE_SUDO; then
    echo "Executing with sudo privileges: ansible-playbook -K -i ${INVENTORY} ${TEMP_PLAYBOOK}"
    ansible-playbook -K -i "${INVENTORY}" "${TEMP_PLAYBOOK}"
else
    echo "Executing: ansible-playbook -i ${INVENTORY} ${TEMP_PLAYBOOK}"
    ansible-playbook -i "${INVENTORY}" "${TEMP_PLAYBOOK}"
fi

# Check execution status
EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
    echo ""
    echo "Success: ${ENTRY} for ${SERVICE} completed successfully"
    
    # Remove the temporary playbook on success
    echo "Cleaning up generated playbook"
    rm -f "${TEMP_PLAYBOOK}"
    
    exit 0
else
    echo ""
    echo "Error: ${ENTRY} for ${SERVICE} failed with exit code ${EXIT_CODE}"
    echo "Generated playbook preserved for debugging: ${TEMP_PLAYBOOK}"
    exit 1
fi