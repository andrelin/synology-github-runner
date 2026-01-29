 # Changelog

  All notable changes to this project will be documented in this file.

  The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
  and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

  ## [Unreleased]

  ## [1.0.0] - 2026-01-29

  ### Added
  - Initial release
  - Docker Compose configuration with security hardening
  - Automated installation script (`scripts/setup/install.sh`)
  - Health monitoring script (`scripts/monitoring/runner-health-check.sh`)
  - Real-time dashboard script (`scripts/monitoring/runner-dashboard.sh`)
  - Comprehensive README with quick start guide
  - Environment configuration template (`.env.example`)
  - Complete `.gitignore` for runner infrastructure

  ### Features
  - 🚀 30-minute automated setup
  - 🔒 Security hardened (read-only FS, minimal privileges)
  - 📊 Health monitoring with 8 automated checks
  - 💪 Optimized for 2-core/8GB systems
  - 📦 Docker-in-Docker support
  - 🔄 Auto-restart on failure

  [Unreleased]: https://github.com/andrelin/synology-github-runner/compare/v1.0.0...HEAD
  [1.0.0]: https://github.com/andrelin/synology-github-runner/releases/tag/v1.0.0
  
