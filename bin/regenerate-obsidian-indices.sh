#!/usr/bin/env bash
# Regenerates Obsidian indices from immutable run records
# Source of truth: runs/*/index.md YAML frontmatter
#
# Usage: ./bin/regenerate-obsidian-indices.sh [obsidian_dir]
#
# This script uses atomic file writes (temp + mv) for NFS safety

set -euo pipefail

OBSIDIAN_DIR="${1:-./verify_output/obsidian}"
RUNS_DIR="$OBSIDIAN_DIR/runs"

# Validate directories exist
if [[ ! -d "$RUNS_DIR" ]]; then
    echo "No runs directory found at: $RUNS_DIR"
    echo "Nothing to regenerate."
    exit 0
fi

# Parse all run metadata
declare -A runs_by_distro
declare -A runs_by_capability
runs_chrono=()

for run_dir in "$RUNS_DIR"/*/; do
    # Find the run index file (either index.md or run-*.md)
    index_file=$(find "$run_dir" -maxdepth 1 -name "run-*.md" -o -name "index.md" | head -1)
    [[ -f "$index_file" ]] || continue

    # Extract YAML frontmatter
    timestamp=$(grep "^timestamp:" "$index_file" | cut -d' ' -f2 || echo "")
    distribution=$(grep "^distribution:" "$index_file" | cut -d' ' -f2- || echo "Unknown")
    status=$(grep "^overall_status:" "$index_file" | cut -d' ' -f2 || echo "UNKNOWN")
    capabilities=$(grep "^capabilities_tested:" "$index_file" | sed 's/.*\[\(.*\)\]/\1/' | tr -d '"' || echo "")
    run_name=$(basename "$run_dir")
    index_basename=$(basename "$index_file" .md)

    # Skip if essential metadata missing
    [[ -n "$timestamp" ]] || continue

    # Store for chronological index
    runs_chrono+=("$timestamp|$distribution|$status|$run_name|$index_basename")

    # Store for distribution index
    distro_key=$(echo "$distribution" | tr ' ' '-')
    runs_by_distro[$distro_key]+="$timestamp|$status|$run_name|$index_basename"$'\n'

    # Store for capability indices
    if [[ -n "$capabilities" ]]; then
        IFS=',' read -ra caps <<< "$capabilities"
        for cap in "${caps[@]}"; do
            cap=$(echo "$cap" | xargs)  # trim whitespace
            runs_by_capability[$cap]+="$timestamp|$distribution|$status|$run_name|$index_basename"$'\n'
        done
    fi
done

# Generate chronological index (atomic write with NFS-safe temp file)
{
    cat <<EOF
---
type: index
index_type: chronological
last_updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
---

# Test Run History

All test runs in chronological order (newest first).

[[README|← Map of Content]] | [[Logs-Capability|Logs]] | [[Metrics-Capability|Metrics]]

## Runs

EOF

    # Sort chronologically (newest first)
    printf '%s\n' "${runs_chrono[@]}" | sort -r | while IFS='|' read -r ts dist stat runname indexname; do
        # Format timestamp for display
        date_str=$(date -d "$ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$ts")
        echo "- $date_str - [[runs/$runname/$indexname|$dist]] - $stat"
    done
} > "$OBSIDIAN_DIR/index.md.tmp.$$"
mv "$OBSIDIAN_DIR/index.md.tmp.$$" "$OBSIDIAN_DIR/index.md"

echo "✓ Regenerated chronological index: $OBSIDIAN_DIR/index.md"

# Generate distribution-specific indices
for distro_key in "${!runs_by_distro[@]}"; do
    distro_display=$(echo "$distro_key" | tr '-' ' ')
    index_file="$OBSIDIAN_DIR/${distro_key}-Index.md"

    {
        cat <<EOF
---
type: index
index_type: distribution
distribution: $distro_display
last_updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
---

# $distro_display Test Runs

[[README|← Map of Content]] | [[index|Chronological]]

## Runs

EOF

        # Sort chronologically (newest first)
        echo "${runs_by_distro[$distro_key]}" | grep -v '^$' | sort -r | while IFS='|' read -r ts stat runname indexname; do
            [[ -n "$runname" ]] || continue
            date_str=$(date -d "$ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$ts")
            echo "- $date_str - [[runs/$runname/$indexname|Test Run]] - $stat"
        done
    } > "$index_file.tmp.$$"
    mv "$index_file.tmp.$$" "$index_file"

    echo "✓ Regenerated distribution index: $index_file"
done

# Generate capability-specific indices
for capability in "${!runs_by_capability[@]}"; do
    cap_display=$(echo "$capability" | tr '[:lower:]' '[:upper:]')
    index_file="$OBSIDIAN_DIR/${capability^}-Capability.md"

    {
        cat <<EOF
---
type: index
index_type: capability
capability: $capability
last_updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
---

# $cap_display Verification Results

Cross-distribution view of $capability capability testing.

[[README|← Map of Content]] | [[index|Chronological]]

## Test Results by Distribution

EOF

        # Group by distribution
        declare -A distro_runs
        echo "${runs_by_capability[$capability]}" | grep -v '^$' | while IFS='|' read -r ts dist stat runname indexname; do
            [[ -n "$runname" ]] || continue
            distro_key=$(echo "$dist" | tr ' ' '-')
            echo "$ts|$stat|$runname|$indexname" >> "/tmp/cap_${capability}_${distro_key}.$$"
        done

        # Output by distribution
        for distro_file in /tmp/cap_${capability}_*.$$; do
            [[ -f "$distro_file" ]] || continue
            distro_key=$(basename "$distro_file" | sed "s/cap_${capability}_//" | sed 's/\..*//')
            distro_display=$(echo "$distro_key" | tr '-' ' ')

            echo
            echo "### $distro_display"
            echo

            sort -r "$distro_file" | while IFS='|' read -r ts stat runname indexname; do
                date_str=$(date -d "$ts" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$ts")
                status_icon="✅"
                [[ "$stat" != "PASSED" ]] && status_icon="❌"
                echo "- $status_icon $date_str - [[runs/$runname/${capability}-capability|Details]] - $stat"
            done

            rm -f "$distro_file"
        done
    } > "$index_file.tmp.$$"
    mv "$index_file.tmp.$$" "$index_file"

    echo "✓ Regenerated capability index: $index_file"
done

echo
echo "Index regeneration complete. Found ${#runs_chrono[@]} test runs across ${#runs_by_distro[@]} distributions and ${#runs_by_capability[@]} capabilities."
