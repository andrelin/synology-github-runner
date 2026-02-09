# Configuration Guide

Customize your GitHub self-hosted runner to match your hardware, workflows, and security requirements.

## Configuration File

All configuration is done through the `.env` file in the repository root.

**Location:** `/volume1/docker/synology-github-runner/.env`

**Create from template:**

```bash
cd /volume1/docker/synology-github-runner
cp .env.example .env
nano .env
```

## Required Configuration

### REPO_URL

**Description:** The GitHub repository or organization URL where the runner will be registered.

**Formats:**

- **Repository-level:** `https://github.com/owner/repository` (runner serves one repo)
- **Organization-level:** `https://github.com/owner` (runner serves all repos in org)

**Examples:**

```bash
# Repository-level (single repository)
REPO_URL=https://github.com/andrelin/planechaser

# Organization-level (all repositories in organization)
REPO_URL=https://github.com/andrelin
```

**Important:**

- ✅ Must include `https://`
- ✅ Must be exact URL (case-sensitive)
- ❌ Do not add trailing slash
- ❌ Do not use SSH format (git@github.com:...)

**Which should I use?**

- **Repository-level:** Use when runner is dedicated to one repository
- **Organization-level:** Use when multiple repositories need to share the runner

> **Note:** Organization-level runner setup requires organization admin permissions. See
> [Prerequisites](01-PREREQUISITES.md) for details.

### GITHUB_PAT

**Description:** GitHub Personal Access Token for runner authentication.

**Format:** `ghp_` followed by 36 characters

**Generate at:** https://github.com/settings/tokens

**Required scopes (repository-level):**

- ✅ `repo` (full control of private repositories)
- ✅ `workflow` (update GitHub Action workflows)

**Required scopes (organization-level):**

- ✅ `repo` (full control of private repositories)
- ✅ `workflow` (update GitHub Action workflows)
- ✅ `admin:org` → `manage_runners:org` (manage organization runners)

**Example:**

```bash
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Security best practices:**

- ✅ Store in password manager (1Password, Bitwarden)
- ✅ Set expiration date (90 days recommended)
- ✅ Rotate regularly
- ✅ Revoke if compromised
- ❌ Never commit to git
- ❌ Never share publicly

**Troubleshooting:**

- If runner won't register, verify token hasn't expired
- Check token has correct scopes
- Generate new token if in doubt

## Optional Configuration

### RUNNER_NAME

**Description:** Name displayed in GitHub UI for this runner.

**Default:** `synology-general-runner`

**Examples:**

```bash
# Descriptive names
RUNNER_NAME=synology-ds920-prod
RUNNER_NAME=nas-build-server-01
RUNNER_NAME=home-runner

# Project-specific
RUNNER_NAME=planechaser-synology
RUNNER_NAME=myapp-nas-runner
```

**Best practices:**

- Use descriptive names if you have multiple runners
- Include hardware/location info for identification
- Keep it concise (shows in GitHub UI)

### LABELS

**Description:** Comma-separated labels for targeting this runner in workflows.

**Default:** `self-hosted,linux,synology,general`

**Format:** Comma-separated, no spaces

**Examples:**

```bash
# Add custom labels for workflow targeting
LABELS=self-hosted,linux,synology,kotlin,docker,gradle

# Specialized runner
LABELS=self-hosted,linux,high-memory,gpu

# Project-specific
LABELS=self-hosted,linux,planechaser,mobile-builds
```

**Usage in workflows:**

```yaml
jobs:
  build:
    runs-on: [self-hosted, kotlin, gradle]  # Targets runners with these labels
```

**Built-in labels (automatically added by GitHub):**

- `self-hosted` - All self-hosted runners
- `Linux` - Runner OS
- `X64` - Architecture

**When to add custom labels:**

- ✅ Specialize runners for specific projects
- ✅ Identify hardware capabilities (high-memory, gpu, fast-disk)
- ✅ Organize multiple runners
- ✅ Target specific tech stacks (kotlin, python, node)

## Resource Limits

### RUNNER_MEMORY

**Description:** Maximum memory the container can use.

**Default:** `5g` (5 gigabytes)

**Format:** Number + unit (`g` for gigabytes, `m` for megabytes)

**Examples:**

```bash
# Minimal (tight on RAM)
RUNNER_MEMORY=3g

