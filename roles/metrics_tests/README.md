# Metrics Tests Role

## Overview

The `metrics_tests` role provides comprehensive verification and integration testing for the InfluxDB and Telegraf metrics collection stack. This role focuses on interoperability testing to ensure the complete metrics pipeline functions correctly from collection to storage.

## Purpose

This role is designed to:

- Verify correct operation of the InfluxDB-Telegraf metrics pipeline
- Confirm metrics data is being properly collected by Telegraf and stored in InfluxDB
- Test query capabilities and data retrieval from InfluxDB
- Generate detailed reports on integration status
- Identify configuration and connectivity issues between components

## Requirements

### Platform Support

- Debian/Ubuntu systems
- RedHat/CentOS systems
- Systemd-based systems

### Prerequisites

- InfluxDB service installed and running
- Telegraf service installed and running
- Network connectivity between Telegraf and InfluxDB
- Proper port access (InfluxDB default: 8086)

## Features

- Comprehensive verification of InfluxDB and Telegraf services
- Connection testing between components
- Metrics data ingestion verification
- Query capability testing
- Detailed report generation
- Integration with CI/CD pipelines
- Support for various metric collectors (CPU, memory, disk, network)

## Role Variables

```yaml
# Output directory for test reports
report_root: "{{ project_root }}/verify_output"
```

## Test Methodology

The role performs a series of tests including:

1. **Service Status Verification**
   - Checks if InfluxDB and Telegraf services are running and enabled
   - Verifies process states and systemd configurations

2. **Network Connectivity Tests**
   - Confirms InfluxDB is listening on port 8086
   - Verifies Telegraf has established a connection to InfluxDB
   - Examines network socket connections and TCP communication

3. **Data Flow Validation**
   - Tests that metrics are flowing from Telegraf to InfluxDB
   - Queries recent metrics to confirm data ingestion
   - Verifies no errors in metrics forwarding

4. **Query Functionality**
   - Tests InfluxDB's query API
   - Confirms data retrieval works correctly
   - Validates query response format

5. **Health Checks**
   - Verifies InfluxDB API health endpoints
   - Confirms bucket configuration and access
   - Tests write and read permissions

6. **Error Detection**
   - Examines service logs for errors
   - Verifies no critical issues in configuration
   - Identifies potential data loss scenarios

## Usage Examples

### Basic Verification

```yaml
- hosts: monitoring_servers
  roles:
    - role: metrics_tests
```

### Integration with CI/CD

```yaml
- hosts: ci_test_hosts
  roles:
    - role: metrics_tests
  vars:
    report_root: "/tmp/test_reports"
```

## Output and Reporting

The role generates detailed reports in YAML format containing:

- Service versions
- Service states
- Connection information
- Bucket information
- Query test results
- Write test results
- Error messages (if any)
- Detailed diagnostics

Reports are stored in the specified `report_root` directory and organized by distribution and hostname.

## Integration with Monitoring Stack

This role complements the monitoring stack by providing:

- Verification after initial deployment
- Regular health checks for the metrics pipeline
- Diagnostic information for troubleshooting
- Integration test capabilities for CI/CD pipelines

## Example Output

A successful test report includes:

```yaml
=== Monitor Stack Integration Test Results ===
Timestamp: 2025-03-23T12:34:56+00:00

Service Status:
- InfluxDB: running
- Telegraf: running

InfluxDB Status:
- Version: InfluxDB v2.7.3
- Health Check: pass
- API Status: true
- Write Test Success: true
- Query Test Success: true
- Bucket Configuration:
    Name: telegraf
    ID: 8f9a8e87c6940e4a
    Retention: infinite
    Organization ID: 8a7b6c5d4e3f2a1b

Telegraf Integration:
- Connection Status: Established
- Network Connections: [detailed connection info]
- Process Information: [detailed process info]

Recent Log Activity:
✓ No errors found in logs
```

## Testing in CI Environment

For CI/CD environments, the role can be adapted to:

- Run non-interactively
- Generate machine-readable reports
- Return appropriate exit codes
- Output JUnit-compatible test results

## Troubleshooting

Common issues and solutions:

1. **Connection failures**
   - Check network configuration
   - Verify port accessibility
   - Confirm service addresses

2. **Data not appearing in queries**
   - Check Telegraf configuration
   - Verify metric sources
   - Examine InfluxDB bucket configuration

3. **Write permission errors**
   - Verify token permissions
   - Check bucket access controls
   - Confirm organization settings

4. **Service status errors**
   - Check systemd service configuration
   - Verify permissions
   - Examine service logs

## How It Works

The role executes a comprehensive series of checks:

1. Verifies service status using `service_facts`
2. Checks port connectivity with `wait_for`
3. Examines network connections using `ss` utility
4. Tests data write and query capabilities
5. Inspects logs for errors
6. Verifies API health endpoints
7. Generates detailed reports

All tests are performed in sequence with proper error handling to provide a complete picture of the metrics pipeline health.

## License

MIT

## Author Information

Originally developed for verifying the InfluxDB-Telegraf metrics collection stack.
