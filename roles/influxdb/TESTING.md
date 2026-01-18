# InfluxDB Role Testing Guide

## Quick Test Commands

### 1. Deploy Service

```bash
cd mylab
./manage-svc.sh influxdb deploy
```

**Expected Results:**
- InfluxDB 2.x package installed from InfluxData repository
- Service `influxdb.service` enabled and started
- Database initialized with org, user, and buckets
- Admin token generated and stored
- System operator token created
- HTTP API accessible on port 8086

### 2. Verify Deployment

```bash
# Automated verification
cd mylab
./svc-exec.sh influxdb verify

# Manual checks
systemctl status influxdb
influx version
influx ping
```

**Expected Results:**
- Service status: `active (running)`
- Service enabled: `enabled`
- HTTP API responding to ping
- No errors in logs

### 3. Check Database Health

```bash
# Check health endpoint
curl -I http://localhost:8086/health

# List organizations
influx org list

# List buckets
influx bucket list

# Check system metrics
influx query 'from(bucket: "_monitoring") |> range(start: -1h) |> limit(n: 5)'
```

**Expected Results:**
- HTTP 200 OK on health endpoint
- Organization exists
- Configured buckets created
- System metrics being collected

## Configuration Architecture

### Configuration Files

```
/etc/influxdb/
├── influxd.conf                    # Service configuration (minimal)
└── /var/lib/influxdb/
    ├── influxd.bolt                # Metadata database (BoltDB)
    ├── engine/                     # Time series data (TSM files)
    └── /var/lib/influxdb/.influxdbv2/
        └── configs                 # influx CLI configuration
```

### InfluxDB v2.x Architecture

**Key Concepts:**
- **Organization**: Top-level tenant (like `myorg`)
- **Buckets**: Data storage locations with retention policies (like `telegraf`)
- **Tokens**: Authentication credentials for API access
- **Users**: Human accounts for UI/CLI access

### How Role Variables Map to Configuration

```yaml
# In inventory:
influxdb_org: "myorg"
influxdb_bucket: "telegraf"
influxdb_username: "admin"
influxdb_password: "generated"
  ↓
# Creates during influx setup:
  - Organization: "myorg"
  - Primary bucket: "telegraf"
  - Admin user: "admin" (with random password if "generated")
  - Admin token: (stored in /root/.influxdbv2/credentials)
  - System operator token: (stored in /root/.influxdbv2/credentials)

influxdb_buckets: ['telegraf', 'metrics', 'logs']
  ↓
# Creates buckets:
  influx bucket create -n telegraf -o myorg
  influx bucket create -n metrics -o myorg
  influx bucket create -n logs -o myorg

influxdb_s3: true
influxdb_s3_bucket: "influx-data"
  ↓
# Sets environment variables in systemd:
  INFLUXD_STORAGE_S3_BUCKET=influx-data
  AWS_ACCESS_KEY_ID=...
  AWS_SECRET_ACCESS_KEY=...
```

### Key Configuration Variables

**Core Variables:**
```yaml
influxdb_state: present              # Install/remove control
influxdb_org: "myorg"                # Organization name
influxdb_bucket: "telegraf"          # Primary bucket name
influxdb_username: "admin"           # Admin username
influxdb_password: "generated"       # Auto-generate secure password
influxdb_data_path: /var/lib/influxdb  # Data storage location
```

**Bucket Management:**
```yaml
influxdb_buckets: ['telegraf', 'metrics']  # List of buckets to create
```

**S3 Storage (Optional):**
```yaml
influxdb_s3: false                   # Enable S3 backend
influxdb_s3_access_key: ""           # S3 access key
influxdb_s3_secret_key: ""           # S3 secret key
influxdb_s3_bucket: ""               # S3 bucket name
```

**Advanced:**
```yaml
influxdb_force_reload: false         # Force package reinstall
influxdb_force_configure: false      # Force reconfiguration
influxdb_level: info                 # Logging level (debug|info|warn|error)
```

## Molecule Testing Scenarios

### Proxmox Scenario

```bash
cd solti-monitoring/roles/influxdb
molecule test -s proxmox
```

**Test Sequence:**
1. `destroy` - Remove any existing test VM
2. `create` - Clone Proxmox template, assign IP
3. `prepare` - Install dependencies, configure SSH
4. `converge` - Run influxdb role
5. `verify` - Check service status, database initialized, buckets created
6. `destroy` - Cleanup test VM

