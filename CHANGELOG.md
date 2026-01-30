# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added (2026-01-30)
- Claude Code Review support with pre-installed Anthropic Python SDK
- Custom Dockerfile extending myoung34/github-runner:latest
- Build process integrated into docker-compose.yml
- Comprehensive workflow examples guide (docs/08-WORKFLOWS.md)
- CI workflow optimization with path filters for docs/plans

### Added (2026-01-29)
- Docker Compose configuration with security hardening
- Automated installation script (`scripts/setup/install.sh`)
- Health monitoring script (`scripts/monitoring/runner-health-check.sh`)
- Real-time dashboard script (`scripts/monitoring/runner-dashboard.sh`)
- Comprehensive documentation (README, installation guide, monitoring guide)
- Environment configuration template (`.env.example`)
- Complete `.gitignore` for runner infrastructure
- CI/CD workflows (quality checks, security scanning, link validation)

### Changed
- Docker Compose now builds custom image instead of using base image directly
- Image tagged as `synology-github-runner:latest` for easy identification
- Quality and security workflows skip execution for docs-only changes

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
  
