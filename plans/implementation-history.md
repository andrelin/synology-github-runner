# Plan 1: Self-Hosted GitHub Runner

**Part of:** Project 1 - Infrastructure & Tooling
**Duration:** 1-2 days
**Priority:** Critical
**Status:** In Progress - Phase 5 Complete, Phase 5.5 Ongoing

## Overview

Set up a self-hosted GitHub Actions runner on Synology NAS to eliminate GitHub Actions minute limitations and provide unlimited CI/CD capacity for the Planechaser project.

## Prerequisites

- Synology NAS with DSM 7.0+
- Container Manager installed and running
- 2+ CPU cores, 8+ GB RAM available
- GitHub Personal Access Token with repo and workflow scopes

## Hardware Configuration

**Example Synology NAS Specs:**
```
✅ DSM Version: 7.0+
✅ Container Manager: Running Docker containers
✅ CPU: 2 cores minimum
✅ RAM: 8 GB minimum

⚠️ Existing Containers:
├─ Example web application
├─ Other services
└─ GitHub runner will share resources
```

**Resource Allocation Plan:**
```yaml
Optimized for 2-core/8GB NAS:
├─ GitHub Runner: 5GB RAM, 1536 CPU shares (higher priority)
├─ Other services: Lower priority, limited resources as needed
└─ Reserve: ~0.5 cores + 1-2 GB for DSM
```

**Actual Configuration:**
- Container Manager Project at `/volume1/docker/github-runner/`
- Using myoung34/github-runner:latest image
- Repository: your-username/your-repo
- Runner name: synology-runner
- Labels: self-hosted, Linux, X64, synology, general

## Phases

### Phase 1: Preparation & Planning (30 minutes)

**Objectives:**
- Verify system resources
- Generate GitHub Personal Access Token
- Plan runner configuration

**Steps:**

1. **Generate GitHub PAT:**
   - Navigate to: https://github.com/settings/tokens
   - Click: "Generate new token (classic)"
   - Token name: `Synology Runner - Planechaser`
   - Select scopes: `repo`, `workflow`
   - Save token securely

2. **Verify NAS Resources:**
   ```bash
   ssh admin@<nas-ip>
   docker ps
   docker stats --no-stream
   ```

**Deliverables:**
- GitHub PAT generated and saved
- Resource allocation plan verified
- Storage directories planned

### Phase 2: Docker Setup (1 hour)

**Objectives:**
- Configure Docker storage
- Create persistent directories
- Pull GitHub runner Docker image

**Steps:**

1. **Create storage directories:**
   ```bash
   ssh admin@<nas-ip>

   # Create persistent directories
   mkdir -p /volume1/docker/github-runner/workspace
   mkdir -p /volume1/docker/github-runner/cache

   # Set permissions
   chmod 755 /volume1/docker/github-runner/workspace
   chmod 755 /volume1/docker/github-runner/cache
   ```

2. **Pull runner image:**
   ```bash
   docker pull myoung34/github-runner:latest
   ```

**Deliverables:**
- Storage directories created
- Docker image downloaded
- Permissions configured

### Phase 3: Runner Installation (2 hours)

**Objectives:**
- Install and configure GitHub runner
- Register runner with repository
- Verify connection

**Steps:**

1. **Start runner container:**
   ```bash
   # Set your GitHub PAT
   export GITHUB_PAT="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

   # Start runner
   docker run -d \
     --name github-runner \
     --restart unless-stopped \
     --cpus="1.5" \
     --cpu-shares=768 \
     --memory="5g" \
     --memory-swap="5g" \
     -e RUNNER_NAME="synology-runner" \
     -e REPO_URL="https://github.com/your-username/your-repo" \
     -e ACCESS_TOKEN="${GITHUB_PAT}" \
     -e GRADLE_OPTS="-Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200" \
     -v /volume1/docker/github-runner/workspace:/workspace \
     -v /volume1/docker/github-runner/cache:/cache \
     -v /var/run/docker.sock:/var/run/docker.sock \
     myoung34/github-runner:latest
   ```

2. **Verify runner:**
   ```bash
   # Check container status
   docker ps | grep github-runner

   # Check runner logs
   docker logs github-runner

   # Verify in GitHub
   # Navigate to: https://github.com/your-username/your-repo/settings/actions/runners
   ```

**Deliverables:**
- Runner container running
- Runner registered with GitHub repository
- Connection verified

### Phase 4: Workflow Migration (2 hours)

**Objectives:**
- Update workflows to use self-hosted runner
- Configure concurrency controls
- Test workflow execution

**Steps:**

1. **Update workflow files:**
   ```yaml
   # Example: .github/workflows/shared-tests.yml
   jobs:
     test:
       runs-on: [self-hosted, linux]  # Changed from ubuntu-latest
   ```

