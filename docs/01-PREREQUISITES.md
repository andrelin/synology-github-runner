# Prerequisites

Before installing the GitHub self-hosted runner on your Synology NAS, ensure you meet all requirements and have necessary access credentials.

## Hardware Requirements

### Minimum Requirements

| Component | Minimum | Notes |
|-----------|---------|-------|
| **CPU** | 2 cores | Intel/AMD x86_64 architecture |
| **RAM** | 8 GB | For basic workflows (linting, tests) |
| **Storage** | 20 GB free | For runner workspace and Docker cache |
| **Network** | 10 Mbps | Stable internet connection |

**Use case:** Light workflows (Node.js tests, Python linting, documentation builds)

### Recommended Requirements

| Component | Recommended | Notes |
|-----------|-------------|-------|
| **CPU** | 4+ cores | Better for parallel builds |
| **RAM** | 16 GB | For Docker builds and heavy frameworks |
| **Storage** | 50+ GB free | More cache space = faster builds |
| **Network** | 100 Mbps | Faster artifact uploads/downloads |

**Use case:** Complex builds (Android apps, Kotlin Multiplatform, Docker images, Gradle projects)

### Tested Hardware

These Synology models have been tested and confirmed working:

| Model | CPU | RAM | Status | Notes |
|-------|-----|-----|--------|-------|
| **DS920+** | 4-core Intel Celeron J4125 | 8-16 GB | ✅ **Excellent** | Recommended for production |
| **DS220+** | 2-core Intel Celeron J4025 | 6-8 GB | ✅ **Good** | Requires resource tuning |
| **DS718+** | 2-core Intel Celeron J3455 | 6 GB | ⚠️ **Works** | Basic workflows only |
| **DS1621+** | 4-core AMD Ryzen V1500B | 16-32 GB | ✅ **Excellent** | High-performance builds |

**Note:** Most Synology NAS with DSM 7.0+ and x86_64 CPU should work. ARM-based models are not supported.

## Software Requirements

### Synology DSM

- **DSM Version:** 7.0 or later (7.2+ recommended)
- **Architecture:** x86_64 (Intel/AMD processors only)

**Check your DSM version:**
1. Open DSM
2. Control Panel → Info Center
3. Look for "DSM Version"

**To update DSM:**
1. Control Panel → Update & Restore
2. Check for updates and install

### Container Manager

Container Manager (formerly Docker) must be installed:

**Installation:**
1. Open **Package Center** in DSM
2. Search for "**Container Manager**"
3. Click **Install**
4. Wait for installation to complete

**Verify installation:**
1. Open Container Manager from main menu
2. Should see "Container", "Registry", "Project" tabs

### Git Server (for installation)

Git is required to clone the repository:

**Installation:**
1. Open **Package Center** in DSM
2. Search for "**Git Server**"
3. Click **Install**

**Verify installation:**
SSH into your NAS and run:
```bash
which git
# Should output: /usr/bin/git
```

### SSH Access

SSH must be enabled to install and configure the runner:

**Enable SSH:**
1. Open **Control Panel** → **Terminal & SNMP**
2. Enable **SSH service**
3. Port: 22 (default) or custom port
4. Apply

**Test SSH access:**
```bash
# From your computer
ssh admin@<your-nas-ip>
```

If successful, you'll see a login prompt for your NAS.

## Network Requirements

### Internet Access

The runner needs outbound internet access to:
- ✅ GitHub API (api.github.com, github.com)
- ✅ Docker Hub (for pulling images during builds)
- ✅ NPM, PyPI, Maven, etc. (dependency downloads)

**Ports required:**
- **Outbound HTTPS (443):** GitHub API, Docker Hub, package registries
- **Outbound HTTP (80):** Package registries (fallback)

**No inbound ports needed** - the runner initiates all connections outbound.

### Firewall / Router

If you have strict firewall rules:
- ✅ Allow outbound HTTPS (port 443) to all destinations
- ✅ Allow outbound HTTP (port 80) to all destinations
- ❌ No inbound ports required

### DNS Resolution

Ensure your NAS can resolve DNS:
```bash
# SSH into NAS and test
nslookup github.com
# Should return IP addresses
```

## GitHub Requirements

### Personal Access Token (PAT)

You need a GitHub Personal Access Token with specific scopes:

**Create a token:**
1. Go to: https://github.com/settings/tokens
2. Click **Generate new token** → **Generate new token (classic)**
3. Give it a descriptive name: `Synology Runner - <Project Name>`
4. Set expiration: 90 days (or custom - you'll need to rotate it)
5. Select scopes:
   - ✅ **repo** (all sub-scopes) - Required for private repos
   - ✅ **workflow** - Required for runner registration
6. Click **Generate token**
7. **Copy the token immediately** - you won't see it again!

**Token format:** Starts with `ghp_` followed by 36 characters
```
ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Store securely:** Use a password manager (1Password, Bitwarden, etc.)

**Security best practices:**
- ✅ Use minimum required scopes (only `repo` and `workflow`)
- ✅ Set expiration date (90 days recommended)
- ✅ Rotate tokens regularly
- ✅ Never commit tokens to git
- ✅ Revoke tokens if compromised

### Repository Access

You need **admin access** to the repository where you want to add the runner.

**Verify access:**
1. Go to your repository on GitHub
2. Click **Settings** (if you don't see this tab, you don't have admin access)
3. Click **Actions** → **Runners**
4. You should see "Add runner" button

**For organization repositories:**
- You need organization owner or repository admin permissions
- Organization may have runner policies that restrict self-hosted runners

### Repository Type

This runner works with:
- ✅ **Private repositories** (requires `repo` scope on PAT)
- ✅ **Public repositories** (requires `repo` and `workflow` scopes)
- ✅ **Organization repositories** (with proper permissions)

## Disk Space Requirements

### Initial Installation

- **Docker images:** ~2-3 GB (runner image + base images)
- **Repository clone:** varies by repo size
- **Configuration files:** < 1 MB

### Ongoing Usage

| Component | Space Needed | Notes |
|-----------|--------------|-------|
| **Workspace** | 5-10 GB | Builds, checkouts, artifacts |
| **Docker cache** | 10-20 GB | Gradle, npm, pip caches |
| **Docker images** | 5-10 GB | Build images (Node, Python, etc.) |
| **Logs** | < 1 GB | Runner logs |

**Total recommended:** 50 GB free space for comfortable operation

**Monitor disk usage:**
```bash
# Check free space
df -h /volume1

# Check Docker usage
docker system df
```

**Clean up space:**
```bash
# Remove unused Docker images
docker system prune -a

# Clean workspace (safe - rebuilds on next run)
rm -rf /volume1/docker/synology-github-runner/workspace/*
```

## Knowledge Requirements

### Required Knowledge

You should be comfortable with:
- ✅ Basic Linux/Unix commands (cd, ls, mkdir, nano/vi)
- ✅ SSH and terminal usage
- ✅ Basic Docker concepts (containers, images, volumes)
- ✅ GitHub Actions basics (workflows, jobs, runners)

### Helpful But Not Required

Nice to have:
- GitHub Actions workflow syntax (YAML)
- Docker Compose
- Shell scripting
- Synology DSM administration

## Pre-Installation Checklist

Before proceeding to installation, verify you have:

### Hardware & Software
- [ ] Synology NAS with x86_64 CPU (Intel/AMD)
- [ ] DSM 7.0 or later installed
- [ ] At least 2 CPU cores and 8GB RAM
- [ ] At least 20GB free disk space (50GB recommended)
- [ ] Container Manager installed
- [ ] Git Server installed
- [ ] SSH access enabled and tested

### Network & Access
- [ ] NAS has internet access
- [ ] Can access GitHub.com from NAS
- [ ] DNS resolution working
- [ ] No firewall blocking outbound HTTPS

### GitHub Credentials
- [ ] GitHub account with access to target repository
- [ ] Admin access to the repository
- [ ] Personal Access Token created with `repo` and `workflow` scopes
- [ ] Token saved securely (password manager)
- [ ] Repository URL handy (https://github.com/username/repo)

### Local Computer
- [ ] SSH client installed (Terminal on Mac/Linux, PuTTY on Windows)
- [ ] Can SSH into your NAS
- [ ] Text editor for editing .env file (or comfortable with nano/vi)

## Next Steps

Once all prerequisites are met:

1. **Quick Setup:** See [Quick Start Guide](00-QUICK-START.md) for 5-minute setup
2. **Detailed Setup:** See [Installation Guide](02-INSTALLATION.md) for step-by-step instructions

## Troubleshooting Prerequisites

### "Can't find Container Manager"

**Problem:** Container Manager not in Package Center

**Solution:**
- Ensure DSM is 7.0 or later
- Update DSM to latest version
- Look for "Docker" instead (older DSM versions)
- Verify you have x86_64 architecture (ARM not supported)

### "Git not found"

**Problem:** `which git` returns nothing

**Solution:**
- Install Git Server from Package Center
- Restart SSH session after installation
- Try: `/usr/local/git/bin/git` (alternative path)

### "SSH connection refused"

**Problem:** Can't SSH into NAS

**Solution:**
- Verify SSH is enabled: Control Panel → Terminal & SNMP
- Check port (default 22): `ssh -p <port> admin@<nas-ip>`
- Check firewall rules: Control Panel → Security → Firewall
- Try from different computer/network

### "Can't access GitHub.com from NAS"

**Problem:** No internet access or DNS issues

**Solution:**
```bash
# Test connectivity
ping -c 3 github.com

# Test HTTPS
curl -I https://github.com

# Check DNS
nslookup github.com
```

If any fail, check:
- NAS network settings: Control Panel → Network → Network Interface
- DNS servers: Control Panel → Network → General → DNS Server
- Router/firewall settings

## Getting Help

If you're stuck on prerequisites:

- 📖 [Synology Knowledge Base](https://kb.synology.com/)
- 🔧 [Troubleshooting Guide](05-TROUBLESHOOTING.md)
- 🐛 [GitHub Issues](https://github.com/andrelin/synology-github-runner/issues)

---

**Ready?** Proceed to [Quick Start Guide](00-QUICK-START.md) or [Installation Guide](02-INSTALLATION.md)
