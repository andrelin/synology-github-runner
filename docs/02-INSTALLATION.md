# Installation Guide

## Overview

This guide shows how to install the GitHub self-hosted runner on your Synology NAS using **Container Manager
Projects**. This method uses the Synology UI for container management while keeping your configuration in sync with
the repository.

**Estimated time:** 15-20 minutes

## Prerequisites

Before starting, ensure you have:

- ✅ **Synology NAS** with DSM 7.0 or later
- ✅ **Container Manager** installed (from Package Center)
- ✅ **Git Server** installed (from Package Center)
- ✅ **SSH access** enabled (Control Panel → Terminal & SNMP)
- ✅ **GitHub Personal Access Token** with `repo` and `workflow` scopes
  - Generate at: https://github.com/settings/tokens

**Hardware Requirements:**

- **Minimum:** 2 CPU cores, 8GB RAM, 20GB free space
- **Recommended:** 4 CPU cores, 16GB RAM, 50GB free space

## Installation Steps

### Step 1: Clone Repository to Synology

SSH into your Synology NAS:

```bash
ssh admin@<your-nas-ip>
```

Verify git is installed:

```bash
which git
# Should output: /usr/bin/git or similar
```

If git is not found, install Git Server from Package Center.

Clone the repository:

```bash
# Navigate to docker directory
cd /volume1/docker

# Clone the repository
git clone https://github.com/andrelin/synology-github-runner.git

# Enter the repository
cd synology-github-runner

# Verify contents
ls -la
```

You should see:

- `docker-compose.yml` - Runner configuration
- `.env.example` - Configuration template
- `scripts/` - Monitoring and setup scripts
- `docs/` - Documentation

### Step 2: Create .env File

Create the `.env` file with your secrets:

```bash
# Copy template
cp .env.example .env

# Edit configuration
nano .env
```

**Required settings:**

```bash
# Your repository URL
REPO_URL=https://github.com/your-username/your-repo

# Your GitHub Personal Access Token
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Optional settings (defaults are provided):**

```bash
# Runner name (default: synology-general-runner)
RUNNER_NAME=synology-general-runner

# Runner labels (default: self-hosted,linux,synology,general)
LABELS=self-hosted,linux,synology,general

# Memory limit (default: 5g)
RUNNER_MEMORY=5g

# CPU priority (default: 1536)
RUNNER_CPU_SHARES=1536

# Gradle options (default: -Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200)
GRADLE_OPTS=-Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
```

**Resource Tuning Guide:**

- **2-core/8GB NAS:** Use defaults (5g memory, -Xmx3g)
- **4-core/16GB NAS:** `RUNNER_MEMORY=10g`, `GRADLE_OPTS=-Xmx6g ...`
- **4-core/8GB NAS (tight):** `RUNNER_MEMORY=4g`, `GRADLE_OPTS=-Xmx2g ...`

Save and exit (Ctrl+X, Y, Enter in nano).

**Secure your .env file:**

```bash
chmod 600 .env
```

### Step 3: Create Required Directories

Create workspace and cache directories:

```bash
# Still in /volume1/docker/synology-github-runner
mkdir -p workspace cache

