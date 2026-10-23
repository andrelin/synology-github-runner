# Frequently Asked Questions (FAQ)

Quick answers to common questions about running GitHub self-hosted runners on Synology NAS.

## General Questions

### What is a self-hosted runner?

A self-hosted runner is a server you manage that runs GitHub Actions workflows, instead of using GitHub's cloud
infrastructure. It gives you:

- ✅ Unlimited build minutes (no usage limits)
- ✅ Access to your local network and resources
- ✅ Custom hardware and software configurations
- ✅ Faster builds with persistent caching

### Why use my Synology NAS for this?

Your Synology NAS is perfect because:

- ✅ **Already running 24/7** - No additional power costs
- ✅ **Spare resources** - Most NAS have unused CPU/RAM
- ✅ **Docker support** - Container Manager built-in
- ✅ **Reliable** - Designed for continuous operation
- ✅ **Cost-effective** - Use existing hardware

**Real savings:** If you use 10,000 minutes/month, you save ~$64/month ($768/year) vs GitHub-hosted runners.

### Will this slow down my NAS?

Not significantly if configured properly:

- ✅ Resource limits prevent overload (set in `.env`)
- ✅ CPU priority can be adjusted
- ✅ Workflows queue instead of running parallel
- ✅ Runner uses spare resources

**Recommendation:** Leave 30-40% of RAM/CPU for DSM and other services.

### Can I use this for private repositories?

Yes! It works with:

- ✅ Private repositories (requires `repo` scope on PAT)
- ✅ Public repositories
- ✅ Organization repositories (with proper permissions)

### Is this secure?

Yes, when properly configured:

- ✅ Container security hardening included (no-new-privileges, minimal capabilities)
- ✅ Secrets stored in `.env` file (gitignored)
- ✅ Runner connects outbound only (no inbound ports needed)
- ✅ Regular security updates via Docker image

See [Security Guide](07-security.md) for more details.

### How much does this cost?

**Direct costs:** $0 (free, uses your existing NAS)

**Indirect costs:**

- Minimal electricity (~5-10W additional power draw)
- Your time for setup and maintenance (~30 minutes initial, ~15 minutes/month)

**Savings vs GitHub-hosted:**

- 2,000 free minutes/month, then $0.008/minute
- Self-hosted: Unlimited minutes, $0

## Installation Questions

### What are the minimum hardware requirements?

**Minimum:**

- 2 CPU cores (Intel/AMD x86_64)
- 8 GB RAM
- 20 GB free disk space

**Recommended:**

- 4+ CPU cores
- 16+ GB RAM
- 50+ GB free disk space

See [Prerequisites Guide](01-prerequisites.md) for detailed requirements.

### Which Synology models are supported?

Any x86_64 (Intel/AMD) Synology NAS with DSM 7.2+:

✅ **Tested and confirmed:**

- DS920+, DS1621+ (Excellent)
- DS220+, DS718+ (Good)
- Most Plus series (DS218+, DS418+, etc.)

❌ **Not supported:**

- ARM-based models (use x86_64 only)
- DSM 6.x (upgrade to 7.0+)

### Do I need a GitHub Pro account?

No! Works with:

- ✅ GitHub Free (personal)
- ✅ GitHub Pro
- ✅ GitHub Team
- ✅ GitHub Enterprise

### How long does installation take?

**Quick Start:** 5-10 minutes if prerequisites are ready
**Full Setup:** 20-30 minutes including understanding and customization

See [Quick Start Guide](00-quick-start.md).

### Can I use SSH or do I need the UI?

You can use either:

- **Via SSH:** Full control, faster for advanced users
- **Via DSM UI:** Container Manager for management
- **Hybrid:** SSH for setup, UI for monitoring (recommended)

See [Installation Guide](02-installation.md) for both approaches.

## Configuration Questions

### How do I tune resources for my hardware?

Edit `.env` file based on your NAS:

**For 2-core/8GB NAS:**

```bash
RUNNER_MEMORY=5g
RUNNER_CPU_SHARES=1536
GRADLE_OPTS=-Xmx3g ...
```

**For 4-core/16GB NAS:**

```bash
RUNNER_MEMORY=10g
RUNNER_CPU_SHARES=2048
GRADLE_OPTS=-Xmx6g ...
```

See [Configuration Guide](03-configuration.md) for details.

### Can I run multiple runners?

Yes, but consider:

- ✅ Each runner needs its own directory and container
- ✅ Each needs dedicated resources (RAM/CPU)
- ⚠️ Resource contention if not careful
- ⚠️ More complex to manage

**For single NAS:** One powerful runner is usually better than multiple weak runners.

### Can I use this for multiple repositories?

**Per-runner:** No, each runner is registered to one repository.

**Solutions:**

- Run multiple runner containers (one per repo)
- Use organization-level runner (if you have org access)
- Share runner across repos in same org

### How do I add custom labels?

