# Implementation Plans

This directory contains the planning documents and implementation history for the self-hosted GitHub runner infrastructure.

## Active Plans

Plans are organized by priority and dependencies. Complete them in order for the best experience.

### [plan-1-repository-integration.md](plan-1-repository-integration.md)

**🟢 Complete (Simplified) - 2026-01-29**

Repository docker-compose.yml now matches production Synology configuration.
Only remaining task is creating `.env` file on Synology to separate secrets from
configuration.

**What Was Completed:**

- ✅ Updated docker-compose.yml to match production Synology setup
- ✅ Simplified from 120 lines to 48 lines (Synology-compatible syntax)
- ✅ Made all resource limits configurable via .env file
- ✅ Created comprehensive installation guide (docs/02-INSTALLATION.md)
- ✅ Git-based approach documented (clone repo on Synology)
- ✅ Container Manager Project workflow documented

**Remaining:**

- [ ] Follow installation guide to create `.env` file on Synology
- [ ] Create Container Manager Project pointing to repository

**Priority:** Critical (but mostly done)
**Duration:** 5 minutes (just create .env)

---

### [plan-2-monitoring-setup.md](plan-2-monitoring-setup.md)

**🟡 Ready to Start**

Deploy monitoring scripts and configure automated health checks with DSM Task Scheduler.

**Prerequisites:**

- ✅ Plan 1 complete (docker-compose.yml matches production)
- ✅ Monitoring scripts exist (runner-health-check.sh, runner-dashboard.sh)
- ✅ Documentation exists (docs/04-MONITORING.md)

**What's Needed:**

- Deploy scripts to NAS
- Configure DSM Task Scheduler
- Set up email alerts (optional)
- Tune thresholds after observation

**Priority:** High
**Duration:** 2-3 hours

---

### [plan-3-repository-workflows.md](plan-3-repository-workflows.md)

**🟢 Complete - 2026-01-30**

CI/CD workflows for this repository ensuring code quality, security, and reliability.

**Completed Deliverables:**

- ✅ `.github/workflows/quality.yml` - Shellcheck, Docker, Markdown, Spell check
- ✅ `.github/workflows/security.yml` - Gitleaks, Trivy, Privacy validation
- ✅ `.github/workflows/weekly-link-check.yml` - External link validation
- ✅ Workflow status badges in README
- ✅ Smart concurrency control (per-workflow, per-branch)
- ✅ Skip workflows when only docs/plans change
- ✅ Renovate automated dependency updates
- ✅ CONTRIBUTING.md with workflow documentation

**Priority:** Complete
**Duration:** 3 hours actual

---

### [plan-4-documentation-guides.md](plan-4-documentation-guides.md)

**🟢 Complete - 2026-01-30**

Comprehensive documentation and ready-to-use workflow examples for users.

**Completed Deliverables:**

- ✅ `docs/00-QUICK-START.md` - 5-minute TL;DR guide
- ✅ `docs/01-PREREQUISITES.md` - Hardware/software requirements
- ✅ `docs/02-INSTALLATION.md` - Step-by-step installation
- ✅ `docs/03-CONFIGURATION.md` - Complete config reference
- ✅ `docs/04-MONITORING.md` - Monitoring setup
- ✅ `docs/05-TROUBLESHOOTING.md` - Comprehensive troubleshooting (2,100+ lines)
- ✅ `docs/06-MAINTENANCE.md` - Update & cleanup procedures
- ✅ `docs/07-SECURITY.md` - Security best practices (708 lines)
- ✅ `docs/08-WORKFLOWS.md` - Advanced workflow patterns
- ✅ `docs/FAQ.md` - 50+ questions answered
- ✅ `examples/workflows/` - 7 production-ready workflow examples
  - basic-ci.yml, orchestrator.yml, docker-build.yml
  - nodejs-ci.yml, python-ci.yml, gradle-ci.yml, rust-ci.yml

**Total:** 10 documentation guides + 7 workflow examples

**Priority:** Complete
**Duration:** 7 hours actual (completed in 3 phases)

---

### [plan-6-multi-repo-runner.md](plan-6-multi-repo-runner.md)

**🔴 Not Started**

Investigate and document how to configure a single runner to serve multiple repositories under a personal GitHub account.

**Goals:**

- Research how GitHub runners work with multiple repos
- Test both personal account and organization-level approaches
- Document simplest working solution with step-by-step instructions
- Provide migration guide from single-repo to multi-repo setup

**Key Questions:**

- Can repository-level runner serve multiple repos in personal account?
- Should users create a GitHub Organization?
- What are pros/cons of each approach?
- How do concurrent jobs from different repos interact?

**Deliverables:**

- `docs/09-MULTI-REPO-SETUP.md` - Complete multi-repo guide
- Updated configuration documentation
- Tested migration path
- Clear recommendation: personal vs organization approach

**Priority:** Medium
**Duration:** 2-3 hours

---

### [plan-5-restart-reliability.md](plan-5-restart-reliability.md)

**🟡 In Progress - first fix (2026-02-09) did not work; second attempt underway**

Fix runner crash-loop after Synology NAS restarts. Currently requires manual intervention (delete container + rebuild).

**Priority:** High (blocks production use)
**Duration:** 2-3 hours

**Problem:**

- Runner enters crash-loop after NAS reboot
- Container repeatedly restarts but doesn't recover
- Requires manual deletion and rebuild of container

**Proposed Solutions:**

- Enhanced health checks with longer start period
- Initialization script with pre-checks
- Improved restart policy with delays
- Startup delay to wait for volumes/network

---

## Implementation History

### [implementation-history.md](implementation-history.md)

Complete implementation history from the original Planechaser project,
documenting the journey from initial planning through completion of foundational
phases.

