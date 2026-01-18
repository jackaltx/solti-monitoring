# Alloy Ansible Role

## Overview

This Ansible role installs and configures [Grafana Alloy](https://grafana.com/docs/alloy/latest/), a vendor-neutral distribution of the OpenTelemetry (OTel) Collector that provides a unified way to collect and process observability data from various sources and forward it to different backends.

Alloy streamlines the collection of logs, metrics, and traces with consistent configuration across multiple observability signals. This role primarily focuses on log collection and forwarding to Loki, but is extensible for other use cases.

**📋 For comprehensive testing documentation, see [TESTING.md](TESTING.md)**

## Features

- Installs and configures Alloy from official Grafana repositories
- Manages Alloy service lifecycle (start/stop/restart)
- Configures log sources including systemd journal, files, and application logs
- Configures multiple pipelines for custom log processing
- Supports sending data to multiple Loki endpoints
- Includes utility scripts for easy deployment and verification
- Includes pre-configured templates for common applications:
  - Apache web server
  - Fail2ban
  - Bind9 DNS server
  - Mail services (Postfix/Dovecot)
  - WireGuard VPN
  - Gitea
  - ISPConfig
- Intelligent filtering to reduce journald noise:
  - **Cron noise**: Filters routine cron execution (ISPConfig, getmail, system cron) while preserving errors
  - **WireGuard**: Drops keepalives, preserves connection events
  - **Bind9**: Drops cache cleaning, preserves zone operations

## Quick Verification

After deployment, verify Alloy is working:

```bash
# Check service status
systemctl status alloy

# Verify configuration
alloy validate /etc/alloy/config.alloy

# Check metrics endpoint
curl http://127.0.0.1:12345/metrics | head -20

# Check logs flowing to Loki
curl -G "http://loki-endpoint:3100/loki/api/v1/query" \
  --data-urlencode 'query={hostname="yourhost"}' \
  --data-urlencode 'limit=10'
```

**⚠️ IMPORTANT: Always test config before deploying!**

```bash
# 1. TEST first (does NOT restart service)
ansible-playbook playbooks/your-host/91-alloy-test.yml

# 2. DEPLOY only after test passes
ansible-playbook playbooks/your-host/22-alloy-deploy.yml
```

**For comprehensive testing and troubleshooting, see [TESTING.md](TESTING.md)**

## Requirements

### Platform Support

- Debian/Ubuntu systems (using `apt` package manager)
- RedHat-based systems (Rocky Linux, RHEL) via shared configuration
- Systemd-based systems

### Prerequisites

- Systemd-based operating system
- Network connectivity to Loki endpoint(s)
- Grafana package repository access

## Role Variables

### Main Control Variables

```yaml
# Installation state
alloy_state: "present"                # Use 'absent' to remove Alloy

# Service configuration
alloy_custom_args: "--disable-reporting --server.http.listen-addr=0.0.0.0:12345"

# Configuration path
alloy_config: "/etc/alloy/config.alloy"

# Uninstallation options
alloy_delete_config: false            # Remove config files on uninstall
alloy_delete_data: false              # Remove data files on uninstall
```

### Endpoint Configuration

```yaml
# Loki endpoints - REQUIRED
alloy_loki_endpoints:
  - label: localhost                  # Label for the endpoint (used in configuration)
    endpoint: "127.0.0.1"            # Loki server IP/hostname
```

### Log Source Configuration

```yaml
# Enable specific log collection modules
alloy_monitor_apache: false           # Apache logs
alloy_monitor_ispconfig: false        # ISPConfig logs
alloy_monitor_fail2ban: false         # Fail2ban logs
alloy_monitor_mail: false             # Mail server logs
alloy_monitor_bind9: false            # Bind9 logs
alloy_monitor_wg: false               # WireGuard logs
alloy_monitor_gitea: false            # Gitea logs

# Filtering options (reduce log noise)
alloy_filter_cron_noise: false        # Filter cron execution noise (default: false)
                                       # Drops: PAM sessions, routine CMD execution
                                       # Keeps: Errors, failures, auth issues
```

## Installation

The role uses the official Grafana package repositories to install Alloy. It also configures the systemd service and manages necessary directories with appropriate permissions.

## Configuration

The role takes a template-based approach to configuration, allowing you to easily enable or disable specific log collection modules based on your needs. The main configuration file is generated from templates that include:

1. Core configuration for log processing
2. Specific log sources based on enabled modules
3. Output configuration for Loki endpoints

## Usage Examples

### Basic Installation

```yaml
- hosts: servers
  roles:
    - role: alloy
      vars:
        alloy_loki_endpoints:
          - label: local_loki
            endpoint: "127.0.0.1"
```

### Using the Utility Scripts

The included utility scripts make deploying and managing Alloy simpler:

```bash
# Deploy Alloy using the management script
./manage-svc alloy deploy

# Verify Alloy is working correctly
./svc-exec alloy verify

# Deploy to a specific host
./manage-svc -h monitoring01 alloy deploy
```

### Comprehensive Configuration

```yaml
- hosts: web_servers
  roles:
    - role: alloy
      vars:
        alloy_loki_endpoints:
          - label: main_loki
            endpoint: "loki.example.com"
          - label: backup_loki
            endpoint: "backup-loki.example.com"
        
        # Enable specific log collection
        alloy_monitor_apache: true
        alloy_monitor_fail2ban: true
        
        # Custom listening address
        alloy_custom_args: "--disable-reporting --server.http.listen-addr=0.0.0.0:3100"
```

### Removal Configuration

```yaml
- hosts: servers
  roles:
    - role: alloy
      vars:
        alloy_state: 'absent'
        alloy_delete_config: true
        alloy_delete_data: true
```

## Log Processing Capabilities

### Journal Processing

Alloy is configured to collect logs from the systemd journal with enriched metadata:

- Priority levels
- Unit information
- Transport metadata
- Hostname labels

### File-Based Log Processing

The role can process various log files with specialized parsing:

**Apache Logs:**

- Access logs with detailed request information
- Error logs with enhanced error categorization
- ModSecurity integration
- PHP error parsing

**Bind9 DNS Logs:**

- Zone operations
- Query information
- DNSSEC operations
- Transfer logs
- Security events

**Fail2ban Logs:**

- Jail information
- Action categorization
- Ban/Unban events

**Mail Server Logs:**

- Authentication events
- Connection information
- Delivery status
- Error tracking

**WireGuard Logs:**

- Connection establishment
- Peer activity
- Handshake information
- Error tracking

### Advanced Parsing Features

- Multi-line log support
- Regular expression-based field extraction
- Label enrichment
- Filtering and dropping of noisy events
- Error categorization
- Security incident tracking

## Service-Specific Prerequisites

### Bind9 Journald Integration

**IMPORTANT**: The `bind9-journal-classifier.alloy.j2` template assumes Bind9 logs are sent to systemd journald. This is **NOT** Bind9's default behavior and must be configured separately.

#### Current State

- ✅ Role includes classifier for Bind9 logs from journald
- ❌ Role does NOT configure Bind9 to log to journald
- ⚠️ Users must manually configure Bind9 logging channels

#### Required Configuration

Configure Bind9 to send logs to syslog daemon facility (journald intercepts this on systemd systems):

**Create `/etc/bind/named.conf.custom`:**

```bind
logging {
    channel journal_channel {
        syslog daemon;          // Syslog facility 'daemon'
        severity info;          // Log level
        print-time yes;         // Include timestamp
        print-severity yes;     // Include severity level
        print-category yes;     // Include category name
    };

    // Route log categories to journald
    category default { journal_channel; };
    category queries { journal_channel; };       // DNS queries (including denied)
    category security { journal_channel; };      // Security events
    category dnssec { journal_channel; };        // DNSSEC operations
    category client { journal_channel; };        // Client requests
    category network { journal_channel; };       // Network operations
    category config { journal_channel; };        // Configuration events
};
```

**Include in `/etc/bind/named.conf`:**

```bind
include "/etc/bind/named.conf.custom";
```

#### Known Issues

**Zone Transfer Category Error**: Some Bind9 versions (observed on Debian 12) fail `named-checkconf` validation when `category zone-transfer` is configured:

```
/etc/bind/named.conf.custom:X: unknown category 'zone-transfer'
```

**Workaround**: Comment out the zone-transfer category line:

```bind
// category zone-transfer { journal_channel; }; // Causes named-checkconf error on some versions
```

#### ISPConfig Compatibility

If using ISPConfig to manage Bind9:

- Use `.custom` extension for config files (ISPConfig won't overwrite)
- Main `/etc/bind/named.conf` is rarely touched by ISPConfig
- Files like `named.conf.local` and `named.conf.options` are regenerated by ISPConfig

#### Future Work

- Integrate Bind9 logging configuration into alloy role as optional tasks
- Add version detection for zone-transfer category support
- Make journald integration configurable (support file-based collection as alternative)
- Investigate zone-transfer category compatibility across distros

#### Bind9 Verification

After configuring Bind9 logging:

```bash
# Verify logs are reaching journald (should see hundreds/hour, not just a few)
journalctl -u named --since '1 hour ago' --no-pager | wc -l

# Verify Alloy is collecting them
# Check Alloy component health at http://localhost:12345
```

### Fail2ban Journald Integration

**IMPORTANT**: The fail2ban log collection has migrated from file-based monitoring to systemd journald integration (effective 2026-01-01). This provides better structured logging and integration with the monitoring stack.

#### Current State

- ✅ Role collects fail2ban logs from journald via `loki.source.journal`
- ✅ Logs are automatically available when `alloy_monitor_fail2ban: true`
- ✅ No additional fail2ban configuration required (journald is default on systemd systems)
- ⚠️ Log structure differs from legacy file-based collection

#### Label Structure

Fail2ban logs in journald are identified by these Loki labels:

```yaml
{
  service_type: "fail2ban"           # Primary identifier
  hostname: "hostname"                # Source hostname
  service_name: "fail2ban"           # Service name
  unit: "fail2ban.service"           # Systemd unit
  job: "loki.source.journal.read"    # Collection method
  transport: "journal"                # Transport type
  component: "loki.source.journal"   # Alloy component
}
```

**Important**: Labels do NOT include `jail` or `action_type` - these must be extracted from the log message content using LogQL parsing.

#### Log Message Format

Fail2ban logs appear in journald with this format:

```text
[jail_name] Action IP_ADDRESS
```

Examples:

```text
[sshd] Ban 192.168.1.100
[apache-4xx] Unban 10.0.0.50
[recidive] Increase Ban 172.16.0.10 (3 # 4w 2d -> 2026-01-31 01:41:59)
```

#### Querying Fail2ban Logs in Loki/Grafana

Since jail and action information is in the log message (not labels), you must use LogQL parsing:

**Basic query:**

```logql
{hostname="yourhost", service_type="fail2ban"}
```

**Extract jail, action, and IP:**

```logql
{hostname="yourhost", service_type="fail2ban"}
| regexp `\[(?P<jail>[^\]]+)\]\s+(?P<action>Ban|Unban)\s+(?P<banned_ip>\d+\.\d+\.\d+\.\d+)`
```

**Filter by action:**

```logql
{hostname="yourhost", service_type="fail2ban"}
| regexp `\[(?P<jail>[^\]]+)\]\s+(?P<action>Ban|Unban)\s+(?P<banned_ip>\d+\.\d+\.\d+\.\d+)`
| action="Ban"
```

