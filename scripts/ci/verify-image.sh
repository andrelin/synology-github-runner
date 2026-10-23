#!/bin/bash
# Checks that a runner image starts the runner: runs it once with DEBUG_ONLY=true, which
# makes the base entrypoint print the command it would run instead of registering.
# Exits 0 only if the container exited 0 within VERIFY_TIMEOUT seconds (default 120)
# and printed "Running ./bin/Runner.Listener run". The container is always removed.
#
# Usage: scripts/ci/verify-image.sh <image-ref>

set -euo pipefail

image=${1:?usage: verify-image.sh <image-ref>}
limit=${VERIFY_TIMEOUT:-120}
name="verify-image-$$-$RANDOM"

trap 'docker rm -f "$name" > /dev/null 2>&1 || true' EXIT

docker create --name "$name" \
    -e DEBUG_ONLY=true \
    -e STARTUP_DELAY_SECONDS=0 \
    -e RUNNER_WORKDIR=/tmp \
    -e REPO_URL=https://github.com/your-username/your-repo \
    -e ACCESS_TOKEN=unused \
    "$image" > /dev/null
docker start "$name" > /dev/null

status=''
wait_rc=0
status=$(timeout "$limit" docker wait "$name") || wait_rc=$?
output=$(docker logs "$name" 2>&1)
printf '%s\n' "$output"

if [ "$wait_rc" != 0 ]; then
    echo "❌ The container did not exit within $limit seconds"
    exit 1
fi
if [ "$status" != 0 ]; then
    echo "❌ The container exited with status $status"
    exit 1
fi
if [[ $output != *"Running ./bin/Runner.Listener run"* ]]; then
    echo "❌ Container would not launch Runner.Listener"
    exit 1
fi
echo "✓ Container launches Runner.Listener"
