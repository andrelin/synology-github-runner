# Maintenance Guide

Keep your GitHub self-hosted runner healthy, updated, and running efficiently.

## Maintenance Schedule

### Weekly Tasks (5 minutes)

- [ ] Check runner status in GitHub (Settings → Actions → Runners)
- [ ] Review recent workflow failures
- [ ] Check disk space: `df -h /volume1`

### Monthly Tasks (15 minutes)

- [ ] Update runner Docker image
- [ ] Clean Docker cache
- [ ] Review and clean logs
- [ ] Check for DSM updates
- [ ] Verify GitHub PAT expiration date

### Quarterly Tasks (30 minutes)

- [ ] Rotate GitHub Personal Access Token
- [ ] Review and update resource limits
- [ ] Audit workflow performance
- [ ] Backup configuration
- [ ] Review security settings

### As Needed

- [ ] Update docker-compose.yaml (when new features released)
- [ ] Increase disk space (when <20% free)
- [ ] Tune performance (if builds are slow)

## Updating the Runner

### Pull and Update

The project folder is a clone of this repository, and the runner image is published from its `Dockerfile` to
`ghcr.io/andrelin/synology-github-runner`; base image updates arrive as commits here and as new images there. The NAS
keeps running the image it last pulled until you update. Update while the runner is idle:

```bash
ssh admin@<your-nas-ip>
cd /volume1/docker/synology-github-runner
git pull                    # this repository's fixes
sudo docker compose pull    # the newest published runner image
sudo docker compose up -d   # recreate the container from it
```

`RUNNER_IMAGE_TAG` in `.env` picks the image: unset or `latest` follows `main`, and a `sha-` tag pins one build.

**Check the result:**

```bash
# Verify it's running
docker ps | grep github-runner

# Check logs for successful startup
docker-compose logs -f
```

**Expected output:**

```text
✓ Runner successfully configured
✓ Runner listener started successfully
```

**Verify in GitHub:**

- Settings → Actions → Runners
- Your runner should show as "Idle" (green)

### Update Repository Configuration

When new features or fixes are released in this repository:

**Pull updates:**

```bash
cd /volume1/docker/synology-github-runner

# Check for updates
git fetch origin main

# Review changes
git log HEAD..origin/main --oneline

# Pull updates
git pull origin main
```

**Apply changes:**

```bash
# Review what changed
git diff HEAD~1

# If docker-compose.yaml changed, restart container
docker-compose down
docker-compose up -d

# If only docs changed, no restart needed
```

**Preserve your settings:**

- `.env` file is gitignored (your secrets are safe)
- `workspace/` and `cache/` are gitignored (preserved)
- Custom modifications to `docker-compose.yaml` may be overwritten

### Update DSM and Container Manager

Keep Synology software up to date:

**DSM updates:**

1. Control Panel → Update & Restore
2. Check for DSM updates
3. Download and install
4. Restart NAS if required

**Container Manager updates:**

1. Package Center → Installed
2. Find "Container Manager"
3. Update if available

**After updates:**

```bash
# Verify runner still works
docker ps | grep github-runner

# Restart if needed
docker-compose down
docker-compose up -d
```

## Log Management

### Viewing Logs

**Via Container Manager:**

1. Container Manager → Container
2. Select `github-runner`
3. Click **Details** → **Log** tab

**Via SSH:**

```bash
cd /volume1/docker/synology-github-runner

# View recent logs
docker-compose logs --tail=100

# Follow logs in real-time
docker-compose logs -f

# Search logs
docker-compose logs | grep -i error

# Save logs to file
docker-compose logs > runner-logs-$(date +%Y%m%d).txt
```

### Log Rotation

Docker handles log rotation automatically, but you can configure limits:

**Edit docker-compose.yaml:**

```yaml
services:
  github-runner:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"    # Max log file size
        max-file: "3"      # Keep 3 log files
```

**Apply changes:**

```bash
docker-compose down
docker-compose up -d
```

### Cleaning Old Logs

**Manual cleanup:**

```bash
# Clear container logs (careful - erases all logs)
docker-compose down
rm -f /var/lib/docker/containers/*/*-json.log
docker-compose up -d
```