**Count bans by jail (24h):**

```logql
sum by(jail) (
  count_over_time(
    {hostname="yourhost", service_type="fail2ban"}
    | regexp `\[(?P<jail>[^\]]+)\]\s+(?P<action>Ban|Unban)\s+(?P<banned_ip>\d+\.\d+\.\d+\.\d+)`
    | action="Ban"
    [24h]
  )
)
```

**Top banned IPs:**

```logql
topk(20,
  sum by(banned_ip) (
    count_over_time(
      {hostname="yourhost", service_type="fail2ban"}
      | regexp `\[(?P<jail>[^\]]+)\]\s+(?P<action>Ban|Unban)\s+(?P<banned_ip>\d+\.\d+\.\d+\.\d+)`
      | action="Ban"
      [24h]
    )
  )
)
```

#### Migration from Legacy File-Based Collection

**OLD method (deprecated as of 2026-01-01 04:18 UTC):**

- Direct file monitoring: `/var/log/fail2ban.log`
- Pre-parsed labels: `{job="fail2ban", action_type="Ban", jail="sshd"}`
- Structured labels for easy querying

**NEW method (current as of 2026-01-01 04:41 UTC):**

- Journald collection via `loki.source.journal`
- Labels: `{service_type="fail2ban"}`
- Log parsing required in queries