# Standard (2-core/8GB NAS)
RUNNER_MEMORY=5g

# Generous (4-core/16GB NAS)
RUNNER_MEMORY=10g

# High-memory builds
RUNNER_MEMORY=12g
```

**How to choose:**

| Your NAS RAM | Recommended Setting | Notes |
| ------------ | ------------------- | ----- |
| 8 GB | `RUNNER_MEMORY=5g` | Leave 3GB for DSM + other services |
| 16 GB | `RUNNER_MEMORY=10g` | Leave 6GB for DSM + other services |
| 32 GB | `RUNNER_MEMORY=20g` | Leave 12GB for DSM + other services |

**Formula:** Allocate ~60-70% of total RAM to runner, leaving rest for DSM and other services.

**Symptoms of too low:**

- Workflows fail with OOM (Out of Memory) errors
- Build processes killed unexpectedly
- Gradle/npm builds fail

**Symptoms of too high:**

- DSM becomes slow/unresponsive
- Other Docker containers crash
- NAS services fail

### RUNNER_CPU_SHARES

**Description:** CPU priority for the runner container (relative weight).

**Default:** `1536` (higher than default 1024)

**Range:** `0` to `2048`

**How it works:**

- Higher number = higher priority when CPU is contended
- Doesn't limit CPU usage, only sets priority
- All containers share CPU proportionally based on their shares

**Examples:**

```bash
# Normal priority (same as other containers)
RUNNER_CPU_SHARES=1024

# Higher priority (default - recommended)
RUNNER_CPU_SHARES=1536

# Highest priority (builds take precedence)
RUNNER_CPU_SHARES=2048

# Lower priority (background builds)
RUNNER_CPU_SHARES=512
```

**When to adjust:**

- ✅ Set high (1536-2048) if builds are critical
- ✅ Set low (512-1024) if runner is secondary to other services
- ✅ Keep default (1536) for balanced performance

**Note:** This doesn't limit CPU cores - runner can still use all available cores.

### TMPFS_TMP_SIZE and TMPFS_RUN_SIZE

**Description:** Size of in-memory temporary storage for `/tmp` and `/run`.

**Defaults:**

```bash
TMPFS_TMP_SIZE=1g
TMPFS_RUN_SIZE=512m
```

**What is tmpfs:**

- In-memory filesystem (very fast)
- Used for temporary files during builds
- Cleared on container restart
- Doesn't persist to disk

**When to increase:**

- ✅ Workflows create many temporary files
- ✅ Build processes need temp space
- ✅ Seeing "No space left on device" for /tmp

**Examples:**

```bash
# Standard (default)
TMPFS_TMP_SIZE=1g
TMPFS_RUN_SIZE=512m

# Large temporary needs
TMPFS_TMP_SIZE=2g
TMPFS_RUN_SIZE=1g

# Minimal (save RAM)
TMPFS_TMP_SIZE=512m
TMPFS_RUN_SIZE=256m
```

**Note:** tmpfs uses RAM, so larger sizes reduce available memory for builds.

## Build Tool Configuration

### GRADLE_OPTS

**Description:** JVM options for Gradle builds (Java/Kotlin/Android projects).

**Default:** `-Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200`

**Components:**

- `-Xmx3g` - Maximum heap memory (3 gigabytes)
- `-XX:+UseG1GC` - Use G1 garbage collector (better for large heaps)
- `-XX:MaxGCPauseMillis=200` - Target max GC pause time (200ms)

**How to tune `-Xmx` (heap memory):**

| RUNNER_MEMORY | Recommended GRADLE_OPTS |
| ------------- | ----------------------- |
| 3g | `-Xmx1.5g -XX:+UseG1GC -XX:MaxGCPauseMillis=200` |
| 5g | `-Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200` |
| 8g | `-Xmx5g -XX:+UseG1GC -XX:MaxGCPauseMillis=200` |
| 10g | `-Xmx6g -XX:+UseG1GC -XX:MaxGCPauseMillis=200` |

**Rule of thumb:** Set `-Xmx` to ~60% of `RUNNER_MEMORY`

**Examples:**

```bash
# Conservative (tight memory)
GRADLE_OPTS=-Xmx2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200

