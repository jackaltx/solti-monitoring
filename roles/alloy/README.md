# Alloy Ansible Role

This role installs and configures Grafana Alloy, a vendor-neutral distribution of the OpenTelemetry (OTel) Collector that combines leading open source observability signals.

## Overview

The role manages:
- Installation of Grafana Alloy package
- Configuration of Alloy service
- Management of log collection and forwarding
- Integration with Loki endpoints
- Systemd service configuration

## Requirements

### Platform Support
- Debian/Ubuntu systems (uses apt for package management)
- Systemd-based systems

### Prerequisites
- Systemd
- A running Loki instance to receive logs
- Proper network connectivity to Loki endpoint

## Role Variables

### Required Variables

```yaml
alloy_loki_endpoint: "127.0.0.1"    # Loki server endpoint
```

### Optional Variables

```yaml
# Installation control
alloy_state: 'present'              # Use 'absent' to remove Alloy

# Configuration
alloy_config: "/etc/alloy/config.alloy"  # Path to main config file
alloy_custom_args: "--disable-reporting --server.http.listen-addr=0.0.0.0:12345"  # Custom CLI arguments

# Cleanup options
alloy_delete_config: false          # Whether to remove config files on uninstall
alloy_delete_data: false           # Whether to remove data directory on uninstall
```

## Configuration Features

### Log Sources
The role supports collecting logs from multiple sources:

1. Systemd Journal
   - Priority levels
   - Unit information
   - Transport metadata
   - Hostname labels

2. Apache Logs
   - Access logs with detailed request information
   - Error logs with extensive error categorization
   - ModSecurity integration
   - PHP error parsing

3. Fail2ban Logs
   - Jail information
   - Action categorization
   - Ban/Unban events

4. System Logs
   - Standard system logs
   - Application logs
   - Security events

### Metrics Collection

Additionally supports SNMP metrics collection from:
- QNAP NAS systems
- Ubiquiti Dream Machine
- Network interfaces
- System metrics

## Dependencies

This role has no direct dependencies on other Ansible roles.

## Example Playbook

Basic usage:

```yaml
- hosts: servers
  roles:
    - role: alloy
      vars:
        alloy_loki_endpoint: "loki.example.com"
```

Advanced configuration:

```yaml
- hosts: servers
  roles:
    - role: alloy
      vars:
        alloy_loki_endpoint: "loki.example.com"
        alloy_custom_args: "--disable-reporting --server.http.listen-addr=0.0.0.0:3100"
        alloy_config: "/etc/alloy/custom-config.alloy"
```

Removal configuration:

```yaml
- hosts: servers
  roles:
    - role: alloy
      vars:
        alloy_state: 'absent'
        alloy_delete_config: true
        alloy_delete_data: true
```

## Handlers

The role includes the following handlers:

- `restart alloy`: Restarts the Alloy service and reloads systemd daemon

## File Structure

```
alloy/
├── defaults/
│   └── main.yml           # Default variables
├── files/
│   ├── amber-config.alloy # Example configurations
│   ├── apache-error.alloy
│   ├── qnap.alloy
│   └── udm.alloy
├── handlers/
│   └── main.yml          # Service handlers
├── tasks/
│   └── main.yml          # Main tasks
└── templates/
    ├── client-config-alloy.j2   # Main config template
    └── etc-default-alloy.j2     # Environment config
```

## License

BSD

## Author Information

Originally created by Anthropic and Jack. Extended by the community.

## Proposed Development Directions

### 1. Enhanced Log Processing
- Implement advanced parsing for additional log formats:
  - Mail server logs (Postfix, Dovecot)
  - Database logs (MySQL, PostgreSQL)
  - Container logs (Docker, Kubernetes)
- Add support for custom log parsing templates
- Develop pre-built parsing configurations for common applications

### 2. Metrics Collection Enhancement
- Expand SNMP collection capabilities:
  - Additional network device support
  - Extended metrics for existing devices
  - Custom MIB support
- Add native support for:
  - Prometheus metrics scraping
  - StatsD protocol
  - JMX metrics collection

### 3. Security Improvements
- Add support for TLS encryption for Loki connections
- Implement log signing and verification
- Add role-based access control for metrics collection
- Enhance sensitive data masking capabilities
- Add audit logging for configuration changes

### 4. Scaling and Performance
- Implement log buffering and batching
- Add support for multiple Loki endpoints with load balancing
- Implement metric aggregation and pre-processing
- Add support for high-availability configurations
- Optimize resource usage for high-volume environments

### 5. Configuration Management
- Add validation for configuration files
- Implement configuration version control
- Add support for dynamic configuration reloading
- Develop configuration templates for common use cases
- Add configuration migration tools

### 6. Monitoring and Self-Observability
- Add health check endpoints
- Implement performance metrics collection
- Add self-monitoring capabilities
- Develop alerting integration
- Add diagnostic tools for troubleshooting

### 7. Integration Capabilities
- Add support for cloud provider integrations:
  - AWS CloudWatch
  - Azure Monitor
  - Google Cloud Monitoring
- Implement webhook support for external notifications
- Add support for external authentication systems
- Develop API integration capabilities

### 8. Testing and Quality Assurance
- Expand test coverage:
  - Unit tests for configuration generation
  - Integration tests for log collection
  - Performance benchmarking tests
- Add automated configuration validation
- Implement continuous integration pipelines
- Add load testing capabilities

### 9. Documentation and Usability
- Create interactive configuration guides
- Develop troubleshooting documentation
- Add more example configurations
- Create deployment best practices guide
- Improve variable documentation

### 10. Platform Support
- Add support for additional Linux distributions
- Implement Windows log collection
- Add MacOS support
- Develop container-native deployment options
- Add support for ARM architectures


## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Notes

- The role automatically handles service restarts when configuration changes
- Supports graceful uninstallation with configurable cleanup options
- Includes extensive log parsing and labeling capabilities
- Provides flexible SNMP metric collection options