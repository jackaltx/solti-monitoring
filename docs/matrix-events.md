# Matrix Events - SOLTI Monitoring Collection

## Overview

The `solti-monitoring` collection provides a `matrix_event` module for posting structured JSON events to Matrix rooms. This enables integration with Matrix Synapse for real-time notifications, audit trails, and AI-assisted DevOps workflows.

## Module: `matrix_event`

### Purpose

Post custom events to Matrix rooms using the Client-Server API. Events are sent as structured JSON data with custom event types, enabling:

- Verification result notifications
- Deployment status updates
- Service health alerts
- Audit logging
- Integration with AI tools (future phase)

### Quick Start

```yaml
- name: Post verification failure to Matrix
  jackaltx.solti_matrix_mgr.matrix_event:
    homeserver_url: "https://matrix-web.jackaltx.com"
    access_token: "{{ matrix_bot_token }}"
    room_id: "#solti-verify:jackaltx.com"
    event_type: "com.solti.verify.fail"
    event_content:
      service: "loki"
      error: "Connection timeout"
      timestamp: "{{ ansible_date_time.iso8601 }}"
```

### Parameters

| Parameter | Type | Required | Default | Description |
| --------- | ---- | -------- | ------- | ----------- |
| `homeserver_url` | str | yes | - | Matrix homeserver URL (e.g., `https://matrix-web.jackaltx.com`) |
| `access_token` | str | yes | - | Bot or user access token (marked `no_log`) |
| `room_id` | str | yes | - | Room ID (`!xxx:server.com`) or alias (`#xxx:server.com`) |
| `event_type` | str | yes | - | Custom event type (e.g., `com.solti.verify.fail`) |
| `event_content` | dict | yes | - | Event content as YAML dict (converted to JSON) |
| `state` | str | no | `present` | Whether to post event (`present`) or skip (`absent`) |
| `transaction_id` | str | no | auto-generated | Explicit transaction ID for idempotency |
| `validate_certs` | bool | no | `true` | Whether to validate SSL certificates |

### Return Values

```yaml
event_id: "$abc123:jackaltx.com"
room_id: "!NGwlzxqbkdXnRGKvEF:jackaltx.com"
transaction_id: "ansible-1770752746-82cdffde"
event_type: "com.solti.verify.fail"
```

## Event Schema

### Standard Event Types

#### `com.solti.verify.fail` - Verification Failure

Posted when service verification fails during molecule tests.

**Structure:**

```json
{
  "service": "jackaltx.solti_monitoring.loki",
  "host": "monitor11.a0a0.org",
  "test": "verify_loki_query_endpoint",
  "error": "Connection timeout after 5s",
  "severity": "error",
  "timestamp": "2026-02-10T12:34:56Z",
  "context": {
    "playbook": "mylab/playbooks/svc-monitor11-logs.yml",
    "distribution": "debian12",
    "collection": "solti-monitoring"
  }
}
```

**Fields:**

- `service` (str, required): Fully qualified service name
- `host` (str, optional): Target hostname
- `test` (str, optional): Test name that failed
- `error` (str, required): Error message
- `severity` (str, optional): Error severity (`error`, `warning`, `critical`)
- `timestamp` (str, required): ISO 8601 timestamp
- `context` (dict, optional): Additional context information

#### `com.solti.verify.pass` - Verification Success

Posted when all service verifications pass.

**Structure:**

```json
{
  "status": "PASSED",
  "distribution": "debian_12",
  "hostname": "molecule-instance",
  "timestamp": "2026-02-10T12:34:56Z",
  "summary": {
    "total_services": 5,
    "failed_services": 0,
    "passed_services": 5
  },
  "services": {
    "loki": true,
    "influxdb": true,
    "alloy": true,
    "telegraf": true,
    "grafana": true
  },
  "context": {
    "collection": "solti-monitoring",
    "scenario": "default",
    "platform": "debian12"
  }
}
```

**Fields:**