# Standard (default)
GRADLE_OPTS=-Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200

# High-memory builds
GRADLE_OPTS=-Xmx6g -XX:+UseG1GC -XX:MaxGCPauseMillis=200

# Additional optimizations
GRADLE_OPTS=-Xmx5g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:MaxMetaspaceSize=512m
```

**When to adjust:**

- ✅ Gradle builds failing with OOM
- ✅ Very large Kotlin/Android projects
- ✅ Multi-module builds

**Not using Gradle?** You can remove this variable or leave it as-is (doesn't affect non-Gradle workflows).

## Configuration Examples

### Minimal Setup (2-core/8GB NAS)

**Scenario:** Basic workflows, tight on resources, shared NAS

```bash
# Required
REPO_URL=https://github.com/your-username/your-repo
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Optional (resource-conservative)
RUNNER_NAME=synology-ds220-runner
LABELS=self-hosted,linux,synology,basic
RUNNER_MEMORY=4g
RUNNER_CPU_SHARES=1024
TMPFS_TMP_SIZE=512m
TMPFS_RUN_SIZE=256m
GRADLE_OPTS=-Xmx2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
```

### Standard Setup (4-core/8GB NAS)

**Scenario:** Balanced configuration, most common setup

```bash
# Required
REPO_URL=https://github.com/your-username/your-repo
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Optional (defaults)
RUNNER_NAME=synology-general-runner
LABELS=self-hosted,linux,synology,general
RUNNER_MEMORY=5g
RUNNER_CPU_SHARES=1536
TMPFS_TMP_SIZE=1g
TMPFS_RUN_SIZE=512m
GRADLE_OPTS=-Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
```

### High-Performance Setup (4-core/16GB NAS)

**Scenario:** Dedicated build server, heavy workflows, plenty of RAM

```bash
# Required
REPO_URL=https://github.com/your-username/your-repo
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Optional (high-performance)
RUNNER_NAME=synology-build-server
LABELS=self-hosted,linux,synology,high-memory,kotlin,gradle,docker
RUNNER_MEMORY=10g
RUNNER_CPU_SHARES=2048
TMPFS_TMP_SIZE=2g
TMPFS_RUN_SIZE=1g
GRADLE_OPTS=-Xmx6g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
```

### Kotlin Multiplatform (Android/iOS/Web)

**Scenario:** Large Kotlin project with multiple targets

```bash
# Required
REPO_URL=https://github.com/your-username/planechaser
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Optional (Kotlin-optimized)
RUNNER_NAME=planechaser-synology
LABELS=self-hosted,linux,synology,kotlin,multiplatform,android,gradle
RUNNER_MEMORY=8g
RUNNER_CPU_SHARES=1536
TMPFS_TMP_SIZE=1g
TMPFS_RUN_SIZE=512m
GRADLE_OPTS=-Xmx5g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:MaxMetaspaceSize=512m
```

### Docker-Heavy Builds

**Scenario:** Workflows that build many Docker images

```bash
# Required
REPO_URL=https://github.com/your-username/your-repo
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Optional (Docker-optimized)
RUNNER_NAME=synology-docker-builder
LABELS=self-hosted,linux,synology,docker,containers
RUNNER_MEMORY=8g
RUNNER_CPU_SHARES=2048
TMPFS_TMP_SIZE=2g  # Docker builds use /tmp
TMPFS_RUN_SIZE=1g
GRADLE_OPTS=-Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
```

## Applying Configuration Changes

After editing `.env`, you must restart the container:

### Via Container Manager UI

1. Open **Container Manager**
2. Go to **Project** → `github-runner`
3. Click **Build** button
4. Container Manager recreates container with new config

### Via SSH

```bash
cd /volume1/docker/synology-github-runner
docker-compose down
docker-compose up -d
```

### Verify Changes

```bash
# Check container is running
docker ps | grep github-runner

