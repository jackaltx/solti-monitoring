# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Debian 13 (Trixie) support for all roles
- Podman test container for Debian 13 (uut-ct3)
- TESTING.md documentation for all roles

### Changed

- Modernized InfluxDB GPG key handling (removed deprecated apt_key)
- Cloud-init wait in Proxmox prepare uses `--wait` flag
- InfluxDB service now enabled on boot (not just started)

### Fixed

- Duplicate `alloy_filter_cron_noise` variable definition
- Deprecated `ansible_date_time` variable usage (now uses `ansible_facts['date_time']`)
- Undefined variable guard in network diagnostics
- OLDPWD error in run-proxmox-tests.sh script

## [1.0.0] - 2025-01-18

### Initial Release

- Initial release of solti-monitoring collection
- Support for Debian 11/12, Rocky 9, Ubuntu 24
- Roles: alloy, loki, telegraf, influxdb, fail2ban_config, wazuh_agent
- Molecule testing scenarios: podman, proxmox, github
- Comprehensive verification tasks for all roles

### Documentation

- Role READMEs with usage examples
- CLAUDE.md with development context
- Test execution scripts (run-podman-tests.sh, run-proxmox-tests.sh)

[Unreleased]: https://github.com/jackaltx/solti-monitoring/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/jackaltx/solti-monitoring/releases/tag/v1.0.0
