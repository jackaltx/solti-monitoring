#!/bin/bash
#
# manage-svc.sh - Manage services using dynamically generated Ansible playbooks
#
# Usage: manage-svc [-h HOST] <service> <action>
#

# Exit on error
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${SCRIPT_DIR}/inventory.yml"
TEMP_DIR="${SCRIPT_DIR}/tmp"
HOST=""

# Ensure temp directory exists
mkdir -p "${TEMP_DIR}"

# Supported services
SUPPORTED_SERVICES=(
    "loki"
    "alloy"
    "influxdb"
    "telegraf"
)

# Supported actions
SUPPORTED_ACTIONS=(
    "remove"
    "install"
)

# Map actions to state values
declare -A STATE_MAP
STATE_MAP["install"]="present"
STATE_MAP["remove"]="absent"

# Display usage information
usage() {
    echo "Usage: $(basename $0) [-h HOST] <service> <action>"
    echo ""
    echo "Options:"
    echo "  -h HOST    Target host from inventory (default: uses hosts defined in role)"
    echo ""
    echo "Services:"
    for svc in "${SUPPORTED_SERVICES[@]}"; do
        echo "  - $svc"
    done
    echo ""
    echo "Actions:"
    for action in "${SUPPORTED_ACTIONS[@]}"; do
        echo "  - $action"
    done
    echo ""
    echo "Examples:"
    echo "  $(basename $0) -h monitor3 loki install"
    echo "  $(basename $0) -h monitor4 telegraf install"
    echo "  $(basename $0) -h monitor3 alloy remove"
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

# Check if an action is supported
is_action_supported() {
    local action="$1"
    for act in "${SUPPORTED_ACTIONS[@]}"; do
        if [[ "$act" == "$action" ]]; then
            return 0
        fi
    done
    return 1
}

# Generate playbook from template
generate_playbook() {
    local service="$1"
    local action="$2"
    local state="${STATE_MAP[$action]}"
    local host_param=""
    
    # Add host specification if provided
    if [[ -n "$HOST" ]]; then
        host_param="hosts: $HOST"
    else
        host_param="hosts: ${service}_svc"
    fi
    
    # Create playbook directly with the proper substitutions
    cat > "$TEMP_PLAYBOOK" << EOF
---
# Dynamically generated playbook
- name: Manage ${service} Service
  $host_param
  become: true
  vars:
    ${service}_state: ${state}
  roles:
    - role: ${service}
EOF
    
    echo "Generated playbook for ${service} ${action}"
}

# Parse command line arguments
while getopts "h:" opt; do
    case ${opt} in
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
if [[ $# -ne 2 ]]; then
    echo "Error: Incorrect number of arguments"
    usage
fi

# Extract arguments
SERVICE="$1"
ACTION="$2"

# Validate service
if ! is_service_supported "$SERVICE"; then
    echo "Error: Unsupported service '$SERVICE'"
    usage
fi

# Validate action
if ! is_action_supported "$ACTION"; then
    echo "Error: Unsupported action '$ACTION'"
    usage
fi

# Generate timestamp for files
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
TEMP_PLAYBOOK="${TEMP_DIR}/${SERVICE}-${ACTION}-${TIMESTAMP}.yml"

# Generate the playbook
generate_playbook "$SERVICE" "$ACTION"

# Display execution info
echo "Managing service: $SERVICE"
echo "Action: $ACTION"
if [[ -n "$HOST" ]]; then
    echo "Target host: $HOST"
else
    echo "Target hosts: ${SERVICE}_svc (from inventory)"
fi
echo "Using generated playbook: $TEMP_PLAYBOOK"
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

# Always use sudo for all states
echo "Executing with sudo privileges: ansible-playbook -K -i ${INVENTORY} ${TEMP_PLAYBOOK}"
ansible-playbook -K -i "${INVENTORY}" "${TEMP_PLAYBOOK}"

# Check execution status
EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
    echo ""
    echo "Success: ${SERVICE} ${ACTION} completed successfully"
    
    # Remove the temporary playbook on success
    echo "Cleaning up generated playbook"
    rm -f "${TEMP_PLAYBOOK}"
    
    exit 0
else
    echo ""
    echo "Error: ${SERVICE} ${ACTION} failed with exit code ${EXIT_CODE}"
    echo "Generated playbook preserved for debugging: ${TEMP_PLAYBOOK}"
    exit 1
fi