**Query migration:**

```logql
# OLD (deprecated)
{job="fail2ban", action_type="Ban", jail="sshd"}

# NEW (current)
{service_type="fail2ban"}
| regexp `\[(?P<jail>[^\]]+)\]\s+(?P<action>Ban|Unban)\s+(?P<banned_ip>\d+\.\d+\.\d+\.\d+)`
| action="Ban"
| jail="sshd"
```

**Updating Grafana dashboards:**

If you have existing fail2ban dashboards using the old label structure:

1. Update datasource queries to use `{service_type="fail2ban"}`
2. Add regexp parsing to extract jail/action/IP from messages
3. Change instant/range query types as needed (tables use `instant`, graphs use `range`)
4. Test queries against Loki API before deploying dashboard changes:

   ```python
   # Test query before deploying to dashboard
   import subprocess, json, time

   now_ns = int(time.time() * 1e9)
   query = 'sum by(jail) (count_over_time({service_type="fail2ban"} | regexp `\\[(?P<jail>[^\\]]+)\\]` [24h]))'

   cmd = f'curl -s -G "http://loki-server:3100/loki/api/v1/query" \
     --data-urlencode \'query={query}\' \
     --data-urlencode time={now_ns}'

   result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
   data = json.loads(result.stdout)

   if data['status'] == 'success' and data['data']['result']:
       print(f"✅ Query works! {len(data['data']['result'])} results")
   else:
       print(f"❌ Query failed: {data.get('error', 'unknown')}")
   ```

