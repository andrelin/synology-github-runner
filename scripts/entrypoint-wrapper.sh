#!/bin/bash
# entrypoint-wrapper.sh - Wrapper around runner entrypoint
# Runs initialization checks before starting the GitHub runner

set -e

echo "=== GitHub Runner Container Starting ==="

# Run initialization script
if [ -f /opt/init-runner.sh ]; then
  echo "Running pre-start initialization..."
  /opt/init-runner.sh
  if [ $? -ne 0 ]; then
    echo "FATAL: Initialization failed"
    exit 1
  fi
else
  echo "WARNING: Initialization script not found, skipping"
fi

# Execute the original entrypoint from base image
# The myoung34/github-runner image uses /entrypoint.sh
echo "Starting GitHub runner..."
exec /entrypoint.sh "$@"