**Better approach:** Configure log rotation (above) to prevent logs from growing too large.

## Disk Space Management

### Monitor Disk Usage

**Overall disk usage:**

```bash
df -h /volume1
```

**Docker disk usage:**

```bash
docker system df
```

**Workspace and cache:**

```bash
du -sh /volume1/docker/synology-github-runner/workspace
du -sh /volume1/docker/synology-github-runner/cache
```

### Clean Up Docker

**Remove unused Docker data:**

```bash
# Safe cleanup (removes stopped containers, unused images)
docker system prune -f

# Aggressive cleanup (also removes unused volumes)
docker system prune -af --volumes

# Clean specific items
docker image prune -af    # Remove unused images
docker container prune -f # Remove stopped containers
docker volume prune -f    # Remove unused volumes
```

**Scheduled cleanup:**

Create a monthly cron job:

```bash
# Edit crontab
crontab -e

# Add monthly cleanup at 3 AM
0 3 1 * * docker system prune -af --filter "until=168h"
```

### Clean Workspace and Cache

**Workspace cleanup:**

```bash
cd /volume1/docker/synology-github-runner

# Safe - rebuilt on next workflow run
rm -rf workspace/*
```

**Cache cleanup:**

```bash
# Warning: Next build will be slower (needs to rebuild cache)
rm -rf cache/*

# Selective cleanup (Gradle only)
rm -rf cache/gradle/*

# Selective cleanup (npm only)
rm -rf cache/npm/*
```

**When to clean:**

- Disk space < 20% free
- Builds failing due to disk space
- Cache corruption suspected
- After major project changes

### Expand Storage

If consistently running out of space:

**Option 1: Clean up other data on NAS**

- Review and delete old files
- Move large files to external storage
- Compress old backups

**Option 2: Add storage volume**

- Install additional hard drive
- Create new volume
- Move runner to new volume:

  ```bash
  # Copy to new location
  cp -r /volume1/docker/synology-github-runner /volume2/docker/

  # Update path in Container Manager
  # Or update docker-compose.yaml paths
  ```

**Option 3: External storage**

- Mount external drive
- Move `cache/` to external storage
- Update docker-compose.yaml volume paths

## Backup and Restore

### What to Backup

**Critical (backup regularly):**

- ✅ `.env` file (contains secrets)
- ✅ `docker-compose.yaml` (if customized)
- ✅ Custom scripts or configurations

**Optional (nice to have):**

- ✅ `cache/` directory (speeds up next build, but can rebuild)

**No need to backup:**

- ❌ `workspace/` (temporary, rebuilt each run)
- ❌ Docker images (can re-pull)
- ❌ Container data (ephemeral)

### Backup Procedure

**Secure backup of .env:**

```bash
cd /volume1/docker/synology-github-runner

# Copy .env to secure location
cp .env ~/backup/.env.github-runner.$(date +%Y%m%d)

# Set restrictive permissions
chmod 600 ~/backup/.env.github-runner.*

# Better: Store in password manager (1Password, Bitwarden)
# Or encrypt before storing:
gpg -c .env  # Creates .env.gpg
```

**Backup docker-compose.yaml:**

```bash
cp docker-compose.yaml ~/backup/docker-compose.yaml.$(date +%Y%m%d)
```

**Backup entire configuration:**

```bash
# Create tarball (excludes workspace/cache)
tar -czf ~/backup/runner-config-$(date +%Y%m%d).tar.gz \
  --exclude='workspace' \
  --exclude='cache' \
  --exclude='.git' \
  .env docker-compose.yaml scripts/
```

### Restore Procedure

**Restore from backup:**

```bash
# Navigate to runner directory
cd /volume1/docker/synology-github-runner

# Restore .env
cp ~/backup/.env.github-runner.YYYYMMDD .env
chmod 600 .env

# Restore docker-compose.yaml
cp ~/backup/docker-compose.yaml.YYYYMMDD docker-compose.yaml

# Restart container
docker-compose down
docker-compose up -d
```

**Full restore from tarball:**

