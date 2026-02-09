# Workflow Examples

> Real-world GitHub Actions workflow patterns optimized for self-hosted Synology runners.

This guide provides production-ready workflow examples that work efficiently on resource-constrained hardware.

## Overview

Self-hosted runners require different patterns than GitHub-hosted runners:

- **Resource awareness** - Limit concurrent jobs to prevent OOM
- **Caching strategies** - Leverage persistent disk for faster builds
- **Smart concurrency** - Queue instead of cancel for single-runner setups
- **Error handling** - Account for potential hardware constraints

## Basic CI Workflow

Simple continuous integration for every push and PR:

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: [self-hosted, linux, X64]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up environment
        run: |
          echo "Runner: $RUNNER_NAME"
          echo "Workspace: $GITHUB_WORKSPACE"

      - name: Run tests
        run: |
          # Your test commands here
          ./gradlew test

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: build/test-results/
```

## Orchestrator Pattern (Resource-Constrained)

For runners with limited resources, use an orchestrator to control job execution:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:

# Queue jobs instead of canceling - important for single runner!
concurrency:
  group: synology-runner
  cancel-in-progress: false

jobs:
  # Orchestrator job that controls execution order
  orchestrate:
    runs-on: [self-hosted, linux, X64]
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build
        run: ./gradlew build

      - name: Test Shared
        run: ./gradlew :shared:test

      - name: Test App
        run: ./gradlew :app:test

      - name: Deploy
        if: github.ref == 'refs/heads/main'
        run: ./scripts/deploy.sh
```

**Benefits:**

- Single runner handles everything sequentially
- No resource contention
- Predictable execution order
- Simple debugging

## Reusable Workflow Pattern

Break large workflows into reusable pieces:

### Main Workflow (`ci-cd.yml`)

```yaml
name: CI/CD

on: [push, pull_request]

concurrency:
  group: synology-runner
  cancel-in-progress: false

jobs:
  build:
    uses: ./.github/workflows/build.yml

  test:
    needs: build
    uses: ./.github/workflows/test.yml

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    uses: ./.github/workflows/deploy.yml
```

### Build Workflow (`.github/workflows/build.yml`)

```yaml
name: Build

on:
  workflow_call:

jobs:
  build:
    runs-on: [self-hosted, linux, X64]
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: ./gradlew assemble
        env:
          GRADLE_OPTS: "-Xmx3g -XX:+UseG1GC"

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-artifacts
          path: build/libs/
```

## Docker Build and Push

Build Docker images on your runner and push to registry:

```yaml
name: Docker Build

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  docker:
    runs-on: [self-hosted, linux, X64]

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: your-username/your-app
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=local,src=/cache/docker
          cache-to: type=local,dest=/cache/docker,mode=max
```

**Note:** The runner has `/cache` volume mounted for persistent Docker layer caching.

## AI-Powered Code Review with Claude

Automatically review pull requests using Claude AI:

```yaml
name: Claude Code Review

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  code-review:
    runs-on: [self-hosted, linux, X64]

    permissions:
      contents: read
      pull-requests: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for better context

      - name: Run Claude Code Review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # Install review tool if not in custom image
          # pip3 install --user anthropic  # Already installed!

          # Run code review
          python3 scripts/claude-review.py \
            --pr-number ${{ github.event.pull_request.number }} \
            --repo ${{ github.repository }}
```

**Prerequisites:**

- ✅ Anthropic SDK (pre-installed in runner)
- ✅ GitHub CLI (pre-installed in runner)
- Add `ANTHROPIC_API_KEY` to repository secrets
- Create `scripts/claude-review.py` (see example below)

### Example Review Script

Create `scripts/claude-review.py`:

```python
#!/usr/bin/env python3
"""Claude-powered code review for GitHub pull requests."""

import os
import sys
from anthropic import Anthropic

def main():
    # Initialize Claude client
    client = Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    # Get PR diff (using gh CLI)
    import subprocess
    pr_number = os.environ.get("PR_NUMBER")
    diff = subprocess.check_output(
        f"gh pr diff {pr_number}",
        shell=True,
        text=True
    )

    # Request code review from Claude
    message = client.messages.create(
        model="claude-sonnet-4-5-20250929",
        max_tokens=4000,
        messages=[{
            "role": "user",
            "content": f"""Review this code change and provide:
1. Summary of changes
2. Potential issues or bugs
3. Suggestions for improvement
4. Security concerns (if any)

Diff:
{diff}
"""
        }]
    )

    review = message.content[0].text

    # Post review as PR comment (using gh CLI)
    subprocess.run(
        f'gh pr comment {pr_number} --body "{review}"',
        shell=True,
        check=True
    )

    print("✅ Code review posted successfully")

if __name__ == "__main__":
    main()
```

Make it executable:

```bash
chmod +x scripts/claude-review.py
```

## Gradle/Kotlin Multiplatform

Optimized workflow for Kotlin projects:

