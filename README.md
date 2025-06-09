Ansible Collection - jackaltx.solti_monitoring

A comprehensive monitoring ecosystem for modern infrastructure, integrating metrics and log collection using Telegraf, InfluxDB, Alloy, and Loki. Part of the SOLTI (Systems Oriented Laboratory Testing & Integration) framework with advanced testing and utility script automation.
What is SOLTI?

Systems Oriented Laboratory Testing & Integration (SOLTI) is a suite of Ansible collections designed for defining and testing networked laboratory environments. The project emphasizes methodical testing, system behavior analysis, and component integration to combat entropy and maintain reliable systems.

solti/
├── solti-monitoring/   # System monitoring and metrics collection (this project)
├── solti-conductor/    # Proxmox management and orchestration
├── solti-ensemble/     # Support tools and shared utilities
├── solti-containers/   # Support containers for testing
└── solti-score/        # Documentation and playbooks

Architecture Overview

The collection is built around two parallel monitoring pipelines with comprehensive testing frameworks:
Monitoring Pipelines
Metrics Pipeline

    Telegraf (Client): Collects system and application metrics
    InfluxDB (Server): Stores time-series metrics data
    Supports customizable input plugins and multiple output configurations

Logging Pipeline

    Alloy (Client): Collects and forwards system and application logs
    Loki (Server): Stores and indexes log data
    Flexible configuration for various log sources and filtering

Testing Framework

    Multi-Environment Testing: GitHub CI, Podman containers, Proxmox VMs
    Verification System: Multi-level verification tasks for deep testing
    Utility Scripts: Purpose-built scripts for efficient operations
        manage-svc.sh: Service lifecycle management
        svc-exec.sh: Task-oriented service operations

AI-Powered Security Integration

Security roles include Claude AI integration for professional analysis:

    Git-Based Configuration Versioning: Complete audit trails
    Intelligent Recommendations: AI-powered security assessments
    Compliance Validation: Automated security framework alignment

Getting Started
Prerequisites

    Ansible 2.9 or higher
    Python 3.6 or higher
    Supported platforms: Debian 11/12 (primary), Rocky Linux 9 (experimental)
    For testing: Podman/Docker or Proxmox environment

Installation

bash

ansible-galaxy collection install jackaltx.solti_monitoring

Core Roles
Server Components
InfluxDB

Time Series Database for Metrics Storage - Automated InfluxDB v2.x installation with bucket management, token-based authentication, and support for both local disk and S3-compatible storage. Includes initial setup, organization configuration, and integration preparation for Telegraf clients.
Loki

Log Aggregation System - Horizontally-scalable log storage with label-based indexing. Supports local filesystem, NFS mounts, and S3-compatible object storage. Designed for cost-effective operation without full-text indexing, focusing on efficient label-based queries.
Client Components
Telegraf

Metrics Collection Agent - Collects system and application metrics with support for multiple input plugins (CPU, memory, disk, network, Apache, MySQL, Redis, Memcached). Configurable outputs to multiple InfluxDB instances with automatic token discovery for local installations.
Alloy

Log Collection Agent - Modern log collector based on Grafana Alloy. Supports systemd journal, file sources, and application-specific log parsing for Apache, Bind9, Fail2ban, mail services, WireGuard, and Gitea. Includes multi-line log support and label enrichment.
Support Components
NFS Client

NFS Storage Support - Manages NFS client installation and mount configuration with optimized mount options for monitoring components. Supports multiple shares and cross-platform compatibility.
Testing & Verification
Log Tests

Log Pipeline Verification - Comprehensive testing for the Loki-Alloy log collection stack. Validates service connectivity, data flow, query capabilities, and generates detailed integration reports.
Metrics Tests

Metrics Pipeline Verification - Integration testing for the InfluxDB-Telegraf metrics collection stack. Verifies data ingestion, query functionality, bucket configuration, and health status.
Security & Configuration Management
Fail2Ban Config

Fail2Ban with Git Versioning - Manages Fail2Ban with integrated Git-based configuration tracking. Provides complete version control of security configurations with automatic commits, rollback capabilities, and compliance audit trails.
Wazuh Agent

Security Monitoring Agent - Comprehensive Wazuh agent management with deployment profiles (isolated, internal, internet_facing, ispconfig), intelligent service detection, Git-based configuration versioning, and container environment support.
Deployment Patterns
Quick Deploy with Utility Scripts

