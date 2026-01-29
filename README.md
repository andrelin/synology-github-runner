# 🚀 GitHub Self-Hosted Runner on Synology NAS

> Run unlimited GitHub Actions workflows on your Synology NAS. No more minute limits, faster builds, and full control over your CI/CD pipeline.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell Script](https://img.shields.io/badge/Shell_Script-121011?logo=gnu-bash&logoColor=white)](scripts/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](docker-compose.yml)
[![Synology](https://img.shields.io/badge/Synology-B5B5B6?logo=synology&logoColor=white)](https://www.synology.com)

## ✨ Features

- 🎯 **Quick Setup** - Get running in 30 minutes with automated installation
- 🔒 **Security Hardened** - Read-only filesystem, minimal privileges, no-new-privileges flag
- 📊 **Built-in Monitoring** - Health checks, real-time dashboard, automated alerts
- 💪 **Resource Optimized** - Works great on 2-core/8GB systems, scales to larger hardware
- 📦 **Docker-in-Docker** - Build and push Docker images directly from workflows
- 🔄 **Auto-Restart** - Resilient to crashes with automatic recovery
- 📝 **Comprehensive Docs** - Step-by-step guides for every aspect
- 🎨 **Example Workflows** - Production-ready workflow templates included

## 🎯 Why Self-Host?

| GitHub-Hosted | Self-Hosted on Synology |
|--------------|------------------------|
| ⏱️ 2,000 free minutes/month | ✅ **Unlimited** minutes |
| 💰 $0.008/minute after limit | ✅ **Free** (use your NAS) |
| 🐌 Shared resources | ✅ **Dedicated** resources |
| 🔒 No private network access | ✅ **Full** network access |
| 📦 No Docker layer caching | ✅ **Persistent** caching |

**Real Savings:** If you use 10,000 minutes/month, you save **$64/month** ($768/year)!

## 📋 Requirements

### Hardware
- **Synology NAS** with DSM 7.0 or later
- **2+ CPU cores** (4+ recommended)
- **8+ GB RAM** (16+ recommended)
- **20+ GB free disk space** (for workspace and cache)

### Software
- **Container Manager** installed from DSM Package Center
- **SSH access** enabled (for installation)
- **GitHub Personal Access Token** with `repo` and `workflow` scopes

### Tested Hardware
✅ Synology DS920+ (4-core, 8GB) - **Excellent**
✅ Synology DS220+ (2-core, 8GB) - **Good** (resource tuning recommended)
✅ Synology DS718+ (2-core, 6GB) - **Works** (basic workflows only)

## 🚀 Quick Start

### Option 1: Automated Installation (Recommended)

```bash
# 1. Clone this repository
git clone https://github.com/andrelin/synology-github-runner.git
cd synology-github-runner

# 2. Copy to your NAS
scp -r . admin@<your-nas-ip>:/volume1/temp/runner-setup/

# 3. SSH into NAS and run installer
ssh admin@<your-nas-ip>
cd /volume1/temp/runner-setup
sudo ./install.sh
```

The installer will:
- ✅ Check prerequisites
- ✅ Create directory structure
- ✅ Set up configuration
- ✅ Install monitoring scripts
- ✅ Start the runner
- ✅ Guide you through remaining steps

### Option 2: Manual Installation

See [Installation Guide](docs/02-INSTALLATION.md) for step-by-step instructions.

## 📖 Documentation

### Getting Started
- [Prerequisites](docs/01-PREREQUISITES.md) - Hardware, software, and account setup
- [Installation](docs/02-INSTALLATION.md) - Step-by-step installation guide
- [Quick Start](docs/00-QUICK-START.md) - TL;DR for experienced users

### Configuration
- [Configuration Guide](docs/03-CONFIGURATION.md) - Customize your runner
- [Security Hardening](docs/07-SECURITY.md) - Best practices for production
- [Workflow Examples](docs/08-WORKFLOWS.md) - Real-world workflow patterns

### Operations
- [Monitoring](docs/04-MONITORING.md) - Health checks and dashboards
- [Maintenance](docs/06-MAINTENANCE.md) - Updates, backups, cleanup
- [Troubleshooting](docs/05-TROUBLESHOOTING.md) - Common issues and solutions

### Reference
- [FAQ](docs/FAQ.md) - Frequently asked questions
- [Contributing](CONTRIBUTING.md) - How to contribute
- [Changelog](CHANGELOG.md) - Version history

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│ GitHub (github.com)                             │
│ ├─ Repository                                   │
│ ├─ Actions Workflows                            │
│ └─ Self-Hosted Runner (registered)              │
└─────────────────────┬───────────────────────────┘
                      │ HTTPS (GitHub API)
                      ▼
┌─────────────────────────────────────────────────┐
│ Synology NAS                                    │
│ ┌───────────────────────────────────────────┐   │
│ │ Docker Container: github-runner           │   │
│ │ ├─ Runner Agent (myoung34/github-runner) │   │
│ │ ├─ Workspace (/volume1/.../workspace)    │   │
│ │ ├─ Cache (/volume1/.../cache)            │   │
│ │ └─ Docker Socket (Docker-in-Docker)      │   │
│ └───────────────────────────────────────────┘   │
│                                                  │
│ ┌───────────────────────────────────────────┐   │
│ │ Monitoring Scripts                        │   │
│ │ ├─ Health Check (every 5 min)            │   │
│ │ ├─ Dashboard (on-demand)                 │   │
│ │ └─ Alerts (/volume1/.../alerts.log)      │   │
│ └───────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## 🎨 Example Workflows

### Basic CI Workflow

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: [self-hosted, Linux, X64]
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: ./gradlew test
```

### Orchestrator Pattern (Resource-Constrained)

```yaml
name: CI/CD Pipeline
on: [push, pull_request]

concurrency:
  group: synology-runner
  cancel-in-progress: false  # Queue instead of cancel

jobs:
  test-shared:
    uses: ./.github/workflows/test-shared.yml

  test-app:
    needs: test-shared
    uses: ./.github/workflows/test-app.yml

  deploy:
    needs: [test-shared, test-app]
    if: github.ref == 'refs/heads/main'
    uses: ./.github/workflows/deploy.yml
```

See [examples/workflows/](examples/workflows/) for more patterns.

## 📊 Real-World Performance

Tested with a Kotlin Multiplatform project (Android, iOS, Web):

| Metric | GitHub-Hosted | Self-Hosted (2-core/8GB) | Improvement |
|--------|--------------|--------------------------|-------------|
| Shared Tests | 3m 45s | 2m 30s | **33% faster** |
| Android Build | 8m 20s | 5m 10s | **38% faster** |
| Web Build | 4m 30s | 2m 50s | **37% faster** |
| Docker Build | 6m 40s | 3m 20s | **50% faster** |

**With Caching:** 2-3x faster on subsequent runs.

## 🔧 Customization

### Resource Limits

Adjust in `.env`:

```bash
# For 2-core/8GB system (conservative)
RUNNER_CPUS=1.5
RUNNER_MEMORY=5G
GRADLE_OPTS=-Xmx3g

# For 4-core/16GB system (recommended)
RUNNER_CPUS=3
RUNNER_MEMORY=10G
GRADLE_OPTS=-Xmx6g
```

### Labels

Add custom labels to target specific runners:

```bash
LABELS=self-hosted,Linux,X64,synology,kotlin,docker
```

Then use in workflows:

```yaml
runs-on: [self-hosted, kotlin]
```

## 🛡️ Security Best Practices

✅ **Use minimal GitHub PAT scopes** - Only `repo` and `workflow`
✅ **Enable read-only filesystem** - Included in docker-compose.yml
✅ **Drop all capabilities** - Only add what's needed
✅ **Use tmpfs for sensitive data** - Ephemeral storage for tokens
✅ **Regular updates** - Keep runner image up to date
✅ **Monitor logs** - Watch for suspicious activity

See [Security Guide](docs/07-SECURITY.md) for complete hardening checklist.

## 📈 Monitoring Dashboard

Run the included dashboard script:

```bash
/volume1/scripts/runner-dashboard.sh
```

```
╔════════════════════════════════════════════════════════════════╗
║  GitHub Self-Hosted Runner - Status Dashboard                 ║
╚════════════════════════════════════════════════════════════════╝

━━━ Container Status ━━━
Status:      ✅ Running
Started:     2026-01-28T20:00:00Z
Restarts:    0

━━━ Resource Usage ━━━
CPU:         45.2%
Memory:      2.1GiB / 5GiB (42%)
Network I/O: 1.2MB / 3.4MB

━━━ Runner Connectivity ━━━
GitHub API:  ✅ Reachable
Runner:      ✅ Listening for Jobs
```

## 🤝 Contributing

Contributions welcome! Whether it's:

- 🐛 Bug reports
- 📝 Documentation improvements
- ✨ New features
- 🎨 Workflow examples
- 💡 Ideas and suggestions

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

Free to use, modify, and distribute. Attribution appreciated but not required.

## 🙏 Acknowledgments

Built with and inspired by:

- [myoung34/docker-github-actions-runner](https://github.com/myoung34/docker-github-actions-runner) - Docker image for GitHub runners
- [GitHub Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners) - Official documentation
- Synology Community - Tips and best practices

## ⭐ Star History

If this project helped you, please star the repository! It helps others discover it.

## 💬 Support

- 📖 Check the [Documentation](docs/)
- 🐛 Report issues on [GitHub Issues](https://github.com/andrelin/synology-github-runner/issues)
- 💡 Share ideas in [Discussions](https://github.com/andrelin/synology-github-runner/discussions)

## 🚦 Status

✅ **Production Ready** - Used in real projects
✅ **Actively Maintained** - Regular updates
✅ **Well Documented** - Comprehensive guides
✅ **Battle Tested** - Handles complex workflows

---

Made with ❤️ for the Synology + GitHub Actions community