```yaml
name: Kotlin CI

on: [push, pull_request]

concurrency:
  group: synology-runner
  cancel-in-progress: false

jobs:
  test:
    runs-on: [self-hosted, linux, X64]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Gradle
        uses: gradle/gradle-build-action@v2
        with:
          cache-read-only: false

      - name: Test Shared Module
        run: ./gradlew :shared:test
        env:
          GRADLE_OPTS: "-Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
          ORG_GRADLE_PROJECT_org.gradle.workers.max: "2"

      - name: Test Android
        run: ./gradlew :android:test
        env:
          GRADLE_OPTS: "-Xmx3g"

      - name: Build Release
        if: github.ref == 'refs/heads/main'
        run: ./gradlew assembleRelease
```

## Scheduled Maintenance

Run periodic tasks on your runner:

```yaml
name: Weekly Maintenance

on:
  schedule:
    # Every Sunday at 2 AM
    - cron: '0 2 * * 0'
  workflow_dispatch:  # Manual trigger

jobs:
  cleanup:
    runs-on: [self-hosted, linux, X64]

    steps:
      - name: Clean Gradle cache
        run: |
          rm -rf ~/.gradle/caches/
          rm -rf ~/.gradle/wrapper/dists/

      - name: Clean Docker
        run: |
          docker system prune -af --volumes
          docker builder prune -af

      - name: Report disk usage
        run: |
          df -h /workspace
          df -h /cache
```

## Multi-Job with Dependencies

Complex pipeline with job dependencies:

```yaml
name: Complex Pipeline

on: [push]

concurrency:
  group: synology-runner
  cancel-in-progress: false

jobs:
  lint:
    runs-on: [self-hosted, linux, X64]
    steps:
      - uses: actions/checkout@v4
      - run: ./gradlew ktlintCheck

  unit-test:
    needs: lint
    runs-on: [self-hosted, linux, X64]
    steps:
      - uses: actions/checkout@v4
      - run: ./gradlew test

  integration-test:
    needs: lint
    runs-on: [self-hosted, linux, X64]
    steps:
      - uses: actions/checkout@v4
      - run: ./gradlew integrationTest

  build:
    needs: [unit-test, integration-test]
    runs-on: [self-hosted, linux, X64]
    steps:
      - uses: actions/checkout@v4
      - run: ./gradlew build

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: [self-hosted, linux, X64]
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh
```

**Note:** Jobs with `needs:` still run sequentially on a single runner.

## Resource-Aware Testing

Adjust test parallelism based on available resources:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: [self-hosted, linux, X64]

    steps:
      - uses: actions/checkout@v4

      - name: Run tests (resource-aware)
        run: |
          # Detect available resources
          CORES=$(nproc)
          MEM_GB=$(free -g | awk '/^Mem:/{print $2}')

          # Calculate optimal parallelism
          if [ $MEM_GB -ge 16 ]; then
            MAX_WORKERS=4
          elif [ $MEM_GB -ge 8 ]; then
            MAX_WORKERS=2
          else
            MAX_WORKERS=1
          fi

          echo "Running tests with $MAX_WORKERS workers"

          ./gradlew test \
            -Dorg.gradle.workers.max=$MAX_WORKERS \
            -Dorg.gradle.parallel=$([[ $MAX_WORKERS -gt 1 ]] && echo true || echo false)
```

## Best Practices

### 1. Use Concurrency Groups

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false  # Queue for single runner
```

### 2. Cache Dependencies

```yaml
- name: Cache Gradle
  uses: actions/cache@v3
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
    key: gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
```

### 3. Set Resource Limits

```yaml
env:
  GRADLE_OPTS: "-Xmx3g -XX:+UseG1GC"
  ORG_GRADLE_PROJECT_org.gradle.workers.max: "2"
```

### 4. Use Artifacts for Build Results

```yaml
- name: Upload artifacts
  uses: actions/upload-artifact@v4
  with:
    name: build-outputs
    path: build/outputs/
    retention-days: 7
```

### 5. Clean Up After Builds

```yaml
- name: Cleanup
  if: always()
  run: |
    rm -rf build/
    docker system prune -f
```

## Troubleshooting Workflows

### Out of Memory

**Problem:** Workflow fails with OOM errors

**Solution:**

```yaml
env:
  GRADLE_OPTS: "-Xmx2g"  # Reduce from 3g
  ORG_GRADLE_PROJECT_org.gradle.workers.max: "1"  # Reduce parallelism
```

### Disk Space Issues

**Problem:** "No space left on device"

**Solution:**

```yaml
- name: Free disk space
  run: |
    docker system prune -af --volumes
    rm -rf ~/.gradle/caches/
```

### Stale Locks

**Problem:** Gradle daemon locks

**Solution:**

```yaml
- name: Stop Gradle daemon
  if: always()
  run: ./gradlew --stop
```

## Next Steps

- [Configuration Guide](03-CONFIGURATION.md) - Tune resource limits
- [Monitoring Guide](04-MONITORING.md) - Watch workflow performance
- [Troubleshooting Guide](05-TROUBLESHOOTING.md) - Debug issues

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Self-Hosted Runner Guide](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Workflow Syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)

---

**Tips:**

- Start simple, add complexity as needed
- Monitor resource usage with dashboard
- Test workflows on feature branches first
- Use workflow_dispatch for manual testing
