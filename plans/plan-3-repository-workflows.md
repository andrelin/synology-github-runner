# Plan 3: Repository CI/CD Workflows

**Status:** 🔴 Not Started
**Priority:** High
**Estimated Duration:** 3-4 hours

## Overview

Implement GitHub Actions workflows for this repository to ensure code quality, security, and reliability. These workflows will run on the Synology self-hosted runner with strict resource constraints (one job at a time), making them perfect real-world examples of the patterns this repository teaches.

## Goals

- Establish automated quality checks for all contributions
- Implement security scanning for dependencies and code
- Create documentation validation workflows
- **Demonstrate resource-constrained workflow patterns**
- **Show strict concurrency controls (one job at a time)**
- Provide working examples that users can reference

## Critical Constraints

⚠️ **RESOURCE LIMITATIONS:**
- All workflows run on Synology self-hosted runner
- Very limited resources (1.5 CPU cores, 5GB RAM)
- **STRICT POLICY: Only one job at a time**
- Must use orchestrator pattern for multiple jobs
- Queue jobs instead of running parallel
- Optimize for efficiency and speed

## Workflow Architecture

### Orchestrator Pattern (Required)

All workflows MUST use this pattern to ensure only one job runs at a time:

```yaml
# Global concurrency control - CRITICAL
concurrency:
  group: synology-runner-${{ github.ref }}
  cancel-in-progress: false  # Queue jobs, don't cancel

jobs:
  job-name:
    runs-on: [self-hosted, Linux, X64]
    # Job will wait in queue if another is running
```

### Combined Jobs Strategy

Instead of separate workflows, **combine related checks into single jobs** to minimize total job count. This reduces overhead and makes better use of limited resources.

## Workflows to Implement

### 1. Quality Checks (Combined)

**File:** `.github/workflows/quality.yml`

**Purpose:** Combined quality checks (shell, docker, docs) in a single job

**Checks in ONE job:**
- Shellcheck validation
- Docker compose validation
- Documentation link checking
- Markdown linting
- Spell checking

**Triggers:**
- Push to main
- Pull requests
- Manual dispatch

**Configuration:**
```yaml
name: Quality Checks

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

# CRITICAL: Only one job at a time across entire repository
concurrency:
  group: synology-runner-${{ github.ref }}
  cancel-in-progress: false

jobs:
  quality:
    runs-on: [self-hosted, Linux, X64]

    steps:
      - uses: actions/checkout@v4

      # Shell script validation
      - name: ShellCheck
        run: |
          docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable \
            scripts/**/*.sh

      - name: Verify script executability
        run: |
          non_executable=$(find scripts -name "*.sh" -type f ! -executable)
          if [ -n "$non_executable" ]; then
            echo "Non-executable scripts found:"
            echo "$non_executable"
            exit 1
          fi

      # Docker validation
      - name: Validate docker-compose
        run: docker-compose config -q

      - name: Check for hardcoded secrets
        run: |
          if grep -E '(password|token|secret|key).*=.*[^$]' docker-compose.yml; then
            echo "Found potentially hardcoded secrets!"
            exit 1
          fi

      # Documentation validation
      - name: Setup Node for doc tools
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install documentation tools
        run: |
          npm install -g markdownlint-cli2
          npm install -g markdown-link-check

      - name: Markdown lint
        run: markdownlint-cli2 "**/*.md"

      - name: Check links
        run: |
          find . -name "*.md" -not -path "./node_modules/*" | \
            xargs -I {} markdown-link-check {}

      - name: Spell check
        run: |
          npx cspell "**/*.md" --config .github/cspell.json
```

### 2. Security Scanning

**File:** `.github/workflows/security.yml`

**Purpose:** Combined security scanning (secrets, dependencies, privacy) in a single job

**Checks in ONE job:**
- Secret scanning (gitleaks)
- Dependency vulnerabilities (Trivy)
- Privacy validation (no personal info)
- .env file protection

**Triggers:**
- Push to main
- Pull requests
- Scheduled weekly (not daily - too resource intensive)

