# Contributing to synology-github-runner

Thank you for your interest in contributing! This project helps developers run unlimited GitHub Actions on their Synology NAS.

## How to Contribute

We welcome contributions of all kinds:

- 🐛 **Bug Reports** - Found something broken? Let us know!
- 📝 **Documentation** - Improve guides, fix typos, add examples
- ✨ **Features** - New functionality, workflow patterns, scripts
- 🎨 **Examples** - Share your workflow configurations
- 💡 **Ideas** - Suggest improvements or new directions

## Before You Start

1. **Check existing issues** - Someone might already be working on it
2. **Read CLAUDE.md** - Important guidelines for this repository
3. **Review documentation** - Familiarize yourself with the project structure

## Development Workflow

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/your-username/synology-github-runner.git
cd synology-github-runner
```

### 2. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
```

### 3. Make Changes

Follow these guidelines:

**Shell Scripts:**
- Use `#!/bin/bash` and `set -euo pipefail`
- Run `shellcheck` before committing
- Make scripts executable: `chmod +x scripts/**/*.sh`
- Add comments explaining "why" not "what"
- Test on actual Synology hardware if possible

**Documentation:**
- Use clear, concise language
- Include code examples
- Add cross-references to related docs
- Check for broken links
- Run spell checker

**Docker/Compose:**
- Validate with `docker-compose config`
- Never commit secrets
- Use `.env` for configuration
- Include security hardening

**Privacy (CRITICAL):**
- ❌ No personal IP addresses (use `<your-nas-ip>`)
- ❌ No real domain names (use `example.com`)
- ❌ No personal service names
- ❌ No specific hardware IDs
- ✅ Use generic placeholders and examples

### 4. Test Your Changes

**Automated Checks:**

All pull requests automatically run:

1. **Quality Checks** (`.github/workflows/quality.yml`)
   - ShellCheck validation
   - Script executability check
   - Docker compose validation
   - Markdown linting
   - Link checking
   - Spell checking

2. **Security Scanning** (`.github/workflows/security.yml`)
   - Secret detection (Gitleaks)
   - Vulnerability scanning (Trivy)
   - Privacy validation (no personal info)
   - .env file protection
   - File size checks

3. **Weekly Link Check** (`.github/workflows/weekly-link-check.yml`)
   - External link validation (informational only)

**Local Testing:**

Before pushing, run these checks locally:

```bash
# Validate shell scripts
shellcheck scripts/**/*.sh

# Check docker-compose
docker-compose config

# Test spell checking (requires Node.js)
npm install -g cspell
npx cspell "**/*.md" --config .github/cspell.json

# Test markdown linting (requires Node.js)
npm install -g markdownlint-cli2
markdownlint-cli2 "**/*.md"
```

### 5. Commit Your Changes

Use [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Format
<type>(<scope>): <description>

# Examples
feat(monitoring): add email alerts for health check failures
fix(install): resolve permission error on DSM 7.2
docs(security): add 2FA setup instructions
chore(deps): update runner image to latest version
```

**Commit Types:**
- `feat` - New features
- `fix` - Bug fixes
- `docs` - Documentation only
- `chore` - Maintenance tasks
- `refactor` - Code improvements
- `test` - Adding tests
- `security` - Security improvements

### 6. Push and Create PR

```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub with:

- **Clear title** - What does this change?
- **Description** - Why is this needed?
- **Testing** - How did you test it?
- **Screenshots** - If UI/output changed
- **Related issues** - Link to issues

## Workflow Details

### Resource Constraints

All workflows run on a Synology self-hosted runner with limited resources (1.5 CPU cores, 5GB RAM). This means:

✅ **Strict concurrency control** - Only one job runs at a time
✅ **Combined checks** - Multiple validations in single jobs
✅ **Queue, don't cancel** - Jobs wait instead of failing
✅ **Efficient execution** - Target <10 minutes per workflow

### Understanding Workflow Status

When you create a PR, workflows will:

1. **Quality Checks** (5-10 min)
   - Must pass for PR to merge
   - Validates code quality
   - Checks documentation

2. **Security Scanning** (10-15 min)
   - Must pass for PR to merge
   - Detects secrets and vulnerabilities
   - Validates privacy compliance

3. **Weekly Link Check**
   - Runs on schedule only
   - Informational, doesn't block PRs
   - May report external link issues

### If Workflows Fail

**Quality Check Failures:**
- Run shellcheck locally and fix issues
- Check markdown syntax
- Fix broken internal links
- Correct spelling errors

**Security Scan Failures:**
- Remove any committed secrets
- Check for personal information in docs
- Ensure .env is not committed
- Fix dependency vulnerabilities

**Need help?** Comment on your PR and maintainers will assist.

## Code Style

### Shell Scripts

```bash
#!/bin/bash
set -euo pipefail

# UPPERCASE for constants
CONTAINER_NAME="github-runner"
MAX_RETRIES=3

# lowercase for local variables
current_status="running"
log_file="/var/log/runner.log"

# Descriptive function names
check_container_status() {
    # Implementation
}

# Always quote variables
cp "$SOURCE" "$DEST"

# Handle errors explicitly
if ! command_that_might_fail; then
    echo "Error: Command failed"
    exit 1
fi
```

### YAML Files

```yaml
# 2 spaces for indentation
jobs:
  build:
    runs-on: [self-hosted, Linux, X64]

    # Comments above what they describe
    steps:
      - name: Clear step description
        run: echo "Action"
```

### Markdown

- Use ATX-style headers (`#`, `##`, not underlines)
- Code blocks with language specifiers
- Use relative links for internal docs
- Include examples for complex topics

## Testing on Synology

If you have access to a Synology NAS:

1. **Test your changes** on actual hardware
2. **Document any issues** specific to DSM versions
3. **Verify compatibility** with Container Manager
4. **Check resource usage** during execution

If you don't have Synology hardware, that's fine - mention it in your PR and maintainers will test.

## Documentation Guidelines

When adding or updating documentation:

1. **Be clear and concise** - No fluff
2. **Show examples** - Code blocks with comments
3. **Include expected output** - Show what success looks like
4. **Add troubleshooting** - Common issues and solutions
5. **Cross-reference** - Link to related docs
6. **Privacy first** - No personal information

### Documentation Structure

- `docs/00-*.md` - Numbered guides (read sequentially)
- `docs/FAQ.md` - Questions and answers
- `examples/` - Working example files
- `scripts/` - Executable utilities with inline docs

## Questions?

- Check the [FAQ](docs/FAQ.md)
- Review existing [Issues](https://github.com/andrelin/synology-github-runner/issues)
- Start a [Discussion](https://github.com/andrelin/synology-github-runner/discussions)

## Code of Conduct

Be respectful and constructive:

- ✅ Be welcoming to newcomers
- ✅ Provide constructive feedback
- ✅ Focus on the issue, not the person
- ✅ Accept that others may have different approaches
- ❌ No harassment or discrimination
- ❌ No trolling or spam

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to synology-github-runner! 🚀
