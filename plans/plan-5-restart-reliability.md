# Plan 5: Fix Runner Restart Reliability

**Status:** 🔴 Not Started
**Priority:** High
**Estimated Duration:** 2-3 hours

## Problem Statement

The GitHub runner container does not recover properly when the Synology NAS restarts. The container enters a crash-loop and requires manual intervention to restore functionality.

**Current Workaround:**
1. Delete the container via Container Manager
2. Rebuild the project
3. Runner comes back up successfully

This is not acceptable for production use where the runner should automatically recover after planned/unplanned restarts.

## Symptoms

- Container shows as "Running" but runner not responding
- Container repeatedly restarts (crash-loop)
- Runner does not appear as "Idle" in GitHub after NAS restart
- Logs show repeated crashes or connection failures

## Suspected Root Causes

### 1. Volume Mount Issues
- Docker volumes may not be ready when container starts
- Volume mount points may have changed after restart
- Permissions may have changed on restart

### 2. Network Timing Issues
- Container starts before network is fully ready
- DNS resolution fails on startup
- GitHub API not reachable during initial start

### 3. State Corruption
- Runner registration state becomes corrupted during unclean shutdown
- `.runner` file or credentials cache in inconsistent state
- GitHub API session tokens expired/invalid

### 4. Container Startup Dependencies
- Docker daemon starts before dependent services (network, volumes)
- No proper health check or retry logic
- Container Manager restart policy not appropriate

### 5. Resource Constraints
- System under heavy load during startup
- Insufficient memory available during boot
- CPU throttling preventing proper startup

## Investigation Plan

### Phase 1: Gather Information (30 minutes)

**Tasks:**
1. [ ] Reproduce the issue:
   - Document current working state
   - Reboot Synology NAS
   - Observe crash-loop behavior
   - Capture logs during crash-loop

2. [ ] Examine Container Manager logs:
   ```bash
   # SSH into Synology
   ssh admin@<your-nas-ip>

   # Check docker daemon logs
   sudo journalctl -u docker.service -n 100

   # Check container logs during crash
   docker logs github-runner --tail 200

   # Check system logs
   cat /var/log/messages | grep -i docker
   ```

3. [ ] Check volume mount status:
   ```bash
   # Verify volumes exist and are accessible
   ls -la /volume1/docker/github-runner/
   ls -la /volume1/docker/github-runner/.runner

   # Check permissions
   stat /volume1/docker/github-runner/

   # Check if volumes mounted when container tries to start
   mount | grep volume1
   ```

4. [ ] Examine runner state:
   ```bash
   # Check runner registration files
   cat /volume1/docker/github-runner/.runner
   cat /volume1/docker/github-runner/.credentials

   # Check for lock files
   find /volume1/docker/github-runner -name "*.lock"
   ```

5. [ ] Review docker-compose configuration:
   - Check restart policy
   - Check volume definitions
   - Check health check configuration
   - Check dependency ordering

**Deliverables:**
- Crash-loop logs captured
- Volume mount status documented
- Current configuration reviewed
- Root cause hypothesis formed

### Phase 2: Implement Fixes (1-1.5 hours)

Based on investigation, implement appropriate fixes:

#### Fix 1: Improve Health Check

Add proper health check with retry logic:

```yaml
healthcheck:
  test: ["CMD-SHELL", "pgrep -f 'Runner.Listener' || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 60s  # Give runner time to start after reboot
```

**Reasoning:** Current health check may be too aggressive, killing container before runner fully initializes after reboot.

#### Fix 2: Add Startup Delay

Add environment variable to delay startup:

```yaml
environment:
  - STARTUP_DELAY_SECONDS=30
```

Then modify runner startup script to wait for network/volumes:

```bash
#!/bin/bash
# Wait for network and volumes to be ready
if [ -n "$STARTUP_DELAY_SECONDS" ]; then
  echo "Waiting ${STARTUP_DELAY_SECONDS} seconds for system stabilization..."
  sleep "$STARTUP_DELAY_SECONDS"
fi

# Verify volume is accessible
while [ ! -d "/volume1/docker/github-runner" ]; do
  echo "Waiting for volume to be mounted..."
  sleep 5
done

# Verify network connectivity
while ! ping -c 1 github.com &> /dev/null; do
  echo "Waiting for network connectivity..."
  sleep 5
done

# Start runner normally
./run.sh
```

#### Fix 3: Improve Restart Policy

Update restart policy to be more resilient:

```yaml
restart: unless-stopped
deploy:
  restart_policy:
    condition: on-failure
    delay: 30s
    max_attempts: 5
    window: 120s
```

**Reasoning:** Give container time to recover between restart attempts, limit infinite crash-loops.

#### Fix 4: Add Initialization Script

Create init-container pattern with proper pre-checks:

```bash
#!/bin/bash
# init-runner.sh - Run before starting runner

set -e

echo "=== Runner Initialization ==="

# 1. Check volumes are accessible
echo "Checking volume access..."
if [ ! -d "/volume1/docker/github-runner" ]; then
  echo "ERROR: Runner directory not accessible"
  exit 1
fi

# 2. Check network connectivity
echo "Checking network connectivity..."
if ! curl -sf https://api.github.com &> /dev/null; then
  echo "WARNING: GitHub API not reachable, waiting..."
  sleep 10
fi

# 3. Check runner registration
echo "Checking runner registration..."
if [ ! -f ".runner" ]; then
  echo "ERROR: Runner not registered"
  exit 1
fi

# 4. Clean up stale state
echo "Cleaning stale state..."
rm -f *.lock
rm -f .runner.lock

# 5. Verify runner binary
echo "Verifying runner binary..."
if [ ! -x "./bin/Runner.Listener" ]; then
  echo "ERROR: Runner binary not found or not executable"
  exit 1
fi

echo "=== Initialization complete ==="
```

#### Fix 5: Add Systemd Dependency (Alternative)

If using systemd service, add proper dependencies:

```ini
[Unit]
Description=GitHub Actions Runner
After=docker.service network-online.target
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=30s
```

### Phase 3: Testing (30-45 minutes)

**Test scenarios:**

1. [ ] **Clean restart test:**
   - Stop runner gracefully
   - Reboot Synology
   - Verify runner comes back up automatically
   - Check runner shows as "Idle" in GitHub

2. [ ] **Unclean shutdown test:**
   - While runner is active, pull power plug
   - Power back on
   - Verify runner recovers

3. [ ] **Resource constraint test:**
   - Start several other containers
   - Reboot Synology
   - Verify runner still recovers

4. [ ] **Network delay test:**
   - Simulate network delay during boot
   - Verify runner waits and recovers

5. [ ] **Multiple restart test:**
   - Reboot 3 times in succession
   - Verify runner recovers each time

**Success criteria:**
- Runner recovers automatically after reboot
- No crash-loop behavior
- Runner appears as "Idle" in GitHub within 2 minutes of boot
- No manual intervention required

### Phase 4: Documentation (15 minutes)

**Tasks:**
1. [ ] Document the fix in implementation history
2. [ ] Update docker-compose.yml with new configuration
3. [ ] Update docs/06-MAINTENANCE.md with restart behavior
4. [ ] Add troubleshooting section for restart issues
5. [ ] Document recovery procedures if auto-restart fails

## Possible Solutions (Ranked)

### Solution A: Enhanced Health Check + Startup Delay (Easiest)
**Effort:** 30 minutes
**Likelihood to fix:** 70%

Just improve health check timing and add startup delay. Simple, minimal changes.

### Solution B: Initialization Script + Better Restart Policy (Moderate)
**Effort:** 1 hour
**Likelihood to fix:** 85%

Add proper initialization script that validates state before starting runner. Update restart policy.

### Solution C: Custom Runner Image (Most Robust)
**Effort:** 2-3 hours
**Likelihood to fix:** 95%

Build custom runner image with proper init system, health checks, and restart logic built in.

### Solution D: External Monitoring + Recovery (Nuclear Option)
**Effort:** 3-4 hours
**Likelihood to fix:** 99%

Add external monitoring script that detects crash-loop and automatically rebuilds container. This is the current manual workaround, automated.

## Recommended Approach

**Start with Solution B (Initialization Script + Better Restart Policy):**

1. Implement initialization script with proper pre-checks
2. Update health check with longer start period
3. Improve restart policy with delays
4. Test thoroughly

**If Solution B doesn't work:**
- Move to Solution C (custom runner image)
- Or implement Solution D (automated recovery script)

## Success Criteria

- [ ] Runner survives planned reboot (clean shutdown)
- [ ] Runner survives unplanned reboot (power loss)
- [ ] No crash-loop behavior observed
- [ ] Runner appears in GitHub within 2 minutes of boot
- [ ] Zero manual intervention required
- [ ] Solution works consistently (5/5 reboots successful)
- [ ] Documentation updated with restart behavior

## Related Issues

- Impacts Plan 1 (Repository Integration) - may need to update docker-compose
- Impacts Plan 2 (Monitoring) - health checks should detect restart issues
- Critical for production reliability

## Temporary Workaround

**Until this is fixed, document the recovery procedure:**

```bash
# If runner is in crash-loop after reboot:

# 1. Via Container Manager UI:
#    - Open Container Manager
#    - Find github-runner project
#    - Action → Stop
#    - Action → Delete (container only, not project)
#    - Action → Build
#    - Wait for runner to appear in GitHub

# 2. Via SSH:
ssh admin@<your-nas-ip>
cd /volume1/docker/github-runner
docker-compose down
docker-compose up -d
```

## Notes

- This is a common issue with Docker containers on NAS systems
- Timing issues between Docker daemon, networking, and volume mounts
- Proper initialization and health checks are critical
- May need to adjust based on specific Synology model and DSM version

## Future Enhancements

After fixing the immediate issue:
- [ ] Add automated recovery script as backup
- [ ] Implement proper logging of startup sequence
- [ ] Add metrics for restart success rate
- [ ] Consider systemd service for more control
