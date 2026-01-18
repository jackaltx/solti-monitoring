# Telegraf Role Testing Guide

## Quick Test Commands

### 1. Deploy Service

```bash
cd mylab
./manage-svc.sh telegraf deploy
```

**Expected Results:**

- Telegraf package installed from InfluxData repository
- `/etc/telegraf/telegraf.conf` created (base config)
- `/etc/telegraf/telegraf.d/` directory populated with input configs
- `/etc/default/telegraf` created with environment variables
- Systemd service `telegraf.service` enabled and started
- Metrics flowing to configured InfluxDB endpoint(s)

### 2. Verify Deployment

```bash
# Automated verification
cd mylab
./svc-exec.sh telegraf verify

# Manual checks
systemctl status telegraf
telegraf --version
telegraf --config /etc/telegraf/telegraf.conf --test
```

**Expected Results:**

- Service status: `active (running)`
- Service enabled: `enabled`
- Test mode shows metrics being collected
- No configuration errors

### 3. Check Metrics Collection

```bash
# Test configuration and see sample output
telegraf --config /etc/telegraf/telegraf.conf --test --input-filter cpu:mem:disk

# Check what's being sent to InfluxDB
journalctl -u telegraf -n 100 | grep -i error
```

**Expected Results:**

- Sample metrics printed to stdout
- No errors in journal logs
- InfluxDB receives data (check in Grafana/InfluxDB UI)

## Configuration Architecture

### The telegraf.d Discovery Pattern

**Core Concept**: Telegraf automatically loads **all** `.conf` files from `/etc/telegraf/telegraf.d/`

```
/etc/telegraf/
├── telegraf.conf              # Base config (agent settings, no inputs/outputs)
├── telegraf.d/                # AUTO-LOADED directory
│   ├── inputs.conf            # Core system metrics (always deployed)
│   ├── output-localhost.conf  # InfluxDB output (if 'localhost' in telegraf_outputs)
│   ├── output-monitor2.conf   # Additional output (if 'monitor2' in telegraf_outputs)
│   ├── apache.conf            # Optional: Apache metrics (if influxdb_apache=true)
│   ├── mariadb.conf           # Optional: MariaDB metrics (if influxdb_mariadb=true)
│   ├── redis.conf             # Optional: Redis metrics (if influxdb_redis=true)
│   ├── memcache.conf          # Optional: Memcached metrics (if influxdb_memcache=true)
│   └── prometheus-alloy.conf  # Optional: Alloy scraper (if telegraf_scrape_alloy=true)
└── /etc/default/telegraf      # Environment variables (InfluxDB tokens)
```

### How Role Variables Map to Configuration

```yaml
# In inventory or playbook vars:
telegraf_outputs: ['localhost', 'monitor2']
  ↓
# Generates two output files:
  - /etc/telegraf/telegraf.d/output-localhost.conf
  - /etc/telegraf/telegraf.d/output-monitor2.conf

influxdb_apache: true
  ↓
# Copies input plugin:
  - /etc/telegraf/telegraf.d/apache.conf

telegraf_scrape_alloy: true
  ↓
# Templates scraper config:
  - /etc/telegraf/telegraf.d/prometheus-alloy.conf
```

### Output Configuration Details

**Key Variable**: `telgraf2influxdb_configs` (defined in `group_vars/all/`)

```yaml
# In group_vars/all/telegraf2influx-configs.yml
telgraf2influxdb_configs:
  localhost:                          # Label used in telegraf_outputs
    url: "http://127.0.0.1:8086"      # InfluxDB endpoint
    token: ""                         # Auto-discovered if telegraf_testing=true
    bucket: "telegraf"                # Destination bucket
    org: "myorg"                      # Organization
    namedrop: '["influxdb_oss"]'      # Metrics to exclude
    insecure_skip_verify: false       # TLS verification

  monitor2:
    url: "http://monitor11.example.com:8086"
    token: !vault |                   # Encrypted with ansible-vault
      $ANSIBLE_VAULT;1.1;AES256
      ...
    bucket: "telegraf"
    org: "myorg"
    namedrop: '["influxdb_oss"]'
    insecure_skip_verify: false
```

**Per-host output selection**:

```yaml
# In host_vars/webserver.yml
telegraf_outputs: ['localhost', 'monitor2']  # Send to both

# In host_vars/fleur.yml
telegraf_outputs: ['monitor2']              # Send only to monitor2
```

## Molecule Testing Scenarios

### Proxmox Scenario

