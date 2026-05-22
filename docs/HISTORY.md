# solti-monitoring: What Actually Happened

<!-- Generated from git history analysis — update when significant new patterns emerge -->
<!-- Last analyzed: 2026-05-22 | Commits: 62 | Range: initial → HEAD -->

Written from git history, not from memory. Captures what was built, what was
hard, and critically — what was tried and reversed.

## Significant Features

### Obsidian Vault as Test Reporting (event-sourced architecture)
*5 commits — fully adopted*

Started as consolidated reports, evolved into an event-sourced Obsidian vault.
Raw verification data is embedded directly in markdown notes with InfluxDB2/3
dual-write support. Obsidian index regenerates automatically after Proxmox runs.

Pattern: test results as a knowledge graph, not flat files. Each test run
produces a linked note — you can navigate "what failed on Rocky 9 in March"
rather than grepping log files.

### InfluxDB3 Migration
*3 commits — complete*

Added v3 support alongside v2 for a dual-write period. Rocky 10 required a
systemd service override (systemd 257 incompatibility with the unit file).
The dual-support period was short — v3 is now primary.

### Alloy — Log Classifiers (kept) / Metrics (reverted)
*20+ commits — mixed outcome*

Heavy investment in Alloy for both log classification AND metrics collection.

**What stayed:** UFW, fail2ban, journald, Bind9, cron, Apache, Gitea log
classifiers. These work and are in production.

**What was reverted:** Alloy metrics collection to InfluxDB. After implementing
it, it was pulled back in favor of keeping Telegraf as the metrics path.
Alloy is logs-only.

This distinction matters — the natural instinct is to use Alloy for everything
since it's already deployed. Don't. Telegraf remains the metrics path.

Pain points during Alloy work:
- Selector syntax: single vs double quotes caused silent failures
- Label naming inconsistencies across classifiers
- Mail classifier required multiple iterations to stabilize

### GitHub CI + Proxmox Testing
*12 commits — working, required multiple fixes*

CI workflow took significant iteration to stabilize:
- Proxmox test template mapping for Debian distributions (wrong template selected)
- 2-minute wait required before verify phase — metrics need time to accumulate
- Shared verify playbook required for Proxmox scenario
- GPG timing issues on Ubuntu 24 CI runs
- Rocky 10 / systemd 257 InfluxDB3 service compatibility

### Multi-Distribution Support
*4 commits — ongoing*

Rocky 9 (primary), Debian 12/13, Ubuntu 24 all supported. Rocky 10 added later,
required the systemd override mentioned above.

## What Was Hard

The Alloy metrics attempt stands out — 15+ commits of work ultimately reverted.
The `checkpoint: add Alloy metrics implementation documentation` commit followed
by `refactor: remove Alloy metrics attempt, keep Telegraf scraper` tells the
story. The work informed the decision to keep clear separation: Alloy=logs,
Telegraf=metrics.

Proxmox test timing was consistently painful — the 2-minute wait before verify
feels wrong but is necessary. Metrics pipelines have real latency.

## Current Architecture (what survived)

```
Metrics:      hosts → Telegraf → InfluxDB3
Logs:         hosts → Alloy → Loki
Visualization: InfluxDB3 + Loki → Grafana
Test results: Molecule verify → Obsidian vault (event-sourced)
CI:           GitHub Actions + Proxmox molecule driver
```
