# Telegraf Role

This Ansible role installs and configures Telegraf on Debian 12 systems. Telegraf is an agent for collecting, processing, aggregating, and writing metrics.

## Features

- Installs Telegraf package
- Configures basic system metrics collection (CPU, memory, disk, network, etc.)
- Supports outputting metrics to InfluxDB v2
- Optional metric collection for:
  - Apache 
  - MariaDB
  - Memcache
  - Redis
  - InfluxDB OSS metrics
- Ping monitoring for specified hosts
- Supports both installation and removal workflows

## Requirements

- Debian 12 (Bookworm)
- Ansible 2.1 or higher

## TLS Connectivity

Telegraf operates in two distinct TLS roles:

1. **Output Connections** (e.g., to InfluxDB):
   - Telegraf acts as a TLS client
   - Can use standard TLS client configuration (cert, key, CA verification)
   - Current role supports basic TLS config for InfluxDB output via `insecure_skip_verify`

2. **Input Collection** (e.g., SNMP, HTTP endpoints):
   - Telegraf acts as a TLS client when scraping remote endpoints
   - Each input plugin can have its own TLS client configuration
   - Plugin-specific TLS settings needed per input


## Role Variables

### Main Configuration

- `telegraf_state`: Installation state ['present', 'absent']
- `telegraf_delete_config`: Whether to delete config files on removal  
- `telegraf_delete_data`: Whether to delete data files on removal
- `telegraf_outputs`: List of output destinations

### Optional Metric Collection

Enable/disable collection of additional metrics:

```yaml
influxdb_apache: false
influxdb_mariadb: false
influxdb_memcache: false  
influxdb_redis: false
influxdb_oss_metrics: false
```

### InfluxDB Output Configuration

Configure InfluxDB connection details in `telgraf2influxdb_configs`:

```yaml
telgraf2influxdb_configs:
  localhost:
    url: "http://localhost" 
    token: ""
    bucket: "telegraf"
    org: "myorg"
    # Additional options...
```

## Example Playbook

```yaml
---
- hosts: metrics_collectors
  vars:
    # Basic setup
    telegraf_state: present
    telegraf_outputs: ['localhost']
    
    # InfluxDB output configuration
    telgraf2influxdb_configs:
      localhost:
        url: "https://influxdb.example.com"
        token: "{{ vault_influxdb_token }}"
        bucket: "system_metrics"
        org: "myorg"
        insecure_skip_verify: false
        
    # Enable additional collectors
    influxdb_apache: true
    
    # Configure ping targets
    telegraf_ping_loc:
      - "1.1.1.1"
      - "8.8.8.8"
      - "gateway.example.com"
    
    # SNMP collection example with TLS
    telegraf_snmp_configs:
      - name: "core_switch"
        agents: ["tcp://switch.example.com:161"]
        tls_ca: "/etc/telegraf/ca.pem"
        tls_cert: "/etc/telegraf/cert.pem"
        tls_key: "/etc/telegraf/key.pem"

  roles:
    - telegraf
```

## Recommendations for Improvement

1. **Operating System Support**:
   - Add support for Rocky Linux 9 and other major Linux distributions
   - Create separate OS-specific variable files
   - Abstract package management tasks

2. **Configuration Management**:
   - Make configuration more modular
   - Add templates for additional metrics collection
   - Improve validation of configuration parameters

3. **Security**:
   - Add support for TLS/SSL configuration
   - Improve token/credentials handling
   - Add SELinux support for Rocky Linux

4. **Features**:
   - Add support for additional input plugins
   - Add support for additional output destinations
   - Add support for Telegraf processors and aggregators

5. **Testing**:
   - Add molecule tests
   - Add CI/CD integration
   - Add linting with ansible-lint

## Rocky 9 Extension Plan

To extend this role to Rocky 9, the following changes would be needed:

1. **Package Management**:
   - Add RPM repository configuration 
   - Update package installation tasks for dnf
   - Handle SELinux contexts

2. **File Paths**: 
   - Account for different default paths in Rocky
   - Update templates for Rocky-specific configurations

3. **Service Management**:
   - Update systemd service handling for Rocky
   - Add appropriate security contexts

4. **Dependencies**:
   - Update prerequisites for Rocky
   - Handle EPEL repository requirements

5. **Variables**: 
   - Add Rocky-specific variables file
   - Update defaults for Rocky environment

## License

MIT

## Author Information

[Original Author Info]

Let me know if you would like me to expand any section or add additional details!