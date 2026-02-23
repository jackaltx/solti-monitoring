# Tech Stack

## Programming Languages

*   **Python:** Primarily used for Ansible modules, plugins, and scripting.

## Configuration Management

*   **Ansible:** Core automation engine for deployment, configuration, and orchestration of infrastructure components.

## Core Monitoring & Logging Technologies

*   **InfluxDB:** Time-series database for storing and querying metrics data.
*   **Telegraf:** Agent for collecting and sending metrics to InfluxDB.
*   **Loki:** Log aggregation system for storing and querying log data.
*   **Alloy:** Agent for collecting and sending logs to Loki.

## Security & Active Response

*   **Fail2Ban:** Intrusion prevention software that scans log files and bans suspicious IPs.
*   **Wazuh:** Security monitoring platform for threat detection, integrity monitoring, incident response, and compliance.

## Testing & Development Tools

*   **Molecule:** Framework for testing Ansible roles and collections across various environments.
*   **Podman:** Container engine used for container-based testing environments (e.g., in CI).
*   **Proxmox:** Virtualization platform used for VM-based full-stack testing environments.
*   **Git:** Version control system.

## Continuous Integration / Continuous Deployment

*   **GitHub Actions:** Platform for automating workflows, including CI/CD pipelines.
