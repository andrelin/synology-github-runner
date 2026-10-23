# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed (2026-10-23)

- **Installer:** `scripts/setup/install.sh` now prepares the clone it runs in as the Container Manager project:
  it writes `.env` safely (any token characters, private from creation, only the keys it is given), validates the
  configuration and creates the workspace and cache folders the compose file mounts. Tests run in CI.
- **Install and update docs:** the installation guide created the data folders inside the clone instead of where the
  compose file mounts them, and the update instructions never pulled this repository's changes.

### Added (2026-10-23)

- **`CONTAINER_NAME`**, which also names the Compose project, so `docker compose` commands in the project folder act on
  the Container Manager project

### Changed (2026-10-23)

- **DSM 7.2 is the minimum**, for Container Manager's Docker Compose v2

### Removed (2026-10-23)

- **The installer's copies** into `/volume1/docker/github-runner` and of the monitoring scripts into `/volume1/scripts`

### Fixed (2026-10-22)

- **Runner crash-loop on every start:** the custom image's `ENTRYPOINT` cleared the base
  image's `CMD`, and `USER runner` made the base entrypoint exit (`RUN_AS_ROOT` defaults to
  `true`). Rebuild the image to pick this up.
- **Restart after an outage:** the init script now waits for the workspace and GitHub
  indefinitely instead of exiting after a minute.

### Changed (2026-10-22)

- **Renamed `docker-compose.yml` to `docker-compose.yaml`**

### Added (2026-10-22)

- **GitHub App authentication** (`APP_ID`, `APP_PRIVATE_KEY`) as a non-expiring
  alternative to `GITHUB_PAT`
- **CI check** that the built image launches `Runner.Listener`

### Added (2026-01-30)

- **AI Code Review:** Pre-installed Anthropic Python SDK (v0.72.0)
- **Custom Docker Image:** Dockerfile extending myoung34/github-runner:latest
- **Build Process:** Integrated into docker-compose.yaml with automatic image building
- **Documentation:**
  - Comprehensive workflow examples guide (docs/08-workflows.md, 470 lines)
  - Quick start guide (docs/00-quick-start.md)
  - Prerequisites guide (docs/01-prerequisites.md)
  - Configuration reference (docs/03-configuration.md)
  - Troubleshooting guide (docs/05-troubleshooting.md)
  - Maintenance guide (docs/06-maintenance.md)
  - Security best practices (docs/07-security.md)
  - FAQ (docs/faq.md)
- **Utility Script:** Claude Code Review dependency installer

### Added (2026-01-29)

- **Core Infrastructure:**
  - Docker Compose configuration with security hardening
  - Configurable resource limits via environment variables
  - Container Manager Project support
- **Installation & Setup:**
  - Automated installation script (`scripts/setup/install.sh`)
  - Environment configuration template (`.env.example`)
  - Complete `.gitignore` for runner infrastructure
- **Monitoring & Operations:**
  - Health check script with 8 automated checks (`scripts/monitoring/runner-health-check.sh`)
  - Real-time dashboard script (`scripts/monitoring/runner-dashboard.sh`)
  - Monitoring documentation (docs/04-monitoring.md)
- **Documentation:**
  - Comprehensive README with feature overview
  - Installation guide (docs/02-installation.md)
  - Guide for Claude Code (CLAUDE.md)
  - Implementation plans and history
- **CI/CD Workflows:**
  - Quality checks (shellcheck, docker validation, markdown lint, link check, spell check)
  - Security scanning (secret detection, vulnerability scanning, privacy validation)
  - Weekly external link validation
  - Smart concurrency control for resource-constrained runners

### Changed

- **Docker Compose:** Now builds custom image instead of using base image directly
- **Image Tagging:** Tagged as `synology-github-runner:latest` for easy identification
- **CI Optimization:** Quality and security workflows skip execution for docs-only changes
- **Configuration:** Simplified docker-compose.yaml from 120 to 53 lines (Synology-compatible)

### Features

- 🚀 Quick setup with Container Manager Projects
- 🔒 Security hardened (minimal privileges, no-new-privileges flag)
- 📊 Built-in monitoring with health checks and dashboard
- 💪 Resource optimized for 2-core/8GB systems
- 📦 Docker-in-Docker support
- 🔄 Auto-restart on failure
- 🤖 AI Code Review ready (Anthropic SDK pre-installed)

---

*No releases created yet. First release will be tagged when project reaches stable v1.0.0.*
  
