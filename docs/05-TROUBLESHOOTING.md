# Troubleshooting Guide

Common issues, diagnostic commands, and solutions for GitHub self-hosted runner on Synology NAS.

## Quick Diagnostic Commands

Run these commands to gather information when troubleshooting:

```bash
# SSH into your NAS
ssh admin@<your-nas-ip>
cd /volume1/docker/synology-github-runner

# Check container status
docker ps -a | grep github-runner

# View recent logs
docker-compose logs --tail=100

# Check resource usage
docker stats github-runner --no-stream

# Verify .env file
cat .env | grep -v "^#" | grep -v "^$"

# Check disk space
df -h /volume1

# Test GitHub connectivity
curl -I https://api.github.com
```

## Runner Not Appearing in GitHub

### Problem

Runner doesn't show up in GitHub repository settings (Settings → Actions → Runners).

### Symptoms

- Container is running but runner not listed in GitHub UI
- GitHub shows "No runners available"
- Workflows don't execute

### Diagnosis

**1. Check container logs:**
```bash
docker-compose logs -f | grep -i error
```

Look for:
- Authentication errors
- Registration failures
- Network errors

**2. Check container is actually running:**
```bash
docker ps | grep github-runner
# Should show: Up X minutes
```

**3. Verify GitHub token:**
```bash
# Check token is set in .env
grep GITHUB_PAT .env
# Should show: GITHUB_PAT=ghp_xxxxx...
```

### Solutions

**Invalid or Expired Token**

**Problem:** GitHub PAT is expired or has wrong scopes

**Fix:**
1. Generate new token: https://github.com/settings/tokens
2. Ensure scopes: `repo` + `workflow`
3. Update `.env`:
   ```bash
   nano .env
   # Update GITHUB_PAT=ghp_newtoken...
   ```
4. Restart container:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

**Incorrect Repository URL**

**Problem:** REPO_URL doesn't match actual repository

**Fix:**
1. Check current setting:
   ```bash
   grep REPO_URL .env
   ```
2. Verify format: `https://github.com/owner/repository`
3. Update if wrong:
   ```bash
   nano .env
   # Fix REPO_URL=https://github.com/correct/repo
   ```
4. Restart container

**Runner Already Registered**

**Problem:** Runner with same name already exists

**Fix:**
1. Check GitHub: Settings → Actions → Runners
2. Remove old/offline runner from GitHub UI
3. Restart container:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

**Network Connectivity Issues**

**Problem:** Cannot reach GitHub API

**Fix:**
1. Test connectivity:
   ```bash
   ping -c 3 github.com
   curl -I https://api.github.com
   ```
2. Check firewall: Control Panel → Security → Firewall
3. Check DNS: Control Panel → Network → General → DNS
4. Verify no proxy issues

## Container Won't Start

### Problem

Container shows status "Exited" immediately after starting.

### Symptoms

- `docker ps -a` shows container with "Exited (1)" status
- Container restarts continuously
- Logs show errors immediately

### Diagnosis

**Check exit code and logs:**
```bash
# View container status with exit code
docker ps -a | grep github-runner

# View full logs
docker-compose logs --tail=200

# Check specific errors
docker-compose logs 2>&1 | grep -i "error\|failed\|fatal"
```

### Solutions

**Missing .env File**

**Problem:** `.env` file doesn't exist or is empty

**Fix:**
```bash
# Check if .env exists
ls -la .env

# If missing, create from example
cp .env.example .env
nano .env
# Fill in REPO_URL and GITHUB_PAT

# Restart
docker-compose up -d
```

**Invalid Environment Variables**

**Problem:** Malformed variables in `.env`

**Fix:**
```bash
# Validate .env syntax
docker-compose config

# Common issues:
# - Missing quotes around values with spaces
# - Invalid memory format (use "5g" not "5GB")
# - Special characters in values

# Fix and restart
nano .env
docker-compose down
docker-compose up -d
```

**Insufficient Permissions**

**Problem:** Container can't access Docker socket or volumes

