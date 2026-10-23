# 🚀 GitHub Self-Hosted Runner on Synology NAS

> **Eliminate GitHub Actions costs for private repositories** by running workflows on your Synology NAS.
> Trade per-minute charges ($0.008/minute) for self-hosted infrastructure.
> Performance depends on your hardware; maintenance is your responsibility.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell Script](https://img.shields.io/badge/Shell_Script-121011?logo=gnu-bash&logoColor=white)](scripts/)
[![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white)](docker-compose.yaml)
[![Synology](https://img.shields.io/badge/Synology-B5B5B6?logo=synology&logoColor=white)](https://www.synology.com)

[![Quality Checks](https://github.com/andrelin/synology-github-runner/actions/workflows/quality.yml/badge.svg)](https://github.com/andrelin/synology-github-runner/actions/workflows/quality.yml)
[![Security Scanning](https://github.com/andrelin/synology-github-runner/actions/workflows/security.yml/badge.svg)](https://github.com/andrelin/synology-github-runner/actions/workflows/security.yml)
[![Weekly Link Check](https://github.com/andrelin/synology-github-runner/actions/workflows/weekly-link-check.yml/badge.svg)](https://github.com/andrelin/synology-github-runner/actions/workflows/weekly-link-check.yml)

## ✨ What This Provides

- 💰 **Zero Per-Minute Costs** - Eliminate $0.008/minute charges for private hobby projects
- 🎓 **Learning Platform** - Hands-on experience with self-hosted CI/CD infrastructure
- 🎯 **Automated Setup** - Installation script handles most configuration
- 🔒 **Security Hardened** - Read-only filesystem, minimal privileges, no-new-privileges flag
- 📊 **Built-in Monitoring** - Health checks and dashboard to manage your infrastructure
- 💪 **Resource Optimized** - Tuned for consumer NAS hardware (2-core/8GB minimum)
- 📦 **Docker-in-Docker** - Build and push Docker images from your workflows
- 🔄 **Auto-Restart** - Automatic recovery from crashes
- 📝 **Honest Documentation** - Clear trade-off discussions so you know what you're getting into
- 🎨 **Example Workflows** - Templates for common CI/CD patterns on self-hosted runners

## 🤔 Should You Self-Host?

### ✅ Only Do This If:

- **💰 Private repos costing real money** - You're exceeding free tier and paying $0.008/minute
- **💵 Money matters more than everything else** - You're willing to accept worse performance, reliability, and
  convenience to save costs

### ❌ Don't Do This If:

- **📂 Public repositories** - You already have **unlimited free minutes** on GitHub-hosted runners (which are also faster)
- **⚡ Speed matters** - GitHub-hosted runners are faster
- **🏃 Parallelism matters** - GitHub can run multiple jobs simultaneously; self-hosted = one at a time
- **🔧 Convenience matters** - No maintenance, no monitoring, no troubleshooting with GitHub-hosted
- **📊 Reliability matters** - GitHub's infrastructure is more reliable than consumer NAS
- **💤 Within free tier** - If you're under 2,000-3,000 minutes/month, GitHub-hosted is free AND better

### ⚖️ Honest Trade-Offs

**What you gain:**

- 💰 **Zero per-minute costs** for private repos (save $64/month if using 10,000 minutes)

**What you sacrifice:**

- 🔧 **Maintenance burden** - Updates, monitoring, troubleshooting, disk space management now your responsibility
- ⏰ **Setup time** - 30-60 minutes initial setup plus ongoing maintenance
- 🤯 **Complexity** - Docker, networking, security configuration vs "just works" on GitHub

**Hardware-dependent factors:**

- 📊 **Performance** - Speed depends entirely on your Synology hardware (CPU, RAM, storage type)
- 🚦 **Parallelism** - This guide covers a single runner setup. You could run multiple runners if you have
  sufficient CPU/RAM, but most consumer NAS devices aren't specced for that
- 💾 **Resource constraints** - Lower-end devices (2-4 cores, 8GB RAM) typically run one runner; high-end
  devices could support multiple

**Your mileage WILL vary.** The only universal benefit is cost savings for private repositories.

### 💰 Cost Savings Calculator (Private Repos Only)

**Is it worth the trade-offs for your hobby project?**

| Monthly Minutes | GitHub Cost | Self-Hosted Cost | Annual Savings | Worth It? |
| --------------- | ----------- | ---------------- | -------------- | --------- |
| 3,000 (free tier) | $0 | $0 | **$0** | ❌ No cost savings |
| 10,000 | $64/mo | $0 | **$768/year** | 🎨 Maybe for hobby projects |
| 25,000 | $184/mo | $0 | **$2,208/year** | 🎨 Good for large hobby projects |
| 50,000 | $392/mo | $0 | **$4,704/year** | 🏢 At this scale, consider managed solutions |

> **Bottom line:** This is for hobby projects and learning, not businesses. If you're a business spending
> $200+/month on Actions, just pay for it—your team's time is worth more than the savings. This is for
> hobbyists who enjoy tinkering and want to avoid costs on personal projects.

## 📋 Requirements

### Hardware

- **Synology NAS** with DSM 7.2 or later
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
# 1. SSH into the NAS and clone this repository; the clone becomes the project folder
ssh admin@<your-nas-ip>
cd /volume1/docker
git clone https://github.com/andrelin/synology-github-runner.git
cd synology-github-runner

# 2. Run the installer
sudo ./scripts/setup/install.sh
```

The installer will:

- ✅ Check prerequisites
- ✅ Write `.env` with your repository, token and runner name
- ✅ Validate the configuration
- ✅ Create the workspace and cache folders
- ✅ Tell you how to create the Container Manager project from the clone

Because the project folder is a git clone, `git pull` and a pull of the published runner image keep it up to date
(see the [Maintenance Guide](docs/06-maintenance.md#pull-and-update)).

### Option 2: Manual Installation

See [Installation Guide](docs/02-installation.md) for step-by-step instructions.

## 📖 Documentation

### Getting Started

- [Prerequisites](docs/01-prerequisites.md) - Hardware, software, and account setup
- [Installation](docs/02-installation.md) - Step-by-step installation guide
- [Quick Start](docs/00-quick-start.md) - TL;DR for experienced users

### Configuration

- [Configuration Guide](docs/03-configuration.md) - Customize your runner
- [Security Hardening](docs/07-security.md) - Best practices for production
- [Workflow Examples](docs/08-workflows.md) - Real-world workflow patterns

### Operations

- [Monitoring](docs/04-monitoring.md) - Health checks and dashboards
- [Maintenance](docs/06-maintenance.md) - Updates, backups, cleanup
- [Troubleshooting](docs/05-troubleshooting.md) - Common issues and solutions

### Reference

- [FAQ](docs/faq.md) - Frequently asked questions
- [Contributing](contributing.md) - How to contribute
- [Changelog](changelog.md) - Version history

## 🏗️ Architecture

```text
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
│ │ └─ Log (<project>/health-check.log)      │   │
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

## 💰 Primary Benefit: Eliminate Per-Minute Costs

**For private repositories that exceed the free tier (2,000-3,000 minutes/month), this eliminates per-minute costs.**

### ⚖️ The Trade-Offs

Compared to GitHub-hosted runners, self-hosting on Synology means:

| Dimension | GitHub-Hosted | Self-Hosted (Synology) |
| --------- | ------------- | ---------------------- |
| **Speed** | Fast (cloud infrastructure) | **Hardware-dependent** - Varies by device |
| **Parallelism** | Multiple jobs simultaneously | **Hardware-dependent** - Single runner typical; multiple possible with sufficient resources |
| **Reliability** | Enterprise SLA, managed infrastructure | Your hardware and maintenance |
| **Maintenance** | ✅ Zero (managed by GitHub) | ❌ Your responsibility |
| **Setup** | ✅ Just works | ❌ 30-60 min setup + ongoing |
| **Cost (private)** | ❌ $0.008/min after free tier | ✅ $0 per-minute |
| **Cost (public)** | ✅ Free unlimited | ✅ Free unlimited |

### 🎯 Who This Is For

**✅ Good fit:**

- 🎨 **Hobby projects** with heavy CI usage (personal projects, side projects, open-source work)
- 🎓 **Learning** about self-hosted CI/CD infrastructure
- 💰 **Hobbyists** with private repos exceeding free tier who want to tinker and save money
- 🔬 **Experimentation** with CI/CD setups and optimization

**❌ NOT for:**

- 🏢 **Businesses or organizations** - Just pay for GitHub Actions or use enterprise CI/CD
- 💼 **Production-critical infrastructure** - Needs reliability, SLAs, and professional support
- 👔 **Professional development teams** - Your time is worth more than the cost savings
- ⚖️ **Mission-critical workflows** - Use managed infrastructure with proper support

### 🎯 When This Makes Sense Technically

Self-host if:

1. ✅ **Private repositories** exceeding free tier (actually costing you money)
2. ✅ **Hobby/learning context** (not business-critical)
3. ✅ **Comfortable managing infrastructure** (Docker, networking, monitoring)
4. ✅ **Enjoy tinkering** with self-hosted solutions

Don't self-host if:

1. ❌ **Public repositories** (already free on GitHub)
2. ❌ **Within free tier** (under 2,000-3,000 min/month = no cost savings)
3. ❌ **Business/organization use** (just pay for proper infrastructure)
4. ❌ **Want zero maintenance** (GitHub-hosted "just works")

**Performance depends entirely on your Synology hardware.** This is about hobby cost optimization and learning,
not enterprise infrastructure.

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
✅ **Enable read-only filesystem** - Included in docker-compose.yaml
✅ **Drop all capabilities** - Only add what's needed
✅ **Use tmpfs for sensitive data** - Ephemeral storage for tokens
✅ **Regular updates** - Keep runner image up to date
✅ **Monitor logs** - Watch for suspicious activity

See [Security Guide](docs/07-security.md) for complete hardening checklist.

## 📈 Monitoring Dashboard

Run the included dashboard script:

```bash
sudo bash /volume1/docker/synology-github-runner/scripts/monitoring/runner-dashboard.sh
```

```text
━━━ Container Status (github-runner) ━━━
Status:      ✅ Running
Started:     2026-01-28T20:00:00Z
Restarts:    0
Health:      healthy

━━━ Resource Usage ━━━
CPU:         45.20%
Memory:      2.1GiB / 5GiB (42.00%)

━━━ Disk Usage ━━━
Disk:        /volume1/docker/github-runner/workspace: 1117.6 GiB / 3725.3 GiB (30%)

━━━ Health-check log ━━━
  2026-01-29T12:55:00Z OK
  2026-01-29T13:00:00Z OK
```

A scheduled health check emails you once when the runner can't take jobs and once when it recovers; see the
[Monitoring Guide](docs/04-monitoring.md).

## 🤝 Contributing

Contributions welcome! Whether it's:

- 🐛 Bug reports
- 📝 Documentation improvements
- ✨ New features
- 🎨 Workflow examples
- 💡 Ideas and suggestions

See [contributing.md](contributing.md) for guidelines.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

Free to use, modify, and distribute. Attribution appreciated but not required.

## 🙏 Acknowledgments

Built with and inspired by:

- [myoung34/docker-github-actions-runner](https://github.com/myoung34/docker-github-actions-runner) -
  Docker image for GitHub runners
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