```bash
# Extract backup
cd /volume1/docker
tar -xzf ~/backup/runner-config-YYYYMMDD.tar.gz

# Recreate workspace and cache
cd synology-github-runner
mkdir -p workspace cache

# Start container
docker-compose up -d
```

## Health Monitoring

### Check Runner Status

**In GitHub:**

1. Go to repository → **Settings → Actions → Runners**
2. Check status:
   - 🟢 **Idle** - Ready for jobs (good)
   - 🔵 **Active** - Running a job (good)
   - 🔴 **Offline** - Not connected (bad - investigate)

**Via Container Manager:**

1. Container Manager → Container
2. Find `github-runner`
3. Status should be: **Running** (green play icon)
4. Check CPU/Memory graphs

**Via SSH:**

```bash
# Check if container is running
docker ps | grep github-runner

# Check resource usage
docker stats github-runner --no-stream

# Check logs for errors
docker-compose logs --tail=50 | grep -i error
```

### Performance Monitoring

**Monitor during workflow execution:**

```bash
# Watch resources in real-time
docker stats github-runner

# Check NAS resources
# DSM → Resource Monitor → Performance
```

**Check historical performance:**

- Container Manager → Container → github-runner → Details
- View CPU and Memory graphs

**Identify bottlenecks:**

- **High CPU** - Increase `RUNNER_CPU_SHARES`
- **High Memory** - Increase `RUNNER_MEMORY`
- **Disk I/O** - Consider SSD cache or faster drives

### Automated Health Checks

**Use monitoring script:**

```bash
cd /volume1/docker/synology-github-runner

# Run health check (what the scheduled task would report)
sudo env STATE_FILE=$(mktemp) LOG_FILE=$(mktemp) ALERT_AFTER_FAILURES=1 \
  bash scripts/monitoring/runner-health-check.sh

# View dashboard
sudo bash scripts/monitoring/runner-dashboard.sh
```

Schedule the health check with DSM Task Scheduler as the [Monitoring Guide](04-monitoring.md) describes; it emails
once per incident.

## Security Maintenance

### Rotate GitHub Personal Access Token

**Every 90 days (recommended):**

1. **Generate new token:**
   - Go to: https://github.com/settings/tokens
   - Click **Generate new token (classic)**
   - Name: `Synology Runner - YYYY-MM-DD`
   - Expiration: 90 days
   - Scopes: `repo` + `workflow`
   - Click **Generate token**
   - **Copy token immediately**

2. **Update .env:**

   ```bash
   cd /volume1/docker/synology-github-runner
   nano .env
   # Update GITHUB_PAT=ghp_new_token
   # Save (Ctrl+X, Y, Enter)
   ```

3. **Restart container:**

   ```bash
   docker-compose down
   docker-compose up -d
   ```

4. **Verify in GitHub:**
   - Settings → Actions → Runners
   - Runner should show as "Idle"

5. **Revoke old token:**
   - GitHub → Settings → Developer settings → Personal access tokens
   - Find old token, click **Delete**

6. **Set reminder for next rotation:**
   - Add to calendar: "Rotate GitHub Runner Token" in 90 days

### Review Security Settings

**Quarterly security review:**

1. **Check container security:**

   ```bash
   docker inspect github-runner | grep -A 10 SecurityOpt
   # Should show: no-new-privileges:true
   ```

2. **Verify .env permissions:**

   ```bash
   ls -la .env
   # Should show: -rw------- (600 permissions)
   ```

3. **Check for unauthorized access:**
   - Review GitHub Actions logs for unexpected runs
   - Check runner activity in GitHub

4. **Update security patches:**

   ```bash
   # Pull the latest runner image (includes base image security updates)
   cd /volume1/docker/synology-github-runner
   git pull
   sudo docker compose pull
   sudo docker compose up -d
   ```

5. **Review access logs:**

   ```bash
   # Check who's accessing via SSH
   last -20

   # Review Docker events
   docker events --since 24h
   ```

## Performance Tuning

### Optimize Resource Allocation

**Review current usage:**

```bash
# During a workflow run
docker stats github-runner

# Check if resources are underutilized or maxed out
```

**Adjust based on patterns:**

**If consistently < 50% memory used:**

