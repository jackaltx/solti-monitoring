# Metrics Collection Strategy

## Current Architecture

**Separation of Concerns:**
- **Alloy + Loki** = Security logs (long-term storage, search, security events)
- **Telegraf + InfluxDB** = Performance metrics (time-series, dashboards, trends)

## Current State (as of 2025-12-31)

### Alloy (Running on fleur)
- **Purpose**: Collect and forward logs to Loki
- **Sources**:
  - Journald (mail, bind9, wireguard, system)
  - Log files (Apache, ISPConfig, Fail2ban, Gitea)
- **Processing**: Classification, parsing, filtering
- **Destination**: Loki on monitor11 (via WireGuard)
- **Metrics Endpoint**: http://127.0.0.1:12345/metrics (Alloy internal metrics only)

### Telegraf (Placeholder)
- **Infrastructure**: Ready but not deployed on fleur
- **Template Available**: `roles/telegraf/templates/inputs/prometheus-alloy.conf.j2`
- **Capability**: Can scrape Alloy's Prometheus endpoint
- **Currently Collecting**: Alloy's built-in operational metrics (component status, pipeline stats)

## Future Possibilities

### Option 1: Native Bind9 Metrics (Recommended)
Use Telegraf's `inputs.bind` plugin to directly query Bind9's statistics channel:

```toml
[[inputs.bind]]
  urls = ["http://localhost:8053/xml/v3"]
  gather_memory_contexts = true
  gather_views = true
```

**Pros:**
- Battle-tested, maintained by Telegraf team
- Direct access to Bind9's full stats (queries, cache, zones, memory)
- No complex log parsing required
- Separate from security log pipeline

**Cons:**
- Requires enabling Bind9 statistics-channels in named.conf
- Another port to manage (though localhost-only)

### Option 2: Alloy Custom Metrics (Attempted)
Parse Bind9 logs in Alloy using `stage.metrics` to generate Prometheus metrics:

**Status**: Attempted but encountered runtime errors
- Config validation passed
- Runtime pipeline creation failed
- Error: "invalid selector syntax for match stage"
- Root cause unclear - might be Jinja2/Alloy interaction

**Pros:**
- Single data source (logs already collected)
- Granular control over what's measured
- No additional Bind9 configuration

**Cons:**
- Complex template management
- Harder to debug
- Mixes security (logs) and performance (metrics) concerns

### Option 3: LogQL Aggregation
Query Loki directly for metrics using LogQL:

```logql
sum(rate({service_type="dns", event_type="query"}[5m])) by (query_type)
```

**Pros:**
- No additional collection infrastructure
- Flexible ad-hoc queries
- Already have the data

**Cons:**
- Query performance on large log volumes
- Not optimized for real-time dashboards
- Loki is for logs, not metrics aggregation

## Recommendation

For Bind9 DNS metrics, use **Option 1: Native Bind9 plugin**

1. Enable Bind9 statistics channel in named.conf
2. Deploy Telegraf role to fleur
3. Configure `inputs.bind` plugin
4. Metrics flow to InfluxDB on monitor11
5. Build Grafana dashboards

Keep Alloy focused on security log collection and processing. This maintains clean separation between logs (security/audit) and metrics (performance/trends).

## Implementation Notes

### Telegraf Scraping Alloy (Available)
The infrastructure exists to scrape Alloy's internal metrics:

```yaml
# In inventory or playbook vars
telegraf_scrape_alloy: true
alloy_server_listen_addr: "127.0.0.1:12345"
```

This gives you Alloy operational metrics like:
- `alloy_build_info` - Version information
- `alloy_component_controller_running_components` - Component health
- `loki_process_dropped_lines_total` - Log processing stats
- `loki_write_sent_entries_total` - Logs forwarded to Loki

Useful for monitoring the monitoring system itself.

## Related Files

- Telegraf scraper template: `roles/telegraf/templates/inputs/prometheus-alloy.conf.j2`
- Telegraf task: `roles/telegraf/tasks/telegrafd-inputs-setup.yml`
- Alloy Bind9 classifier: `roles/alloy/templates/classifiers/bind9-journal-classifier.alloy.j2`
