# Analysis of the `influxdb` Ansible Role for V3 Migration

This document outlines the current structure of the `influxdb` Ansible role and identifies the key areas that will require modification to support InfluxDB V3.

## Current Role Structure (InfluxDB v2)

The existing `influxdb` role is designed to install, configure, and manage InfluxDB v2.

### Key Variables (`defaults/main.yml`)

-   **`influxdb_state`**: Controls installation (`present`) or removal (`absent`).
-   **`influxdb_configure`**: A boolean that triggers the configuration process.
-   **Credentials (`influxdb_org`, `influxdb_bucket`, `influxdb_username`, `influxdb_password`)**: Used for the initial setup of the InfluxDB v2 instance.
-   **`influxdb_buckets`**: A list of additional buckets to create.
-   **`influxdb_data_path`**: Defines the local storage path for InfluxDB data (`/var/lib/influxdb`).
-   **`influxdb_nfs`**: An option to mount the data directory via an NFS share.
-   **`influx_pkgs` (`vars/main.yml`)**: A dictionary of InfluxDB v2 package names for different operating systems.

### Core Tasks (`tasks/main.yml`)

-   **Installation**: The role uses the system's package manager to install InfluxDB v2 based on the `influx_pkgs` variable.
-   **Configuration**:
    -   It templates a primary configuration file from `config.toml.j2` to `/etc/influxdb/config.toml`.
    -   It also templates a secondary file, `etc-default-influxdb.j2`, to `/etc/default/influxdb2`.
-   **Initialization**: A dedicated task, `initializedb.yml`, uses the InfluxDB v2 CLI (`influx`) to perform the initial setup, including creating the organization, user, and buckets.
-   **Service Management**: It manages the `influxdb` systemd service.
-   **Removal**: When `influxdb_state` is `absent`, it removes the package and can optionally delete configuration and data files.

## Identified Areas for V3 Modification

Based on the research into InfluxDB V3, the following areas of the role will require significant changes:

1.  **Installation Method**:
    -   The `influx_pkgs` variable will be obsolete. The installation logic must be updated to either use the official InfluxDB v3 installation script, manage a binary download, or integrate with a container-based approach (Docker).

2.  **Configuration Management**:
    -   The `config.toml.j2` template is incompatible with V3. A new configuration template will be needed to support V3's structure, including settings for the object store, node ID, and cluster ID.
    -   The `/etc/default/influxdb2` file is likely unnecessary for V3.

3.  **Initialization and Authentication**:
    -   The `initializedb.yml` task must be completely rewritten. The InfluxDB v2 CLI commands for setup are not compatible with V3.
    -   The new process will involve using the `influxd` or `influxdb3` CLI to generate an admin token.
    -   All credential handling (`influxdb_username`, `influxdb_password`) must be adapted to V3's token-centric authentication model. The `influxdb_operators_token` will need to be created and managed using the V3 CLI.

4.  **API and CLI Commands**:
    -   All direct calls to the `influx` CLI must be replaced with the equivalent `influxd` or `influxdb3` commands.

5.  **Data and Storage**:
    -   While the `influxdb_data_path` variable can be reused for file-based object storage, the role should be aware that V3 has a different underlying storage format.
    -   The NFS mounting logic should still be applicable for local file storage.

6.  **Systemd Service**:
    -   The name of the systemd service file for InfluxDB v3 might be different (e.g., `influxd.service`). The role's service management tasks will need to be updated to reflect this.

7.  **Backward Compatibility Strategy**:
    -   A decision must be made on whether to create a new `influxdb3` role or to update the existing `influxdb` role with conditional logic to support both V2 and V3. Given the number of breaking changes, a new role is likely the cleaner approach.
