# Ansible Role Migration Strategy: InfluxDB V2 to V3

This document outlines the designed strategy for migrating the Ansible role from supporting InfluxDB V2 to InfluxDB V3.

## Decision: Create a New `influxdb3` Role

Given the significant breaking changes between InfluxDB V2 and V3 (including a different query language, a new storage engine, and a completely different CLI and API), a new, separate Ansible role named `influxdb3` will be created.

**Rationale:**

-   **Clarity and Maintainability:** A separate role avoids the complexity of conditional logic to support two vastly different versions, making the new role easier to understand, maintain, and extend.
-   **Reduced Risk:** It eliminates the risk of introducing unintended side effects into existing deployments that rely on the stable InfluxDB V2 role.
-   **Clean Slate:** It allows for a fresh implementation that is idiomatic to InfluxDB V3 without being constrained by the legacy structure of the V2 role.

## Data Migration

As per the requirements for this test environment, **data migration from InfluxDB v2 to v3 is out of scope.** The focus will be on establishing a functional InfluxDB v3 instance and ensuring it can receive new data.

## Parallel Operation and Telegraf Integration

The `influxdb3` role will be designed to allow InfluxDB v3 to run in parallel with an existing InfluxDB v2 instance. This will be achieved by using distinct ports, data directories, and service names.

The `telegraf` role will be updated to configure it to send metrics to both the InfluxDB v2 and InfluxDB v3 instances simultaneously. This will involve adding a second `outputs.influxdb_v2` plugin to the Telegraf configuration, one for each database instance.

## `influxdb3` Role Design Outline

The new `influxdb3` role will be structured as follows:

### `defaults/main.yml` (Proposed Variables)

```yaml
# Controls whether to install ('present') or remove ('absent') the role
influxdb3_state: "present"

# Version of InfluxDB v3 to install
influxdb3_version: "3.0.0"

# Installation method: "package" (e.g., dnf, apt), "script", "binary", or "docker"
influxdb3_install_method: "package" # Default to package if available

# Controls whether to apply configuration
influxdb3_configure: true

# HTTP port for the InfluxDB v3 service, to avoid conflict with v2
influxdb3_http_bind_port: 8087

# Controls whether to perform the initial setup (token, org, bucket creation)
influxdb3_initial_setup: true

# InfluxDB v3 organization, bucket, and token names
influxdb3_org: "my-org"
influxdb3_bucket: "my-bucket"
influxdb3_admin_token_name: "admin-token"
influxdb3_operator_token_name: "operator-token"

# Variables to store the generated tokens (will be set via register)
influxdb3_admin_token: ""
influxdb3_operator_token: ""

# Path for the file-based object storage
influxdb3_data_path: "/var/lib/influxdb3"

# Type of object store: "file" or "memory"
influxdb3_object_store: "file"

# Controls whether to delete configuration and data on removal
influxdb3_delete_config: false
influxdb3_delete_data: false
```

### `tasks/main.yml` (Execution Flow)

1.  **Main Block for `influxdb3_state: 'present'`**:
    -   **Installation**: A task to handle installation based on `influxdb3_install_method`. This will involve using the appropriate package manager (e.g., `dnf`, `apt`), downloading and running the official InfluxDB installation script, or managing a binary/Docker installation.
    -   **Configuration**: Create the configuration directory (e.g., `/etc/influxdb3`) and template the new V3 `config.toml.j2`.
    -   **Service Management**: Manage the `influxd` systemd service (start, stop, enable).
    -   **Initial Setup**:
        -   A conditional block for `influxdb3_initial_setup`.
        -   Wait for the service to become available on its HTTP port.
        -   Use the `influxd` or `influxdb3` CLI to perform the initial setup: create the admin token, organization, bucket, and operator token.
        -   Register the generated tokens as Ansible facts for use in subsequent plays.
2.  **Main Block for `influxdb3_state: 'absent'`**:
    -   Stop and disable the `influxd` service.
    -   Remove the InfluxDB package or binary.
    -   Optionally remove configuration and data directories.

### `templates/config.toml.j2` (New V3 Template)

A new template will be created for the InfluxDB v3 configuration file. It will be structured to support V3-specific settings, such as:

-   `http-bind-address` (using the `influxdb3_http_bind_port` variable)
-   `object-store` (e.g., `file`)
-   `data-path` (for the file object store)
-   Other relevant V3 configuration options.

## Molecule Testing Plan

-   **New Scenario**: A dedicated Molecule scenario will be created for the `influxdb3` role.
-   **Converge Playbook**: The `converge.yml` playbook will execute the `influxdb3` role to perform a full installation and configuration.
-   **Verification Playbook**: The `verify.yml` playbook will be updated to perform V3-specific tests:
    -   Verify that the `influxd` service is running and enabled.
    -   Use the `influxdb3` CLI or API, authenticated with the generated admin token, to confirm:
        -   The target organization exists.
        -   The target bucket exists.
    -   Perform a simple write-and-read test: insert a data point into the test bucket and query it back to ensure the data pipeline is functional.
