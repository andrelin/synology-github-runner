# Workflow Examples

Ready-to-use GitHub Actions workflows optimized for resource-constrained self-hosted runners on Synology NAS.

## Quick Start

1. **Choose a workflow** from the examples below
2. **Copy to your repository** at `.github/workflows/<name>.yml`
3. **Customize** for your tech stack and requirements
4. **Commit and push** to trigger the workflow

## Available Examples

### 1. Basic CI (`basic-ci.yml`)

**Use for:** Simple continuous integration with build and test

**What it does:**

- ✅ Runs on every push and pull request
- ✅ Lints code
- ✅ Runs tests
- ✅ Builds project
- ✅ Uploads build artifacts

**Best for:**

- Getting started with self-hosted runners
- Small to medium projects
- Single-job workflows

**Resource usage:** Low (runs one job at a time)

**Example tech stacks:**

- Node.js/npm
- Python/pip
- Java/Gradle
- Rust/Cargo

**Customize:**

- Change tech stack (Node.js → Python, etc.)
- Add/remove steps (coverage, security scans)
- Modify triggers (schedule, paths)

---

### 2. Orchestrator (`orchestrator.yml`)

**Use for:** Complex CI/CD pipelines with multiple sequential jobs

**What it does:**

- ✅ Runs jobs **sequentially** (one after another)
- ✅ Lint → Unit Tests → Integration Tests → Build → Docker → Deploy
- ✅ Fails fast (stops if early job fails)
- ✅ Optimized for single runner with limited resources

**Best for:**

- Resource-constrained runners (1-2 CPU cores, limited RAM)
- Projects with heavy build steps (Docker, Gradle, large test suites)
- Multi-phase CI/CD pipelines

**Resource usage:** Medium-High (but sequential = no overload)

**Pipeline stages:**

1. **Lint** (5 min) - Fast code quality checks
2. **Unit Tests** (15 min) - Core functionality tests
3. **Integration Tests** (25 min) - Full system tests
4. **Build** (15 min) - Production bundle
5. **Docker** (20 min) - Container image [main branch only]
6. **Deploy** (5 min) - Production deployment [main branch only]

**Customize:**

- Add/remove pipeline stages
- Adjust job dependencies (`needs:`)
- Add parallel jobs where safe
- Skip Docker/Deploy on feature branches

---

### 3. Docker Build (`docker-build.yml`)

**Use for:** Building and pushing Docker images with layer caching

**What it does:**

- ✅ Builds Docker images efficiently
- ✅ Uses Docker layer caching (faster rebuilds)
- ✅ Multi-stage build support
- ✅ Smart image tagging (branch, SHA, latest)
- ✅ Optional push to registry (Docker Hub, GHCR)
- ✅ Image testing before deployment

**Best for:**

- Containerized applications
- Microservices
- Projects deployed via Docker

**Resource usage:** High (Docker builds are memory/CPU intensive)

**Performance:**

- First build: 20-30 minutes
- Subsequent builds: 3-5 minutes (with cache)

**Customize:**

- Enable push to registry (Docker Hub, GHCR)
- Add multi-platform builds (amd64, arm64)
- Customize image tags
- Add image scanning/security checks

---

### 4. Node.js CI (`nodejs-ci.yml`)

**Use for:** Node.js, TypeScript, React, Next.js, Vue, or any npm-based project

**What it does:**

- ✅ Dependency caching (npm/yarn/pnpm)
- ✅ Linting with ESLint
- ✅ Testing with coverage
- ✅ Production build
- ✅ Artifact upload
- ✅ Memory optimization

**Best for:**

- JavaScript/TypeScript applications
- Frontend projects (React, Vue, Angular)
- Backend Node.js services
- Full-stack applications

**Resource usage:** Low-Medium (configurable with NODE_OPTIONS)

**Features:**

- Auto-detects package manager (npm, yarn, pnpm)
- Incremental builds with caching
- Turbo/Nx monorepo support examples
- Memory limit configuration (~2GB default)

**Customize:**

- Switch between npm/yarn/pnpm
- Add E2E tests (Playwright, Cypress)
- Enable source maps or disable for faster builds
- Add deployment steps

---

### 5. Python CI (`python-ci.yml`)

**Use for:** Python applications, Django, FastAPI, Flask, data science projects

**What it does:**

- ✅ Dependency caching (pip/poetry/pipenv)
- ✅ Code linting (flake8)
- ✅ Formatting checks (black)
- ✅ Type checking (mypy)
- ✅ Testing with pytest and coverage
- ✅ Package building

**Best for:**

- Python web applications
- API services (Django, FastAPI, Flask)
- Data science / Jupyter notebooks
- CLI tools and packages

**Resource usage:** Low-Medium

**Features:**

- Supports pip, poetry, and pipenv
- Includes security scanning (bandit, safety)
- Coverage reporting with codecov integration
- Virtual environment management

