# Known Issues - solti-monitoring

## CI Matrix Timeout (Low Priority)

**Issue**: GitHub Actions CI cannot run full 3-platform test matrix

**Details**:
- Target: Test all roles on Debian 12, Rocky 9, Ubuntu 24
- Reality: Only Rocky 9 (uut-ct1) enabled in ci.yml:36
- Reason: Each platform takes ~60 minutes, total would be 180 minutes
- GitHub Actions timeout: 60 minutes per job

**Current Configuration**:
```yaml
# ci.yml line 36
platform: ['uut-ct1' ]  # Only Rocky 9 active
# Commented out: , 'uut-ct0', 'uut-ct2'
```

**Impact**:
- ✅ Main testing happens locally via run-podman-tests.sh (all 3 platforms)
- ✅ Proxmox testing via run-proxmox-tests.sh (all 3 platforms)
- ⚠️ GitHub CI only validates Rocky 9 (33% coverage)

**Workarounds**:

### Option 1: Scheduled Full Matrix (Recommended)
```yaml
strategy:
  matrix:
    platform: ${{ github.event_name == 'schedule' && fromJson('["uut-ct0", "uut-ct1", "uut-ct2"]') || fromJson('["uut-ct1"]') }}
```
- PR/push: Test Rocky 9 only (fast feedback)
- Scheduled (weekly): Full 3-platform matrix
- Requires: Add schedule trigger to ci.yml

### Option 2: Self-Hosted Runner
- Deploy GitHub Actions runner on local infrastructure
- No 60-minute timeout
- Can test all 3 platforms in parallel
- Requires: Infrastructure setup, runner registration

### Option 3: Parallel with Timeout Management
```yaml
strategy:
  matrix:
    platform: ['uut-ct0', 'uut-ct1', 'uut-ct2']
  max-parallel: 3
timeout-minutes: 60
```
- Run all 3 in parallel (not sequential)
- Each must complete within 60 min
- Risk: If any platform is slow, it times out
- Current max-parallel: 1 (sequential)

### Option 4: Selective Role Testing
- Detect which roles changed in PR
- Only test changed roles (faster)
- Still test all roles on schedule/main branch
- Requires: Changed file detection logic

### Option 5: Optimize Molecule Tests
- Review molecule test sequence for unnecessary steps
- Skip idempotence test in CI (run locally)
- Reduce verification depth
- May compromise test quality

**Recommendation**: Option 1 (Scheduled Full Matrix)
- Best balance of coverage and feedback speed
- PR gets fast feedback (Rocky 9, ~60min)
- Weekly regression catches platform-specific issues
- No infrastructure changes needed

**Priority**: Low
- Local testing already validates all platforms
- Rocky 9 is most representative (RHEL-based, enterprise focus)
- CI is safety net, not primary test method

**Related**:
- ci.yml:36 (platform matrix)
- ci.yml:38 (max-parallel setting)
- run-podman-tests.sh (local 3-platform testing)
- run-proxmox-tests.sh (VM-based testing)

---

## No Other Known Issues

The collection is mature and stable. Other than CI timeout, all known issues have been resolved.

**If you encounter issues**:
1. Check GitHub Actions logs
2. Use save-container.yml to debug failed tests
3. Run locally: `./run-podman-tests.sh`
4. Review verify_output reports