```bash
# Reduce memory allocation
nano .env
# RUNNER_MEMORY=4g  # Down from 5g
```

**If hitting memory limits:**

```bash
# Increase memory
nano .env
# RUNNER_MEMORY=8g  # Up from 5g
# GRADLE_OPTS=-Xmx5g ...  # Up from -Xmx3g
```

**If CPU underutilized:**

```bash
# Lower priority to give resources to other services
nano .env
# RUNNER_CPU_SHARES=1024  # Down from 1536
```

**After changes:**

```bash
docker-compose down
docker-compose up -d
```

### Optimize Workflow Performance

**Enable caching:**

```yaml
- uses: actions/setup-node@v6
  with:
    cache: 'npm'
```

**Use sequential jobs:**

```yaml
jobs:
  test:
    needs: [build]  # Wait for build to finish
```

**Clean cache periodically:**

```bash
# If builds are getting slower
rm -rf cache/*
```

See [Workflow Examples](../examples/workflows/) for optimization patterns.

## Troubleshooting Common Maintenance Issues

### Runner Stops Working After Update

**Rollback procedure:**

```bash
# Pull previous image version
docker pull myoung34/github-runner:<previous-version>

# Or restore from backup
cp ~/backup/docker-compose.yaml.YYYYMMDD docker-compose.yaml

# Restart
docker-compose down
docker-compose up -d
```

### Disk Fills Up Quickly

**Identify culprit:**

```bash
# Find large files
du -h --max-depth=2 /volume1/docker/synology-github-runner | sort -h

# Check Docker usage
docker system df -v
```

**Solutions:**

- Clean Docker cache more frequently
- Reduce `cache/` size
- Move cache to external storage
- Increase workspace cleanup frequency

### Performance Degrades Over Time

**Common causes:**

- Cache corruption
- Log files growing
- Docker images accumulating
- Memory leaks (rare)

**Reset procedure:**

```bash
cd /volume1/docker/synology-github-runner

# Stop container
sudo docker compose down

# Clean everything
sudo docker system prune -af --volumes
sudo rm -rf /volume1/docker/github-runner/workspace/* /volume1/docker/github-runner/cache/*

# Start fresh
sudo docker compose pull
sudo docker compose up -d
```

## Maintenance Checklist

### Monthly Checklist

```text
[ ] Update runner Docker image
[ ] Clean Docker cache (docker system prune -af)
[ ] Check disk space (df -h)
[ ] Review failed workflows
[ ] Check GitHub PAT expiration
[ ] Review resource usage (docker stats)
[ ] Check for DSM updates
[ ] Review security logs
[ ] Backup .env file
```

### Quarterly Checklist

```text
[ ] Rotate GitHub Personal Access Token
[ ] Full security audit
[ ] Review and optimize resource allocation
[ ] Backup full configuration
[ ] Clean cache directory
[ ] Review workflow performance trends
[ ] Update documentation if needed
[ ] Check for repository updates
[ ] Test disaster recovery procedure
```

## Automated Maintenance Script

**Create maintenance script:**

```bash
#!/bin/bash
# /volume1/scripts/runner-maintenance.sh

set -euo pipefail

echo "Starting runner maintenance..."

# Updating the runner stays a manual step (see "Pull and Update"): recreating the
# container from a schedule would cut off whatever job is running

# Clean Docker
docker system prune -af --filter "until=168h"

# Check disk space
DISK_USAGE=$(df -h /volume1 | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "Warning: Disk usage at ${DISK_USAGE}%"
    # Clean cache
    rm -rf /volume1/docker/github-runner/cache/*
fi

echo "Maintenance complete!"
```

**Make executable:**

```bash
chmod +x /volume1/scripts/runner-maintenance.sh
```

**Schedule monthly:**

```bash
# Run first Sunday of month at 3 AM
0 3 1-7 * 0 /volume1/scripts/runner-maintenance.sh
```

## Getting Help

If you encounter issues during maintenance:

- [Troubleshooting Guide](05-troubleshooting.md)
- [FAQ](faq.md)
- [GitHub Issues](https://github.com/andrelin/synology-github-runner/issues)

---

**Regular maintenance keeps your runner healthy and performant!** 🛠️