# Verify structure
ls -la
```

You should see:

- `workspace/` - Runner working directory (gitignored)
- `cache/` - Build cache directory (gitignored)
- `.env` - Your secrets (gitignored)

You can now exit SSH (type `exit`).

### Step 4: Create Container Manager Project

Now use the Synology Container Manager UI:

1. **Open Container Manager:**
   - Open DSM
   - Launch Container Manager application

2. **Create New Project:**
   - Click **Project** in left sidebar
   - Click **Create**

3. **Configure Project:**

   **General Settings:**
   - **Project Name:** `github-runner`
   - **Path:** `/volume1/docker/synology-github-runner`
   - **Source:** `Create docker-compose.yml`

   Click **Next**

4. **Compose File:**

   The wizard should automatically detect the `docker-compose.yml` file in the directory.

   - Verify the compose file is loaded (you should see the github-runner service)
   - **Do NOT edit** the compose file in the UI

   Click **Next**

5. **Web Portal Settings:**

   - Leave empty (runner doesn't need web portal)

   Click **Next**

6. **Review and Create:**

   - Review the configuration
   - Click **Done**

The Container Manager will:

- Read the `docker-compose.yml` file
- Read the `.env` file for secrets
- Create the container
- Start the runner

### Step 5: Verify Installation

**Check Container Manager:**

1. Go to **Container** in left sidebar
2. Find `github-runner` container
3. Verify:
   - Status: **Running** (green arrow)
   - CPU/Memory usage showing

**View Logs:**

1. Select `github-runner` container
2. Click **Details** button
3. Go to **Log** tab
4. Look for:

   ```text
   ✓ Runner successfully configured
   ✓ Runner listener started successfully
   ```

**Check Runner in GitHub:**

1. Open your repository on GitHub
2. Go to: **Settings → Actions → Runners**
3. Verify your runner shows as **Idle** (green circle)

### Step 6: Test the Runner

Create a simple test workflow (`.github/workflows/test-runner.yml` in your repository):

```yaml
name: Test Self-Hosted Runner

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: [self-hosted, linux]
    steps:
      - name: Print runner info
        run: |
          echo "Runner name: $RUNNER_NAME"
          echo "Runner OS: $RUNNER_OS"
          uname -a
          docker --version
