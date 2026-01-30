# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added (2026-01-30)
- **AI Code Review:** Pre-installed Anthropic Python SDK (v0.72.0)
- **Custom Docker Image:** Dockerfile extending myoung34/github-runner:latest
- **Build Process:** Integrated into docker-compose.yml with automatic image building
- **Documentation:**
  - Comprehensive workflow examples guide (docs/08-WORKFLOWS.md, 470 lines)
  - Quick start guide (docs/00-QUICK-START.md)
  - Prerequisites guide (docs/01-PREREQUISITES.md)
  - Configuration reference (docs/03-CONFIGURATION.md)
  - Troubleshooting guide (docs/05-TROUBLESHOOTING.md)
  - Maintenance guide (docs/06-MAINTENANCE.md)
  - Security best practices (docs/07-SECURITY.md)
  - FAQ (docs/FAQ.md)
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
  - Monitoring documentation (docs/04-MONITORING.md)
- **Documentation:**
  - Comprehensive README with feature overview
  - Installation guide (docs/02-INSTALLATION.md)
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
- **Configuration:** Simplified docker-compose.yml from 120 to 53 lines (Synology-compatible)

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
  
