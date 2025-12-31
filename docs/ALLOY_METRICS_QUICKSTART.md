# Alloy Metrics Quick Start Checklist

**Before starting**: Read [ALLOY_METRICS_IMPLEMENTATION_PLAN.md](ALLOY_METRICS_IMPLEMENTATION_PLAN.md) for full details

## Prerequisites

- [ ] Alloy deployed on fleur
- [ ] Telegraf deployed on fleur
- [ ] InfluxDB running on monitor11
- [ ] SSH access to both hosts

## Implementation Steps

### 1. Add Variable to Alloy Defaults (1 min)

```bash
cd solti-monitoring
vim roles/alloy/defaults/main.yml
```

Add after line 30 (after `alloy_filter_cron_noise`):
```yaml
# Metrics and advanced filtering
alloy_bind9_metrics_enabled: false  # Opt-in for safety
```

### 2. Update Bind9 Classifier (5 min)

```bash
cd solti-monitoring
vim roles/alloy/templates/classifiers/bind9-journal-classifier.alloy.j2
```

Add after existing query classification (around line 60):
```alloy
{% if alloy_bind9_metrics_enabled | default(false) %}
// Metrics tracking stages - see ALLOY_METRICS_IMPLEMENTATION_PLAN.md
// Copy from plan document, section 1
{% endif %}
```

### 2. Create Telegraf Input (2 min)

```bash
mkdir -p roles/telegraf/templates/inputs
vim roles/telegraf/templates/inputs/prometheus-alloy.conf.j2
```

Paste content from plan document, section 2.

### 3. Update Telegraf Tasks (2 min)

```bash
vim roles/telegraf/tasks/main.yml
```

Add task from plan document, section 3 (after line ~50).

### 4. Update Inventory (1 min)

```bash
vim inventory.yml
```

Add to fleur host:
```yaml
# SECURITY: Bind Alloy to localhost only
alloy_custom_args: "--disable-reporting --server.http.listen-addr=127.0.0.1:12345"

# Enable metrics and Telegraf scraping
alloy_bind9_metrics_enabled: true
alloy_server_listen_addr: "127.0.0.1:12345"
telegraf_scrape_alloy: true
```

### 5. Deploy Alloy (3 min)

```bash
# Check mode first
ansible-playbook playbooks/deploy-alloy.yml --limit fleur --check

# If OK, deploy
ansible-playbook playbooks/deploy-alloy.yml --limit fleur
```

### 6. Verify Metrics Endpoint (1 min)

```bash
ssh root@fleur.lavnet.net "curl -s http://127.0.0.1:12345/metrics | grep alloy_bind9"
```

Should see output like:
```
alloy_bind9_queries_by_type_total{query_type="A"} 42
alloy_bind9_spam_queries_dropped_total{spam_service="rspamd"} 15
```

### 7. Deploy Telegraf (2 min)

```bash
ansible-playbook playbooks/deploy-telegraf.yml --limit fleur
```

### 8. Verify Telegraf Scraping (2 min)

```bash
ssh root@fleur.lavnet.net "journalctl -u telegraf -n 20 | grep prometheus"
```

Should see successful scrapes.

### 9. Check InfluxDB (3 min)

```bash
ssh root@monitor11.a0a0.org
influx -database telegraf -execute "SHOW MEASUREMENTS" | grep alloy_bind9
```

Should see 4 measurements.

### 10. Query Sample Data (2 min)

```bash
influx -database telegraf -execute "
SELECT * FROM alloy_bind9_spam_queries_dropped_total
WHERE time > now() - 5m
LIMIT 10
"
```

## Success Criteria

- [x] Alloy config validates and deploys
- [x] Metrics endpoint returns data
- [x] Telegraf successfully scrapes
- [x] InfluxDB contains 4 new measurements
- [x] Counters are increasing over time

## Rollback (if needed)

```bash
# Disable in inventory.yml
telegraf_scrape_alloy: false
alloy_bind9_metrics_enabled: false

# Redeploy
ansible-playbook playbooks/deploy-telegraf.yml --limit fleur
ansible-playbook playbooks/deploy-alloy.yml --limit fleur
```

## Total Time

**~25 minutes** (excluding 5-10 min monitoring wait)

## Next Steps

After successful deployment:
1. Monitor for 24 hours to verify data collection
2. Create Grafana dashboards (see plan for queries)
3. Set up alerts for anomalies
4. Consider expanding to other classifiers

## Troubleshooting

**Metrics endpoint not responding**:
```bash
# Check Alloy service
ssh root@fleur.lavnet.net "systemctl status alloy"

# Check Alloy logs
ssh root@fleur.lavnet.net "journalctl -u alloy -n 50"

# Verify listen address
ssh root@fleur.lavnet.net "netstat -tlnp | grep 12345"
```

**Telegraf not scraping**:
```bash
# Check config syntax
ssh root@fleur.lavnet.net "telegraf --test --config /etc/telegraf/telegraf.d/prometheus-alloy.conf"

# Check Telegraf logs
ssh root@fleur.lavnet.net "journalctl -u telegraf -f"
```

**No data in InfluxDB**:
```bash
# Verify Telegraf output
ssh root@fleur.lavnet.net "telegraf --test --config /etc/telegraf/telegraf.conf --config-directory /etc/telegraf/telegraf.d"

# Check InfluxDB logs on monitor11
ssh root@monitor11.a0a0.org "journalctl -u influxdb -n 50"
```