**Configuration:**
```yaml
name: Security Scanning

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 2 * * 0'  # Weekly Sunday 2 AM
  workflow_dispatch:

# CRITICAL: Only one job at a time
concurrency:
  group: synology-runner-${{ github.ref }}
  cancel-in-progress: false

jobs:
  security:
    runs-on: [self-hosted, Linux, X64]

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Need full history for gitleaks

      # Secret scanning
      - name: Gitleaks scan
        run: |
          docker run --rm -v "$PWD:/path" zricethezav/gitleaks:latest \
            detect --source="/path" --verbose

      # Dependency scanning
      - name: Trivy filesystem scan
        run: |
          docker run --rm -v "$PWD:/workspace" \
            aquasec/trivy:latest fs /workspace \
            --severity HIGH,CRITICAL \
            --exit-code 1

      # Privacy validation - no personal info in public repo
      - name: Privacy check
        run: |
          # Check for non-RFC1918 IPs (except placeholders)
          if grep -rE --include="*.md" --include="*.yml" \
            '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' . | \
            grep -vE '(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|\<your-nas-ip\>|example|0\.0\.0\.0|127\.0\.0\.1)'; then
            echo "Found potentially real IP addresses"
            exit 1
          fi

          # Check for .env files in git
          if git ls-files | grep -E '^\.env$'; then
            echo "ERROR: .env file found in repository!"
            exit 1
          fi

      # Check for large files
      - name: Check file sizes
        run: |
          large_files=$(find . -type f -size +1M -not -path "./.git/*")
          if [ -n "$large_files" ]; then
            echo "Large files found (>1MB):"
            echo "$large_files"
            exit 1
          fi
```

### 3. Weekly Link Check

**File:** `.github/workflows/weekly-link-check.yml`

**Purpose:** Check external links weekly (separate from PR checks)

**Why separate:** External link checking is slow and can fail due to external factors. Don't block PRs on external links, but check them regularly.

**Triggers:**
- Scheduled weekly
- Manual dispatch

**Configuration:**
```yaml
name: Weekly Link Check

on:
  schedule:
    - cron: '0 3 * * 0'  # Weekly Sunday 3 AM
  workflow_dispatch:

# CRITICAL: Only one job at a time
concurrency:
  group: synology-runner-${{ github.ref }}
  cancel-in-progress: false

jobs:
  external-links:
    runs-on: [self-hosted, Linux, X64]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install link checker
        run: npm install -g markdown-link-check

      - name: Check external links
        run: |
          find . -name "*.md" -not -path "./node_modules/*" | \
            xargs -I {} markdown-link-check {} --config .github/markdown-link-check.json
        continue-on-error: true  # Don't fail on external link issues

      - name: Report results
        if: failure()
        run: |
          echo "Some external links are broken. Review the logs above."
          echo "This is informational only - does not block PRs."
```

---

## Summary: 3 Workflows Total

**Minimal workflow count for resource constraints:**

1. **quality.yml** - Combined quality checks (shell, docker, docs)
   - Runs on every push/PR
   - Fast feedback (<5 minutes)

2. **security.yml** - Combined security scanning (secrets, dependencies, privacy)
   - Runs on push to main, PRs, weekly schedule
   - More thorough (<10 minutes)

3. **weekly-link-check.yml** - External link validation
   - Runs weekly only
   - Doesn't block PRs
   - Informational only

**Total:** 3 workflows, each with strict concurrency control, queuing instead of parallel execution.

## Implementation Steps

### Step 1: Setup Configuration Files (15 minutes)

**Tasks:**
1. [ ] Create `.github/workflows/` directory
2. [ ] Create `.github/markdown-link-check.json` config
3. [ ] Create `.github/markdownlint.json` config
4. [ ] Create `.github/cspell.json` config

**Configuration files needed:**

`.github/markdown-link-check.json`:
```json
{
  "ignorePatterns": [
    {"pattern": "^http://localhost"}
  ],
  "timeout": "20s",
  "retryOn429": true,
  "retryCount": 3
}
```

`.github/markdownlint.json`:
```json
{
  "default": true,
  "MD013": false,
  "MD033": false
}
```

`.github/cspell.json`:
```json
{
  "version": "0.2",
  "language": "en",
  "words": ["synology", "planechaser", "andrelin", "kubectl", "cicd"],
  "ignorePaths": ["node_modules/**", ".git/**"]
}
```

### Step 2: Quality Workflow (1 hour)

**Tasks:**
1. [ ] Create `quality.yml` with combined checks
2. [ ] Test shellcheck locally first
3. [ ] Fix any issues found in existing scripts
4. [ ] Test docker-compose validation
5. [ ] Test documentation checks
6. [ ] Push and verify workflow runs successfully

**Verification:**
- Workflow runs in <5 minutes
- All checks pass
- Only one job executes

