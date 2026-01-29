# Plan 1: Repository Integration

**Status:** 🟢 Complete (Simplified)
**Priority:** Critical
**Estimated Duration:** 5 minutes

## Overview

The repository's docker-compose.yml now matches the production Synology configuration. The only remaining step is to add a `.env` file to separate secrets from the configuration.

## What Changed

The repository docker-compose.yml was updated (commit e1d53b5) to match the battle-tested production configuration:
- ✅ Synology-compatible syntax (mem_limit, memswap_limit, cpu_shares)
- ✅ Absolute volume paths (/volume1/docker/github-runner/)
- ✅ Security hardening (no-new-privileges, minimal capabilities, tmpfs)
- ✅ Simple, focused configuration
- ✅ Environment variable support for secrets

## Remaining Task: Create .env File (5 minutes)

The docker-compose.yml now expects secrets from a `.env` file instead of being hardcoded.

### Step 1: Create .env File on Synology

SSH into your Synology and create the `.env` file:

```bash
# SSH into Synology
ssh admin@<your-nas-ip>

# Navigate to project directory
cd /volume1/docker/github-runner

# Copy the example file
cp .env.example .env

# Edit the .env file
nano .env
```

### Step 2: Set Required Variables

Edit `.env` and set these values:

```bash
# REQUIRED: Your repository URL
REPO_URL=https://github.com/andrelin/planechaser

# REQUIRED: Your GitHub Personal Access Token
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# OPTIONAL: Runner name (defaults to synology-general-runner)
RUNNER_NAME=synology-general-runner

# OPTIONAL: Labels (defaults to self-hosted,linux,synology,general)
LABELS=self-hosted,linux,synology,general

# OPTIONAL: Gradle settings (defaults to -Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200)
GRADLE_OPTS=-Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
```

### Step 3: Update Container Manager Project

Since the docker-compose.yml now references the `.env` file, you need to recreate the container:

```bash
# Stop and remove current container
docker-compose down

# Pull latest image (optional)
docker-compose pull

# Start with new configuration
docker-compose up -d

# Check logs
docker-compose logs -f
```

Or via Container Manager UI:
1. Open DSM → Container Manager
2. Find the `github-runner` project
3. Click "Build" to rebuild with new docker-compose.yml
4. Verify runner shows as "Idle" in GitHub

### Step 4: Verify

1. **Check runner status:**
   ```bash
   docker ps | grep github-runner
   docker logs github-runner --tail 50
   ```

2. **Check GitHub:**
   - Go to: https://github.com/andrelin/planechaser/settings/actions/runners
   - Verify runner shows as "Idle" (green)

3. **Test with a workflow:**
   - Trigger any workflow that uses `runs-on: [self-hosted, linux]`
   - Verify it runs successfully

## Benefits

✅ **Secrets separated** - No hardcoded tokens in docker-compose.yml
✅ **Easy updates** - Change REPO_URL or PAT without editing docker-compose.yml
✅ **Version controlled** - docker-compose.yml can be committed safely
✅ **Production-tested** - Using exact configuration that's already working
✅ **Security** - .env file is gitignored, never committed

## Success Criteria

- [x] docker-compose.yml matches production configuration
- [ ] .env file created with correct values
- [ ] Container recreated with .env support
- [ ] Runner shows "Idle" in GitHub
- [ ] Test workflow runs successfully

## Next Steps

Once this plan is complete:
- ✅ Proceed to **Plan 2: Monitoring Setup**
- The docker-compose.yml and .env structure is now ready for monitoring integration