5. Update dashboard JSON via Grafana HTTP API
6. Verify changes in browser with hard refresh (Ctrl+Shift+R)

#### Benefits of Journald Integration

- **Unified collection**: Single journal source for all systemd services
- **Better metadata**: Automatic hostname, unit, and transport labels
- **Reliability**: No log rotation issues or file permission problems
- **Filtering**: Alloy can filter/process before sending to Loki
- **Scalability**: Journal compression and efficient storage

#### Fail2ban Verification

```bash
# Verify fail2ban logs in journald
journalctl -u fail2ban --since '1 hour ago' --no-pager | grep -E '\[(Ban|Unban)\]' | wc -l

# Check Alloy is forwarding them to Loki
# Query Loki directly:
curl -G "http://loki-server:3100/loki/api/v1/query" \
  --data-urlencode 'query={service_type="fail2ban"}' \
  --data-urlencode 'limit=10'
```

## Directory Structure

```
alloy/
├── defaults/
│   └── main.yml                 # Default variables
├── files/
│   ├── apache-error.alloy       # Example configurations
│   ├── claude-two-outputs.alloy
│   └── grafana.list
├── handlers/
│   └── main.yml                # Service handlers
├── meta/
│   └── main.yml               # Role metadata
├── molecule/                  # Testing configuration
├── tasks/
│   ├── main.yml              # Main tasks
│   └── verify.yml            # Verification tasks
├── templates/
│   ├── client-config-alloy.j2  # Main template
│   ├── etc-default-alloy.j2    # Environment configuration
│   ├── apache-logs.alloy.j2    # Module templates
│   ├── fail2ban.alloy.j2
│   └── ...                     # Other module templates
└── README.md                   # This file
```

## Handlers

The role includes the following handlers:

- `Restart alloy`: Restarts the Alloy service when configuration changes

## Testing

The role includes Molecule tests for:

- Basic installation
- Configuration verification
- Service status checks
- Log collection functionality

## Security Considerations

