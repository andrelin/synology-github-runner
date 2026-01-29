# Plan 1: Repository Integration

**Status:** 🔴 Not Started
**Priority:** Critical
**Estimated Duration:** 20-30 minutes

## Overview

Update your existing Container Manager Project to use the production-ready docker-compose.yml and .env configuration from this repository. This ensures your infrastructure matches the documented setup and makes future updates easier.

## Prerequisites

- ✅ Existing Container Manager Project running
- ✅ This repository cloned/accessible
- ✅ GitHub PAT available (same one currently in use)
- ✅ Access to DSM Container Manager UI

## Current State

**Existing Setup:**
- Container Manager Project with docker-compose.yml
- Configuration: Embedded in docker-compose.yml or passed via UI
- Project path: `/volume1/docker/github-runner/` (likely)
- Working correctly with current workflows

**Target State:**
- Same Container Manager Project
- Updated: docker-compose.yml from this repository
- Configuration: Separated into `.env` file
- Same functionality, cleaner separation
- Ready for monitoring integration (Plan 2 (Monitoring Setup))

## Step 1: Backup Current Configuration (5 minutes)

### Tasks

1. **Export current Container Manager Project settings:**
   - Open DSM → Container Manager
   - Find your github-runner project
   - Note current settings (container name, volumes, environment variables)
   - Screenshot the configuration (optional but helpful)

2. **Backup current docker-compose.yml:**
   ```bash
   # SSH into Synology
   ssh admin@<your-nas-ip>

   # Navigate to project directory (adjust path if different)
   cd /volume1/docker/github-runner

   # Backup existing config
   cp docker-compose.yml docker-compose.yml.backup
   cp .env .env.backup 2>/dev/null || echo "No .env file yet"

   # List current files
   ls -la
   ```

3. **Verify runner is working:**
   - Check GitHub: Settings → Actions → Runners
   - Should show "Idle" or currently running a job
   - Note runner name and labels

**Verification:**
- [ ] Current config backed up
- [ ] Runner visible in GitHub
- [ ] Container Manager Project accessible

## Step 2: Prepare New Configuration (10 minutes)

### Tasks

1. **Copy new files to NAS:**
   ```bash
   # From your local machine
   cd ~/src/andrelin/synology-github-runner

   # Copy new docker-compose.yml (don't overwrite yet)
   scp docker-compose.yml admin@<your-nas-ip>:/volume1/docker/github-runner/docker-compose.yml.new

   # Copy .env.example
   scp .env.example admin@<your-nas-ip>:/volume1/docker/github-runner/
   ```

2. **Create .env file with your actual configuration:**
   ```bash
   # SSH into Synology
   ssh admin@<your-nas-ip>
   cd /volume1/docker/github-runner

   # Create .env from example
   cp .env.example .env

   # Edit .env with your actual values
   nano .env
   ```

   **Required values (use your current settings):**
   ```bash
   # Repository
   REPO_URL=https://github.com/your-username/your-repo

   # GitHub PAT (same token currently in use)
   GITHUB_PAT=ghp_your_actual_token_here

   # Runner settings (match current)
   RUNNER_NAME=synology-runner
   RUNNER_GROUP=default
   LABELS=self-hosted,Linux,X64,synology,general

   # Resource limits (match current allocation)
   RUNNER_CPUS=1.5
   RUNNER_MEMORY=5G
   RUNNER_CPU_SHARES=1536

   # Build tool settings
   GRADLE_OPTS=-Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:MaxMetaspaceSize=512m
   GRADLE_WORKERS=2
   ```

3. **Review new docker-compose.yml:**
   ```bash
   # Compare new vs old
   diff docker-compose.yml.backup docker-compose.yml.new

   # Key differences should be:
   # - Uses .env file for configuration
   # - Security hardening (read-only, tmpfs, cap_drop)
   # - Health checks
   # - Proper volume mappings
   ```

**Verification:**
- [ ] docker-compose.yml.new on NAS
- [ ] .env file created with actual values
- [ ] Reviewed differences

## Step 3: Update Container Manager Project (10 minutes)

### Tasks

