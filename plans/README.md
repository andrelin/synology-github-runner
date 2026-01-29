# Implementation Plans

This directory contains the planning documents and implementation history for the self-hosted GitHub runner infrastructure.

## Active Plans

Plans are organized by priority and dependencies. Complete them in order for the best experience.

### [plan-1-repository-integration.md](plan-1-repository-integration.md)
**🔴 Not Started - DO THIS FIRST**

Integrate the existing Container Manager Project with this repository's docker-compose.yml and .env configuration.

**Priority:** Critical
**Duration:** 20-30 minutes

**Why This Matters:**
- Ensures infrastructure matches repository documentation
- Makes configuration manageable via `.env` file
- Enables easier updates and version control
- Required for monitoring integration (Plan 2)

**Quick Overview:**
1. Backup current configuration
2. Copy docker-compose.yml and create .env
3. Update Container Manager Project
4. Test and verify

---

### [plan-2-monitoring-setup.md](plan-2-monitoring-setup.md)
**⏸️ Blocked by Plan 1**

Deploy monitoring scripts and configure automated health checks with DSM Task Scheduler.

**Priority:** High
**Duration:** 2-3 hours

**What's Ready:**
- ✅ Health check script (`scripts/monitoring/runner-health-check.sh`)
- ✅ Dashboard script (`scripts/monitoring/runner-dashboard.sh`)
- ✅ Documentation (`docs/04-MONITORING.md`)

**What's Needed:**
- Deploy scripts to NAS
- Configure DSM Task Scheduler
- Set up email alerts (optional)
- Tune thresholds after observation

---

### [plan-3-repository-workflows.md](plan-3-repository-workflows.md)
**🔴 Not Started**

Implement CI/CD workflows for this repository to ensure code quality, security, and reliability.

**Priority:** High
**Duration:** 3-4 hours

**Goals:**
- Automated quality checks for all contributions
- Security scanning (dependencies, secrets, vulnerabilities)
- Documentation validation (links, spelling, formatting)
- Shell script linting with shellcheck
- Docker configuration validation
- Privacy validation (no personal info in public repo)

**Deliverables:**
- `.github/workflows/` with 6+ workflow files
- Workflow status badges in README
- Configuration files for linters
- Demonstrates best practices for self-hosted runners

---

### [plan-4-documentation-guides.md](plan-4-documentation-guides.md)
**🔴 Not Started**

Complete comprehensive documentation and create ready-to-use workflow examples for users.

**Priority:** Medium
**Duration:** 10-14 hours

**Documentation to Create:**
- `docs/00-QUICK-START.md` - 5-minute TL;DR guide
- `docs/01-PREREQUISITES.md` - System requirements
- `docs/02-INSTALLATION.md` - Step-by-step setup
- `docs/03-CONFIGURATION.md` - Configuration reference
- `docs/05-TROUBLESHOOTING.md` - Common issues & solutions
- `docs/06-MAINTENANCE.md` - Updates & cleanup
- `docs/07-SECURITY.md` - Security best practices
- `docs/08-WORKFLOWS.md` - GitHub Actions integration
- `docs/FAQ.md` - Frequently asked questions
- `CONTRIBUTING.md` - Contribution guidelines
- `CHANGELOG.md` - Version history

**Workflow Examples to Create:**
- `examples/workflows/` with 10+ ready-to-use workflow files
- Language-specific examples (Node.js, Python, Java/Kotlin, Rust)
- Advanced patterns (monorepo, releases, performance testing)
- Complete documentation and customization guide

**Also:**
- Enhanced README with badges, visuals, features
- Documentation polish and testing

---

### [plan-5-restart-reliability.md](plan-5-restart-reliability.md)
**🔴 Not Started - Critical Issue**

Fix runner crash-loop after Synology NAS restarts. Currently requires manual intervention (delete container + rebuild).

**Priority:** High
**Duration:** 2-3 hours

**Problem:**
- Runner enters crash-loop after NAS reboot
- Container repeatedly restarts but doesn't recover
- Requires manual deletion and rebuild of container

**Suspected Causes:**
- Volume mount timing issues
- Network not ready during startup
- Insufficient health check grace period
- Runner state corruption

**Proposed Solutions:**
- Enhanced health checks with longer start period
- Initialization script with pre-checks
- Improved restart policy with delays
- Startup delay to wait for volumes/network

**Temporary Workaround:**
- Delete container via Container Manager
- Rebuild project
- Runner recovers successfully

---

## Implementation History

### [implementation-history.md](implementation-history.md)

Complete implementation history from the original Planechaser project, documenting the journey from initial planning through completion of foundational phases.

**Original Phases Completed:**
- ✅ Phase 1: Preparation & Planning
- ✅ Phase 2: Docker Setup
- ✅ Phase 3: Runner Installation
- ✅ Phase 4: Workflow Migration
- ✅ Phase 5: Security Hardening
- ✅ Phase 5.5: Resource Management & Concurrency Tuning

This document is kept for historical reference and lessons learned.

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

⚠️ **CRITICAL:** Always keep plans up to date as you work. See [CLAUDE.md](../CLAUDE.md) for detailed guidance on updating plans.

**When to Update:**
- Starting a plan (🔴 → 🟡)
- Completing tasks (check boxes)
- Finishing a plan (🟡 → 🟢)
- Discovering issues or blockers
- Making architectural decisions

## Roadmap to v1.0.0

To reach version 1.0.0, complete these plans in order:

1. ✅ **Foundation** - Repository created, scripts written, core docs done
2. 🔴 **Plan 1** - Repository integration (NEXT)
3. ⏸️ **Plan 2** - Monitoring setup (blocked by Plan 1)
4. 🔴 **Plan 5** - Fix restart reliability (CRITICAL - blocks production use)
5. 🔴 **Plan 3** - CI/CD workflows (recommended before v1.0.0)
6. 🔴 **Plan 4** - Documentation & examples (recommended before v1.0.0)
7. 🔄 **Final Review** - Test everything, polish, prepare release

**Priority order:**
- **Must complete:** Plans 1, 2, 5 (core functionality + reliability)
- **Strongly recommended:** Plan 3 (quality gates for contributions)
- **Nice to have:** Plan 4 (comprehensive docs and examples)

**Critical Path:**
- Plan 1 → Plan 2 → Plan 5 (core infrastructure + monitoring + reliability)
- Plan 3 can start after Plan 1 (needs working runner for CI/CD)
- Plan 4 can be done anytime (documentation work)

**Note:** Plan 5 is CRITICAL - the runner must survive reboots for production use.

## From Planechaser Project

This infrastructure was originally built to support the Planechaser project (a Kotlin Multiplatform app) and has been extracted into its own repository for reusability and community benefit.

The architecture and patterns developed here are applicable to any GitHub repository needing self-hosted runners on resource-constrained hardware.

## Contributing to Plans

If you're working on implementing these plans:

1. Update plan files as you work (don't let them go stale)
2. Document any deviations from the original plan
3. Add lessons learned in notes sections
4. Update this README if plan structure changes

See [CONTRIBUTING.md](../CONTRIBUTING.md) (when created) for full contribution guidelines.
