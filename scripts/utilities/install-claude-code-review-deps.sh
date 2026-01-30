#!/bin/bash
set -euo pipefail

# Script to install Claude Code Review dependencies into the running GitHub runner
# This only needs to be run once - the packages persist in the container

echo "Installing Claude Code Review dependencies..."

# Install Anthropic SDK
docker exec github-runner pip3 install anthropic

# Verify installation
echo ""
echo "Verifying installation..."
docker exec github-runner python3 -c "import anthropic; print(f'✅ Anthropic SDK version: {anthropic.__version__}')"
docker exec github-runner python3 --version | sed 's/^/✅ /'
docker exec github-runner gh --version | head -n1 | sed 's/^/✅ /'

echo ""
echo "✅ All Claude Code Review prerequisites are installed!"
echo ""
echo "Note: These packages are installed in the container and will persist"
echo "until you recreate the container (docker-compose down + up)."