# View current resource limits
docker inspect github-runner | grep -A 5 "Memory"

# Check logs
docker-compose logs -f
```

## Security Configuration

The docker-compose.yml includes security hardening by default. These are **not** configurable via `.env` but you
can edit `docker-compose.yml` if needed.

### Current Security Settings

```yaml
security_opt:
  - no-new-privileges:true  # Prevents privilege escalation

cap_drop:
  - ALL  # Drops all Linux capabilities

cap_add:  # Only adds what's needed
  - CHOWN
  - SETGID
  - SETUID
  - DAC_OVERRIDE

tmpfs:  # In-memory temp storage (secure)
  - /tmp
  - /run
```

**These settings provide:**

- ✅ Minimal privilege principle
- ✅ No privilege escalation
- ✅ Reduced attack surface
- ✅ Secure temporary storage

**Do not modify unless you know what you're doing.** See [Security Guide](07-SECURITY.md) for more details.

## Troubleshooting Configuration

### Container won't start after config change

**Problem:** Changed `.env`, now container shows "Exited"

**Solution:**

1. Check logs: `docker-compose logs`
2. Common issues:
   - Invalid memory format (use `5g` not `5GB`)
   - REPO_URL missing or malformed
   - GITHUB_PAT expired or invalid
3. Restore previous working .env
4. Make one change at a time

### Workflows fail with OOM (Out of Memory)

**Problem:** Builds fail with "Out of memory" errors

**Solution:**

1. Increase `RUNNER_MEMORY`:

   ```bash
   RUNNER_MEMORY=8g  # Increase from 5g
   ```

2. Increase `GRADLE_OPTS` if using Gradle:

   ```bash
   GRADLE_OPTS=-Xmx5g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
   ```

3. Check total NAS memory: Control Panel → Resource Monitor
4. Rebuild container: Container Manager → Project → Build

### Workflows are slow

**Problem:** Builds take longer than expected

**Solution:**

1. Increase CPU priority:

   ```bash
   RUNNER_CPU_SHARES=2048
   ```

2. Check if other services are competing for resources
3. Monitor during builds: Control Panel → Resource Monitor
4. Consider adding more RAM to NAS
5. Optimize workflows: Use caching, parallel jobs

### Runner not appearing with custom labels

**Problem:** Can't target runner with custom labels in workflow

**Solution:**

1. Verify labels in .env:

   ```bash
   LABELS=self-hosted,linux,synology,your-label
   ```

2. Rebuild container to apply labels
3. Check runner in GitHub: Settings → Actions → Runners
4. Use labels in workflow:

   ```yaml
   runs-on: [self-hosted, your-label]
   ```

## Best Practices

### Configuration Management

- ✅ Keep `.env` file backed up (securely)
- ✅ Document your settings (comments in .env)
- ✅ Version control `.env.example` (not `.env`)
- ✅ Use password manager for GITHUB_PAT
- ✅ Review settings quarterly

### Resource Tuning

- ✅ Start with defaults, tune as needed
- ✅ Monitor resource usage: Container Manager
- ✅ Leave headroom for DSM and other services
- ✅ Test after configuration changes
- ✅ Keep GRADLE_OPTS ~60% of RUNNER_MEMORY

### Security

- ✅ Secure .env file: `chmod 600 .env`
- ✅ Rotate GITHUB_PAT every 90 days
- ✅ Use minimal token scopes (repo + workflow)
- ✅ Never commit .env to git
- ✅ Monitor runner activity in GitHub

## Next Steps

- [Monitoring Guide](04-MONITORING.md) - Monitor resource usage and health
- [Workflows Guide](08-WORKFLOWS.md) - Optimize workflows for your setup
- [Security Guide](07-SECURITY.md) - Additional security hardening
- [Troubleshooting Guide](05-TROUBLESHOOTING.md) - Fix common issues

---

**Need help?** See [Troubleshooting Guide](05-TROUBLESHOOTING.md) or [open an issue](https://github.com/andrelin/synology-github-runner/issues)