**Customize:**

- Add Django migrations and database setup
- Include notebook testing (Jupyter)
- Add FastAPI/Flask server smoke tests
- Configure PyPI publishing

---

### 6. Gradle CI (`gradle-ci.yml`)

**Use for:** Java, Kotlin, Android, or any Gradle-based project

**What it does:**

- ✅ Gradle dependency caching
- ✅ JVM memory optimization
- ✅ Testing with JUnit
- ✅ Building JAR/APK files
- ✅ Test report upload
- ✅ Artifact management

**Best for:**

- Java/Kotlin backend services
- Spring Boot applications
- Android applications
- Kotlin Multiplatform projects

**Resource usage:** Medium-High (JVM memory configurable)

**Features:**

- Gradle daemon management
- Build cache support
- Multi-module project support
- Android SDK setup examples
- JaCoCo code coverage

**Customize:**

- Adjust JVM heap size (GRADLE_OPTS)
- Add Spring Boot Docker builds
- Include Detekt/ktlint for Kotlin
- Configure Android APK signing

---

### 7. Rust CI (`rust-ci.yml`)

**Use for:** Rust projects with Cargo

**What it does:**

- ✅ Cargo dependency caching
- ✅ Incremental compilation
- ✅ Clippy linting (strict mode)
- ✅ Rustfmt formatting checks
- ✅ Testing with cargo test
- ✅ Release builds with optimization

**Best for:**

- Rust applications and libraries
- CLI tools
- System programming projects
- WebAssembly projects

**Resource usage:** Medium-High (compilation is CPU/memory intensive)

**Features:**

- Faster linker configuration (lld)
- Incremental compilation enabled
- Clippy with warnings-as-errors
- Swatinem/rust-cache for fast rebuilds
- Cross-compilation examples

**Customize:**

- Add cargo-tarpaulin for coverage
- Include benchmarking (criterion)
- Add WASM builds (wasm-pack)
- Configure cargo-deny for security

---

## Comparison Table

| Workflow | Complexity | Resource Usage | Build Time | Best Use Case |
| -------- | ---------- | -------------- | ---------- | ------------- |
| **basic-ci** | ⭐ Simple | 🟢 Low | ~5-10 min | Quick CI for small projects |
| **orchestrator** | ⭐⭐⭐ Complex | 🟡 Medium | ~30-90 min | Full CI/CD pipeline |
| **docker-build** | ⭐⭐ Moderate | 🔴 High | ~20-30 min | Docker image building |
| **nodejs-ci** | ⭐⭐ Moderate | 🟢 Low-Med | ~5-15 min | Node.js/TypeScript projects |
| **python-ci** | ⭐⭐ Moderate | 🟢 Low-Med | ~5-15 min | Python applications |
| **gradle-ci** | ⭐⭐⭐ Complex | 🟡 Med-High | ~15-30 min | Java/Kotlin/Android projects |
| **rust-ci** | ⭐⭐⭐ Complex | 🟡 Med-High | ~15-40 min | Rust projects |

## Resource Optimization Tips

### For All Workflows

**1. Use Concurrency Control**

All examples include smart concurrency control:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

This cancels older runs of the same workflow on the same branch, saving resources.

**2. Enable Dependency Caching**

```yaml
- uses: actions/setup-node@v6
  with:
    node-version: '20'
    cache: 'npm'  # ← Caches node_modules
```

Supported cache types:

- `npm` for Node.js
- `pip` for Python
- `gradle` for Java/Kotlin
- `cargo` for Rust

**3. Set Realistic Timeouts**

```yaml
jobs:
  build:
    timeout-minutes: 30  # Fail if takes > 30 min
```

Prevents stuck jobs from consuming resources indefinitely.

**4. Optimize Docker Builds**

- Use multi-stage builds (smaller final images)
- Create `.dockerignore` file
- Enable Docker layer caching
- Clean old images: `docker system prune -af`

### For Resource-Constrained Runners

**Use Sequential Jobs (Orchestrator Pattern)**

Instead of parallel jobs that compete for resources:

```yaml
jobs:
  test:
    needs: [lint]  # Wait for lint to finish first
```

**Tune Runner Memory**

In your runner's `.env` file:

```bash
RUNNER_MEMORY=5g  # Adjust based on NAS RAM
GRADLE_OPTS=-Xmx3g  # JVM heap (~60% of RUNNER_MEMORY)
```

**Optimize Gradle Builds**

For Java/Kotlin projects, add to workflow:

```yaml
env:
  GRADLE_OPTS: "-Xmx3g -XX:+UseG1GC"
  ORG_GRADLE_PROJECT_org.gradle.workers.max: "2"
  ORG_GRADLE_PROJECT_org.gradle.parallel: "false"
```

## Common Patterns

### Pattern 1: Run Only on Main Branch

```yaml
if: github.ref == 'refs/heads/main'
```

