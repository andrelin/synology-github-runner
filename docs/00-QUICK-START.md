# Quick Start Guide

> Get your GitHub self-hosted runner running on Synology NAS in **5 minutes**.

This is the TL;DR guide. For detailed explanations, see the [full installation guide](02-INSTALLATION.md).

## Prerequisites Checklist

Before starting, ensure you have:

- ✅ Synology NAS with DSM 7.0+ and Container Manager installed
- ✅ SSH access enabled on your NAS
- ✅ GitHub Personal Access Token with `repo` and `workflow` scopes
  - Create at: https://github.com/settings/tokens
- ✅ Repository URL where you want to add the runner

**Minimum specs:** 2 CPU cores, 8GB RAM, 20GB free space

## Quick Setup

### Step 1: Clone to Synology (2 minutes)

SSH into your NAS and clone the repository:

```bash
ssh admin@<your-nas-ip>

# Navigate to docker directory
cd /volume1/docker

# Clone repository
git clone https://github.com/andrelin/synology-github-runner.git
cd synology-github-runner
```

### Step 2: Configure Environment (1 minute)

Create your `.env` file with secrets:

```bash
# Copy template
cp .env.example .env

# Edit with your details
nano .env
```

**Required settings:**
```bash
REPO_URL=https://github.com/your-username/your-repo
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Save and exit (Ctrl+X, Y, Enter).

**Secure the file:**
```bash
chmod 600 .env
```

### Step 3: Create Directories (30 seconds)

```bash
mkdir -p workspace cache
```

### Step 4: Build and Start via Container Manager (2 minutes)

1. Open **Container Manager** in DSM
2. Go to **Project** → **Create**
3. Configure:
   - **Project Name:** `github-runner`
   - **Path:** `/volume1/docker/synology-github-runner`
   - **Source:** `Create docker-compose.yml`
4. Click **Next** → **Next** → **Done**

Container Manager will:
- Build the custom runner image (includes Anthropic SDK for Claude Code Review)
- Start the runner automatically

**Note:** First build takes 2-3 minutes. Subsequent starts are instant.

### Step 5: Verify (30 seconds)

**Check Container:**
- Container Manager → Container → `github-runner` should show **Running**

**Check GitHub:**
- Go to your repository → **Settings → Actions → Runners**
- Your runner should show as **Idle** (green circle)

**Check Logs:**
```bash
# Via SSH (optional)
cd /volume1/docker/synology-github-runner
docker-compose logs -f
```

Look for:
```
✓ Runner successfully configured
✓ Runner listener started successfully
```

## Test Your Runner

Create `.github/workflows/test-runner.yml` in your repository:

```yaml
name: Test Self-Hosted Runner

on: workflow_dispatch

jobs:
  test:
    runs-on: [self-hosted, Linux, X64]
    steps:
      - name: Test runner
        run: |
          echo "Runner name: $RUNNER_NAME"
          echo "Runner OS: $RUNNER_OS"
          uname -a
```

1. Commit and push
2. Go to **Actions** tab in GitHub
3. Click **Test Self-Hosted Runner** → **Run workflow**
4. Watch it execute on your Synology!

## What's Next?

### Tune Your Setup

See [Configuration Guide](03-CONFIGURATION.md) to:
- Optimize resource limits for your hardware
- Add custom runner labels
- Configure security hardening

### Update Your Workflows

Change your existing workflows to use the self-hosted runner:

```yaml
jobs:
  build:
    runs-on: [self-hosted, Linux, X64]  # Changed from: ubuntu-latest
```

### Set Up Monitoring

See [Monitoring Guide](04-MONITORING.md) to:
- Configure health checks
- Set up automated alerts
- View real-time dashboard

## Common Issues

### Runner not appearing in GitHub

**Problem:** Runner doesn't show in GitHub Settings → Actions → Runners

**Solution:**
1. Check container logs: Container Manager → `github-runner` → Details → Log
2. Verify `GITHUB_PAT` is correct and not expired
3. Verify `REPO_URL` is correct (must include https://)
4. Restart container: Container Manager → `github-runner` → Restart

### Container shows "Exited"

**Problem:** Container status is "Exited" instead of "Running"

**Solution:**
1. View logs: Container Manager → `github-runner` → Details → Log
2. Common causes:
   - Invalid GitHub PAT (expired or wrong scopes)
   - Incorrect REPO_URL format
   - Network connectivity issues
3. Fix `.env` file via SSH and rebuild in Container Manager

### Out of memory errors

**Problem:** Workflows fail with OOM errors

**Solution:**
Edit `.env` and increase memory:
```bash
RUNNER_MEMORY=8g  # Increase from default 5g
GRADLE_OPTS=-Xmx5g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
```

Rebuild in Container Manager: Project → `github-runner` → Build

## Getting Help

- 📖 [Full Documentation](README.md)
- 🔧 [Troubleshooting Guide](05-TROUBLESHOOTING.md)
- 🐛 [Report Issues](https://github.com/andrelin/synology-github-runner/issues)

## Congratulations! 🎉

You now have unlimited GitHub Actions minutes on your Synology NAS!

**Actual time to set up:** 3-5 minutes (if you have prerequisites ready)

---

**Next steps:**
- [Prerequisites Guide](01-PREREQUISITES.md) - Detailed requirements
- [Installation Guide](02-INSTALLATION.md) - Step-by-step with explanations
- [Configuration Guide](03-CONFIGURATION.md) - Customize your setup
- [Workflow Examples](08-WORKFLOWS.md) - Ready-to-use workflow patterns