bash

$ ./manage-svc.sh
Usage: manage-svc.sh [-h HOST] <service> <action>

Services: loki, alloy, influxdb, telegraf
Actions: remove, install, deploy, prepare

Deploy using inventory default groups:

bash

# Deploy a metrics server

./manage-svc.sh influxdb deploy

# Deploy a log server

./manage-svc.sh loki deploy

Or target specific hosts:

bash

# Deploy clients to specific hosts

./manage-svc.sh -h client01 telegraf deploy
./manage-svc.sh -h client01 alloy deploy

Complete Stack Deployment

yaml

- name: Deploy Monitoring Server
  hosts: monitoring_servers
  roles:
  - role: influxdb
      vars:
        influxdb_org: "myorg"
        influxdb_bucket: "metrics"

  - role: loki
      vars:
        loki_local_storage: true

- name: Deploy Monitoring Agents
  hosts: all_servers
  roles:
  - role: telegraf
      vars:
        telegraf_outputs: ['central']
        telgraf2influxdb_configs:
          central:
            url: "<http://monitoring.example.com:8086>"
            token: "{{ influxdb_token }}"
            bucket: "telegraf"
            org: "myorg"

  - role: alloy
      vars:
        alloy_loki_endpoints:
          - label: main
            endpoint: "monitoring.example.com"
        alloy_monitor_apache: true

Advanced Configuration
Storage Configuration
InfluxDB Storage Options

yaml

# Local storage (default)

influxdb_data_path: /var/lib/influxdb

# NFS storage

influxdb_data_path: /mnt/nfs/influxdb
mount_nfs_share: true
cluster_nfs_mounts:
  influxdb:
    src: "nfs.example.com:/storage/influxdb"
    path: "/mnt/nfs/influxdb"
    opts: "rw,noatime,bg"
    state: "mounted"
    fstype: "nfs4"

Loki Storage Options

yaml

# Local storage

loki_local_storage: true

# S3 storage

loki_local_storage: false
loki_endpoint: "s3.example.com"
loki_s3_bucket: "loki-logs"
loki_key_id: "ACCESS_KEY_ID"
loki_access_key: "SECRET_ACCESS_KEY"

Testing Infrastructure
Molecule Framework

Multiple test scenarios for comprehensive verification:

    GitHub: CI-focused testing with Podman containers
    Podman: Local container-based testing
    Proxmox: Full stack VM-based testing

Verification System

Multi-layered verification provides deployment confidence:

    Level 0: Core service functionality
    Level 1: Component interaction
    Level 2: Advanced functionality

bash

# Run verification for Loki

./svc-exec.sh loki verify

# Run extended verification

./svc-exec.sh loki verify1

# Run specific tasks

./svc-exec.sh influxdb backup

Utility Scripts
manage-svc.sh

Service lifecycle management with dynamically generated playbooks.
svc-exec.sh

Task-oriented service operations for verification and maintenance.

Both scripts provide convenient ways to manage the monitoring stack without manually creating playbooks.
AI-Powered Security Analysis

Security roles in this collection integrate with Claude AI for professional analysis:

    Configuration Auditing: Automated security baseline assessment
    Compliance Validation: Alignment with security frameworks
    Intelligent Recommendations: AI-powered remediation guidance
    Change Tracking: Git-based configuration versioning

Want to try professional AI-powered security analysis? Sign up for Claude with my referral if ya want!
Part of the SOLTI Ecosystem

This collection is part of the broader SOLTI framework:

    solti-monitoring: System monitoring and metrics collection (this collection)
    solti-ensemble: Support tools and shared utilities
    solti-conductor: Proxmox management and orchestration
    solti-containers: Testing containers
    solti-score: Documentation and playbooks

Installation

bash

ansible-galaxy collection install jackaltx.solti_monitoring

Usage

yaml

- hosts: monitoring_servers
  roles:
  - jackaltx.solti_monitoring.influxdb
  - jackaltx.solti_monitoring.loki

- hosts: monitored_servers  
  roles:
  - jackaltx.solti_monitoring.telegraf
  - jackaltx.solti_monitoring.alloy

License

MIT License - see the LICENSE file for details
Authors

    Jack Lavender - Infrastructure automation and testing specialist
    Claude AI - AI-powered development assistant

This project represents a collaborative effort combining practical infrastructure expertise with systematic documentation and architectural design.