**Environment Variables Required:**
```bash
export PROXMOX_VMID=9000          # Unique VM ID
export PROXMOX_TEMPLATE=rocky9    # rocky9, debian12, ubuntu24
export MOLECULE_IP=10.0.50.100    # Static IP for test VM
```

**What Gets Verified** ([molecule/proxmox/verify.yml](molecule/proxmox/verify.yml)):
- [ ] InfluxDB service running and enabled
- [ ] HTTP API accessible on port 8086
- [ ] Organization created
- [ ] Buckets created
- [ ] Admin user exists
- [ ] Tokens generated and stored
- [ ] No errors in service logs
- [ ] Test report generated in `verify_output/<distro>/`

## Initial Setup Process

### First-Time Initialization

When deployed, the role performs `influx setup`:

```bash
# Equivalent to:
influx setup \
  --username admin \
  --password <generated> \
  --org myorg \
  --bucket telegraf \
  --retention 0 \
  --force
```

**Creates:**
- Organization (`myorg`)
- Admin user (`admin`)
- Primary bucket (`telegraf`)
- Admin token (full access)
- Initial configs in `/root/.influxdbv2/credentials`

**Tokens Generated:**
1. **Admin Token**: Full access to all resources
2. **System Operator Token**: Read access to system buckets

### Subsequent Runs

The role is **idempotent** - safe to run multiple times:

```bash
# Check if already configured
influx config list

# If configured, skip setup
# If not configured or influxdb_force_configure=true, run setup
```

## Bucket Management

### Default Buckets

**Automatically created:**
- `_monitoring`: System metrics (retention: 168h / 7 days)
- `_tasks`: Task logs (retention: 72h / 3 days)
- Primary bucket from `influxdb_bucket` variable

### Creating Additional Buckets

```yaml
# In inventory
influxdb_buckets:
  - telegraf      # Metrics from Telegraf
  - metrics       # Application metrics
  - logs          # Log-derived metrics
```

**Verification:**
```bash
# List all buckets
influx bucket list -o myorg

# Expected output:
# ID                  Name         Retention  Shard group duration  ...
# abc123...           telegraf     infinite   168h0m0s
# def456...           metrics      infinite   168h0m0s
# ghi789...           logs         infinite   168h0m0s
```

### Bucket Retention Policies

```bash
# Create bucket with 30-day retention
influx bucket create \
  -n shortterm \
  -o myorg \
  --retention 720h  # 30 days

# Update retention
influx bucket update \
  -n telegraf \
  -o myorg \
  --retention 8760h  # 1 year
```

## Token Management

### Retrieving Tokens

```bash
# Admin token (stored during setup)
sudo cat /root/.influxdbv2/credentials | grep 'admin.*Token'

# System operator token
sudo cat /root/.influxdbv2/credentials | grep 'system.*operator.*Token'

# List all tokens via CLI
influx auth list -o myorg
```

### Creating Custom Tokens

```bash
# Read/Write token for specific bucket
influx auth create \
  -o myorg \
  --read-bucket telegraf \
  --write-bucket telegraf \
  --description "Telegraf read/write token"

# Read-only token
influx auth create \
  -o myorg \
  --read-bucket telegraf \
  --description "Grafana read-only token"
```

### Token Usage

```bash
# Set token for CLI
export INFLUX_TOKEN="your-admin-token"

# Or use in curl
curl -H "Authorization: Token your-token" \
  "http://localhost:8086/api/v2/query?org=myorg" \
  -H "Content-type: application/vnd.flux" \
  -d 'from(bucket:"telegraf") |> range(start: -1h) |> limit(n: 5)'
```

## Common Test Scenarios

### Scenario 1: Basic Local Deployment

```yaml
# In inventory
influxdb_org: "myorg"
influxdb_bucket: "telegraf"
influxdb_username: "admin"
influxdb_password: "generated"
```

**Deploy:**
```bash
cd mylab
./manage-svc.sh influxdb deploy
```

**Verify:**
```bash
# Service running
systemctl is-active influxdb

# Database accessible
influx ping

# Bucket exists
influx bucket list -o myorg | grep telegraf

# Write test data
influx write \
  -b telegraf \
  -o myorg \
  'test,host=local value=1.0'

# Read test data
influx query 'from(bucket:"telegraf") |> range(start: -1m)' -o myorg
```

### Scenario 2: Multiple Buckets

```yaml
# In inventory
influxdb_org: "myorg"
influxdb_bucket: "telegraf"
influxdb_buckets:
  - telegraf
  - metrics
  - logs
  - shortterm
```