- The role configures Alloy with appropriate file permissions
- Service runs as its own user
- Configuration is validated before restarting the service
- Label filtering to remove sensitive information
- Optional dropping of connection data for privacy

## Troubleshooting

Common issues and solutions:

1. **Service fails to start**
   - Check logs with `journalctl -u alloy`
   - Verify configuration with `alloy --config.file /etc/alloy/config.alloy --config.expand-env --config.check`
   - Use the verification script: `./svc-exec alloy verify`

2. **No logs being collected**
   - Verify Loki endpoint is correct and accessible
   - Check network connectivity to Loki endpoint
   - Verify file paths and permissions
   - Use `./svc-exec alloy verify1` for deeper connection checks

3. **High CPU/memory usage**
   - Check for excessive log volume
   - Verify filtering is properly configured
   - Consider increasing system resources

4. **Need to quickly reinstall the service**
   - Use the management script: `./manage-svc alloy remove && ./manage-svc alloy deploy`

5. **Connection to Loki failing**
   - Verify network connectivity: `ss -ntp '( dst = :3100 )'`
   - Check Loki service is running properly
   - Use `./svc-exec -K alloy verify` to run comprehensive checks

## Testing Configuration Changes Safely

The role supports test mode to validate configuration changes before deploying to production.

### Test Mode Variables

```yaml
alloy_test_mode: false                # Default: production deployment
alloy_test_config_path: "/tmp/alloy-test-config-{timestamp}.alloy"
```

When `alloy_test_mode: true`:
- Configuration written to `/tmp` instead of `/etc/alloy/config.alloy`
- Service NOT restarted
- Safe to test potentially breaking changes
- Validate before deploying to production

### Example Test Playbook

Create a test playbook in your orchestration layer:

```yaml
---
- name: Test Alloy configuration changes
  hosts: monitoring_servers
  become: true
  vars:
    alloy_test_mode: true              # Enable test mode
    alloy_monitor_apache: true
    alloy_monitor_fail2ban: true
    alloy_loki_endpoints:
      - label: loki01
        endpoint: "10.0.0.11"

  roles:
    - jackaltx.solti_monitoring.alloy

  post_tasks:
    - name: Validate test config
      command: "alloy validate {{ alloy_test_config_path }}"
      register: validation
      failed_when: false

    - name: Compare with production config
      command: "diff -u /etc/alloy/config.alloy {{ alloy_test_config_path }}"
      register: config_diff
      failed_when: false
      changed_when: false

    - name: Display validation results
      debug:
        msg: |
          Validation: {{ 'PASSED' if validation.rc == 0 else 'FAILED' }}
          Config differs: {{ 'YES' if config_diff.rc != 0 else 'NO' }}

          Next: Deploy with production playbook if validation passed
```

### Test Workflow

1. **Generate test config** - Run playbook with `alloy_test_mode: true`
2. **Validate syntax** - `alloy validate` checks for errors
3. **Compare changes** - `diff` shows what will change in production
4. **Review output** - Examine validation and diff results
5. **Deploy if passed** - Run production playbook without test mode

### Benefits

- Catch configuration errors before production deployment
- See exactly what will change in production
- No service disruption during testing
- Safe rollback (just delete test file)

## Operational Verification

The role includes verification tasks for post-deployment health checks.

### Invoking Verification

Create a verification playbook in your orchestration:

```yaml
# playbooks/verify-alloy.yml
- hosts: monitoring_servers
  tasks:
    - include_role:
        name: jackaltx.solti_monitoring.alloy
        tasks_from: verify.yml
```

### What Verification Checks

- Service status (running/enabled)
- Network connectivity to Loki endpoints
- Configuration file validity

## License

MIT

## Development Tools

**Note for collection developers:** Helper scripts (`manage-svc.sh`, `svc-exec.sh`) are available in the parent repository for rapid role testing during development. See `.claude/DEVELOPMENT.md` for details.

End users should create their own orchestration playbooks using standard Ansible patterns as shown in the examples above.

## Author Information

Created by Jack Lavender with assistance from Anthropic's Claude. Extended by the community.
