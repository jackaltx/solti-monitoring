# Wazuh Agent Ansible Role

## Overview

This role manages the installation, configuration, and lifecycle of Wazuh agents across diverse environments. It provides intelligent configuration for security monitoring and log collection with support for different deployment scenarios, automated service detection, and configuration versioning.

The Git-based configuration versioning is a key feature that addresses three critical needs:

1. **Maintainability over time**: Tracking all configuration changes with commit messages
2. **Quick recovery**: Easy rollback to previous working configurations
3. **Audit capability**: Complete history of who changed what and when for compliance

## Features

- Installation and registration of Wazuh agents with Wazuh server
- Customizable deployment profiles for different security requirements
- Intelligent service detection and configuration recommendations
- Git-based configuration versioning for change tracking
- Tailored log monitoring based on detected services
- Security module management (rootcheck, syscheck, SCA, etc.)
- Container environment support (Docker/Podman)
- Comprehensive verification and validation tasks

## Requirements

### Platform Support

- Debian/Ubuntu systems
- RHEL/CentOS/Fedora systems

### Prerequisites

- Ansible 2.9 or higher
- Git (for configuration versioning feature)
- Network connectivity to Wazuh server
- Appropriate permissions for service management

## Role Variables

### Main Control Variables

```yaml
# Agent state control
wazuh_agent_state: present      # Options: present, configure, absent

# Agent connection settings
wazuh_server_address: "localhost"
wazuh_server_port: 1514
wazuh_server_protocol: "tcp"
wazuh_agent_group: "default"
wazuh_registration_password: "" # Should be provided in secure way

# Deployment profile
wazuh_deployment_profile: "internal" # Options: isolated, internal, internet_facing, ispconfig
```

### Deployment Profiles

The role includes predefined deployment profiles:

- **isolated**: For isolated LANs where another tool is the primary log collector
- **internal**: For internal services with balanced security and logging
- **internet_facing**: For internet-connected systems requiring comprehensive monitoring
- **ispconfig**: Specialized profile for ISPConfig web server environments

### Configuration Options

```yaml
# Agent performance settings
wazuh_agent_buffer_queue_size: 5000
wazuh_agent_buffer_events_per_second: 500

# Security modules configuration
wazuh_security_modules:
  rootcheck:
    enabled: yes
    frequency: 43200  # 12 hours
  syscheck:
    enabled: yes
    frequency: 43200  # 12 hours
    # Additional syscheck options...
  sca:
    enabled: yes
    interval: "12h"
  # Additional security modules...

# Log monitoring configuration
wazuh_log_monitoring:
  system:
    journald: yes
    audit: "{{ ansible_os_family == 'RedHat' }}"
    dpkg: "{{ ansible_os_family == 'Debian' }}"
    rpm: "{{ ansible_os_family == 'RedHat' }}"
  # Additional log monitoring options...

# Container support
wazuh_container_monitoring:
  detect_podman: yes
  detect_docker: yes
  monitor_containers: yes

# Git versioning
wazuh_git_versioning:
  enabled: yes
  repository_path: "/var/ossec/git"
  commit_msg: "Configuration updated by Ansible on {{ ansible_date_time.iso8601 }}"
  manage_repository: yes
```

## Dependencies

This role has no dependencies on other Ansible roles.

## Example Playbooks

### Basic Installation

```yaml
- hosts: servers
  roles:
    - role: jackaltx.solti_monitoring.wazuh_agent
      vars:
        wazuh_server_address: "10.10.0.12"
        wazuh_agent_state: present
```

### Internet-Facing Profile with Custom Settings

```yaml
- hosts: web_servers
  roles:
    - role: jackaltx.solti_monitoring.wazuh_agent
      vars:
        wazuh_agent_state: configure
        wazuh_server_address: "wazuh.example.com"
        wazuh_deployment_profile: "internet_facing"
        wazuh_log_monitoring:
          web:
            apache_access: yes  # Override profile defaults
            apache_error: yes
```

### Agent Removal

```yaml
- hosts: decommissioned_servers
  roles:
    - role: jackaltx.solti_monitoring.wazuh_agent
      vars:
        wazuh_agent_state: absent
```

### Real-World Example

```yaml
---
- name: Wazuh agent configure
  hosts: wazuh_agents
  become: true

  roles:
    - role: jackaltx.solti_monitoring.wazuh_agent
      vars:
        wazuh_server_address: "monitor3.example.com"
        wazuh_deployment_profile: "internal"
        wazuh_agent_group: "linux-servers"
```

## Installation and Usage

### Post-Installation Steps

After deployment:

1. Verify agent is running:

   ```bash
   systemctl status wazuh-agent
   ```

