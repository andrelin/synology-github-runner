#!/bin/bash
# init-runner.sh - Initialize runner with proper pre-checks
# This script runs before the GitHub runner starts to ensure system readiness.
#
# It waits for volumes and network instead of exiting: an exit only restarts the
# container into the same wait, and Docker's restart backoff grows each time.

set -e

echo "=== GitHub Runner Initialization ==="
echo "Timestamp: $(date)"

# Startup delay to allow system stabilization after reboot
STARTUP_DELAY=${STARTUP_DELAY_SECONDS:-30}
if [ "$STARTUP_DELAY" -gt 0 ]; then
  echo "Waiting ${STARTUP_DELAY} seconds for system stabilization..."
  sleep "$STARTUP_DELAY"
fi

# 1. Verify workspace directory is accessible
echo "Checking workspace access..."
WORKSPACE_DIR="${RUNNER_WORKDIR:-/volume1/docker/github-runner/workspace}"
RETRIES=0
while [ ! -d "$WORKSPACE_DIR" ]; do
  RETRIES=$((RETRIES + 1))
  echo "Retry $RETRIES: Workspace directory not accessible yet: $WORKSPACE_DIR"
  sleep 5
done
echo "✓ Workspace directory accessible"

# 2. Check network connectivity to GitHub
echo "Checking network connectivity to GitHub..."
RETRIES=0
while ! curl -sf --max-time 10 https://api.github.com/zen &> /dev/null; do
  RETRIES=$((RETRIES + 1))
  echo "Retry $RETRIES: Waiting for GitHub connectivity..."
  # Back off to one check a minute so a long outage doesn't flood the log
  if [ $RETRIES -lt 12 ]; then
    sleep 5
  else
    sleep 60
  fi
done
echo "✓ GitHub API reachable"

# 3. Verify Docker socket is accessible (for Docker-in-Docker workflows)
echo "Checking Docker socket access..."
if [ -S /var/run/docker.sock ]; then
  if docker ps &> /dev/null; then
    echo "✓ Docker socket accessible and working"
  else
    echo "WARNING: Docker socket exists but 'docker ps' failed"
    echo "This may cause Docker-in-Docker workflows to fail"
  fi
else
  echo "WARNING: Docker socket not found at /var/run/docker.sock"
  echo "Docker-in-Docker workflows will not work"
fi

# 4. Verify required environment variables
# Registration state is not checked: the base entrypoint deletes it and registers
# afresh with --replace on every start, which is what makes restarts safe.
echo "Checking required environment variables..."
if [ -z "$REPO_URL" ]; then
  echo "ERROR: REPO_URL environment variable is not set"
  exit 1
fi
if [ -z "$ACCESS_TOKEN" ] && [ -z "$APP_PRIVATE_KEY" ]; then
  echo "ERROR: Set either GITHUB_PAT or the GitHub App credentials (APP_ID, APP_PRIVATE_KEY)"
  exit 1
fi
echo "✓ Required environment variables present"

echo "=== Initialization complete - starting runner ==="
echo ""

# Return success - runner can now start
exit 0
