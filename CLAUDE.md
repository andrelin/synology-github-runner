# Guide for Claude Code

This file tells you how to work effectively in this repository. Follow these guidelines when updating documentation,
improving scripts, or adding features.

## ⚠️ CRITICAL: This is a PUBLIC Repository

**READ THIS FIRST - ABSOLUTELY NO EXCEPTIONS:**

This repository is **PUBLIC** and used by the community. You MUST follow these rules:

**Keep everything generic.** This is a guide for anyone's NAS, not a record of the maintainer's.
Nothing tracked may describe the maintainer's own deployment: what their runner serves, when they deployed or
rebooted, what credential type they use, test logs from their NAS, or what else runs on it.
That applies to `plans/` as much as to `docs/`: plans record design decisions and generic test results only.
The maintainer's own setup (NAS address, login, deploy notes) belongs in the gitignored `CLAUDE.local.md`.

### ✅ ALLOWED Content

- ✅ Generic examples and placeholders (e.g., `your-username/your-repo`)
- ✅ This repository's URL: `andrelin/synology-github-runner` (it's public)
- ✅ `andrelin/dotfiles` in `.github/renovate.json` only: it extends the maintainer's shared Renovate presets
- ✅ Hardware ranges (e.g., "2-core/8GB minimum", "DS920+ tested")
- ✅ References to **Planechaser** project (it's a public project)
- ✅ General Synology NAS examples
- ✅ Common software and tools (Docker, Gradle, etc.)

### ❌ NEVER Include

- ❌ Specific hardware serial numbers or unique identifiers
- ❌ Personal domain names or URLs (only this repository's GitHub URL, plus the Renovate preset above)
- ❌ Container names for personal services
- ❌ IP addresses or network details
- ❌ Specific file paths unique to user's setup
- ❌ Personal tokens or credentials (use `ghp_xxx` placeholders)
- ❌ Other software/services running on the user's NAS

### 📝 When Writing Examples

- Use `<your-nas-ip>` not actual IP addresses
- Use `your-username/your-repo` for generic examples
- OK to use `andrelin/synology-github-runner` for this repo specifically
- Use `example.com` not real personal domains
- Use generic container names ("Web application", not specific app names)
- Use hardware specs as ranges ("2-core minimum") not exact specs

**If you're unsure whether something is personal information, ASK or use a generic placeholder.**

## What You're Working On

This is **synology-github-runner**, a self-hosted GitHub Actions runner solution for Synology NAS.
It eliminates per-minute costs for private repositories in exchange for single-job execution and maintenance
overhead. Performance is hardware-dependent. Includes security hardening, automated monitoring, and resource
optimization for constrained environments.

**Primary Use Case:** Originally built for the Planechaser project (a Kotlin Multiplatform app), but designed to be
universally applicable for any GitHub repository.

**Tech Stack:**

- Docker & Docker Compose
- Shell scripting (Bash, POSIX-compatible where possible)
- GitHub Actions workflows (YAML)
- Synology DSM 7.2+

**Target Audience:**

- 🎨 **Hobbyists** with private projects exceeding GitHub Actions free tier (2,000-3,000/month)
- 🎓 **Learners** wanting hands-on experience with self-hosted CI/CD infrastructure
- 🔬 **Tinkerers** who enjoy managing their own infrastructure
- 💰 **Personal projects** where cost savings justify the maintenance effort

**NOT for:**

- 🏢 **Businesses or organizations** - Just pay for GitHub Actions or use enterprise CI/CD solutions
- 💼 **Production-critical infrastructure** - Needs professional support, SLAs, and guaranteed reliability
- 👔 **Professional development teams** - Team's time is worth more than the cost savings
- ⚖️ **Mission-critical workflows** - Use managed infrastructure with proper support contracts

**Value Proposition:**

- 💰 **Primary benefit:** Eliminate $0.008/minute costs for private hobby projects after free tier
- 🎓 **Secondary benefit:** Learn about self-hosted CI/CD infrastructure
- 🔧 **Trade-off:** Maintenance becomes your responsibility (only universal trade-off)
- 📊 **Hardware-dependent:** Performance and parallelism both depend on device specs

**This is a hobby cost optimization and learning project, not enterprise infrastructure.**

**When NOT to recommend self-hosting:**

- Public repositories (already unlimited free on GitHub-hosted)
- Users within free tier limits (0-3,000 minutes/month) - no cost benefit
- Businesses or organizations (team time > cost savings)
- Users who want zero maintenance burden
- Anyone expecting guaranteed performance improvements

**Key principle:** Make NO claims about performance or parallelism. Hardware determines both. The ONLY universal
claims are:

1. **Cost savings** (for private repos exceeding free tier)
2. **Maintenance responsibility** (user owns it vs GitHub manages it)
3. **This guide covers single-runner setup** (multiple runners possible with sufficient hardware, but not typical
   for consumer NAS)

**Deployment Method:**

- **Synology Container Manager** with docker-compose.yaml
- **NOT** covering manual `docker run` commands
- Focus on Project-based Container Manager setup

## Repository Structure

```text
synology-github-runner/
├── README.md                          # Main landing page
├── changelog.md                       # Version history
├── docker-compose.yaml                # Runner container configuration
├── .env.example                       # Configuration template
│
├── docs/                              # Documentation guides
│   ├── 00-quick-start.md
│   ├── 01-prerequisites.md
│   ├── 02-installation.md
│   ├── 03-configuration.md
│   ├── 04-monitoring.md
│   ├── 05-troubleshooting.md
│   ├── 06-maintenance.md
│   ├── 07-security.md
│   └── 08-workflows.md
│
├── scripts/
│   ├── setup/                        # Installation scripts
│   │   └── install.sh                # Automated installer
│   ├── monitoring/                   # Health checks & dashboards
│   │   ├── runner-health-check.sh
│   │   └── runner-dashboard.sh
│   ├── ci/                           # CI checks: image start-up, workflow permissions, Renovate
│   ├── maintenance/                  # Update & cleanup scripts
│   └── utilities/                    # Helper scripts
│
├── tests/
│   ├── setup/                        # Installer tests and their stubs
│   ├── monitoring/                   # Health check and dashboard tests (Linux)
│   └── ci/fixtures/                  # Workflows that each break one permissions rule
│
├── examples/
│   └── workflows/                    # Example GitHub Actions workflows
│
└── plans/                            # Implementation history
    ├── README.md
    └── implementation-history.md     # Original planning docs
```

## Privacy and Examples

### Creating Safe Examples

**ALWAYS follow these patterns:**

```bash
# ✅ GOOD - Generic placeholders
REPO_URL=https://github.com/your-username/your-repo
ssh admin@<your-nas-ip>
scp file.sh admin@<your-nas-ip>:/volume1/scripts/

# ❌ BAD - Personal information
REPO_URL=https://github.com/jsmith/private-app-repo
ssh admin@10.0.50.200
scp file.sh admin@mynas.homedomain.local:/volume1/scripts/
```

**Hardware Examples:**

```markdown
# ✅ GOOD - Ranges and tested models
- 2-core/8GB minimum
- Tested on DS920+ (4-core/8GB)
- Works with 8GB+ RAM

# ❌ BAD - Exact specs of user's setup
- Intel Atom C2538 (4 cores @ 2.4 GHz)
- 16384 MB RAM
- DSM 7.2.1-69057 Update 5
```

**Container/Service References:**

```markdown
# ✅ GOOD - Generic
- Example web application
- Other services running
- Additional containers

# ❌ BAD - Personal services
- blog.personal-domain.com
- MyCustomWebApp container
- PersonalDevTools service
```

### When Mentioning Planechaser

Planechaser can be mentioned as an example use case:

```markdown
# ✅ ALLOWED
- "Originally built for the Planechaser project"
- "Tested with Kotlin Multiplatform projects"
- General mention as example use case

# ❌ NOT ALLOWED
- Repository URLs
- Specific implementation details
- Personal deployment URLs or domains
- Private configuration specifics
```

## Working with Shell Scripts

### Script Standards

**1. Shebang & Safety:**

```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

**2. POSIX Compatibility:**

- Use `command -v` instead of `which`
- Avoid bash-specific features where possible
- Test on multiple shells if targeting broad compatibility

**3. Error Handling:**

```bash
# Good: Check command success
if ! docker ps &> /dev/null; then
    echo "Error: Cannot access Docker"
    exit 1
fi

# Good: Use functions for repeated logic
check_prerequisites() {
    # validation logic
}
```

**4. User Feedback:**

- Use color coding for output (defined in script)
- Provide clear progress indicators
- Show helpful error messages with solutions

**5. Validation:**

- Always run ShellCheck before committing (the command is under Testing Changes)
- Test on actual Synology hardware when possible
- Include usage examples in script comments

### Script Naming Conventions

- `install.sh` - Setup/installation scripts
- `runner-*.sh` - Runner-specific operations
- `*.sh` - All scripts should have `.sh` extension
- Use kebab-case for multi-word scripts: `setup-monitoring.sh`

## Working with Documentation

### Documentation Standards

**1. Structure:**

- **Overview** - What this document covers (2-3 sentences)
- **Prerequisites** - What's needed before starting (if applicable)
- **Step-by-step instructions** - Numbered or bullet points
- **Verification** - How to confirm success
- **Troubleshooting** - Common issues and solutions

**2. Code Blocks:**

```bash
# Always include comments explaining what the command does
docker ps | grep github-runner  # Check if runner is running
```

**3. Callouts:**

```markdown
> **⚠️ Warning:** Important cautions
> **💡 Tip:** Helpful suggestions
> **✅ Success:** Expected results
```

**4. Cross-References:**

- Link to related docs: `See [Monitoring Guide](04-monitoring.md)`
- Link to external resources with context
- Keep links up-to-date

### Documentation File Naming

- `00-quick-start.md` - TL;DR guide (number indicates reading order)
- `01-prerequisites.md` - Numbered guides read sequentially
- `faq.md` - Special case, no number (alphabetical in listings)
- Filenames are lowercase kebab-case; only `README.md`, `CLAUDE.md` and `LICENSE` stay uppercase

## Container Manager Project Approach

**IMPORTANT:** This repository focuses exclusively on **Synology Container Manager Projects** using docker-compose.yaml.

### Why Container Manager Projects

- ✅ Native Synology UI integration
- ✅ Easy management (Start/Stop/Build in UI)
- ✅ Version control friendly (docker-compose.yaml in repo)
- ✅ Automatic restart on NAS reboot
- ✅ Built-in logging and monitoring

### Not Covered

- ❌ Manual `docker run` commands
- ❌ Docker Swarm or Kubernetes
- ❌ Third-party container managers
- ❌ Non-Synology Docker setups

All documentation and examples assume **Container Manager Project** setup.

## Working with Docker Compose

### Configuration Principles

**1. Security First:**

```yaml
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
read_only: true
```

**2. Resource Limits:**

```yaml
deploy:
  resources:
    limits:
      cpus: '1.5'
      memory: 5G
```

**3. Comments:**

- Explain non-obvious configurations
- Document why specific settings are used
- Include links to relevant documentation

**4. Environment Variables:**

- All secrets in `.env` file (never commit `.env`)
- Provide `.env.example` with sensible defaults
- Document all variables with comments

## Working with GitHub Actions Workflows

### IMPORTANT: When to Use Self-Hosted vs GitHub-Hosted Runners

**This repository's workflows (.github/workflows/):**

- ✅ **Use GitHub-hosted runners** (`runs-on: ubuntu-latest`)
- **Why?** This is a PUBLIC repository, so we get unlimited free minutes on GitHub-hosted runners
- **No need** for self-hosted infrastructure just to run this repo's CI/CD

**Example workflows (examples/workflows/):**

- ✅ **Use self-hosted runners** (`runs-on: [self-hosted, Linux, X64]`)
- **Why?** These are templates for users who followed this guide and set up self-hosted runners on Synology
- These examples demonstrate the **use case this repository teaches**

**Key principle:**

- Don't use self-hosted runners just because this repo is about self-hosted runners
- Use the right tool for the job: GitHub-hosted for this public repo, self-hosted in the examples to teach users

### Workflow Patterns

**1. Orchestrator Pattern** (for resource-constrained runners):

```yaml
concurrency:
  group: synology-runner
  cancel-in-progress: false  # Queue instead of cancel

jobs:
  test:
    needs: [build]  # Sequential to avoid resource exhaustion
    uses: ./.github/workflows/test.yml
```

**2. Resource Optimization:**

```yaml
env:
  GRADLE_OPTS: "-Xmx3g -XX:MaxMetaspaceSize=512m"
  ORG_GRADLE_PROJECT_org.gradle.workers.max: "2"
```

**3. Self-Hosted Runner Labels:**

```yaml
runs-on: [self-hosted, Linux, X64]
```

## Code Style Guidelines

### Shell Scripts

**Variable Naming:**

```bash
# UPPERCASE for constants
CONTAINER_NAME="github-runner"
MAX_MEMORY_PERCENT=90

# lowercase for local variables
current_status="running"
log_file="/var/log/runner.log"
```

**Functions:**

```bash
# Use descriptive names with underscores
check_container_status() {
    # implementation
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}
```

### YAML Files

**Indentation:** 2 spaces (never tabs)
**Comments:** Above the line they describe
**Alignment:** Align similar keys for readability

## Testing Changes

### Before Committing

**1. Shell Scripts:**

```bash
# Lint all scripts, tests and test stubs
find scripts tests -type f \( -name '*.sh' -o -path 'tests/*/stubs/*' \) -exec shellcheck -s bash {} +

# Run the script tests (they need Docker Compose; the monitoring tests need Linux, so run those in CI or a container)
for t in tests/*/*.test.sh; do bash "$t" || { echo "FAILED: $t"; break; }; done

# Test script execution (dry-run if available)
bash -n scripts/setup/install.sh

# Test on actual Synology (if possible)
```

**2. Docker Compose:**

```bash
# Validate configuration
docker-compose config

# Test startup
docker-compose up -d
docker-compose logs -f
```

**3. Documentation:**

- Check for broken links
- Verify code blocks are syntactically correct
- Test commands in a clean environment

### Testing Workflow

1. **Local Testing** - Test on your development machine
2. **Synology Testing** - Test on actual Synology hardware
3. **Documentation Review** - Ensure docs reflect changes
4. **Commit** - Use conventional commit messages

## Contributing Guidelines

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Format
<type>(<scope>): <description>

# Examples
feat(monitoring): add email alerts for health check failures
fix(install): resolve permission error on DSM 7.2
docs(security): add 2FA setup instructions
chore(deps): update runner image to latest version
```

**Types:**

- `feat` - New features
- `fix` - Bug fixes
- `docs` - Documentation changes
- `chore` - Maintenance tasks
- `refactor` - Code improvements without changing behavior
- `test` - Adding or updating tests
- `security` - Security improvements

### Pull Request Checklist

- [ ] Scripts pass `shellcheck`
- [ ] Docker Compose config validates
- [ ] Documentation is updated
- [ ] changelog.md is updated
- [ ] Tested on Synology (if possible)
- [ ] Commit messages follow convention
- [ ] No secrets or `.env` files committed

## Documentation Writing Tips

### Be Clear and Concise

**Good:**

```markdown
Show the runner's status:
```bash
sudo bash scripts/monitoring/runner-dashboard.sh
```

**Bad:**

```markdown
Now you can execute the health check script which will verify
that everything is working correctly by running various checks...
```

### Show Expected Output

**Good:**

```markdown
Expected output:
```text
[2026-01-29 13:00:00] ✅ All health checks passed
```

### Provide Context for Commands

```bash
# Check if runner is active (should show "Running")
docker ps | grep github-runner
```

## Implementation Plans - Keep Them Updated

**⚠️ CRITICAL:** As you develop features or make changes to this project, you MUST keep the implementation plan
files up to date.

### Why This Matters

- **Progress Tracking** - Plans document what's done, what's in progress, and what's next
- **Knowledge Preservation** - Future Claude sessions need accurate context about project state
- **Decision History** - Plans capture why choices were made, not just what was done
- **Collaboration** - Updated plans help other contributors understand the project status

### When to Update Plans

Update plan files in `plans/` directory:

1. **When Starting a Phase** - Change status from 🔴 NOT STARTED to 🟡 IN PROGRESS
2. **When Completing Tasks** - Mark tasks as ✅ COMPLETE, add completion notes
3. **When Finishing a Phase** - Change status to 🟢 COMPLETE, add summary
4. **When Discovering Issues** - Document blockers, decisions, or pivots
5. **When Changing Approach** - Update plans to reflect new direction

### How to Update Plans

```markdown
# Example: Updating phase status
## Phase 6.1: Backup Current Configuration (5 minutes)

**Status:** 🟢 COMPLETE

### Completed
- ✅ Exported Container Manager settings
- ✅ Backed up docker-compose.yaml
- ✅ Verified runner working

### Notes
- Current runner name: synology-runner
- Container using 1.5 CPU cores, 5GB memory limit
```

**Don't let plans become stale.** A plan that says "NOT STARTED" when work is actually complete is worse than no
plan at all.

## Common Pitfalls to Avoid

### Shell Scripts

**❌ Don't:**

```bash
# Using cd without checking
cd /some/path
./script.sh

# Using unquoted variables
cp $SOURCE $DEST

# Ignoring errors
command_that_might_fail
echo "Success!"
```

**✅ Do:**

```bash
# Check directory exists
if [ -d "/some/path" ]; then
    cd "/some/path" || exit 1
    ./script.sh
fi

# Quote variables
cp "$SOURCE" "$DEST"

# Handle errors
if ! command_that_might_fail; then
    echo "Error: Command failed"
    exit 1
fi
```

### Documentation

**❌ Don't:**

- Use vague language ("might need to", "probably should")
- Assume knowledge ("as you know", "obviously")
- Skip error cases
- Use outdated screenshots

**✅ Do:**

- Be specific and direct
- Explain technical terms
- Include troubleshooting sections
- Use text examples instead of screenshots (easier to maintain)

### Docker Compose

**❌ Don't:**

- Put secrets in docker-compose.yaml
- Skip resource limits
- Ignore security options
- Forget health checks

**✅ Do:**

- Use `.env` for configuration
- Set appropriate limits
- Apply security hardening
- Include health checks

## Release Process

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **Major (X.0.0)** - Breaking changes
- **Minor (x.X.0)** - New features (backward compatible)
- **Patch (x.x.X)** - Bug fixes

### Creating a Release

1. Update `changelog.md`
2. Update version references in docs
3. Create git tag: `git tag -a v1.1.0 -m "Release v1.1.0"`
4. Push tag: `git push origin v1.1.0`
5. Create GitHub Release with changelog

## Getting Help

If you're stuck:

1. **Check existing docs** - `docs/` directory
2. **Review examples** - `examples/` directory
3. **Check implementation history** - `plans/implementation-history.md`
4. **Test in isolation** - Create minimal reproduction
5. **Ask for help** - Open a GitHub issue with details

## Final Checklist

Before submitting work:

### Privacy & Public Repository ⚠️ **CRITICAL**

- [ ] **NO personal information included**
- [ ] No IP addresses, domain names, or URLs (except GitHub/Planechaser)
- [ ] No specific hardware serial numbers or unique IDs
- [ ] No personal service names (use generic descriptions)
- [ ] All examples use placeholders (`<your-nas-ip>`, `your-username/your-repo`)
- [ ] Hardware specs are ranges ("2-core minimum") not exact
- [ ] Review commit message for personal details
- [ ] Review diff for accidentally included personal info

### Code

- [ ] Shell scripts pass shellcheck
- [ ] Scripts are executable (`chmod +x`)
- [ ] Docker Compose validates
- [ ] No secrets committed (check for tokens, passwords)
- [ ] Comments explain "why" not "what"
- [ ] Examples are generic and reusable

### Documentation

- [ ] Clear and concise
- [ ] Includes generic examples (not personal setup)
- [ ] Cross-references updated
- [ ] No broken links
- [ ] Follows naming conventions
- [ ] No screenshots with personal information
- [ ] **Implementation plans updated** with current status

### Testing

- [ ] Tested locally (if possible)
- [ ] Tested on Synology (if applicable)
- [ ] Error cases handled
- [ ] Documentation matches behavior
- [ ] Examples actually work

### Git

- [ ] Conventional commit messages
- [ ] changelog.md updated
- [ ] .env.example updated (if config changed)
- [ ] Co-authored-by attribution (if applicable)
- [ ] **Final privacy check before push**

## Before Every Commit

Run this mental checklist:

1. **Privacy Check:**
   - Would I be comfortable if anyone on the internet saw this?
   - Are all examples generic enough for anyone to use?
   - Did I accidentally include IPs, domains, or service names?

2. **Quality Check:**
   - Does this help the community?
   - Is it well-documented?
   - Would someone else understand this?

3. **Consistency Check:**
   - Matches repository style?
   - Follows naming conventions?
   - Properly categorized?

**Remember:** This repository helps people worldwide set up self-hosted runners on Synology NAS. Generic,
well-documented examples are more valuable than specific configurations.

---

**Remember:** This repository helps people eliminate GitHub Actions minute limits and run unlimited CI/CD. Quality
documentation and reliable scripts are crucial for user success.