2. Check agent connection to Wazuh server:

   ```bash
   /var/ossec/bin/agent_control -i
   ```

3. Review the applied configuration:

   ```bash
   cat /var/ossec/etc/ossec.conf
   ```

4. If using git versioning, review configuration changes:

   ```bash
   cd /var/ossec/git
   git log -p
   ```

### Verification

The role includes built-in verification tasks that can be run separately:

```bash
# Basic verification
ansible-playbook playbook.yml --tags verify

# Deep configuration verification
ansible-playbook playbook.yml --tags verify-config
```

## Architecture

This role follows a layered approach:

1. **Detection**: Analyzes the host to identify running services and environment
2. **Profile Application**: Applies the selected deployment profile settings
3. **Customization**: Merges user-defined settings with profile defaults
4. **Installation/Configuration**: Deploys and configures the agent
5. **Versioning**: Records configuration changes in git (if enabled)
6. **Verification**: Validates the agent installation and configuration

### Profile Merging

The role uses a sophisticated variable merging approach:

1. Default settings are loaded from `defaults/main.yml`
2. Deployment profile settings are loaded from `vars/profiles.yml`
3. Profile settings are merged with defaults using Ansible's `combine` filter with `recursive=True`
4. User-defined overrides from playbook variables are applied last

This layered approach allows for standardized base configurations while maintaining flexibility for environment-specific customizations.

### Service Detection and Auto-Configuration

**Current Implementation**: The role includes service detection logic to identify running services (Apache, Nginx, MySQL, PostgreSQL, Podman, Docker) but does not yet fully integrate detected services into the configuration.

**Planned Enhancements**:

- Runtime configuration detection for existing Wazuh deployments
- Intelligent recommendations based on detected services and system profile
- Automatic adjustment of monitoring settings based on service detection
- Configuration validation against best practices

**ISPConfig Support**: The role includes an `ispconfig` profile specifically for ISPConfig web hosting environments, but this profile is currently experimental and not fully tested in production environments.

## Security Considerations

1. **Registration Password**: Store the `wazuh_registration_password` securely using Ansible Vault
2. **Deployment Profiles**: Choose the appropriate profile based on the host's exposure
3. **Custom Log Filters**: Use journald filters to reduce the volume of non-security-relevant logs
4. **Active Response**: Enable with caution in production environments
5. **Verification**: Always verify agent functioning after configuration changes

## Troubleshooting

### Common Issues

1. **Agent not connecting to server**
   - Check firewall rules for ports 1514 and 1515
   - Verify `wazuh_server_address` is correct and resolvable
   - Check agent logs: `tail -f /var/ossec/logs/ossec.log`

2. **Configuration issues**
   - Examine `/var/ossec/etc/ossec.conf` for configuration errors
   - Review Ansible output for any template rendering issues
   - Use the verification tasks to validate configuration

3. **Service detection problems**
   - Run the detection tasks with increased verbosity: `ansible-playbook playbook.yml -vv`
   - Manually verify service presence with commands in `vars/{debian,redhat}.yml`

## Maintenance

### Configuration Updates

To update the agent configuration:

```bash
ansible-playbook playbook.yml -e "wazuh_agent_state=configure" --limit target_hosts
```

### Version History

To view configuration history when git versioning is enabled:

```bash
cd /var/ossec/git
git log --oneline
git show <commit-hash>
```

### Backup Procedures

The role automatically creates a backup of the previous configuration when git versioning is enabled. Additionally:

```bash
# Manual backup
cp -a /var/ossec/etc /var/ossec/etc.bak-$(date +%Y%m%d)

# Restore from backup
cp /var/ossec/etc.bak-YYYYMMDD/ossec.conf /var/ossec/etc/
systemctl restart wazuh-agent
```

## Directory Structure

```
wazuh_agent/
├── defaults/
│   └── main.yml          # Default variables
├── handlers/
│   └── main.yml          # Service handlers
├── tasks/
│   ├── main.yml          # Main tasks
│   ├── install.yml       # Installation tasks
│   ├── configure.yml     # Configuration tasks
│   ├── remove.yml        # Removal tasks
│   ├── detect_services.yml # Service detection
│   ├── verify.yml        # Basic verification
│   └── verify-config.yml # Deep verification
├── templates/
│   └── ossec.conf.xml.j2 # Configuration template
├── vars/
│   ├── debian.yml        # Debian specific variables
│   ├── redhat.yml        # RHEL specific variables
│   ├── main.yml          # Global variables
│   └── profiles.yml      # Deployment profiles
└── README.md             # This file
```

## License

MIT

## Author Information

Created by JackalTX. Part of the SOLTI Monitoring collection.

---

For more information about Wazuh itself, visit the [Wazuh documentation](https://documentation.wazuh.com/).