2. **Add concurrency controls:**
   ```yaml
   concurrency:
     group: ci-${{ github.ref }}
     cancel-in-progress: true
   ```

3. **Test workflows:**
   - Push test commit to trigger workflow
   - Monitor execution in GitHub Actions
   - Verify runner picks up jobs

**Deliverables:**
- All workflows updated
- Concurrency groups configured
- Successful test run completed

### Phase 5: Security Hardening (1 hour)

**Objectives:**
- Implement least privilege
- Enable network isolation
- Configure auto-updates
- Set up monitoring

**Steps:**

1. **Security checklist:**
   - [x] GitHub PAT has minimal required scopes (repo + workflow only)
   - [x] Runner container has security hardening (no-new-privileges, cap_drop, tmpfs)
   - [~] Network access restricted to GitHub API only (not feasible with Docker socket access)
   - [~] Runner auto-updates enabled (using latest tag, manual checks recommended)
   - [ ] Monitoring configured for suspicious activity (moved to Phase 6)

2. **Update runner with security settings:**
   ```bash
   # Stop existing runner
   docker stop github-runner
   docker rm github-runner

   # Restart with security hardening
   docker run -d \
     --name github-runner \
     --restart unless-stopped \
     --cpus="1.5" \
     --memory="5g" \
     --read-only \
     --tmpfs /tmp \
     --tmpfs /run \
     -e RUNNER_NAME="synology-runner" \
     -e REPO_URL="https://github.com/your-username/your-repo" \
     -e ACCESS_TOKEN="${GITHUB_PAT}" \
     -v /volume1/docker/github-runner/workspace:/workspace \
     -v /volume1/docker/github-runner/cache:/cache \
     myoung34/github-runner:latest
   ```

**Deliverables:**
- Security hardening completed
- Runner configured with minimal permissions
- Security monitoring enabled

### Phase 6: Monitoring Setup (1 hour)

**Objectives:**
- Create health check script
- Schedule automated monitoring
- Configure alerting

**Steps:**

1. **Create health check script:**
   ```bash
   # Create monitoring directory
   mkdir -p /volume1/scripts

   # Create health check script
   cat > /volume1/scripts/runner-health-check.sh << 'EOF'
   #!/bin/bash
   # GitHub Runner Health Check

   CONTAINER="github-runner"

   # Check if container is running
   if ! docker ps | grep -q $CONTAINER; then
       echo "ALERT: $CONTAINER is not running!"
       exit 1
   fi

   # Check container health
   STATUS=$(docker inspect --format='{{.State.Status}}' $CONTAINER)
   if [ "$STATUS" != "running" ]; then
       echo "ALERT: $CONTAINER status is $STATUS"
       exit 1
   fi

   echo "OK: $CONTAINER is healthy"
   EOF

   chmod +x /volume1/scripts/runner-health-check.sh
   ```

2. **Schedule health checks in DSM Task Scheduler:**
   - Schedule: Every 5 minutes
   - Command: `/volume1/scripts/runner-health-check.sh`

**Deliverables:**
- Health check script created
- Monitoring scheduled
- Alerts configured

## Implementation Status

### Completed Phases

**✅ Phase 1: Preparation & Planning** (Completed)
- GitHub PAT generated and saved in 1Password
- NAS resources verified (adequate CPU, RAM, and disk space)
- Storage directories planned

**✅ Phase 2: Docker Setup** (Completed)
- Created `/volume1/docker/github-runner/workspace`
- Created `/volume1/docker/github-runner/cache`
- Pulled myoung34/github-runner:latest image
- Set up Container Manager Project (preferred over terminal)

**✅ Phase 3: Runner Installation** (Completed)
- Runner container deployed via Container Manager Project
- Resource limits configured (5GB RAM, 1536 CPU shares)
- Other services prioritized lower than runner
- Runner registered as: **synology-runner**
- Status: ✅ Idle and ready

**✅ Phase 4: Workflow Migration** (Completed)
- Updated 8 Linux-compatible workflows to use self-hosted runner
- Kept 2 iOS workflows on GitHub-hosted macOS runners (continue-on-error enabled, GitHub minutes depleted)
- Established orchestrator pattern for CI/CD:
  - **01-test-build-and-deploy.yml**: Main orchestrator with automatic triggers (push to main, PR to main)
  - Calls reusable workflows: 02, 03.1, 03.2, 03.3, 04
  - Component workflows: Use `workflow_call` only (no auto-triggers)
  - Prevents duplicate runs (orchestrator handles all triggers)