**Deploy:**
```bash
cd mylab
./manage-svc.sh influxdb deploy
```

**Verify:**
```bash
# All buckets created
influx bucket list -o myorg
# Should show: telegraf, metrics, logs, shortterm
```

### Scenario 3: S3 Storage Backend

```yaml
# In inventory
influxdb_s3: true
influxdb_s3_access_key: "ACCESS_KEY"
influxdb_s3_secret_key: "SECRET_KEY"
influxdb_s3_bucket: "influx-data"
```

**Deploy:**
```bash
cd mylab
./manage-svc.sh influxdb deploy
```

**Verify:**
```bash
# Check environment variables set
sudo systemctl cat influxdb | grep Environment
# Should show S3 credentials

# Write data
influx write -b telegraf -o myorg 'test,host=s3 value=1.0'

# Check S3 bucket for data (after compaction)
# aws s3 ls s3://influx-data/
```

**Note:** S3 storage in InfluxDB v2.x is limited. Full tiered storage comes in v3.x.

### Scenario 4: Custom Data Path

```yaml
# In inventory
influxdb_data_path: /mnt/influxdb-data
```

**Prepare:**
```bash
# Create mount point
sudo mkdir -p /mnt/influxdb-data
sudo chown influxdb:influxdb /mnt/influxdb-data
```

**Deploy:**
```bash
cd mylab
./manage-svc.sh influxdb deploy
```

**Verify:**
```bash
# Check data path
ls -la /mnt/influxdb-data/
# Should contain: influxd.bolt, engine/

# Check systemd override
sudo systemctl cat influxdb | grep bolt-path
# Should show: --bolt-path=/mnt/influxdb-data/influxd.bolt
```

### Scenario 5: Force Reconfiguration

```yaml
# In inventory
influxdb_force_configure: true
```

**Use Case:** Database corrupted, need to reinitialize

**WARNING:** This will **delete all data** and reinitialize!

**Deploy:**
```bash
cd mylab
./manage-svc.sh influxdb deploy
```

**What Happens:**
1. Service stopped
2. BoltDB file removed
3. `influx setup` runs again
4. New org, buckets, tokens created
5. **All time series data lost!**

## Troubleshooting Tests

### Test 1: Service Health Check

```bash
# Check service status
systemctl status influxdb

# If failed, check logs
journalctl -u influxdb -n 100 --no-pager

# Common errors:
# - "permission denied": Data path permissions issue
# - "address already in use": Port 8086 conflict
# - "failed to open bolt": BoltDB corruption
```

### Test 2: HTTP API Accessibility

```bash
# Test health endpoint
curl -I http://localhost:8086/health

# Expected: HTTP 200 OK

# If connection refused:
# - Check service running
# - Check firewall: sudo firewall-cmd --list-all
# - Check port binding: ss -tlnp | grep 8086
```

### Test 3: Query Engine

```bash
# Test Flux query
influx query 'from(bucket:"_monitoring") |> range(start: -1h) |> limit(n: 5)' -o myorg

# Expected: Query results in table format

# If errors:
# - "unauthorized": Token missing or invalid
# - "bucket not found": Bucket doesn't exist
# - "timeout": Query too complex or database overloaded
```

### Test 4: Write Performance

```bash
# Write test data
time influx write -b telegraf -o myorg 'test,host=perf value=1.0'

# Expected: < 100ms for single write

# Batch write test
for i in {1..1000}; do
  echo "test,host=perf,batch=$i value=$RANDOM"
done | time influx write -b telegraf -o myorg --format lp

# Expected: < 5 seconds for 1000 points
```

### Test 5: BoltDB Integrity

```bash
# Check BoltDB file
sudo ls -lh /var/lib/influxdb/influxd.bolt

# Expected: File exists, growing size over time

# If corrupted, backup and rebuild:
sudo systemctl stop influxdb
sudo mv /var/lib/influxdb/influxd.bolt /var/lib/influxdb/influxd.bolt.backup
sudo systemctl start influxdb
# Then reinitialize with influx setup
```

### Test 6: Token Validation

```bash
# List all tokens
influx auth list -o myorg

# Test token access
curl -H "Authorization: Token your-token-here" \
  "http://localhost:8086/api/v2/buckets?org=myorg"

# Expected: JSON list of buckets
# Error 401: Invalid or expired token
```

## Integration Testing

### With Telegraf (Metric Collection)

