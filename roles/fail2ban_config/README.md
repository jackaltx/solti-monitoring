# Fail2Ban with Git Configuration Versioning

## Overview

This Ansible role manages Fail2Ban with an integrated Git-based configuration tracking system, allowing for complete version control of all changes to your Fail2Ban setup. It provides a reliable way to track configuration changes over time, with the ability to easily roll back to prior working configurations.

## Features

- Installation and configuration of Fail2Ban
- Git-based configuration versioning for comprehensive change tracking
- Automatic commits of configuration changes with timestamps
- Customizable jails and filters
- AbuseIPDB reporting integration
- Consistent configuration across multiple servers

## Key Benefits of Git-Based Configuration Versioning

1. **Complete Audit Trail**: Every configuration change is recorded with timestamps and commit messages
2. **Simplified Rollbacks**: Quickly revert to previous configurations when needed
3. **Compliance Support**: Provides documentation of security control changes for compliance requirements
4. **Troubleshooting**: Easily identify what changed and when if issues arise
5. **Centralized Management**: Maintain a single source of truth for all fail2ban configurations

## Usage Examples

### Basic Installation with Git Versioning

```yaml
- hosts: webservers
  roles:
    - role: jackaltx.solti_monitoring.fail2ban
      vars:
        fail2ban_state: present
        fail2ban_git_versioning:
          enabled: yes
          repository_path: "/var/lib/fail2ban/git"
          commit_msg: "Configuration updated by Ansible on {{ ansible_date_time.iso8601 }}"
```

### Advanced Configuration

```yaml
- hosts: webservers
  roles:
    - role: jackaltx.solti_monitoring.fail2ban
      vars:
        fail2ban_state: configure
        fail2ban_jail_defaults:
          bantime: 1h
          findtime: 10m
          maxretry: 5
        fail2ban_jails:
          - name: apache-auth
            enabled: true
            port: http,https
            filter: apache-auth
            logpath: /var/log/apache2/error.log
            maxretry: 3
            findtime: 30m
            bantime: 2h
          - name: wordpress-hard
            enabled: true
            filter: wordpress-hard
            logpath: /var/log/auth.log
            maxretry: 1
            port: http,https,8080,8081
            action: 
              - %(action_)s
              - "%(action_abuseipdb)s[abuseipdb_category=\"21,15\"]"
```

## Viewing Configuration History

After deployment, you can view the configuration history on a server:

```bash
cd /var/lib/fail2ban/git
git log --oneline
git show <commit-hash>
```

To revert to a previous configuration:

```bash
cd /var/lib/fail2ban/git
git checkout <commit-hash> -- .
cp -r * /etc/fail2ban/
systemctl restart fail2ban
git commit -m "Reverted to previous configuration"
```

## Extending to Other Monitoring Tools

This git-based versioning approach can be extended to other monitoring tools using a similar pattern:

1. Create a git repository directory for each tool
2. Commit the current configuration before making changes
3. Apply configuration changes
4. Commit the new configuration with a descriptive message
5. Restart the service if needed

Examples of other tools that could benefit from this approach:

- Telegraf
- Logrotate
- UFW Firewall rules
- ModSecurity rules
