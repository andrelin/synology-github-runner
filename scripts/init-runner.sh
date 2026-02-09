#!/bin/bash
# init-runner.sh - Initialize runner with proper pre-checks
# This script runs before the GitHub runner starts to ensure system readiness

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
if [ ! -d "$WORKSPACE_DIR" ]; then
  echo "ERROR: Workspace directory not accessible: $WORKSPACE_DIR"
  echo "This likely means volumes are not mounted yet. Waiting..."
  RETRIES=0
  while [ ! -d "$WORKSPACE_DIR" ] && [ $RETRIES -lt 12 ]; do
    sleep 5
    RETRIES=$((RETRIES + 1))
    echo "Retry $RETRIES/12: Checking $WORKSPACE_DIR..."
  done
  if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "FATAL: Workspace directory never became available"
    exit 1
  fi
fi
echo "✓ Workspace directory accessible"

# 2. Check network connectivity to GitHub
echo "Checking network connectivity to GitHub..."
RETRIES=0
while ! curl -sf --max-time 10 https://api.github.com/zen &> /dev/null; do
  if [ $RETRIES -ge 12 ]; then
    echo "ERROR: GitHub API not reachable after 12 attempts"
    echo "This may be a network configuration issue"
    exit 1
  fi
  RETRIES=$((RETRIES + 1))
  echo "Retry $RETRIES/12: Waiting for GitHub connectivity..."
  sleep 5
done
echo "✓ GitHub API reachable"

# 3. Clean up stale lock files that might prevent runner startup
echo "Cleaning stale lock files..."
find /home/runner -name "*.lock" -type f -delete 2>/dev/null || true
find /home/runner -name ".runner.lock" -type f -delete 2>/dev/null || true
echo "✓ Lock files cleaned"

# 4. Verify Docker socket is accessible (for Docker-in-Docker workflows)
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

# 5. Check if this is a re-registration scenario
if [ -f "/home/runner/.runner" ]; then
  echo "✓ Runner already registered (found .runner file)"
else
  echo "⚠ Runner not yet registered - this is expected on first start"
fi

# 6. Verify required environment variables
echo "Checking required environment variables..."
if [ -z "$REPO_URL" ]; then
  echo "ERROR: REPO_URL environment variable is not set"
  exit 1
fi
if [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: ACCESS_TOKEN environment variable is not set"
  exit 1
fi
echo "✓ Required environment variables present"

echo "=== Initialization complete - starting runner ==="
echo ""

# Return success - runner can now start
exit 0
