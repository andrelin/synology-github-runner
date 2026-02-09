# Restart Reliability Fix

## Problem Solved

Previously, the GitHub runner container would enter a crash-loop after Synology NAS restart, requiring manual intervention:

1. Delete container via Container Manager
2. Rebuild the project
3. Runner comes back up

**This is now fixed.** The runner will automatically recover after NAS restart.

## Solution Implemented

**Solution B: Initialization Script + Better Restart Policy**

### Components Added

#### 1. Initialization Script (`scripts/init-runner.sh`)

Runs before the GitHub runner starts and validates:

- ✅ Workspace directory is accessible (volumes mounted)
- ✅ Network connectivity to GitHub API
- ✅ Cleans stale lock files
- ✅ Verifies Docker socket access
- ✅ Checks required environment variables

**Startup delay:** Configurable via `STARTUP_DELAY_SECONDS` (default: 30 seconds)

- Allows network and volumes to be ready before runner starts
- Includes retry logic (up to 12 attempts × 5 seconds = 60 seconds additional wait)

#### 2. Entrypoint Wrapper (`scripts/entrypoint-wrapper.sh`)

- Wraps the base image's entrypoint
- Runs initialization script first
- Fails fast if initialization fails (prevents crash-loop)

#### 3. Enhanced Health Check (docker-compose.yml)

```yaml
healthcheck:
  test: ["CMD-SHELL", "pgrep -f 'Runner.Listener' || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 120s  # 2 minutes grace period after reboot
```

**Why this helps:**

- `start_period: 120s` gives runner plenty of time to initialize after reboot
- Prevents premature health check failures during startup
- Health check monitors runner process, not just container

#### 4. Restart Policy

Still using `restart: unless-stopped` which is appropriate for:

- Automatic restart on failure
- Respects manual stops
- Doesn't restart if you explicitly stop the container

## Configuration

### Default Settings (Recommended)

The defaults work for most Synology hardware:

```bash
# In .env file
STARTUP_DELAY_SECONDS=30
```

### Tuning for Your Hardware

**If runner starts fine after reboot:**

- Reduce delay for faster startup: `STARTUP_DELAY_SECONDS=15`
- Or disable entirely: `STARTUP_DELAY_SECONDS=0`

**If runner still fails after reboot:**

- Increase delay: `STARTUP_DELAY_SECONDS=60`
- Check logs for which validation step is failing
- May indicate network or storage issues

## Testing the Fix

### Test 1: Clean Reboot

```bash
# 1. Verify runner is working
ssh admin@<your-nas-ip>
docker ps | grep github-runner  # Should show "Up" and "healthy"

# 2. Check GitHub
# Go to: https://github.com/your-username/your-repo/settings/actions/runners
# Runner should show as "Idle" with green circle

# 3. Reboot Synology via DSM UI
# Control Panel → Info Center → General → Restart

# 4. Wait for NAS to come back online (2-5 minutes)

# 5. SSH back in and check status
ssh admin@<your-nas-ip>
docker ps | grep github-runner

# Expected: Container shows "Up" and "healthy" status
# Expected: Runner appears as "Idle" in GitHub within 2-3 minutes
```

### Test 2: Check Initialization Logs

```bash
# View initialization logs
docker logs github-runner | head -50

# Expected output:
# === GitHub Runner Container Starting ===
# Running pre-start initialization...
# === GitHub Runner Initialization ===
# Waiting 30 seconds for system stabilization...
# ✓ Workspace directory accessible
# ✓ GitHub API reachable
# ✓ Lock files cleaned
# ✓ Docker socket accessible and working
# ✓ Required environment variables present
# === Initialization complete - starting runner ===
```

### Test 3: Verify Health Check

```bash
# Check health status
docker inspect github-runner | grep -A 5 Health

# Expected: "Status": "healthy"
```

## Troubleshooting

### Runner Still Fails After Reboot

**Check initialization logs:**

```bash
docker logs github-runner 2>&1 | grep -A 20 "Initialization"
```

**Common issues:**

#### Issue: "Workspace directory not accessible"

```text
ERROR: Workspace directory not accessible: /volume1/docker/github-runner/workspace
FATAL: Workspace directory never became available
```

**Solution:**

- Volume mount is failing
- Increase `STARTUP_DELAY_SECONDS=60`
- Check volume path exists: `ls -la /volume1/docker/github-runner/`
- Verify docker-compose.yml volume mounts are correct

#### Issue: "GitHub API not reachable"

```text
ERROR: GitHub API not reachable after 12 attempts
```

**Solution:**

- Network not ready during startup
- Increase `STARTUP_DELAY_SECONDS=60`
- Check network connectivity: `ping github.com`
- Check DNS: `nslookup api.github.com`
- May be firewall or routing issue

#### Issue: Container shows "unhealthy"

```bash
docker ps  # Shows "unhealthy" status
```

**Solution:**

- Health check is failing
- Check if runner process is actually running:

  ```bash
  docker exec github-runner pgrep -f 'Runner.Listener'
  ```

- If no process, check runner logs for why it's not starting
- May need to increase `start_period` in health check

### Manual Recovery (If Needed)

If the runner still doesn't recover automatically:

```bash
# Via SSH
ssh admin@<your-nas-ip>
cd /volume1/docker/github-runner

# Stop and recreate container
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Check logs
docker-compose logs -f
```

## What Changed from Previous Version

| Aspect | Before | After |
| ------ | ------ | ----- |
| **Health check** | None | 30s interval, 2 min start period |
| **Startup validation** | None | Full pre-flight checks |
| **Network wait** | Immediate start | Waits + retries for connectivity |
| **Volume check** | None | Verifies mount before starting |
| **Lock cleanup** | None | Auto-removes stale locks |
| **Startup delay** | None | 30s configurable delay |

## How It Works

### Startup Sequence After Reboot

1. **NAS boots** → DSM starts → Container Manager starts
2. **Docker daemon starts** → May be before network/volumes ready
3. **Container starts** → Entrypoint wrapper runs
4. **Initialization script runs:**
   - Waits 30 seconds (configurable)
   - Checks workspace directory (retries if not ready)
   - Checks GitHub API connectivity (retries if not ready)
   - Cleans stale locks
   - Validates Docker socket
   - Checks environment variables
5. **If initialization succeeds** → GitHub runner starts normally
6. **If initialization fails** → Container exits (no crash-loop)
7. **Health check begins** after 120 seconds → Monitors runner process

### Why This Fixes the Crash-Loop

**Before:** Runner would start immediately, hit errors (network/volumes not ready), crash, restart immediately, repeat.

**After:** Runner waits for system to be ready, validates state, then starts cleanly.

## Performance Impact

- **First startup after reboot:** +30-60 seconds (initialization + health check grace period)
- **Normal restarts:** No impact (initialization is fast when system is already stable)
- **Failed starts:** Fail fast instead of crash-looping

## Maintenance

This fix is **automatic** and requires no manual intervention. The initialization script runs on every container start.

## Related Documentation

- [Maintenance Guide](06-MAINTENANCE.md) - Regular maintenance tasks
- [Troubleshooting Guide](05-TROUBLESHOOTING.md) - General troubleshooting
- [Configuration Guide](03-CONFIGURATION.md) - Environment variable configuration