- `status` (str, required): Overall status (`PASSED` or `FAILED`)
- `distribution` (str, required): OS distribution and version
- `hostname` (str, required): Target hostname
- `timestamp` (str, required): ISO 8601 timestamp
- `summary` (dict, required): Summary statistics
- `services` (dict, required): Per-service verification results
- `context` (dict, optional): Execution context

#### `com.solti.deploy.start` - Deployment Started

Posted when a service deployment begins.

**Structure:**

```json
{
  "service": "alloy",
  "host": "fleur.lavnet.net",
  "playbook": "fleur-alloy.yml",
  "timestamp": "2026-02-10T12:34:56Z",
  "initiator": "ansible"
}
```

#### `com.solti.deploy.complete` - Deployment Completed

Posted when a service deployment finishes.

**Structure:**

```json
{
  "service": "alloy",
  "host": "fleur.lavnet.net",
  "playbook": "fleur-alloy.yml",
  "status": "success",
  "duration_seconds": 45,
  "timestamp": "2026-02-10T12:35:41Z"
}
```

### Custom Event Types

You can define your own event types following the reverse DNS naming convention:

```
com.solti.<category>.<action>
```

Examples:
- `com.solti.backup.start`
- `com.solti.backup.complete`
- `com.solti.alert.critical`
- `com.solti.metric.threshold`

## Integration Patterns

### Molecule Verification

Verification results are automatically posted to Matrix when enabled:

```bash
# Enable Matrix notifications
export MATRIX_NOTIFY_ENABLED=true
export MATRIX_HOMESERVER_URL="https://matrix-web.jackaltx.com"
export MATRIX_ROOM_ID="#solti-verify:jackaltx.com"
export MATRIX_ACCESS_TOKEN="syt_..."

# Run molecule test
cd solti-monitoring
molecule test
```

The `matrix-notify.yml` playbook runs after `report.yml` and posts aggregated results.

### Manual Posting

```yaml
---
- hosts: localhost
  gather_facts: true
  vars:
    matrix_homeserver_url: "https://matrix-web.jackaltx.com"
    matrix_room_id: "#solti-verify:jackaltx.com"
    matrix_access_token: "{{ lookup('file', '~/mylab/data/matrix-logger-token.txt') | trim }}"

  tasks:
    - name: Post custom event
      jackaltx.solti_matrix_mgr.matrix_event:
        homeserver_url: "{{ matrix_homeserver_url }}"
        access_token: "{{ matrix_access_token }}"
        room_id: "{{ matrix_room_id }}"
        event_type: "com.solti.custom.event"
        event_content:
          message: "Custom notification"
          data:
            key1: "value1"
            key2: "value2"
```

### GitHub Actions

```yaml
name: Molecule Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run molecule test with Matrix notifications
        env:
          MATRIX_NOTIFY_ENABLED: "true"
          MATRIX_HOMESERVER_URL: "https://matrix-web.jackaltx.com"
          MATRIX_ROOM_ID: "${{ secrets.MATRIX_VERIFY_ROOM_ID }}"
          MATRIX_ACCESS_TOKEN: "${{ secrets.MATRIX_BOT_TOKEN }}"
        run: |
          cd solti-monitoring
          molecule test
```

## Room Setup

### Creating a Verification Room

```bash
cd mylab
ansible-playbook playbooks/create-matrix-verify-room.yml
```

This creates:
- Room alias: `#solti-verify:jackaltx.com`
- Room name: "SOLTI Verification Results"
- Private, invite-only room
- Bot member: `@solti-logger:jackaltx.com`
- Room ID saved to: `mylab/data/matrix-verify-room.txt`

### Room Configuration

**Recommended settings:**
- **History visibility:** `shared` (members can see history)
- **Guest access:** `forbidden` (no guest users)
- **Encryption:** Disabled (Phase 1) - Enable in Phase 2 for sensitive data
- **Room type:** `private_chat` (invite-only)

## Querying Events

### Via Loki (Matrix Synapse Logs)

Since Matrix Synapse logs are shipped to Loki, you can query for posted events:

