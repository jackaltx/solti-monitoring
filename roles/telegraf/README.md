# Telegraf Ansible Role

## Overview

This role installs and configures [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/), InfluxData's plugin-driven server agent for collecting and reporting metrics. Telegraf integrates with the monitoring stack by collecting system and application metrics and sending them to InfluxDB for storage and analysis.

## Features

- Installs and configures Telegraf from official InfluxData repositories
- Manages Telegraf service lifecycle (start/stop/restart)
- Configures core system metrics collection (CPU, memory, disk, network)
- Supports optional collection modules for common applications:
  - Apache web server
  - MariaDB/MySQL
  - Memcached
  - Redis
- Configures InfluxDB output destinations with authentication
- Supports flexible ping monitoring for network targets
- Includes utility scripts for easy deployment and verification

## Requirements

### Platform Support

- Debian/Ubuntu systems (using `apt` package manager)
- RedHat-based systems (Rocky Linux, RHEL)
- Systemd-based systems

### Prerequisites

- Systemd-based operating system
- Network connectivity to InfluxDB endpoint(s)
- InfluxData package repository access

## Role Variables

### Main Control Variables

```yaml
# Installation state
telegraf_state: present           # Use 'absent' to remove Telegraf

# Configuration paths
telegraf_config: /etc/telegraf/telegraf.conf
telegraf_default_env: /etc/default/telegraf

# Uninstallation options
telegraf_delete_config: false     # Remove config files on uninstall
telegraf_delete_data: false       # Remove data files on uninstall
telegraf_clean_inputs: false      # Clean out existing input configs
```

### Metrics Collection Configuration

```yaml
# Optional metric collectors
influxdb_apache: false            # Apache metrics
influxdb_mariadb: false           # MariaDB/MySQL metrics
influxdb_memcache: false          # Memcached metrics
influxdb_redis: false             # Redis metrics

# Network monitoring targets
telegraf_ping_loc:
  - 1.1.1.1
  - 8.8.8.8
  - www.google.com
```

### InfluxDB Output Configuration

```yaml
# Output destinations (list of endpoint labels to use)
telegraf_outputs: ['localhost']

# Detailed configuration for each endpoint
telgraf2influxdb_configs:
  localhost:                      # Match label in telegraf_outputs
    url: "http://127.0.0.1"       # InfluxDB URL
    token: ""                     # Authentication token
    bucket: "telegraf"            # Destination bucket
    org: "myorg"                  # Organization
    namedrop: ["influxdb_oss"]    # Metrics to exclude
    insecure_skip_verify: false   # TLS verification option
```

## Installation

The role uses the official InfluxData package repositories to install Telegraf. It also configures the systemd service and manages necessary configuration files with appropriate permissions.

## Configuration

The role uses a template-based approach to configuration with three main components:

1. **Base Configuration** (`telegraf.conf`): Core agent settings
2. **Input Plugins** (`telegraf.d/*.conf`): Metric collection configuration
3. **Output Configuration** (`telegraf.d/output-*.conf`): Where to send metrics

### Global Configuration with group_vars

A recommended approach is to define your InfluxDB output configurations in a shared group_vars file:

```yaml
# group_vars/all/telegraf2influx-configs.yml
telgraf2influxdb_configs:
  localhost:
    url: "http://127.0.0.1"
    token: ""
    bucket: "telegraf"
    org: "myorg"
    namedrop: '["influxdb_oss"]'
    bucket_tag: ""
    exclude_bucket_tag: ""
    ping_timeout: "0s"
    read_idle_timeout: "0s"
    insecure_skip_verify: false
  production:
    url: "http://influxdb.example.com"
    token: !vault |
      $ANSIBLE_VAULT;1.1;AES256
      31643462363439373438373331633438383836326566633964646336386461626665613038313538
      6335323137333332636238646564373964326237656330380a363462303330643063386231333364
      66623366373334333332656163316363373036313133646661303266376661393765386238633165
      3566323233353862350a643066626538373730616461616534373937623230653532613035656166
      66386364643332666431383461326462363565386462326661613266383262383531313438326632
      30616234633164373462303233393733353666663531346532636633353464386632613130626330
      66666165623165356163323065356664306538393135373463653632626533396265393962313333
      38366663323439366262363263366632613239643632646561303161373463666563646361333231
      3937
    bucket: "telegraf"
    org: "myorg"
    namedrop: '["influxdb_oss"]'
    bucket_tag: ""
    exclude_bucket_tag: false
    ping_timeout: "0s"
    read_idle_timeout: "0s"
    insecure_skip_verify: false
```

This approach offers several advantages:

- Centralized configuration of multiple InfluxDB endpoints
- Secrets management with Ansible Vault
- Reusable configuration across multiple hosts
- Easy selection of endpoints per host or group

Then, in your host or group vars, you can selectively enable outputs:

```yaml
# host_vars/webserver.yml
telegraf_outputs: ['localhost', 'production']
```

Each component is generated from templates based on the role variables.

## Usage Examples

### Basic Installation with group_vars

```yaml
- hosts: servers
  roles:
    - role: telegraf
      vars:
        # Use endpoints defined in group_vars/all/telegraf2influx-configs.yml
        telegraf_outputs: ['localhost']
```

### Using the Utility Scripts

The included utility scripts make deploying and managing Telegraf simpler:

```bash
# Deploy Telegraf using the management script
./manage-svc telegraf deploy

# Verify Telegraf is working correctly
./svc-exec telegraf verify

# Deploy to a specific host
./manage-svc -h monitoring01 telegraf deploy
```

### Comprehensive Configuration