**Original Phases Completed:**

- ✅ Phase 1: Preparation & Planning
- ✅ Phase 2: Docker Setup
- ✅ Phase 3: Runner Installation
- ✅ Phase 4: Workflow Migration
- ✅ Phase 5: Security Hardening
- ✅ Phase 5.5: Resource Management & Concurrency Tuning

This document is kept for historical reference and lessons learned.

---

## Recent Updates

### 2026-01-30: Claude Code Review Support

**Added AI-Powered Code Review Capabilities:**

- ✅ Created custom Dockerfile extending `myoung34/github-runner:latest`
- ✅ Pre-installed Anthropic Python SDK (v0.72.0) for Claude Code Review
- ✅ Updated docker-compose.yml to build custom image
- ✅ Image tagged as `synology-github-runner:latest`
- ✅ Created comprehensive workflow guide (docs/08-WORKFLOWS.md)
- ✅ Added Claude Code Review example with Python script
- ✅ Updated README with AI Code Review feature
- ✅ Updated CHANGELOG for v1.1.0 release

**Prerequisites Verified (in runner image):**

- ✅ Python 3.8.10 (compatible with Anthropic SDK)
- ✅ GitHub CLI 2.86.0 (for PR interactions)
- ✅ pip 20.0.2 (for package management)
- ✅ Anthropic SDK 0.72.0 (pre-installed)

**Benefits:**

- No runtime dependency installation needed
- Faster workflow execution (dependencies ready)
- Supports AI-powered code review out of the box
- Compatible with Claude Code Review and similar tools

### 2026-01-29: Repository Cleanup & Alignment

**Repository Cleanup:**

- ✅ Squashed commit history (10 commits → 2 commits)
- ✅ Fixed broken .gitignore (leading spaces prevented all patterns from working)
- ✅ Cleaned up empty directories (removed config/, added .gitkeep files)
- ✅ Aligned docker-compose.yml with production Synology configuration
- ✅ Made all resource limits configurable via .env file
- ✅ Created comprehensive installation guide (478 lines)

**Configuration Improvements:**

- ✅ Simplified docker-compose.yml (120 lines → 48 lines, now 53 with build)
- ✅ Removed unnecessary features (networks, healthcheck, logging, read_only)
- ✅ Added environment variable support for all configurable values
- ✅ Included resource tuning guide for different NAS configurations
- ✅ Documented Container Manager Project approach

**Documentation Added:**

- ✅ `docs/02-INSTALLATION.md` - Complete installation guide
  - Git-based repository cloning
  - Container Manager Project creation
  - Step-by-step verification
  - Troubleshooting section
  - Security best practices

---

## Plan Status Legend

- 🔴 **Not Started** - Plan created, work not begun
- 🟡 **In Progress** - Currently being worked on
- 🟢 **Complete** - All tasks finished and verified
- ⏸️ **Blocked** - Waiting on dependencies
- 🔄 **In Review** - Under testing or review

## Using These Plans

The implementation plans serve multiple purposes:

1. **Work Planning** - Clear tasks and acceptance criteria
2. **Progress Tracking** - Update status as work progresses
3. **Knowledge Preservation** - Document decisions and context
4. **Future Reference** - Guide for similar projects

### How to Work With Plans

1. **Read the full plan** before starting work
2. **Update status** as you progress (🔴 → 🟡 → 🟢)
3. **Document decisions** in notes sections
4. **Mark tasks complete** with checkboxes
5. **Add observations** about what worked/didn't work

### Keeping Plans Updated

⚠️ **CRITICAL:** Always keep plans up to date as you work. See
[CLAUDE.md](../CLAUDE.md) for detailed guidance on updating plans.

**When to Update:**

- Starting a plan (🔴 → 🟡)
- Completing tasks (check boxes)
- Finishing a plan (🟡 → 🟢)
- Discovering issues or blockers
- Making architectural decisions

## Roadmap to v1.0.0

To reach version 1.0.0, complete these plans in order:

1. ✅ **Foundation** - Repository created, scripts written, core docs done
2. 🟢 **Plan 1** - Repository integration (MOSTLY COMPLETE - just create .env)
3. 🟡 **Plan 2** - Monitoring setup (READY TO START)
4. 🔴 **Plan 5** - Fix restart reliability (CRITICAL - blocks production use)
5. 🔴 **Plan 3** - CI/CD workflows (recommended before v1.0.0)
6. 🟡 **Plan 4** - Documentation & examples (in progress, ~60% complete)
7. 🔄 **Final Review** - Test everything, polish, prepare release

**Priority order:**

- **Must complete:** Plans 1, 2, 5 (core functionality + reliability)
- **Strongly recommended:** Plan 3 (quality gates for contributions)
- **Nice to have:** Plan 4 completion (comprehensive docs and examples)

**Critical Path:**

- Plan 1 (mostly done) → Plan 2 → Plan 5 (core infrastructure + monitoring + reliability)
- Plan 3 can start anytime (needs working runner for CI/CD)
- Plan 4 is ongoing (documentation work)

**Note:** Plan 5 is CRITICAL - the runner must survive reboots for production use.

## From Planechaser Project

This infrastructure was originally built to support the Planechaser project (a
Kotlin Multiplatform app) and has been extracted into its own repository for
reusability and community benefit.

The architecture and patterns developed here are applicable to any GitHub
repository needing self-hosted runners on resource-constrained hardware.

## Contributing to Plans

If you're working on implementing these plans:

1. Update plan files as you work (don't let them go stale)
2. Document any deviations from the original plan
3. Add lessons learned in notes sections
4. Update this README if plan structure changes

See [CONTRIBUTING.md](../CONTRIBUTING.md) (when created) for full contribution guidelines.