```logql
{service_type="matrix_synapse", event_type=~"com\\.solti\\..*"}
```

### Via Matrix Client-Server API

```bash
# Get room history
curl -H "Authorization: Bearer $TOKEN" \
  "https://matrix-web.jackaltx.com/_matrix/client/v3/rooms/!NGwlzxqbkdXnRGKvEF:jackaltx.com/messages?limit=100"

# Filter by event type (client-side)
curl -H "Authorization: Bearer $TOKEN" \
  "https://matrix-web.jackaltx.com/_matrix/client/v3/rooms/!NGwlzxqbkdXnRGKvEF:jackaltx.com/messages?limit=100" \
  | jq '.chunk[] | select(.type | startswith("com.solti"))'
```

### Via Element Client

1. Open https://matrix.jackaltx.com
2. Navigate to `#solti-verify:jackaltx.com`
3. View events in timeline (custom events display as JSON)
4. Use developer tools (Settings → Labs → Show hidden events) to see full event structure

## Security Considerations

### Phase 1 (Current)

- **Transport:** HTTPS (TLS) to homeserver
- **Authentication:** Bot token (stored in `mylab/data/matrix-logger-token.txt`, mode 0600)
- **Room access:** Private, invite-only
- **Encryption:** None (events stored in plaintext in Synapse database)

**Acceptable for:**
- Internal infrastructure monitoring
- Non-sensitive verification results
- Development and testing

### Phase 2 (Future)

- **Encryption:** Enable E2EE for room
- **Token storage:** Vault-encrypt bot token
- **External access:** Caddy reverse proxy with OIDC for GitHub Actions
- **Secret filtering:** Scrub sensitive data from event content before posting

## Troubleshooting

### Module import errors

**Error:** `Could not find imported module support code for ansible_collections.jackaltx.solti_monitoring...`

**Solution:** The module uses collection-namespaced imports. Ensure you're running from within the collection context or using `ansible-playbook` with the collection installed.

### Room alias not resolving

**Error:** `Failed to resolve room identifier: #solti-verify:jackaltx.com`

**Solution:**
1. Verify room exists: Check Element client
2. Verify homeserver URL: Should match room's homeserver (e.g., `jackaltx.com`)
3. Use room ID directly: `!NGwlzxqbkdXnRGKvEF:jackaltx.com`

### Access denied

**Error:** `HTTP 403 Forbidden`

**Solution:**
1. Verify bot token is valid: `./bin/get-matrix-token.sh`
2. Verify bot is member of room: Check Element client
3. Verify room allows posting: Check room power levels

### SSL certificate errors

**Error:** `SSL: CERTIFICATE_VERIFY_FAILED`

**Solution:** Set `validate_certs: false` (only for testing/development)

## Future Enhancements

### Phase 2: AI Integration

- **refs.tools integration:** Query Digital Garden for suggested fixes
- **Event enrichment:** Attach logs, metrics, configuration diffs
- **Interactive bot:** Respond to commands (`!retry loki`, `!logs influxdb`)

### Phase 3: Advanced Features

- **Event correlation:** Link related events (deploy → verify → alert)
- **Metric snapshots:** Embed metric graphs in events
- **Dashboard integration:** Query Matrix room history from Grafana
- **Workflow automation:** Trigger remediation based on event patterns

## References

- **Matrix Specification:** https://spec.matrix.org/v1.10/client-server-api/
- **Module Source:** [solti-matrix-mgr/plugins/modules/matrix_event.py](../../solti-matrix-mgr/plugins/modules/matrix_event.py)
- **API Wrapper:** [solti-matrix-mgr/plugins/module_utils/matrix_client.py](../../solti-matrix-mgr/plugins/module_utils/matrix_client.py)
- **Test Playbook:** [mylab/playbooks/test-matrix-event.yml](../../mylab/playbooks/test-matrix-event.yml)
- **Matrix Synapse Deployment:** [solti-ensemble/roles/matrix_synapse/](../../solti-ensemble/roles/matrix_synapse/) (deprecated - manually deployed)
