# Implementation Plans

This directory contains the planning documents and implementation history for the self-hosted GitHub runner infrastructure.

## Active Plans

Plans 7, 2 and 8 are complete; Plan 6 is the one left.
Plan 6 is the least important and always stays last: it gets done only if the others are finished.

### [plan-6-multi-repo-runner.md](plan-6-multi-repo-runner.md)

**🔴 Not Started**

Run CI for several private repositories on one NAS: one runner per repository, or a free organization with one
org-level runner.
Fixes organization scope, which is broken today, and lets the compose file run as several projects.

---

## Archived Plans

Completed plans live in [archive/](archive/) for reference.

- [Plan 1: Repository integration](archive/plan-1-repository-integration.md) - `docker-compose.yaml` aligned with
  a working Synology setup, secrets moved to `.env`
- [Plan 3: Repository workflows](archive/plan-3-repository-workflows.md) - CI for this repository: quality,
  security and weekly link checks (complete 2026-01-30)
- [Plan 4: Documentation guides](archive/plan-4-documentation-guides.md) - the `docs/` guides and
  `examples/workflows/` (complete 2026-01-30)
- [Plan 5: Restart reliability](archive/plan-5-restart-reliability.md) - runner recovers by itself after NAS
  reboots and network outages (the first fix did not work; fixed and reboot-tested in the second attempt)
- [Plan 2: Monitoring](archive/plan-2-monitoring-setup.md) - a scheduled health check that emails once per
  incident and once on recovery, and a dashboard (complete 2026-10-23)
- [Plan 7: An installer that works](archive/plan-7-installer.md) - `install.sh` prepares the clone as the Container
  Manager project, with tests in CI (complete 2026-10-23)
- [Plan 8: Publish the runner image](archive/plan-8-publish-image.md) - CI builds, tests, attests and publishes the
  image to GHCR; the compose file pulls it (complete 2026-10-23)

---

## Implementation History

### [implementation-history.md](implementation-history.md)

Lessons learned while building the original setup this guide was extracted from:
memory sizing, sequential jobs, concurrency groups and hardening limits.

---

## Recent Updates

### 2026-01-30: Claude Code Review Support

**Added AI-Powered Code Review Capabilities:**

- ✅ Created custom Dockerfile extending `myoung34/github-runner:latest`
- ✅ Pre-installed Anthropic Python SDK (v0.72.0) for Claude Code Review
- ✅ Updated docker-compose.yaml to build custom image
- ✅ Image tagged as `synology-github-runner:latest`
- ✅ Created comprehensive workflow guide (docs/08-workflows.md)
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
- ✅ Aligned docker-compose.yaml with a working Synology configuration
- ✅ Made all resource limits configurable via .env file
- ✅ Created comprehensive installation guide (478 lines)

**Configuration Improvements:**

- ✅ Simplified docker-compose.yaml (120 lines → 48 lines, now 53 with build)
- ✅ Removed unnecessary features (networks, healthcheck, logging, read_only)
- ✅ Added environment variable support for all configurable values
- ✅ Included resource tuning guide for different NAS configurations
- ✅ Documented Container Manager Project approach

**Documentation Added:**

- ✅ `docs/02-installation.md` - Complete installation guide
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

1. ✅ **Foundation** - Repository created, scripts written, core docs done
2. ✅ **Plan 1** - Repository integration
3. ✅ **Plan 3** - CI/CD workflows
4. ✅ **Plan 4** - Documentation & examples
5. ✅ **Plan 5** - Restart reliability
6. ✅ **Plan 7** - Working installer
7. ✅ **Plan 2** - Monitoring
8. ✅ **Plan 8** - Published image
9. 🔄 **Final Review** - Test everything, polish, prepare release

Plan 6 (multi-repo runner) is not required for v1.0.0.

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

See [contributing.md](../contributing.md) (when created) for full contribution guidelines.
