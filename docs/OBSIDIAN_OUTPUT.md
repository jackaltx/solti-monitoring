# Test Results as Obsidian Vault

Test results are automatically published to an Obsidian-compatible knowledge vault at
`verify_output/obsidian/`. This creates a browsable wiki of test history with
cross-linked navigation by time, distribution, and capability.

## Architecture Pattern: Event Sourcing

- **Test runs are immutable events** (source of truth)
- **Indices are derived views** (regenerated post-test)
- **No concurrent writes** (eliminates race conditions with parallel platform runs)
- **Self-healing** (indices always reflect actual runs)

## File Structure

```text
verify_output/obsidian/
├── README.md                    # Map of Content (navigation hub)
├── index.md                     # Chronological index (newest first)
├── Debian-12-Index.md           # Distribution-specific indexes
├── Rocky-9-Index.md
├── Ubuntu-24-Index.md
├── Logs-Capability.md           # Capability-specific indexes
├── Metrics-Capability.md
└── runs/                        # Immutable test run records
    └── 2026-03-29-debian12-190008/
        ├── run-2026-03-29T190008Z.md       # Test run overview
        ├── logs-capability.md               # Logs verification detail
        ├── metrics-capability.md            # Metrics verification detail
        ├── preverify-diagnostics.md         # Pre-test system state
        └── postverify-diagnostics.md        # Post-test system state
```

## Usage

1. Open `verify_output/obsidian/` as an Obsidian vault
2. Start at `README.md` (Map of Content) or `index.md` for chronological view
3. Use distribution indexes (e.g., `Debian-12-Index.md`) to filter by OS
4. Use capability indexes (`Logs-Capability.md`, `Metrics-Capability.md`) to filter by stack
5. Wiki-style links connect runs ↔ capabilities ↔ indexes

## How It Works

**Step 1 — Test execution creates immutable run records.**
During `molecule verify`, each test writes its own `runs/{timestamp}/` directory.
No shared files are written during the test phase, so parallel platform runs
(e.g. Debian + Rocky + Ubuntu simultaneously) never conflict.

**Step 2 — Post-test index regeneration.**
After all tests complete, `bin/regenerate-obsidian-indices.sh` scans run records
and rebuilds all index files from scratch. If an index gets corrupted or runs are
pruned, regenerate at any time:

```bash
./bin/regenerate-obsidian-indices.sh verify_output/obsidian
```

## NFS Sync (Optional)

To sync results to an Obsidian vault on NFS after each test run:

```bash
source bin/setup-nfs-sync.sh   # sets OBSIDIAN_SYNC_ENABLED, NFS mount path, SSH host
./run-podman-tests.sh           # runs tests, then syncs automatically
```

The sync uses rsync to the NFS mount and fixes remote ownership via SSH — no local
sudo required.