```yaml
- hosts: web_servers
  roles:
    - role: telegraf
      vars:
        # Enable application monitoring
        influxdb_apache: true
        influxdb_mariadb: true
        
        # Configure network monitoring
        telegraf_ping_loc:
          - db.example.com
          - api.example.com
          - 192.168.1.1
        
        # Select which endpoints from group_vars to use
        telegraf_outputs: ['localhost', 'monitor2']
```

### Removal Configuration

```yaml
- hosts: servers
  roles:
    - role: telegraf
      vars:
        telegraf_state: 'absent'
        telegraf_delete_config: true
        telegraf_delete_data: true
```

## Metrics Collection

### Core System Metrics

The role collects these system metrics by default:

- **CPU**: Usage per core and total, including time by state
- **Memory**: Available, used, cached, and swap metrics
- **Disk**: Space usage and IO operations
- **Network**: Interface traffic, errors, and packet counts
- **System**: Load, uptime, and process metrics

### Optional Application Metrics

Enable specific application monitoring:

**Apache Metrics:**

- Request counts, status codes, and types
- Worker status and performance metrics
- Connection statistics

**MariaDB/MySQL Metrics:**

- Query performance and throughput
- Connection statistics
- Buffer usage and cache metrics
- InnoDB metrics

**Memcached Metrics:**

- Cache hit/miss rates
- Memory usage
- Connection tracking
- Evictions and item counts

**Redis Metrics:**

- Command statistics
- Memory usage and fragmentation
- Connection tracking
- Keyspace statistics

## Directory Structure

```
telegraf/
├── defaults/
│   └── main.yml                 # Default variables
├── files/
│   ├── apache.conf              # Application configs
│   ├── mariadb.conf
│   ├── memcache.conf
│   ├── redis.conf
│   └── telegraf.conf            # Base configuration
├── handlers/
│   └── main.yml                 # Service handlers
├── meta/
│   └── main.yml                 # Role metadata
├── molecule/                    # Testing configuration
├── tasks/
│   ├── main.yml                 # Main tasks
│   ├── telegrafd-default-setup.yml
│   ├── telegrafd-inputs-setup.yml
│   └── telegrafd-outputs-setup.yml
├── templates/
│   ├── etc-default-telegraf-localhost.j2
│   ├── output.j2
│   └── ping.j2
└── README.md                    # This file
```

## Handlers

The role includes the following handlers:

- `Restart telegraf`: Restarts the Telegraf service when configuration changes

## Testing

The role includes Molecule tests for:

- Basic installation
- Configuration verification
- Service status checks
- Metrics collection functionality

## Integration with InfluxDB

### Automatic Token Discovery

When `telegraf_testing` is enabled and the target has InfluxDB installed locally, the role can automatically:

1. Detect if InfluxDB is running on the local system
2. Query InfluxDB for the system-operator token
3. Configure Telegraf to use this token for authentication

This feature is particularly useful for testing environments or single-node deployments where both InfluxDB and Telegraf are installed on the same machine.

```yaml
# Enable automatic token discovery for localhost connection
telegraf_testing: true
```

### Multi-Server Configuration

For production environments, the recommended approach is to:

1. Define all possible InfluxDB connections in `group_vars/all/telegraf2influx-configs.yml`
2. Secure tokens using Ansible Vault encryption
3. Selectively enable the appropriate connections per host using the `telegraf_outputs` variable

This provides flexibility to send metrics to different InfluxDB instances based on environment, geographic location, or other criteria.

```yaml
# In host_vars/webserver.yml
telegraf_outputs: ['localhost', 'monitor2']

# In host_vars/database.yml
telegraf_outputs: ['monitor2']
```

## Troubleshooting

Common issues and solutions:

1. **Service fails to start**
   - Check logs with `journalctl -u telegraf`
   - Verify configuration with `telegraf --config /etc/telegraf/telegraf.conf --test`
   - Use the verification script: `./svc-exec telegraf verify`

2. **No metrics being reported**
   - Verify InfluxDB endpoint is correct and accessible
   - Check token has correct permissions
   - Verify network connectivity
   - Use `./svc-exec telegraf verify1` for connection checks

3. **Missing application metrics**
   - Verify application module is enabled
   - Check application is accessible and properly configured
   - Verify service permissions for monitoring

4. **Need to quickly reinstall the service**
   - Use the management script: `./manage-svc telegraf remove && ./manage-svc telegraf deploy`

## Utility Scripts

This role can be easily managed using the following utility scripts included in the project:

### manage-svc.sh

This script helps manage service deployment states using dynamically generated Ansible playbooks.

```bash
Usage: manage-svc [-h HOST] <service> <action>

Options:
  -h HOST    Target host from inventory (default: uses hosts defined in role)

Services:
  - loki
  - alloy
  - influxdb
  - telegraf

Actions:
  - prepare
  - deploy
  - install  # Alias for deploy
  - remove
```

**Examples:**

```bash
# Deploy Telegraf to default hosts
./manage-svc telegraf deploy

# Remove Telegraf from a specific host
./manage-svc -h monitoring01 telegraf remove
```

### svc-exec.sh

This script executes specific tasks within a role for targeted operations like verification or configuration.

```bash
Usage: svc-exec [-K] [-h HOST] <service> [entry]

Options:
  -K        - Prompt for sudo password (needed for some operations)
  -h HOST   - Target specific host from inventory

Parameters:
  service   - The service to manage
  entry     - The entry point task (default: verify)
```

**Examples:**

```bash
# Run verification tasks for Telegraf on default hosts
./svc-exec telegraf verify

# Run specific verification task on a particular host
./svc-exec -h monitoring01 telegraf verify1
```

These scripts provide a convenient way to manage the lifecycle and perform specific operations on the Telegraf role.

## License

MIT

## Author Information

Created and maintained by Jack Lavender.