**Fix:**
```bash
# Check permissions on workspace/cache
ls -la workspace cache

# Fix ownership if needed
sudo chown -R admin:administrators workspace cache

# Check Docker socket permission
ls -la /var/run/docker.sock

# Restart container
docker-compose down
docker-compose up -d
```

**Port Conflict**

**Problem:** Required port already in use (rare, runner doesn't expose ports)

**Fix:**
```bash
# Check if something is using runner's resources
docker ps

# Remove conflicting container if needed
docker stop <conflicting-container>
```

## Out of Memory (OOM) Errors

### Problem

Workflows fail with "Out of memory" or "Killed" errors.

### Symptoms

- Jobs fail mid-execution
- Build processes terminated unexpectedly
- Container shows high memory usage
- Logs show "OOMKilled" or similar

### Diagnosis

**1. Check memory usage:**
```bash
# Current usage
docker stats github-runner --no-stream

# NAS total memory
free -h

# Check if other processes are consuming memory
top
```

**2. Check workflow logs:**
- Look for: "Out of memory", "Killed", "java.lang.OutOfMemoryError"

**3. Check container memory limit:**
```bash
docker inspect github-runner | grep -i memory
```

### Solutions

**Increase Container Memory**

**Fix:**
```bash
# Edit .env
nano .env

# Increase RUNNER_MEMORY
RUNNER_MEMORY=8g  # Up from 5g

# For Gradle builds, increase JVM heap too
GRADLE_OPTS=-Xmx5g -XX:+UseG1GC -XX:MaxGCPauseMillis=200

# Restart container
docker-compose down
docker-compose up -d
```

**Optimize Workflow**

**Fix in workflow file:**
```yaml
jobs:
  build:
    steps:
      - name: Build with memory limit
        run: ./gradlew build
        env:
          # Limit Gradle memory
          GRADLE_OPTS: "-Xmx3g -XX:MaxMetaspaceSize=512m"
          # Limit parallel workers
          ORG_GRADLE_PROJECT_org.gradle.workers.max: "2"
```

**Use Sequential Jobs (Orchestrator Pattern)**

Instead of parallel jobs competing for memory:
```yaml
jobs:
  test:
    needs: [build]  # Wait for build to finish first
```

See [orchestrator.yml example](../examples/workflows/orchestrator.yml)

**Free Up NAS Memory**

```bash
# Stop other non-essential containers
docker stop <other-container>

# Clear Docker cache
docker system prune -f

# Restart NAS if needed (releases memory leaks)
```

## Disk Space Issues

### Problem

"No space left on device" errors during builds.

### Symptoms

- Builds fail with disk space errors
- Docker can't pull images
- Workspace directory full

### Diagnosis

**Check disk usage:**
```bash
# Overall disk usage
df -h /volume1

# Docker disk usage
docker system df

# Workspace size
du -sh /volume1/docker/synology-github-runner/workspace
du -sh /volume1/docker/synology-github-runner/cache

# Find large files
find /volume1/docker/synology-github-runner -type f -size +100M
```

### Solutions

**Clean Docker System**

```bash
# Remove unused images, containers, volumes
docker system prune -af --volumes

# More aggressive cleanup
docker system prune -af
docker volume prune -f
```

**Clean Workspace**

```bash
cd /volume1/docker/synology-github-runner

# Safe to delete - rebuilt on next run
rm -rf workspace/*

# Clean cache (will slow next build)
rm -rf cache/*
```

**Expand Storage**

- Add more disk space to your NAS
- Move runner to volume with more space
- Use external storage for cache

## Slow Build Performance

### Problem

Builds take much longer than expected or timeout.

### Symptoms

- Jobs timeout after 30+ minutes
- Builds slower than GitHub-hosted runners
- High CPU/memory usage during builds

### Diagnosis

**Monitor resources during build:**
```bash
# Watch in real-time
docker stats github-runner

# Check NAS resource monitor
# DSM → Resource Monitor → Performance
```

**Check build logs for bottlenecks:**
- Long dependency downloads
- Slow compilation
- Test timeouts

### Solutions

**Increase CPU Priority**

```bash
# Edit .env
nano .env

# Increase CPU priority
RUNNER_CPU_SHARES=2048  # Up from 1536

# Restart
docker-compose down
docker-compose up -d
```

**Enable Dependency Caching**

In your workflow:
```yaml
- uses: actions/setup-node@v6
  with:
    cache: 'npm'  # Caches node_modules

- uses: actions/setup-java@v6
  with:
    cache: 'gradle'  # Caches Gradle dependencies
```

**Use Docker Layer Caching**

For Docker builds, see [docker-build.yml example](../examples/workflows/docker-build.yml)

**Optimize Gradle Builds**

```bash
# In .env file
GRADLE_OPTS=-Xmx5g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
```

In workflow:
```yaml
env:
  ORG_GRADLE_PROJECT_org.gradle.caching: "true"
  ORG_GRADLE_PROJECT_org.gradle.parallel: "true"
  ORG_GRADLE_PROJECT_org.gradle.workers.max: "2"
```

**Run Builds During Off-Peak Hours**

```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM daily
```

## Network Connectivity Issues

### Problem

Cannot connect to GitHub, Docker Hub, or package registries.

### Symptoms

- "Connection timed out" errors
- "Unable to reach host" errors
- Dependency downloads fail

### Diagnosis

**Test connectivity from container:**
```bash
# Test GitHub
docker exec github-runner curl -I https://github.com

# Test GitHub API
docker exec github-runner curl -I https://api.github.com

# Test Docker Hub
docker exec github-runner curl -I https://hub.docker.com

# Test DNS
docker exec github-runner nslookup github.com
```

**Test from NAS:**
```bash
ping -c 3 github.com
curl -I https://api.github.com
```

### Solutions

**DNS Issues**

**Fix:**
```bash
# Check DNS settings
# DSM → Control Panel → Network → General → DNS Server

# Try Google DNS: 8.8.8.8, 8.8.4.4
# Or Cloudflare DNS: 1.1.1.1, 1.0.0.1
```

**Firewall Blocking**

**Fix:**
```bash
# Check firewall rules
# DSM → Control Panel → Security → Firewall

# Ensure outbound HTTPS (443) is allowed
# Ensure outbound HTTP (80) is allowed
```

**Proxy Configuration**

If you use a proxy:
```bash
# Edit docker-compose.yml
nano docker-compose.yml

# Add to environment:
environment:
  - HTTP_PROXY=http://proxy:port
  - HTTPS_PROXY=http://proxy:port
  - NO_PROXY=localhost,127.0.0.1

# Restart
docker-compose down
docker-compose up -d
```

## Workflow Not Triggering

### Problem

Push commits but workflow doesn't start.

### Symptoms

- No workflow runs appear in Actions tab
- Manual trigger (workflow_dispatch) doesn't work
- Scheduled workflows don't run

### Diagnosis

**1. Check workflow file location:**
```bash
# Must be in .github/workflows/
ls -la .github/workflows/

# Check syntax
cat .github/workflows/your-workflow.yml
```

**2. Validate YAML syntax:**
- Use online YAML validator
- Check GitHub Actions tab for syntax errors

**3. Check workflow triggers:**
```yaml
on:
  push:
    branches: [main]  # Are you pushing to 'main'?
  pull_request:       # Are you creating PRs?
```

### Solutions

**Wrong Branch**

Workflow configured for `main` but you're pushing to `master` or `develop`:

**Fix in workflow:**
```yaml
on:
  push:
    branches: [main, master, develop]  # Add your branches
```

**Workflow Disabled**

**Fix:**
1. Go to repository → Actions tab
2. Find your workflow in the sidebar
3. Click "Enable workflow" if disabled

**Path Filters Too Restrictive**

```yaml
on:
  push:
    paths:
      - 'src/**'  # Only triggers if src/ files change
```

**Fix:** Remove or adjust path filters

**Syntax Errors in YAML**

**Fix:**
1. Check Actions tab for syntax error message
2. Use YAML validator
3. Common issues:
   - Wrong indentation (use 2 spaces)
   - Missing colons
   - Invalid characters

## Docker-in-Docker Bind Mount Errors

### Problem

Workflows that use Docker (Qodana, Trivy, container builds) fail with bind mount errors.

### Symptoms

```
Error response from daemon: invalid mount config for type "bind":
bind source path does not exist: /workspace/_temp/qodana/caches
```

Or similar errors mentioning:
- `/workspace/_temp/...`
- `/home/runner/work/...`
- `bind source path does not exist`

### Root Cause

When you run Docker inside the runner container (Docker-in-Docker), the inner Docker command talks to the **host Docker daemon** via `/var/run/docker.sock`. When the inner Docker tries to bind mount a path like `/workspace/_temp/qodana/caches`, the host Docker daemon looks for that path on the **host filesystem**, not inside the runner container.

**Example:**
- Runner container workspace: `/workspace` → maps to host: `/volume1/docker/github-runner/workspace`
- Qodana runs: `docker run -v /workspace/_temp/qodana/caches:/data/cache`
- Host Docker daemon looks for `/workspace/_temp/qodana/caches` on host → **doesn't exist!**

### Solution 1: Use Matching Paths (Recommended)

Configure the runner to use the same workspace path on both host and container.

**1. Update your `.env` file:**
```bash
# Add or update this line
RUNNER_WORKDIR=/volume1/docker/github-runner/workspace
```

**2. Restart the runner:**
```bash
docker-compose down
docker-compose up -d
```

**3. Verify the configuration:**
```bash
docker exec github-runner env | grep RUNNER_WORKDIR
# Should show: RUNNER_WORKDIR=/volume1/docker/github-runner/workspace
```

**How this works:**
- Host path: `/volume1/docker/github-runner/workspace`
- Container path: `/volume1/docker/github-runner/workspace` (same!)
- When inner Docker runs `docker run -v /volume1/docker/github-runner/workspace/_temp/...`, the host can find it

### Solution 2: Use Environment Variables in Workflows

For workflows that support it, use environment variables to specify cache paths:

```yaml
jobs:
  qodana:
    runs-on: [self-hosted, Linux, X64]
    steps:
      - uses: actions/checkout@v6

      - name: Qodana Scan
        uses: JetBrains/qodana-action@v2024.1
        with:
          # Use a path that exists on the host
          cache-dir: ${{ runner.workspace }}/qodana-cache
```

### Solution 3: Create Symlink (Workaround)

If you can't change `RUNNER_WORKDIR`, create a symlink on the host:

```bash
# SSH to NAS
ssh admin@<your-nas-ip>

# Create symlink
sudo ln -s /volume1/docker/github-runner/workspace /workspace

# Verify
ls -la /workspace
```

**⚠️ Warning:** This requires root access and may affect other containers.

### Verification

After applying Solution 1, test your Qodana workflow:

```bash
# Check runner configuration
docker exec github-runner env | grep RUNNER_WORKDIR

# Check workspace mount
docker inspect github-runner | grep -A 5 "Mounts"

# Check the path exists in container
docker exec github-runner ls -la /volume1/docker/github-runner/workspace
```

Then trigger your Qodana workflow and verify it completes without bind mount errors.

### Common Tools Affected

These tools commonly run Docker-in-Docker and may need this fix:
- **Qodana** - JetBrains code quality
- **Trivy** - Container security scanning
- **Docker buildx** - Multi-platform builds
- **docker-compose** (when run in workflows)
- **Container testing frameworks**

### Additional Notes

**Why not just use `/workspace`?**
- Synology's volume paths start with `/volume1/`
- Using a non-standard path helps avoid conflicts with other software
- It makes the configuration more explicit and Synology-specific

**Already updated docker-compose.yml?**
- The latest version (as of 2026-01-30) includes this fix by default
- Pull the latest changes: `git pull origin main`
- Update your `.env` file with `RUNNER_WORKDIR`

## Permission Errors

### Problem

Workflow fails with permission denied errors.

### Symptoms

- "Permission denied" when accessing files
- Cannot write to workspace
- Docker socket access denied

### Diagnosis

```bash
# Check workspace permissions
ls -la workspace/ cache/

# Check Docker socket
ls -la /var/run/docker.sock

# Check container user
docker exec github-runner whoami
docker exec github-runner id
```

### Solutions

**Fix Workspace Permissions**

```bash
cd /volume1/docker/synology-github-runner

# Fix ownership
sudo chown -R admin:administrators workspace cache

# Set proper permissions
chmod 755 workspace cache
```

**Docker Socket Access**

```bash
# Check Docker socket permission
ls -la /var/run/docker.sock

# If needed, add user to docker group (on NAS)
# This is already configured in docker-compose.yml
```

**Read-Only Filesystem**

If using custom security settings:
```yaml
# In docker-compose.yml - remove read_only if needed
# But this reduces security
```

## Log Analysis

### Finding Useful Logs

**Container logs:**
```bash
# Last 100 lines
docker-compose logs --tail=100

# Follow logs in real-time
docker-compose logs -f

# Search for errors
docker-compose logs 2>&1 | grep -i error

# Save logs to file
docker-compose logs > runner-logs.txt
```

**DSM System Logs:**
- DSM → Log Center → Container

**GitHub Actions Logs:**
- Repository → Actions → Click on workflow run → View job logs

### Common Log Messages

**"Runner listener started successfully"**
✅ Good - runner is working

**"Error: Cannot connect to GitHub"**
❌ Network/token issue - check connectivity and GITHUB_PAT

**"OOMKilled"**
❌ Out of memory - increase RUNNER_MEMORY

**"Permission denied"**
❌ File permission issue - check ownership

**"No space left on device"**
❌ Disk full - clean up Docker/workspace

## When to Ask for Help

If you've tried the solutions above and still have issues:

### Before Asking

1. **Collect diagnostic information:**
   ```bash
   # System info
   uname -a
   docker --version
   docker-compose --version

   # Container info
   docker ps -a | grep github-runner
   docker inspect github-runner > runner-inspect.txt

   # Logs
   docker-compose logs > runner-logs.txt

   # Resource usage
   docker stats github-runner --no-stream > stats.txt
   df -h > disk-usage.txt
   ```

2. **Check existing issues:**
   - Search: https://github.com/andrelin/synology-github-runner/issues

3. **Review documentation:**
   - [FAQ](FAQ.md)
   - [Configuration Guide](03-CONFIGURATION.md)
   - [Installation Guide](02-INSTALLATION.md)

### How to Ask

**Open an issue** with:
- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Diagnostic information (logs, stats, config)
- What you've already tried

**Example:**
```markdown
**Problem:** Runner not appearing in GitHub

**Environment:**
- Synology: DS920+ with 8GB RAM
- DSM: 7.2
- Docker: 20.10.23

**Steps to reproduce:**
1. Followed installation guide
2. Created .env with correct REPO_URL and GITHUB_PAT
3. Started with docker-compose up -d
4. Container running but no runner in GitHub

**Logs:**
[Attach runner-logs.txt]

**Already tried:**
- Verified GITHUB_PAT is valid
- Checked REPO_URL format
- Restarted container multiple times
```

## Quick Reference

| Problem | Quick Fix |
|---------|-----------|
| Runner not in GitHub | Check token & REPO_URL, restart container |
| Container exited | Check logs, verify .env file |
| Out of memory | Increase RUNNER_MEMORY in .env |
| Disk full | `docker system prune -af`, clean workspace |
| Slow builds | Increase CPU_SHARES, enable caching |
| Network errors | Check DNS, firewall, test connectivity |
| Permission denied | Fix workspace ownership/permissions |
| Workflow not triggering | Check branch, validate YAML syntax |

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Documentation](https://docs.docker.com/)
- [Synology Knowledge Base](https://kb.synology.com/)
- [Project Issues](https://github.com/andrelin/synology-github-runner/issues)

---

**Still stuck?** [Open an issue](https://github.com/andrelin/synology-github-runner/issues/new) with diagnostic info!