Use for: Deploy, Docker push, expensive operations

### Pattern 2: Skip on Draft PRs

```yaml
if: github.event.pull_request.draft == false
```

Use for: Expensive builds that don't need to run on WIP PRs

### Pattern 3: Path-Based Triggers

```yaml
on:
  push:
    paths:
      - 'src/**'
      - 'tests/**'
```

Use for: Only run when relevant files change

### Pattern 4: Manual Workflow Dispatch

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options:
          - staging
          - production
```

Use for: Manual deployments, on-demand builds

### Pattern 5: Scheduled Builds

```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
```

Use for: Nightly builds, dependency updates, backups

## Tech Stack Examples

> **💡 Tip:** We now have **complete, production-ready workflow files** for popular tech stacks. See workflows #4-7
> above for full examples with caching, optimization, and customization options.

### Node.js/TypeScript

**📄 See:** [`nodejs-ci.yml`](nodejs-ci.yml) - Complete Node.js CI workflow

Quick snippet:

```yaml
- uses: actions/setup-node@v6
  with:
    node-version: '20'
    cache: 'npm'

- run: npm ci
- run: npm run lint
- run: npm test
- run: npm run build
```

### Python

**📄 See:** [`python-ci.yml`](python-ci.yml) - Complete Python CI workflow

Quick snippet:

```yaml
- uses: actions/setup-python@v6
  with:
    python-version: '3.11'
    cache: 'pip'

- run: pip install -r requirements.txt
- run: pytest
- run: python -m build
```

### Java/Kotlin (Gradle)

**📄 See:** [`gradle-ci.yml`](gradle-ci.yml) - Complete Gradle CI workflow

Quick snippet:

```yaml
- uses: actions/setup-java@v6
  with:
    distribution: 'temurin'
    java-version: '17'
    cache: 'gradle'

- run: ./gradlew test
  env:
    GRADLE_OPTS: "-Xmx3g"  # Configure in runner .env

- run: ./gradlew build
```

### Rust

**📄 See:** [`rust-ci.yml`](rust-ci.yml) - Complete Rust CI workflow

Quick snippet:

```yaml
- uses: dtolnay/rust-toolchain@stable
  with:
    components: clippy, rustfmt

- uses: Swatinem/rust-cache@v2

- run: cargo test
- run: cargo clippy -- -D warnings
- run: cargo build --release
```

### Go

```yaml
- uses: actions/setup-go@v6
  with:
    go-version: '1.21'
    cache: true

- run: go test ./...
- run: go build -v ./...
```

## Troubleshooting

### Workflow Fails with OOM (Out of Memory)

**Problem:** Workflow killed due to memory exhaustion

**Solution:**

1. Increase runner memory in `.env`:

   ```bash
   RUNNER_MEMORY=8g  # Increase from 5g
   ```

2. Optimize workflow (reduce parallel jobs)
3. Use orchestrator pattern (sequential jobs)
4. Check other processes on NAS

### Builds are Very Slow

**Problem:** Builds take much longer than expected

**Solution:**

1. Enable dependency caching
2. Use Docker layer caching
3. Increase CPU priority in `.env`:

   ```bash
   RUNNER_CPU_SHARES=2048
   ```

4. Run builds during off-peak hours
5. Optimize build process (remove unnecessary steps)

### Runner Not Picking Up Jobs

**Problem:** Workflow queued but doesn't run

**Solution:**

1. Check runner status in GitHub: Settings → Actions → Runners
2. Verify runner is "Idle" (green)
3. Check runner labels match workflow `runs-on:`
4. Review runner logs: `docker-compose logs -f`
5. Restart runner if needed

### Docker Build Fails

**Problem:** Docker build step fails or times out

**Solution:**

1. Increase timeout: `timeout-minutes: 45`
2. Check Dockerfile for issues
3. Review Docker logs
4. Ensure enough disk space: `df -h`
5. Clean Docker cache: `docker system prune -af`

## Next Steps

### Learn More

- [Configuration Guide](../../docs/03-CONFIGURATION.md) - Tune runner resources
- [Monitoring Guide](../../docs/04-MONITORING.md) - Track performance
- [Workflows Guide](../../docs/08-WORKFLOWS.md) - Advanced patterns
- [Troubleshooting Guide](../../docs/05-TROUBLESHOOTING.md) - Fix issues

### Customize for Your Project

1. Start with `basic-ci.yml`
2. Add your tech stack (Node, Python, etc.)
3. Add project-specific steps
4. Test on feature branch
5. Merge to main when working

### Contribute

Have a great workflow example to share?

- Open a pull request at: https://github.com/andrelin/synology-github-runner
- Share in Discussions: https://github.com/andrelin/synology-github-runner/discussions

---

**Questions?** Check the [FAQ](../../docs/FAQ.md) or [open an issue](https://github.com/andrelin/synology-github-runner/issues)