- Workflows migrated to self-hosted:
  - 01-test-build-and-deploy.yml (orchestrator: auto on push/PR to main)
  - 02-test-shared.yml (reusable: called by orchestrator)
  - 03.1-test-web-app.yml (reusable: called by orchestrator)
  - 03.3-test-android-app.yml (reusable: called by orchestrator)
  - 04-build-and-deploy-web-app.yml (reusable: called by orchestrator, main branch only)
  - quality-qodana.yml (independent: auto on push to main)
  - 05-docker-promote.yml (manual only)
  - ai-claude.yml (event-driven: issue/PR comments)

- iOS workflow (GitHub-hosted macOS):
  - 03.2-test-ios-app.yml (reusable: called by orchestrator, continue-on-error: true)

**✅ Phase 5: Security Hardening** (Completed)
- ✅ GitHub PAT scopes reduced to minimal (`repo` + `workflow` only, removed `packages:write`)
- ✅ Container security hardening applied:
  - `security_opt: no-new-privileges:true` - Prevents privilege escalation
  - `cap_drop: ALL` + selective `cap_add` - Minimal Linux capabilities
  - `tmpfs` mounts for `/tmp` and `/run` - Secure in-memory storage
- ⚠️ Network isolation: Not implemented due to Docker socket access requirement
  - Runner needs `/var/run/docker.sock` for building containers
  - Complete isolation would break Docker builds and dependency downloads
- ℹ️ Auto-updates: Using `latest` tag with manual update checks recommended
  - Consider periodic `docker pull myoung34/github-runner:latest` and `docker compose restart`
- 📝 Note: Runner container had to be rebuilt after applying security settings
  - In-progress workflows will hang and need to be manually cancelled
  - Cancel via: `gh run cancel <run-id>` or GitHub Actions UI

**🔧 Phase 5.5: Resource Management & Concurrency Tuning** (In Progress)
After Phase 5 completion, discovered resource constraints requiring workflow optimization:

**Issues Identified:**
1. ⚠️ **Memory constraints**: Initial workflow runs hit OOM errors
   - Synology: 2-core, 8GB RAM total, runner has 5GB container limit
   - Gradle configured for 8GB heap (too large for CI)
   - Solution: Added GRADLE_OPTS environment variables to workflows (3GB heap, 2 workers)

2. ⚠️ **Parallel execution risk**: Web + Android tests could run simultaneously
   - Each needs 3GB, would exceed 5GB container limit
   - Solution: Made Android sequential after Web (`needs: [test-shared, test-web-app]`)

3. ⚠️ **Concurrency deadlock**: Orchestrator pattern breaks with concurrency groups
   - **CRITICAL BUG DISCOVERED**: Workflows cancelled with "deadlock detected for concurrency group"
   - Cause: Both orchestrator (01) and reusable workflows (02, 03.x, 04) have concurrency groups
   - When parent calls child with same group, GitHub detects deadlock
   - **Solution**: Remove concurrency groups from reusable workflows (workflow_call only)
   - Only top-level workflows should have concurrency control

**Actions Taken:**
- ✅ Restored local dev to 8GB heap, 8 workers for M1 Max performance (gradle.properties)
- ✅ Added GRADLE_OPTS environment variables to all self-hosted workflows:
  - 02-test-shared.yml, 03.1-test-web-app.yml, 03.3-test-android-app.yml
  - 04-build-and-deploy-web-app.yml (via Dockerfile build arg)
  - quality-qodana.yml, ai-claude.yml
  - Sets: `-Xmx3g -XX:MaxMetaspaceSize=512m` and `org.gradle.workers.max=2`
- ✅ Made Android tests sequential after Web tests in orchestrator
  - Changed: `needs: [test-shared, test-web-app]` (was just `test-shared`)
  - Prevents parallel web+Android execution (would need 6-7GB, exceeds 5GB limit)
- ✅ Updated Dockerfile to accept GRADLE_OPTS as build arg with sensible defaults
- 🔄 Concurrency groups: Multiple attempts, current state unclear

**Current Concurrency Configuration:**
The workflows currently use separate groups from last commit (24d0cb1):
- `synology-ci-builds`: CI/CD workflows (01, 02, 03.1, 03.3, 04, qodana)
- `synology-docker-ops`: Docker promotion (05)
- `synology-claude-{issue-number}`: Claude AI (per-issue)
- All use `cancel-in-progress: true` except Claude (`false`)

**Problem:** Different groups allow parallel execution, defeating resource constraints.

**Next Steps:**
1. **CRITICAL**: Fix concurrency deadlock (discovered during testing)
   - Remove concurrency groups from reusable workflows: 02, 03.1, 03.3, 04
   - Keep concurrency only on top-level workflows:
     - 01-test-build-and-deploy.yml (orchestrator)
     - quality-qodana.yml (independent)
     - ai-claude.yml (independent, per-issue)
     - 05-docker-promote.yml (independent, manual)
   - Use `cancel-in-progress: false` to queue jobs instead of cancelling