### Step 3: Security Workflow (1 hour)

**Tasks:**
1. [ ] Create `security.yml` with combined scanning
2. [ ] Test gitleaks locally
3. [ ] Test Trivy locally
4. [ ] Test privacy validation
5. [ ] Fix any issues discovered
6. [ ] Push and verify workflow runs

**Verification:**
- No secrets detected
- No vulnerabilities found
- Privacy checks pass
- Workflow completes in <10 minutes

### Step 4: Weekly Link Check (30 minutes)

**Tasks:**
1. [ ] Create `weekly-link-check.yml`
2. [ ] Configure to run weekly only
3. [ ] Test manually with workflow_dispatch
4. [ ] Verify external link checking works
5. [ ] Document that this is informational only

### Step 5: Documentation & Polish (1 hour)

**Tasks:**
1. [ ] Add workflow status badges to README
2. [ ] Document workflow triggers in CONTRIBUTING.md
3. [ ] Create workflow troubleshooting guide
4. [ ] Test all workflows together
5. [ ] Verify workflows don't conflict

**Deliverables:**
- README shows workflow status
- Contributing guide updated
- All workflows passing

## Success Criteria

- [ ] Only 3 workflows total (quality, security, weekly-link-check)
- [ ] All workflows use strict concurrency controls
- [ ] Each workflow completes in reasonable time (<10 minutes)
- [ ] All shell scripts pass shellcheck
- [ ] docker-compose.yml validates successfully
- [ ] Documentation has no broken links or spelling errors (internal)
- [ ] No security vulnerabilities detected
- [ ] Privacy validation passes (no personal info in repo)
- [ ] Workflows demonstrate resource-constrained patterns
- [ ] Workflow status badges in README
- [ ] Documentation explains each workflow
- [ ] Workflows serve as examples for users

## Workflow Best Practices Demonstrated

These workflows demonstrate critical patterns for resource-constrained environments:

1. **Strict Concurrency Control:**
   ```yaml
   concurrency:
     group: synology-runner-${{ github.ref }}
     cancel-in-progress: false  # Queue, don't cancel
   ```
   - Only one job at a time across entire repository
   - Jobs queue instead of failing
   - Ref-based grouping prevents conflicts

2. **Combined Jobs:**
   - Multiple related checks in single job
   - Reduces total job count
   - Minimizes startup/teardown overhead
   - Faster overall execution

3. **Resource-Aware Scheduling:**
   - Frequent checks: On push/PR (quality.yml)
   - Thorough checks: Weekly scheduled (security.yml, links)
   - Off-peak timing: 2-3 AM Sunday for scheduled jobs

4. **Container-Based Tools:**
   - Use Docker containers for tools (shellcheck, trivy, gitleaks)
   - No persistent installations needed
   - Consistent versions across runs
   - Easy cleanup

5. **Fast Feedback Priority:**
   - Quality checks first (<5 min)
   - Security checks thorough but less frequent
   - External link checks informational only

6. **Fail Fast:**
   - Shell validation before complex checks
   - Exit early on critical failures
   - Clear error messages

7. **Security:**
   - No secrets in workflow files
   - Minimal permissions
   - Read-only where possible

## Related Files

- `scripts/**/*.sh` - Scripts to be validated
- `docker-compose.yml` - Configuration to validate
- `docs/**/*.md` - Documentation to check
- `.gitignore` - Ensures .env exclusion
- `CONTRIBUTING.md` - Will document workflow expectations

## Notes

**Resource Constraints are a Feature:**
- These workflows demonstrate EXACTLY what users need to do
- Strict concurrency control shows real-world patterns
- Combined jobs show how to minimize overhead
- Every workflow is a working example

**Key Principles:**
- Only 3 workflows (minimal job count)
- Combined checks in single jobs (efficiency)
- Strict concurrency control (one job at a time)
- All workflows run on self-hosted Synology runner
- Fast feedback prioritized (quality.yml < 5 min)
- Scheduled jobs during low-traffic times (2-3 AM Sunday)

**Why This Approach:**
- Respects limited resources (1.5 CPU, 5GB RAM)
- Minimizes queue wait times
- Demonstrates best practices for users
- Works reliably in constrained environments
- Serves dual purpose: quality gates + examples

## Future Enhancements

After Plan 3 completion:
- Automated dependency updates (Dependabot/Renovate)
- Automated release workflow
- Performance regression testing
- Integration testing with actual Synology runner
- Workflow for auto-updating documentation