1. **Stop the current project:**
   - Open DSM → Container Manager → Project
   - Find your github-runner project
   - Click **Action** → **Stop**
   - Wait for containers to stop (green "Stopped" status)

2. **Replace docker-compose.yml:**
   ```bash
   # SSH into Synology
   ssh admin@<your-nas-ip>
   cd /volume1/docker/github-runner

   # Replace with new version
   mv docker-compose.yml.new docker-compose.yml

   # Verify .env is present
   ls -la .env
   ```

3. **Update project in Container Manager:**

   **Option A: Via UI (Recommended):**
   - In Container Manager → Project
   - Select your project
   - Click **Action** → **Build**
   - Container Manager will detect the changed docker-compose.yml
   - Review settings, then click **Done**
   - The project will rebuild with new configuration

   **Option B: Via Command Line:**
   ```bash
   cd /volume1/docker/github-runner
   docker-compose up -d --force-recreate
   ```

4. **Verify startup:**
   ```bash
   # Check container status
   docker-compose ps

   # View logs
   docker-compose logs -f

   # Look for: "Listening for Jobs"
   # Press Ctrl+C to exit logs
   ```

**Verification:**
- [ ] Project stopped successfully
- [ ] docker-compose.yml replaced
- [ ] Project rebuilt with new config
- [ ] Container started successfully
- [ ] Logs show "Listening for Jobs"

## Step 4: Test Integration (5 minutes)

### Tasks

1. **Verify runner registration:**
   - Check GitHub: Settings → Actions → Runners
   - Should show same runner name
   - Status: "Idle" (within 1-2 minutes)
   - Labels unchanged

2. **Verify resource limits:**
   ```bash
   # Check actual resource usage
   docker stats github-runner

   # Should respect limits from .env:
   # - CPU: ~1.5 cores max
   # - Memory: 5GB max
   ```

3. **Test with workflow (optional but recommended):**
   ```bash
   # Trigger a test workflow in Planechaser
   # Or wait for next automatic trigger
   ```

**Verification:**
- [ ] Runner appears in GitHub
- [ ] Resource limits working
- [ ] Optional: Test workflow succeeds

## Success Criteria

- [ ] docker-compose.yml from repository in use
- [ ] Configuration in .env file
- [ ] Container Manager Project running
- [ ] Runner registered and idle in GitHub
- [ ] Resource limits enforced
- [ ] Logs show no errors
- [ ] Backup of old config saved

## Rollback Plan

If something goes wrong:

```bash
# Stop new setup
cd /volume1/docker/github-runner
docker-compose down

# Restore backup
mv docker-compose.yml docker-compose.yml.failed
mv docker-compose.yml.backup docker-compose.yml

# Restart with old config
docker-compose up -d
```

Or use Container Manager UI:
- Stop project
- Replace docker-compose.yml with backup
- Build and start project

## Benefits After Integration

✅ **Configuration Management:**
- Settings in `.env` file (easy to update)
- docker-compose.yml version controlled
- Changes can be tested before applying

✅ **Security Hardening:**
- Read-only filesystem
- Minimal Linux capabilities
- tmpfs for sensitive data
- No-new-privileges flag

✅ **Better Monitoring:**
- Health checks built-in
- Proper logging configuration
- Ready for Plan 2 (Monitoring Setup) monitoring scripts

✅ **Easier Updates:**
- Pull new docker-compose.yml from repository
- Update .env as needed
- Rebuild project in Container Manager

## Next Steps

After Phase 6 completion:
1. ✅ Infrastructure using repository configuration
2. ✅ Settings managed via .env file
3. → Proceed to Plan 2 (Monitoring Setup): Monitoring Setup
4. → Deploy monitoring scripts
5. → Configure DSM Task Scheduler

## Related Files

- `docker-compose.yml` - Production container configuration
- `.env.example` - Configuration template
- `docs/04-MONITORING.md` - Monitoring setup guide (Plan 2 (Monitoring Setup))
- `plans/phase-7-monitoring-completion.md` - Next phase

## Notes

- Your Container Manager Project stays the same
- Just updating the configuration files
- No re-registration with GitHub needed
- Existing workspace and cache preserved
- Zero downtime if you wait for jobs to complete first