2. **Get first successful workflow run** to validate all optimizations
3. Monitor resource usage (CPU, memory) during successful run
4. Proceed to Phase 6 only after successful validation

**Commits Made (Phase 5.5):**
1. `93d9432` - fix: reduce Gradle memory settings for self-hosted runner (initial attempt)
2. `1c21400` - fix: optimize memory settings for local dev and CI (proper split)
3. `1c23a04` - fix: make Android tests sequential after Web tests
4. `24d0cb1` - fix: use separate concurrency groups per workflow type
5. `0a01840` - docs: add Phase 5.5 for resource management and concurrency tuning

**⏳ Phase 6: Monitoring Setup** (Pending)
- Blocked until successful workflow run validates resource configuration

## Success Criteria

- [x] Self-hosted runner running on Synology NAS
- [x] Runner registered with GitHub repository
- [x] Security hardening completed
- [ ] Health monitoring configured
- [x] All Linux workflows successfully migrated
- [ ] **First successful workflow run completed** ⚠️ (blocked on concurrency strategy decision)
- [x] Documentation updated

## Future Improvements

### Documentation Enhancements
- [ ] Add GitHub Actions status badges to README.md
  - CI/CD workflow status (01-test-build-and-deploy.yml)
  - Code quality status (quality-qodana.yml)
  - Docker image version from GHCR
  - License badge
  - Links to Actions pages and registries

### Performance Optimizations
- [ ] Implement Gradle build cache sharing between workflows
- [ ] Set up Docker layer caching for faster builds
- [ ] Consider dedicated build cache volume

### Security Enhancements
- [ ] Set up GitHub Advanced Security scanning
- [ ] Configure Dependabot for dependency updates
- [ ] Add SBOM generation to Docker builds

## Troubleshooting

### Runner Not Connecting

**Symptoms:** Runner offline in GitHub

**Solutions:**
1. Check container status: `docker ps | grep github-runner`
2. Check logs: `docker logs github-runner`
3. Verify GitHub PAT: Check expiration date
4. Restart runner: `docker restart github-runner`

### Builds Failing

**Symptoms:** Jobs fail with errors

**Common Causes & Solutions:**

1. **Out of Memory (OOM) Errors**
   - Symptom: `OOMErrorException: Not enough memory to run compilation`
   - Cause: Gradle heap size exceeds container memory limit
   - Solution: Set GRADLE_OPTS in workflow environment:
     ```yaml
     env:
       GRADLE_OPTS: "-Xmx3g -XX:MaxMetaspaceSize=512m"
       ORG_GRADLE_PROJECT_org.gradle.workers.max: "2"
     ```
   - Note: Keep local gradle.properties at 8GB for dev machine

2. **Parallel Builds Exhausting Resources**
   - Symptom: Multiple jobs running simultaneously, system unresponsive
   - Cause: Multiple workflows or jobs executing in parallel
   - Solution: Use single global concurrency group across all workflows
   - See Phase 5.5 for detailed concurrency strategy discussion

3. **Out of disk space**
   - Check: `df -h /volume1`
   - Clean cache: `docker exec github-runner rm -rf /cache/*`
   - Clean workspace: `docker exec github-runner rm -rf /workspace/_work/*`

4. **Network timeout**
   - Check internet connection on Synology
   - Verify GitHub API is accessible: `curl -I https://api.github.com`

### High Resource Usage

**Symptoms:** NAS slow, other containers affected

**Solutions:**
1. Check CPU usage: `docker stats`
2. Reduce runner allocation: Lower --cpus limit
3. Use concurrency groups to prevent parallel workflows
4. Make workflow jobs sequential with `needs` dependencies

### Concurrency Deadlocks

**Symptoms:** Workflow cancels with "deadlock detected for concurrency group"

**Cause:** Both parent (orchestrator) and child (reusable workflow) have same concurrency group

**Solution:** Only top-level workflows should have concurrency groups
- ✅ Orchestrator (01-test-build-and-deploy.yml): Has concurrency group
- ❌ Reusable workflows (02, 03.x, 04): Should NOT have concurrency groups
- ✅ Independent workflows (qodana, claude, docker-promote): Can have their own groups

## References

- GitHub Self-Hosted Runners: https://docs.github.com/en/actions/hosting-your-own-runners
- Docker Runner Image: https://github.com/myoung34/docker-github-actions-runner
- Synology Docker Guide: https://www.synology.com/en-us/dsm/packages/ContainerManager