Edit `.env`:

```bash
LABELS=self-hosted,linux,synology,kotlin,gradle,docker
```

Use in workflow:

```yaml
runs-on: [self-hosted, kotlin, gradle]
```

See [Configuration Guide](03-configuration.md#labels).

### Where are the logs stored?

**Container logs:**

```bash
docker-compose logs -f
```

**DSM logs:**

- Container Manager → Container → github-runner → Details → Log

**GitHub Actions logs:**

- Repository → Actions → Workflow run → Job logs

## Performance Questions

### Why are my builds slower than GitHub-hosted?

Common reasons:

- ❌ Insufficient memory/CPU allocated
- ❌ No dependency caching enabled
- ❌ Network slower than GitHub's datacenters
- ❌ Other services competing for resources

**Solutions:**

- Increase `RUNNER_MEMORY` and `CPU_SHARES`
- Enable caching in workflows (`cache: 'npm'`, etc.)
- Use sequential jobs (orchestrator pattern)
- Run builds during off-peak hours

See [Troubleshooting Guide](05-troubleshooting.md#slow-build-performance).

### How can I speed up Docker builds?

- ✅ Enable Docker layer caching
- ✅ Use multi-stage builds
- ✅ Create `.dockerignore` file
- ✅ Optimize Dockerfile layer order
- ✅ Clean old images regularly

See [docker-build.yml example](../examples/workflows/docker-build.yml).

### What's the benefit of caching?

**Without cache:**

- Every build downloads dependencies from scratch
- 10-20 minutes for dependency downloads
- Wastes bandwidth and time

**With cache:**

- Dependencies cached on runner
- First build: 20 minutes
- Subsequent builds: 3-5 minutes
- 4-6x faster!

Enable in workflow:

```yaml
- uses: actions/setup-node@v6
  with:
    cache: 'npm'
```

### Can I run builds in parallel?

**Not recommended for single runner:**

- Resource exhaustion
- OOM errors
- Inconsistent performance

**Better approach:**

- Use sequential jobs (orchestrator pattern)
- Set job dependencies (`needs:`)
- Runner handles one job at a time efficiently

See [orchestrator.yml example](../examples/workflows/orchestrator.yml).

## Troubleshooting Questions

### Runner shows in GitHub but workflows don't run

**Check:**

1. Runner status: Should be "Idle" (green), not "Offline" (gray)
2. Workflow targets correct labels:

   ```yaml
   runs-on: [self-hosted, Linux, X64]
   ```

3. No concurrent workflow limits hit
4. Check workflow logs for errors

### Builds fail with "Out of Memory" errors

**Quick fix:**

```bash
# Edit .env
RUNNER_MEMORY=8g  # Increase from 5g
GRADLE_OPTS=-Xmx5g ...  # If using Gradle

# Restart
docker-compose down && docker-compose up -d
```

See [Troubleshooting Guide](05-troubleshooting.md#out-of-memory-oom-errors).

### Container keeps restarting

**Common causes:**

- Invalid `GITHUB_PAT` (expired or wrong scopes)
- Wrong `REPO_URL` format
- Network connectivity issues
- Permission problems

**Check logs:**

```bash
docker-compose logs --tail=100
```

See [Troubleshooting Guide](05-troubleshooting.md#container-wont-start).

### "No space left on device" error

**Quick fix:**

```bash
# Clean Docker
docker system prune -af

# Clean workspace
sudo rm -rf /volume1/docker/github-runner/workspace/* /volume1/docker/github-runner/cache/*

# Check space
df -h /volume1
```

See [Troubleshooting Guide](05-troubleshooting.md#disk-space-issues).

## Maintenance Questions

### How do I update the runner?

While the runner is idle, `git pull` in the project folder, then **Build** the project in Container Manager, or
over SSH:

```bash
cd /volume1/docker/synology-github-runner
git pull                            # this repository's fixes
sudo docker compose build --pull    # rebuild the image from the pinned Dockerfile
sudo docker compose up -d           # recreate the container from it
```

See [Maintenance Guide](06-maintenance.md).

### How often should I update?

**Recommended:**

- Runner image: Monthly (security updates)
- Configuration: When needed (new features)
- Docker/DSM: Follow Synology's schedule

**Check for updates:**

```bash
docker pull myoung34/github-runner:latest
```

### Do I need to backup anything?

**Critical to backup:**

- ✅ `.env` file (contains secrets) - Store securely
- ✅ `docker-compose.yaml` (if customized)
- ✅ Custom scripts or configurations

**No need to backup:**

- ❌ `workspace/` (temporary, rebuilt each run)
- ❌ `cache/` (optional, speeds up builds)
- ❌ Docker images (can re-pull)

**Backup command:**

```bash
# Backup .env securely
cp .env .env.backup
chmod 600 .env.backup
# Store in password manager or secure location
```

### What happens if my NAS restarts?

**Automatic recovery:**

- ✅ Container Manager auto-starts runner (restart: unless-stopped)
- ✅ Runner re-registers with GitHub
- ✅ Workflows resume automatically

**No manual intervention needed!**

### How do I monitor runner health?

**Via Container Manager:**

- Container → github-runner → Details (CPU/Memory graphs)

**Via SSH:**

```bash
docker stats github-runner --no-stream
```

**Via monitoring script:**

```bash
sudo bash /volume1/docker/synology-github-runner/scripts/monitoring/runner-dashboard.sh
```

See [Monitoring Guide](04-monitoring.md).

## Security Questions

### Is my GitHub token safe?

Yes, if you follow best practices:

- ✅ Stored in `.env` file (gitignored)
- ✅ `.env` has restricted permissions (`chmod 600`)
- ✅ Never committed to git
- ✅ Rotated every 90 days

**Make it safer:**

- Use password manager for storage
- Set token expiration date
- Use minimum required scopes (`repo` + `workflow`)

### Can someone exploit my NAS through the runner?

Very unlikely if properly configured:

- ✅ Container security hardening enabled
- ✅ No inbound ports exposed
- ✅ Runner connects outbound only
- ✅ Minimal Linux capabilities
- ✅ No privilege escalation allowed

**Best practices:**

- Only run workflows from trusted repositories
- Review workflow code before running
- Don't use runner for public repos if concerned
- Keep Docker and DSM updated

### Should I use this for open-source projects?

**Pros:**

- Unlimited build minutes
- Custom environment

**Cons:**

- Security risk (arbitrary code execution)
- Resource abuse potential
- Need to monitor carefully

**Recommendation:**

- ✅ Great for your own open-source projects
- ✅ Good for trusted contributors
- ⚠️ Be cautious with public PRs from strangers
- ❌ Don't use for fully public repos with open contributions

**Safer alternative for public projects:** Use GitHub-hosted runners for PRs, self-hosted for main branch.

### How do I rotate my GitHub token?

1. **Generate new token:** https://github.com/settings/tokens
2. **Update `.env`:**

   ```bash
   nano .env
   # Change GITHUB_PAT=ghp_new_token
   ```

3. **Restart container:**

   ```bash
   docker-compose down
   docker-compose up -d
   ```

4. **Revoke old token** in GitHub settings

**Recommended:** Set calendar reminder for every 90 days.

## Workflow Questions

### Can I use actions from GitHub Marketplace?

Yes! All public GitHub Actions work:

```yaml
- uses: actions/checkout@v6
- uses: actions/setup-node@v6
- uses: docker/build-push-action@v5
```

**Note:** Some actions might be optimized for GitHub-hosted runners, but most work fine.

### How do I target my self-hosted runner?

In workflow file:

```yaml
jobs:
  build:
    runs-on: [self-hosted, Linux, X64]  # Targets your runner
```

Or with custom labels:

```yaml
runs-on: [self-hosted, kotlin, gradle]
```

### Can I mix self-hosted and GitHub-hosted runners?

Yes! Use different jobs:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest  # GitHub-hosted

  build:
    runs-on: [self-hosted, Linux, X64]  # Your NAS
```

**Use case:** Light tasks on GitHub-hosted, heavy builds on self-hosted.

### What's the orchestrator pattern?

A workflow pattern for resource-constrained runners where jobs run sequentially instead of in parallel:

```yaml
jobs:
  lint:
    # Runs first

  test:
    needs: [lint]  # Waits for lint

  build:
    needs: [test]  # Waits for test
```

See [orchestrator.yml example](../examples/workflows/orchestrator.yml).

## Getting Help

### Where can I find more information?

**Documentation:**

- [Quick Start Guide](00-quick-start.md)
- [Installation Guide](02-installation.md)
- [Configuration Guide](03-configuration.md)
- [Troubleshooting Guide](05-troubleshooting.md)

**Community:**

- [GitHub Issues](https://github.com/andrelin/synology-github-runner/issues)
- [GitHub Discussions](https://github.com/andrelin/synology-github-runner/discussions)

### How do I report a bug?

1. **Check existing issues:** https://github.com/andrelin/synology-github-runner/issues
2. **Gather information:** Logs, config, steps to reproduce
3. **Open new issue** with clear description

See [Troubleshooting Guide](05-troubleshooting.md#when-to-ask-for-help) for what to include.

### Can I contribute?

Yes! Contributions welcome:

- 🐛 Bug reports
- 📝 Documentation improvements
- ✨ New features
- 🎨 Workflow examples

See [contributing.md](../contributing.md) for guidelines.

### Is there a community chat?

Currently using:

- GitHub Discussions (preferred)
- GitHub Issues (bugs and features)

Open an issue or discussion - maintainers and community members will help!

---

**Question not answered?** [Open a discussion](https://github.com/andrelin/synology-github-runner/discussions) or
[check the full documentation](00-quick-start.md).