```bash
cd solti-monitoring/roles/telegraf
molecule test -s proxmox
```

**Test Sequence:**

1. `destroy` - Remove any existing test VM
2. `create` - Clone Proxmox template, assign IP
3. `prepare` - Install dependencies, configure SSH
4. `converge` - Run telegraf role
5. `verify` - Check service status, config files, permissions
6. `destroy` - Cleanup test VM

**Environment Variables Required:**

```bash
export PROXMOX_VMID=9000          # Unique VM ID
export PROXMOX_TEMPLATE=rocky9    # rocky9, debian12, ubuntu24
export MOLECULE_IP=10.0.50.100    # Static IP for test VM
```

**What Gets Verified** ([molecule/proxmox/verify.yml](molecule/proxmox/verify.yml)):

- [ ] Telegraf service running and enabled
- [ ] `/etc/telegraf/telegraf.conf` exists, mode `0644`
- [ ] `/etc/default/telegraf` exists, mode `0640` (contains tokens)
- [ ] No errors in `telegraf --test` output
- [ ] Service starts without errors
- [ ] Git commit information captured
- [ ] Test report generated in `verify_output/<distro>/`

### Testing Multiple Outputs

```yaml
# In molecule/proxmox/molecule.yml
provisioner:
  inventory:
    host_vars:
      uut-vm:
        telegraf_outputs: ['localhost', 'remote']
        telgraf2influxdb_configs:
          localhost:
            url: "http://127.0.0.1:8086"
            token: ""
            bucket: "telegraf"
            org: "myorg"
          remote:
            url: "http://monitor11.example.com:8086"
            token: "test-token-abc123"
            bucket: "telegraf"
            org: "myorg"
```

**Verify**:

```bash
# After converge:
molecule login -s proxmox
ls /etc/telegraf/telegraf.d/output-*.conf
# Should show: output-localhost.conf, output-remote.conf

cat /etc/default/telegraf
# Should contain both endpoint configs
```

## Input Plugin Testing

### Default System Metrics

**Always enabled** via `inputs.conf`:

- CPU (per-core and total)
- Memory (RAM, swap)
- Disk (usage, IO)
- Network (interfaces, traffic, errors)
- System (load, uptime, processes)
- Kernel (interrupts, sysctl_fs)

**Verification**:

```bash
# Run test mode, filter to specific inputs
telegraf --config /etc/telegraf/telegraf.conf --test --input-filter cpu:mem:disk --test-wait 5

# Expected output sample:
# cpu,cpu=cpu0,host=server01 usage_idle=95.5,usage_system=2.3,usage_user=2.2
# mem,host=server01 available=8589934592,used=3221225472,used_percent=27.3
# disk,device=sda1,host=server01 used_percent=45.2
```

### Optional Application Metrics

#### Apache Metrics

```yaml
# Enable in inventory
influxdb_apache: true
```

**Creates**: `/etc/telegraf/telegraf.d/apache.conf`

**Requirements**:

- Apache `mod_status` enabled
- Status endpoint accessible: `http://localhost/server-status?auto`

**Verification**:

```bash
# Check Apache status endpoint
curl http://localhost/server-status?auto

# Expected output:
# Total Accesses: 12345
# Total kBytes: 56789
# BusyWorkers: 2
# IdleWorkers: 8

# Test telegraf input
telegraf --config /etc/telegraf/telegraf.conf --test --input-filter apache
```

#### MariaDB/MySQL Metrics

```yaml
influxdb_mariadb: true
```

**Creates**: `/etc/telegraf/telegraf.d/mariadb.conf`

**Requirements**:

- MariaDB/MySQL running on localhost:3306
- Credentials configured in config file
- User with PROCESS, REPLICATION CLIENT privileges

**Verification**:

```bash
# Test database connection
mysql -u telegraf -p -e "SHOW GLOBAL STATUS;"

# Test telegraf input
telegraf --config /etc/telegraf/telegraf.conf --test --input-filter mysql
```

#### Redis Metrics

```yaml
influxdb_redis: true
```

**Creates**: `/etc/telegraf/telegraf.d/redis.conf`

**Requirements**:

- Redis running on localhost:6379

**Verification**:

```bash
# Test Redis connection
redis-cli INFO

# Test telegraf input
telegraf --config /etc/telegraf/telegraf.conf --test --input-filter redis
```

#### Memcached Metrics

```yaml
influxdb_memcache: true
```

**Creates**: `/etc/telegraf/telegraf.d/memcache.conf`

**Requirements**:

- Memcached running on localhost:11211

**Verification**:

```bash
# Test memcached connection
echo "stats" | nc localhost 11211

# Test telegraf input
telegraf --config /etc/telegraf/telegraf.conf --test --input-filter memcached
```

### Grafana Alloy Prometheus Scraper

```yaml
telegraf_scrape_alloy: true
```

**Creates**: `/etc/telegraf/telegraf.d/prometheus-alloy.conf`

**Requirements**:

- Alloy running with metrics endpoint: `http://127.0.0.1:12345/metrics`
- Alloy started with: `--server.http.listen-addr=127.0.0.1:12345`

**Verification**:

```bash
# Test Alloy metrics endpoint
curl http://127.0.0.1:12345/metrics | head -20

# Expected output (Prometheus format):
# alloy_component_controller_running_components 5
# alloy_component_controller_evaluating{component_id="loki.source.journal.read"} 1
# loki_write_sent_entries_total{endpoint="http://monitor11:3100/loki/api/v1/push"} 12345

# Test telegraf scraper
telegraf --config /etc/telegraf/telegraf.conf --test --input-filter prometheus
```

**Important Notes**:

- Alloy metrics are **counters** (always increasing)
- Use InfluxDB `derivative()` function to calculate rates:

  ```flux
  from(bucket: "telegraf")
    |> range(start: -1h)
    |> filter(fn: (r) => r["service"] == "alloy")
    |> derivative(unit: 1s, nonNegative: true)
  ```

## Output Verification

### InfluxDB Connection Testing

```bash
# Check if metrics are reaching InfluxDB
# (requires influx CLI installed)

influx query '
  from(bucket: "telegraf")
    |> range(start: -5m)
    |> filter(fn: (r) => r["host"] == "your-hostname")
    |> filter(fn: (r) => r["_measurement"] == "cpu")
    |> limit(n: 5)
' --org myorg
```

**Expected**: Recent CPU metrics from your host

### Automatic Token Discovery (Testing Mode)

When deploying on same host as InfluxDB:

```yaml
telegraf_testing: true
```

**Behavior**:

1. Role detects InfluxDB running locally
2. Queries InfluxDB API for system operator token
3. Uses token in `/etc/default/telegraf`
4. Skips manual token configuration

**Verification**:

```bash
# Check token was discovered
sudo cat /etc/default/telegraf | grep INFLUX_TOKEN

# Should show: INFLUX_TOKEN=<auto-discovered-token>
```

## Troubleshooting Tests

### Test 1: Configuration Validation

```bash
# Validate configuration syntax
telegraf --config /etc/telegraf/telegraf.conf --test --quiet

# Expected: No output = valid config
# Error example: "Error: unknown field 'invalid_option'"
```

### Test 2: Service Startup

```bash
# Check service status
systemctl status telegraf

# If failed, check logs
journalctl -u telegraf -n 50 --no-pager

# Common errors:
# - "permission denied": Check file permissions, SELinux
# - "connection refused": InfluxDB endpoint not accessible
# - "invalid token": Token expired or incorrect
```

### Test 3: Metric Flow

```bash
# Run in foreground with debug logging
sudo -u telegraf telegraf --config /etc/telegraf/telegraf.conf --debug

# Watch for:
# - "Error in plugin" = input plugin failing
# - "Failed to write" = output (InfluxDB) failing
# - Regular metric collection messages = working
```

### Test 4: Input Plugin Errors

```bash
# Test specific input plugin in isolation
telegraf --config /etc/telegraf/telegraf.conf \
  --input-filter apache \
  --test

# If errors, check:
# - Application (Apache) is running
# - Endpoint is accessible (mod_status enabled)
# - Credentials are correct (for DB plugins)
```

### Test 5: Output Plugin Errors

```bash
# Test InfluxDB connectivity
curl -I http://monitor11.example.com:8086/health

# Expected: HTTP 200 OK

# Test write with token
curl -XPOST "http://monitor11.example.com:8086/api/v2/write?org=myorg&bucket=telegraf" \
  -H "Authorization: Token YOUR_TOKEN" \
  --data-raw "test,host=testhost value=1.0"

# Expected: No output = success
# Error: 401 = invalid token
# Error: 404 = bucket doesn't exist
```

### Test 6: Configuration Cleanup

Test the `telegraf_clean_inputs` option:

```bash
# Create test config
sudo touch /etc/telegraf/telegraf.d/test-old-config.conf

# Deploy with cleanup
cd mylab
# Edit playbook or use extra vars:
ansible-playbook -i inventory.yml -l target_host \
  -e telegraf_clean_inputs=true \
  playbooks/svc-telegraf-deploy.yml

# Verify cleanup
ls /etc/telegraf/telegraf.d/
# Should NOT include test-old-config.conf
```

## Common Test Scenarios

### Scenario 1: Single-Host Deployment (localhost only)

```yaml
# In inventory
telegraf_outputs: ['localhost']
telegraf_testing: true  # Auto-discover InfluxDB token

telgraf2influxdb_configs:
  localhost:
    url: "http://127.0.0.1:8086"
    token: ""
    bucket: "telegraf"
    org: "myorg"
```

**Deploy**:

```bash
cd mylab
./manage-svc.sh telegraf deploy
```

**Verify**:

```bash
# Service running
systemctl is-active telegraf

# Config generated
ls /etc/telegraf/telegraf.d/output-localhost.conf

# Metrics flowing
journalctl -u telegraf -f
# Watch for successful writes to InfluxDB
```

### Scenario 2: Remote Monitoring (send to central collector)

```yaml
# In inventory
telegraf_outputs: ['monitor2']

telgraf2influxdb_configs:
  monitor2:
    url: "http://monitor11.example.com:8086"
    token: !vault |
      $ANSIBLE_VAULT;1.1;AES256
      <encrypted-token>
    bucket: "telegraf"
    org: "myorg"
```

**Deploy**:

```bash
cd mylab
./manage-svc.sh -h fleur telegraf deploy
```

**Verify**:

```bash
# On fleur: Check output config
ssh fleur cat /etc/telegraf/telegraf.d/output-monitor2.conf

# On monitor11: Check metrics arriving
influx query 'from(bucket: "telegraf")
  |> range(start: -5m)
  |> filter(fn: (r) => r["host"] == "fleur")
  |> limit(n: 10)' --org myorg
```

### Scenario 3: Web Server with Apache Monitoring

```yaml
# In inventory
influxdb_apache: true
telegraf_outputs: ['monitor2']
```

**Deploy**:

```bash
cd mylab
./manage-svc.sh -h webserver telegraf deploy
```

**Verify**:

```bash
# Apache plugin deployed
ssh webserver ls /etc/telegraf/telegraf.d/apache.conf

# Apache metrics collected
ssh webserver sudo telegraf --config /etc/telegraf/telegraf.conf \
  --test --input-filter apache
```

### Scenario 4: Log Collector with Alloy Monitoring

```yaml
# In inventory
telegraf_scrape_alloy: true
telegraf_outputs: ['monitor2']

# Alloy must be configured with metrics endpoint
alloy_custom_args: "--server.http.listen-addr=127.0.0.1:12345"
```

**Deploy**:

```bash
# Deploy both roles
cd mylab
./manage-svc.sh -h fleur alloy deploy
./manage-svc.sh -h fleur telegraf deploy
```

**Verify**:

```bash
# Alloy metrics endpoint accessible
curl http://127.0.0.1:12345/metrics | head

# Telegraf scraping Alloy
sudo telegraf --config /etc/telegraf/telegraf.conf \
  --test --input-filter prometheus | grep alloy

# Metrics in InfluxDB
influx query 'from(bucket: "telegraf")
  |> range(start: -5m)
  |> filter(fn: (r) => r["service"] == "alloy")
  |> limit(n: 10)' --org myorg
```

### Scenario 5: Multi-Output (localhost + remote)

```yaml
# In inventory
telegraf_outputs: ['localhost', 'monitor2']
```

**Behavior**: Metrics sent to **both** InfluxDB instances

**Verify**:

```bash
# Two output files generated
ls /etc/telegraf/telegraf.d/output-*.conf
# Should show: output-localhost.conf, output-monitor2.conf

# Metrics in both locations
# Check localhost:
influx query 'from(bucket: "telegraf") |> range(start: -5m)' --org myorg

# Check remote:
influx query 'from(bucket: "telegraf") |> range(start: -5m)' \
  --host http://monitor11.example.com:8086 --org myorg
```

## Verification Checklist

After deployment, verify:

- [ ] Service running: `systemctl is-active telegraf`
- [ ] Service enabled: `systemctl is-enabled telegraf`
- [ ] Config valid: `telegraf --test --quiet` (no output)
- [ ] Base config exists: `/etc/telegraf/telegraf.conf`
- [ ] Inputs configured: `/etc/telegraf/telegraf.d/inputs.conf`
- [ ] Outputs configured: `/etc/telegraf/telegraf.d/output-*.conf`
- [ ] Environment file exists: `/etc/default/telegraf`
- [ ] No errors in logs: `journalctl -u telegraf -n 50`
- [ ] Metrics reaching InfluxDB (check Grafana/InfluxDB UI)
- [ ] Optional plugins deployed (apache, mariadb, redis, etc.)
- [ ] Alloy scraper working (if enabled)

## Performance Testing

### Metric Collection Rate

```bash
# Count metrics collected over 10 seconds
telegraf --config /etc/telegraf/telegraf.conf --test --test-wait 10 | wc -l

# Expected: 100-500 lines (depends on enabled inputs)
```

### Memory Usage

```bash
# Check telegraf process memory
ps aux | grep telegraf

# Expected: < 50MB for default config
# Higher with many input plugins enabled
```

### InfluxDB Write Performance

```bash
# Monitor write latency in logs
journalctl -u telegraf -f | grep -i "write\|error"

# Expected: No "write failed" or timeout errors
# Occasional reconnect messages are normal
```

## Debugging Tips

### Enable Debug Logging

```bash
# Add to /etc/default/telegraf
sudo tee -a /etc/default/telegraf <<EOF
TELEGRAF_OPTS="--debug"
EOF

# Restart service
sudo systemctl restart telegraf

# Watch debug logs
journalctl -u telegraf -f
```

### Test Individual Input Plugins

```bash
# Test only CPU metrics
telegraf --config /etc/telegraf/telegraf.conf \
  --input-filter cpu \
  --test

# Test only custom inputs
telegraf --config /etc/telegraf/telegraf.d/apache.conf --test
```

### Check Plugin Documentation

```bash
# List all available input plugins
telegraf --input-list

# List all available output plugins
telegraf --output-list

# Get plugin usage
telegraf --usage <plugin-name>
```

### Validate InfluxDB Token

```bash
# Test token manually
curl -XPOST "http://monitor11.example.com:8086/api/v2/write?org=myorg&bucket=telegraf" \
  -H "Authorization: Token <your-token>" \
  --data-raw "test,host=manual value=1.0"

# Expected: No output = success
```

## Common Errors

### "permission denied" on /etc/telegraf

```bash
# Fix permissions
sudo chown -R telegraf:telegraf /etc/telegraf
sudo chmod 755 /etc/telegraf
sudo chmod 644 /etc/telegraf/telegraf.conf
sudo chmod 755 /etc/telegraf/telegraf.d
sudo chmod 644 /etc/telegraf/telegraf.d/*.conf
sudo chmod 640 /etc/default/telegraf

# Restart
sudo systemctl restart telegraf
```

### "connection refused" to InfluxDB

```bash
# Check InfluxDB is running
curl -I http://monitor11.example.com:8086/health

# Check firewall
sudo firewall-cmd --list-all

# Check network connectivity
ping monitor11.example.com
telnet monitor11.example.com 8086
```

### "unauthorized" or "401" from InfluxDB

```bash
# Token is invalid, expired, or wrong permissions
# Regenerate token in InfluxDB UI:
# Data > API Tokens > Generate API Token > All Access

# Update token in inventory (use ansible-vault for encryption)
ansible-vault edit group_vars/all/telegraf2influx-configs.yml

# Redeploy
cd mylab
./manage-svc.sh telegraf deploy
```

### "no such host" or DNS errors

```bash
# Check DNS resolution
nslookup monitor11.example.com

# Use IP address instead in config:
telgraf2influxdb_configs:
  monitor2:
    url: "http://10.0.0.11:8086"  # Use IP instead of hostname
```

### Apache/MySQL/Redis input not working

```bash
# Check application is running
systemctl status apache2  # or httpd, mariadb, redis

# Check endpoint accessible
curl http://localhost/server-status?auto  # Apache
mysql -u telegraf -p -e "SHOW GLOBAL STATUS;"  # MySQL
redis-cli INFO  # Redis

# Test plugin in isolation
sudo telegraf --config /etc/telegraf/telegraf.d/apache.conf --test
```

## References

- [Telegraf Documentation](https://docs.influxdata.com/telegraf/)
- [Input Plugins Reference](https://docs.influxdata.com/telegraf/latest/plugins/#input-plugins)
- [Output Plugins Reference](https://docs.influxdata.com/telegraf/latest/plugins/#output-plugins)
- [Configuration File Format](https://docs.influxdata.com/telegraf/latest/administration/configuration/)
- [Role README](README.md)