```bash
# Deploy both services
./manage-svc.sh influxdb deploy
./manage-svc.sh telegraf deploy

# Check Telegraf writing to InfluxDB
influx query 'from(bucket:"telegraf")
  |> range(start: -5m)
  |> filter(fn: (r) => r["_measurement"] == "cpu")
  |> limit(n: 10)' -o myorg

# Expected: Recent CPU metrics from Telegraf
```

### With Grafana (Visualization)

```bash
# Get read-only token for Grafana
influx auth create \
  -o myorg \
  --read-bucket telegraf \
  --description "Grafana datasource"

# Configure Grafana datasource:
# Type: InfluxDB
# Query Language: Flux
# URL: http://localhost:8086
# Organization: myorg
# Token: <token-from-above>
# Default Bucket: telegraf

# Test query in Grafana:
from(bucket: "telegraf")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["_measurement"] == "cpu")
```

## Verification Checklist

After deployment, verify:

- [ ] Service running: `systemctl is-active influxdb`
- [ ] Service enabled: `systemctl is-enabled influxdb`
- [ ] HTTP API accessible: `curl -I http://localhost:8086/health`
- [ ] Organization created: `influx org list`
- [ ] Buckets created: `influx bucket list`
- [ ] Admin token exists: `sudo cat /root/.influxdbv2/credentials`
- [ ] Can write data: `influx write -b telegraf -o myorg 'test value=1'`
- [ ] Can query data: `influx query 'from(bucket:"telegraf") |> range(start: -1m)'`
- [ ] No errors in logs: `journalctl -u influxdb -n 50`
- [ ] System metrics being collected: `influx query 'from(bucket:"_monitoring") ...'`

## Performance Testing

### Write Throughput

```bash
# Generate test load (10,000 points)
for i in {1..10000}; do
  echo "perf,host=test,iteration=$i value=$RANDOM $(date +%s)000000000"
done > /tmp/test-data.lp

# Write and measure
time influx write -b telegraf -o myorg --format lp < /tmp/test-data.lp

# Expected: 5,000-20,000 points/second (depends on hardware)
```

### Query Performance

```bash
# Simple query
time influx query 'from(bucket:"telegraf")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "cpu")
  |> mean()' -o myorg

# Expected: < 1 second for 1 hour of data

# Complex aggregation
time influx query 'from(bucket:"telegraf")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "cpu")
  |> aggregateWindow(every: 1m, fn: mean)
  |> pivot(rowKey:["_time"], columnKey: ["cpu"], valueColumn: "_value")' -o myorg

# Expected: < 5 seconds for 24 hours of data
```

### Storage Usage

```bash
# Check database size
du -sh /var/lib/influxdb/

# Check individual components
du -sh /var/lib/influxdb/influxd.bolt  # Metadata
du -sh /var/lib/influxdb/engine/       # Time series data

# Expected: Grows over time, compaction runs periodically
```

### Memory Usage

```bash
# Check influxd memory
ps aux | grep influxd
systemctl status influxdb | grep Memory

# Expected: 200MB-2GB depending on workload and cache settings
```

## Debugging Tips

### Enable Debug Logging

```bash
# Edit systemd service
sudo systemctl edit influxdb

# Add:
[Service]
Environment="INFLUXD_LOG_LEVEL=debug"

# Restart
sudo systemctl restart influxdb

# Watch debug logs
journalctl -u influxdb -f
```

### Check Configuration

```bash
# View effective configuration
influxd print-config

# Check data paths
influxd print-config | grep path

# Check HTTP settings
influxd print-config | grep http
```

### Inspect BoltDB Metadata

```bash
# Dump BoltDB contents (advanced)
sudo -u influxdb influxd inspect export-lp \
  --bucket-id <bucket-id> \
  --engine-path /var/lib/influxdb/engine/ \
  --start 2025-01-01T00:00:00Z \
  --end 2025-01-02T00:00:00Z > export.lp

# Count records
wc -l export.lp
```

### Monitor System Metrics

```bash
# Query InfluxDB's own metrics
influx query 'from(bucket:"_monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "http_api_requests_total")
  |> sum()' -o myorg

# Check for errors
influx query 'from(bucket:"_monitoring")
  |> range(start: -1h)
  |> filter(fn: (r) => r["error"] != "")' -o myorg
```

## Common Errors

### "failed to open bolt: timeout"

**Cause:** BoltDB file locked by another process or corrupted

