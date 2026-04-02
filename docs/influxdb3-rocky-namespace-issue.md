# InfluxDB3 systemd Mount Namespace Failure on Rocky Linux 9/10

## Issue Summary

InfluxDB3 Core service fails to start on Rocky Linux 9 and Rocky Linux 10 due to a systemd mount namespace permission error. The service crashes immediately with exit code 226/NAMESPACE.

## Affected Systems

- **OS:** Rocky Linux 9.x (systemd 252), Rocky Linux 10.x (systemd 257) (likely affects AlmaLinux and RHEL as well)
- **InfluxDB3 version:** influxdb3-core (packaged version from InfluxData repository)
- **Unaffected:** Debian 12, Debian 13, Ubuntu 24

## Error Details

### Symptom

Service fails to start with repeated crash-loop attempts (5 failures) before systemd gives up:

```
influxdb3-core.service: Failed at step NAMESPACE spawning /usr/lib/influxdb3/python/bin/python3: Permission denied
influxdb3-core.service: Main process exited, code=exited, status=226/NAMESPACE
```

### Journal Output

```
Apr 02 14:31:49 uut-vm systemd[71384]: Failed to mount /run/systemd/inaccessible/sock to /run/systemd/unit-root/run/dbus/system_bus_socket: Permission denied
Apr 02 14:31:49 uut-vm systemd[71384]: influxdb3-core.service: Failed to set up mount namespacing: /run/systemd/unit-root/run/dbus/system_bus_socket: Permission denied
Apr 02 14:31:49 uut-vm systemd[71384]: influxdb3-core.service: Failed at step NAMESPACE spawning /usr/lib/influxdb3/python/bin/python3: Permission denied
```

### Root Cause

The InfluxDB3 systemd unit file (`/usr/lib/systemd/system/influxdb3-core.service`) includes security hardening directives:

```ini
[Service]
# ... other directives ...
InaccessiblePaths=-/run/avahi-daemon -/run/cups -/run/snapd.socket -/run/dbus/system_bus_socket
InaccessiblePaths=-/tmp/.X11-unix -/tmp/.XIM-unix -/tmp/.ICE-unix -/tmp/.font-unix -/run/user
```

The `-/run/dbus/system_bus_socket` directive causes systemd 252 on Rocky Linux to fail when attempting to mount it to `/run/systemd/inaccessible/sock` as part of the mount namespace isolation.

**Why this happens:**
- The `-` prefix means "ignore if missing" but systemd still attempts the mount operation
- On Rocky Linux 9 (systemd 252) and Rocky 10 (systemd 257), the mount operation fails with "Permission denied"
- SELinux is **not** the cause (confirmed via `ausearch` - no AVC denials)
- This appears to be a systemd behavior difference between Debian/Ubuntu and RHEL-based distributions
- **Rocky 10 update:** systemd 257 fails even when removing only the dbus socket from InaccessiblePaths

## Workaround

Create a systemd override that completely removes the `InaccessiblePaths` directive:

```bash
sudo mkdir -p /etc/systemd/system/influxdb3-core.service.d
sudo tee /etc/systemd/system/influxdb3-core.service.d/rocky-fix.conf <<'EOF'
[Service]
# Completely override InaccessiblePaths to fix Rocky 9/10 mount namespace issue
# Rocky 9 (systemd 252) and Rocky 10 (systemd 257) both fail with dbus socket
# Removing ALL InaccessiblePaths to prevent "Permission denied" errors
InaccessiblePaths=
EOF

sudo systemctl daemon-reload
sudo systemctl restart influxdb3-core
```

**Note:** This override completely removes ALL `InaccessiblePaths` directives. An initial fix that only removed `/run/dbus/system_bus_socket` worked on Rocky 9 (systemd 252) but failed on Rocky 10 (systemd 257), requiring this more aggressive approach.

## Automated Fix

The `solti-monitoring` influxdb3 role automatically detects and applies this fix on Rocky/AlmaLinux/RedHat systems:

1. Attempts to start the service
2. Waits 3 seconds for potential crash-loop
3. Checks `journalctl` for NAMESPACE errors
4. If detected on RHEL-based systems, applies the systemd override automatically
5. Reloads systemd and restarts the service

See: `roles/influxdb3/tasks/main.yml` lines 57-138

## Investigation Notes

### Why journalctl instead of service_facts?

Service status checks via `service_facts` were unreliable because:
- Service crashes too quickly (< 1 second)
- systemd may not have updated service state before the check runs
- Journal entries provide immediate, definitive evidence of the failure

Using `journalctl -u influxdb3-core -n 10 --no-pager` and checking for `NAMESPACE` in the output is a more reliable detection method.

### Security Implications

Removing ALL `InaccessiblePaths` directives reduces filesystem isolation:

- InfluxDB3 process can now access sockets like D-Bus, CUPS, and desktop services
- In practice, InfluxDB3 is a network service that doesn't use these sockets
- All other security hardening remains in place:
  - `NoNewPrivileges=true`
  - `PrivateDevices=true`
  - `PrivateIPC=true`
  - `PrivateTmp=true`
  - `ProtectHome=true`
  - `ProtectKernelLogs=true`
  - `ProtectSystem=strict`
  - `RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX`
  - `RestrictNamespaces=true`
  - `SystemCallFilter=@system-service`
  - Network access remains unrestricted as required for the database service

## Reporting Upstream

This issue should be reported to:

**Primary:** InfluxData (influxdb3-core package maintainer)
- GitHub: https://github.com/influxdata/influxdb
- The systemd unit file should conditionally exclude this directive on RHEL-based systems

**Secondary:** Rocky Linux (if systemd behavior differs from upstream RHEL)
- If this is Rocky-specific and not present in RHEL 9, report to Rocky Linux

**Possible systemd issue:** If this is a systemd 252 regression
- Check if fixed in newer systemd versions
- May be worth reporting to systemd upstream

## Reproduction Steps

1. Install InfluxDB3 Core on Rocky Linux 9 or 10:
   ```bash
   # Add InfluxData repository (steps omitted)
   sudo dnf install influxdb3-core
   ```

2. Attempt to start the service:
   ```bash
   sudo systemctl start influxdb3-core
   ```

3. Observe failure:
   ```bash
   sudo systemctl status influxdb3-core
   sudo journalctl -u influxdb3-core -n 20 --no-pager
   ```

4. Look for `NAMESPACE` errors in journal output

## References

- systemd InaccessiblePaths documentation: https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#InaccessiblePaths=
- systemd mount namespacing: https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#Sandboxing
- InfluxDB3 systemd unit: `/usr/lib/systemd/system/influxdb3-core.service`

## Related Files

- Detection/Fix: `roles/influxdb3/tasks/main.yml`
- This document: `docs/influxdb3-rocky-namespace-issue.md`

---

**Discovered:** 2026-04-02
**Status:** Workaround implemented, upstream report pending
**Severity:** High (blocks InfluxDB3 deployment on RHEL-based systems)
