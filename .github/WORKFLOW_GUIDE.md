# GitHub Workflow Guide - solti-monitoring

## Branch Strategy

This collection uses a two-branch workflow:

- **test**: Development/integration branch (renamed from dev)
- **main**: Production-ready branch

## Development Workflow

```
feature branch → test → main (via PR)
```

### Working on Features

1. **Create feature branch from test**:
   ```bash
   git checkout test
   git pull
   git checkout -b feature/my-feature
   ```

2. **Develop with checkpoint commits**:
   ```bash
   git add -A
   git commit -m "checkpoint: description"
   # Run tests, iterate
   ```

3. **Push to test branch**:
   ```bash
   git checkout test
   git merge feature/my-feature
   git push origin test
   ```

4. **Monitor test branch workflows**:
   - lint.yml: Fast feedback (~5 min)
   - superlinter.yml: Comprehensive validation (~10 min)

5. **When ready, create PR test → main**:
   - GitHub UI: Create Pull Request
   - Triggers ci.yml: Full testing (Rocky 9 only - 60 min timeout)
   - Review artifacts before merging

## Workflow Triggers

| Workflow | test branch | main branch | What it does |
|----------|-------------|-------------|--------------|
| **lint.yml** | ✅ push/PR | ✅ push/PR | YAML, Markdown, Ansible lint + syntax |
| **superlinter.yml** | ✅ push/PR | ❌ | Comprehensive validation (Super-Linter) |
| **ci.yml** | ❌ | ✅ push/PR | Full molecule tests (Rocky 9) |
| **save-container.yml** | ✅ manual | ✅ manual | Debug: Save container state on failure |

## Testing Locally Before Push

### Lint checks
```bash
# YAML
yamllint .

# Markdown
markdownlint "**/*.md" --ignore node_modules

# Ansible
ansible-lint

# Syntax check
ansible-playbook --syntax-check <playbook.yml>
```

### Molecule tests
```bash
# Using helper scripts
./run-podman-tests.sh    # Test all platforms locally
./run-proxmox-tests.sh   # Test on Proxmox VMs

# Direct molecule
MOLECULE_PLATFORM_NAME=uut-ct1 molecule test -s github
```

## CI Configuration

### Platform Matrix

**Current (GitHub Actions)**:
| Platform | Container Image | SSH Port | Distro | Status |
|----------|----------------|----------|--------|--------|
| uut-ct0 | ghcr.io/jackaltx/testing-containers/debian12-ssh:latest | 2223 | Debian 12 | Disabled (timeout) |
| uut-ct1 | ghcr.io/jackaltx/testing-containers/rocky93-ssh:latest | 2222 | Rocky Linux 9 | ✅ Active |
| uut-ct2 | ghcr.io/jackaltx/testing-containers/ubuntu24-ssh:latest | 2224 | Ubuntu 24 | Disabled (timeout) |

**Note**: Full 3-platform matrix causes GitHub Actions timeout (>60min).
See [Known Issues](#known-issues) below.

**Local Testing**: All 3 platforms available via run-podman-tests.sh

### Environment Variables

**ci.yml accepts**:
- `DEBUG_MODE`: save (saves container state on error)
- `MOLECULE_NO_LOG`: false (enable logging)

### Secrets Required

**WIKI_TOKEN**:
- Required by ci.yml for wiki checkout
- Used to publish results to .wiki repository
- Optional: Can be removed if wiki integration not needed

**GIST_TOKEN** (commented out):
- Would enable GIST publishing (lines 157-184 in ci.yml)
- Currently disabled

## Artifacts

### Test Results (ci.yml)
- **Name**: monitoring-test-results
- **Path**: verify_output/
- **Retention**: 5 days
- **Contains**: Test reports, verification output, consolidated reports

### Container State (save-container.yml)
- **Name**: container-{platform}-{timestamp}
- **Path**: Container tarball + verify_output
- **Retention**: 5 days
- **Use**: Debug failed tests by loading saved container

## Special Features

### save-container.yml - Debug Workflow

When a test fails, use this workflow to preserve container state:

1. Go to Actions → Save Container State
2. Run workflow: Select platform that failed
3. Download artifacts
4. Load container: `podman load -i container.tar`
5. Inspect: `podman start <container> && podman exec -it <container> bash`

### Elasticsearch Reporting (Optional)

If ES_RW_TOKEN is set, test results are indexed to Elasticsearch:
- Index: molecule-tests
- Location: molecule/shared/elasticsearch/result-store.yml
- Conditional: Only runs when token is available

### Wiki Integration

ci.yml checks out .wiki repository and can publish results there.
Commented out code (lines 188-234) shows wiki update logic.

## Known Issues

### CI Matrix Timeout

**Issue**: Full 3-platform matrix exceeds 60-minute GitHub Actions timeout

**Current Workaround**: Only test Rocky 9 (uut-ct1) in CI

**Future Solutions**:
- Scheduled testing: Full matrix weekly, single platform on PR
- Self-hosted runner: Avoid GitHub timeout limits
- Parallel optimization: Reduce per-platform time
- Selective testing: Only test roles changed in PR

**Tracked**: Low priority issue documented in WORKFLOW_ALIGNMENT_ANALYSIS.md

## Troubleshooting

### Lint failures
Check the failing job in GitHub Actions, fix locally, push again.

### Molecule test failures
1. Download artifacts from failed run
2. Review verify_output/{distro}/consolidated_test_report.md
3. Option A: Fix issue locally and re-test
4. Option B: Use save-container.yml to debug in container

### Wiki checkout fails
If WIKI_TOKEN is not configured:
- Either: Add secret to GitHub repo settings
- Or: Remove wiki checkout step from ci.yml (lines 49-54)

### Superlinter too strict
Superlinter runs only on test branch - use it for early feedback.
If a check is problematic, disable it in superlinter.yml.

## Branch Protection (Recommended)

Configure on GitHub:
- **test branch**: No restrictions (direct push allowed)
- **main branch**:
  - Require pull request reviews
  - Require status checks: lint.yml jobs
  - Do not allow force push
  - Do not allow deletions

## Migration Notes

### dev → test Branch Rename

The development branch was renamed from `dev` to `test` for consistency across Solti collections.

**If you have local dev branch**:
```bash
git branch -m dev test
git fetch origin
git branch -u origin/test test
```

**If you have dev checked out remotely**:
```bash
git fetch origin
git checkout -b test origin/test
git branch -D dev  # Delete local dev
```

## Next Steps

1. **Push renamed test branch**:
   ```bash
   git push -u origin test
   git push origin --delete dev  # Delete remote dev
   ```

2. **Update GitHub default branch** (if needed):
   - Settings → Branches → Default branch → Change to main

3. **Test lint.yml** on test branch:
   - Push a change and verify all 4 jobs pass

4. **Consider CI optimization**:
   - Evaluate scheduled full matrix testing
   - Or self-hosted runner for full coverage