**Fix:**
```bash
# Check for stale processes
ps aux | grep influxd

# Kill stale processes
sudo killall -9 influxd

# Restart service
sudo systemctl restart influxdb

# If still fails, BoltDB may be corrupted:
sudo systemctl stop influxdb
sudo mv /var/lib/influxdb/influxd.bolt /var/lib/influxdb/influxd.bolt.backup
sudo systemctl start influxdb
# Requires reinitializing with influx setup
```

### "unauthorized access" when querying

**Cause:** Missing or invalid token

**Fix:**
```bash
# Get admin token
sudo cat /root/.influxdbv2/credentials | grep Token

# Set token for CLI
export INFLUX_TOKEN="your-admin-token"

# Or configure influx CLI
influx config create \
  --config-name default \
  --host-url http://localhost:8086 \
  --org myorg \
  --token "your-admin-token" \
  --active
```

### "bucket not found"

**Cause:** Bucket doesn't exist or wrong organization

**Fix:**
```bash
# List buckets
influx bucket list -o myorg

# Create missing bucket
influx bucket create -n telegraf -o myorg

# Or add to inventory:
influxdb_buckets: ['telegraf', 'missing-bucket']
# Redeploy role
```

### Port 8086 already in use

**Cause:** Another service using port or stale InfluxDB instance

**Fix:**
```bash
# Check what's using port
sudo ss -tlnp | grep 8086

# Kill process or stop conflicting service
sudo systemctl stop <conflicting-service>

# Restart InfluxDB
sudo systemctl restart influxdb
```

### High memory usage

**Cause:** Large queries, cache size, or compaction running

**Fix:**
```bash
# Check current queries
influx query 'from(bucket:"_monitoring")
  |> range(start: -5m)
  |> filter(fn: (r) => r["_measurement"] == "query")' -o myorg

# Kill long-running query (if needed)
# Get query ID from monitoring data, then:
influx task delete --id <query-id>

# Restart to clear cache (if needed)
sudo systemctl restart influxdb
```

### S3 connection errors

**Cause:** Invalid credentials or network connectivity

**Fix:**
```bash
# Test S3 credentials
aws s3 ls s3://your-bucket/

# Check environment variables set
sudo systemctl cat influxdb | grep AWS

# Update credentials in inventory
influxdb_s3_access_key: "NEW_KEY"
influxdb_s3_secret_key: "NEW_SECRET"

# Redeploy
cd mylab
./manage-svc.sh influxdb deploy
```

## Data Management

### Backup

```bash
# Backup BoltDB metadata
sudo systemctl stop influxdb
sudo cp /var/lib/influxdb/influxd.bolt /backup/influxd.bolt.$(date +%Y%m%d)
sudo systemctl start influxdb

# Backup time series data
sudo influxd backup /backup/influxdb-$(date +%Y%m%d)/
```

### Restore

```bash
# Restore from backup
sudo systemctl stop influxdb
sudo influxd restore /backup/influxdb-20250117/
sudo systemctl start influxdb
```

### Downsampling (Reduce Storage)

```bash
# Create task to downsample old data
influx task create \
  --org myorg \
  --name "downsample-hourly" \
  '
option task = {name: "downsample-hourly", every: 1h}

from(bucket: "telegraf")
  |> range(start: -2h, stop: -1h)
  |> aggregateWindow(every: 1m, fn: mean)
  |> to(bucket: "telegraf-downsampled", org: "myorg")
'
```

## References

- [InfluxDB Documentation](https://docs.influxdata.com/influxdb/v2/)
- [Flux Query Language](https://docs.influxdata.com/flux/v0/)
- [InfluxDB CLI Reference](https://docs.influxdata.com/influxdb/v2/reference/cli/influx/)
- [Role README](README.md)

## Notes

- **Password generation**: If `influxdb_password: "generated"`, a random password is created and stored
- **Tokens are sensitive**: Store in `/root/.influxdbv2/credentials`, protect with proper permissions
- **BoltDB is critical**: Corruption means losing metadata (org, buckets, users, tokens)
- **TSM files are time series data**: Stored in `/var/lib/influxdb/engine/`
- **S3 in v2.x is limited**: Full tiered storage requires v3.x upgrade
- **Compaction runs automatically**: May cause temporary high CPU/memory usage
- **Retention policies**: Set per bucket, infinite by default
- **System buckets**: `_monitoring` and `_tasks` are created automatically
- **Force configure is destructive**: Only use when intentionally reinitializing