```

1. Commit and push this workflow
2. Go to **Actions** tab in GitHub
3. Select **Test Self-Hosted Runner** workflow
4. Click **Run workflow**
5. Verify it runs on your Synology runner

## Managing the Runner

### Starting/Stopping via Container Manager

**Stop Runner:**

1. Container Manager → Container
2. Select `github-runner`
3. Click **Stop** (square icon)

**Start Runner:**

1. Container Manager → Container
2. Select `github-runner`
3. Click **Start** (play icon)

**Restart Runner:**

1. Container Manager → Container
2. Select `github-runner`
3. Click **Restart** (circular arrow icon)

### Rebuilding After Configuration Changes

If you update `.env` or pull new changes from git:

**Option 1: Via Container Manager UI**

1. Project → `github-runner` project
2. Click **Build** button
3. Container Manager will recreate the container with new config

**Option 2: Via SSH (if preferred)**

```bash
ssh admin@<your-nas-ip>
cd /volume1/docker/synology-github-runner
docker-compose down
docker-compose up -d
```

## Updating the Runner

### Update from Git Repository

When new versions are released:

1. **SSH into Synology:**

   ```bash
   ssh admin@<your-nas-ip>
   cd /volume1/docker/synology-github-runner
   ```

2. **Pull latest changes:**

   ```bash
   git pull origin main
   ```

3. **Rebuild in Container Manager:**
   - Open Container Manager
   - Go to **Project** → `github-runner`
   - Click **Build**
   - Container Manager recreates with new configuration

4. **Verify:**
   - Check container is running
   - Check logs for successful startup
   - Verify runner shows Idle in GitHub

**Note:** Your `.env` file is preserved (it's gitignored).

### Update Docker Image

To update the runner Docker image to latest:

**Via Container Manager UI:**

1. Container → `github-runner` container
2. Click **Stop**
3. Registry → Search `myoung34/github-runner`
4. Download `latest` tag
5. Project → `github-runner` → **Build**
6. New container uses latest image

## Directory Structure

After installation:

```text
/volume1/docker/synology-github-runner/  # Repository root
├── .git/                                # Git metadata
├── .env                                 # Your secrets (gitignored)
├── .env.example                         # Template
├── docker-compose.yml                   # Runner configuration
├── workspace/                           # Runner workspace (gitignored)
│   └── _work/                          # Job execution directories
├── cache/                               # Build cache (gitignored)
│   ├── gradle/                         # Gradle dependencies
│   └── npm/                            # npm packages
├── scripts/                             # Utility scripts
│   ├── monitoring/                     # Health checks
│   └── setup/                          # Installation helpers
├── docs/                                # Documentation
└── plans/                               # Implementation plans
```

## Container Manager Best Practices

**✅ DO:**

- Use Project tab for managing compose-based containers
- Use Container tab for viewing status and logs
- Update configuration via SSH + git pull
- Rebuild project after config changes

**❌ DON'T:**

- Don't edit docker-compose.yml in Container Manager UI
- Don't manually create containers for compose projects
- Don't delete workspace/ or cache/ directories
- Don't commit .env file to git

## Troubleshooting

### Git Not Found

**Problem:** `bash: git: command not found`

**Solution:**

1. DSM → Package Center
2. Search "Git Server"
3. Install and retry

### Runner Not Appearing in GitHub

**Problem:** Runner doesn't show in GitHub UI

**Solution:**

1. Container Manager → Container → `github-runner` → **Details** → **Log**
2. Check for errors
3. Verify `.env` has correct `REPO_URL` and `GITHUB_PAT`
4. Check token hasn't expired: https://github.com/settings/tokens
5. Verify token has `repo` and `workflow` scopes
6. Restart container in Container Manager

### Container Shows "Exited"

**Problem:** Container status is "Exited" instead of "Running"

**Solution:**

1. View logs: Container → Details → Log
2. Common issues:
   - Invalid `GITHUB_PAT`
   - Incorrect `REPO_URL` format
   - Token expired
   - Network connectivity issues
3. Fix `.env` file via SSH
4. Rebuild project in Container Manager

### Out of Memory Errors

**Problem:** Workflows fail with OOM errors

**Solution:**

1. SSH and edit `.env`:

   ```bash
   cd /volume1/docker/synology-github-runner
   nano .env
   ```

2. Increase memory:

   ```bash
   RUNNER_MEMORY=8g  # Increase from 5g
   GRADLE_OPTS=-Xmx5g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
   ```

3. Rebuild in Container Manager:
   - Project → `github-runner` → **Build**

### Project Build Fails

**Problem:** Container Manager fails to build project

**Solution:**

1. Check docker-compose.yml syntax:

   ```bash
   ssh admin@<your-nas-ip>
   cd /volume1/docker/synology-github-runner
   docker-compose config
   ```

2. Check .env file exists:

   ```bash
   ls -la .env
   cat .env
   ```

3. Check workspace/cache directories exist:

   ```bash
   ls -la workspace/ cache/
   ```

## Security Best Practices

1. **Secure .env file:**

   ```bash
   chmod 600 .env
   chown admin:administrators .env
   ```

2. **Use password manager** for GitHub PAT (1Password, Bitwarden)

3. **Rotate PAT every 90 days**

4. **Monitor runner activity** in GitHub Actions logs

5. **Set up monitoring alerts** - See [Monitoring Guide](04-MONITORING.md)

6. **Review logs regularly** in Container Manager

## Next Steps

After successful installation:

1. ✅ **Set up monitoring** - See [Monitoring Guide](04-MONITORING.md)
2. ✅ **Update your workflows** - Change `runs-on: ubuntu-latest` to `runs-on: [self-hosted, linux]`
3. ✅ **Test with real workflows** - Run your actual CI/CD pipelines
4. ✅ **Monitor resource usage** - Check Container Manager stats
5. ✅ **Review security** - See [Security Guide](07-SECURITY.md)

## Benefits of This Approach

✅ **Git-Based Config** - Version controlled, easy to update
✅ **Container Manager UI** - Familiar Synology interface
✅ **Best of Both Worlds** - Git for config, UI for management
✅ **Easy Updates** - `git pull` + rebuild in UI
✅ **Secure Secrets** - `.env` file gitignored
✅ **Auto-Restart** - Container Manager handles restarts on NAS reboot

## Getting Help

If you encounter issues:

1. Check [Troubleshooting Guide](05-TROUBLESHOOTING.md)
2. View Container Manager logs
3. Check GitHub Issues: https://github.com/andrelin/synology-github-runner/issues
4. Read Docker runner docs: https://github.com/myoung34/docker-github-actions-runner
