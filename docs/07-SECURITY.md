# Security Guide

Security best practices and hardening for your GitHub self-hosted runner on Synology NAS.

## Security Overview

Running a self-hosted runner means you're executing arbitrary code from GitHub workflows on your infrastructure. Proper security is critical.

**Security layers:**
1. ✅ **Container security** - Isolation and privilege restriction
2. ✅ **Network security** - Minimal attack surface
3. ✅ **Secret management** - Secure credential storage
4. ✅ **Access control** - Limited permissions
5. ✅ **Monitoring** - Detect suspicious activity
6. ✅ **Updates** - Stay current with patches

## Quick Security Checklist

### Essential (Must Do)

- [ ] GitHub PAT has minimum scopes (`repo` + `workflow` only)
- [ ] `.env` file has restrictive permissions (`chmod 600`)
- [ ] GitHub PAT expires in 90 days or less
- [ ] Container security hardening enabled (already in docker-compose.yml)
- [ ] Only run workflows from trusted repositories
- [ ] Review workflow code before running
- [ ] Regular security updates (monthly)

### Recommended (Should Do)

- [ ] Store GitHub PAT in password manager
- [ ] Enable 2FA on GitHub account
- [ ] Rotate GitHub PAT every 90 days
- [ ] Monitor runner activity regularly
- [ ] Set up automated security scanning
- [ ] Review GitHub Actions logs weekly
- [ ] Backup .env file securely

### Advanced (Nice to Have)

- [ ] Network isolation (separate VLAN)
- [ ] Audit logging enabled
- [ ] Automated security scanning in workflows
- [ ] Incident response plan documented
- [ ] Regular security audits (quarterly)

## GitHub Personal Access Token Security

### Token Scopes

**Use minimum required scopes:**

✅ **Required:**
- `repo` - Access to repositories
- `workflow` - Modify workflows

❌ **Not needed (don't add):**
- `admin:org` - Too much power
- `delete_repo` - Dangerous
- `admin:public_key` - Unnecessary
- `admin:repo_hook` - Not required

**Why minimal scopes matter:**
If token is compromised, damage is limited to repository access and workflow modifications.

### Token Expiration

**Set expiration date:**
- ✅ 90 days recommended
- ✅ 30-60 days for high-security environments
- ❌ Never use "No expiration"

**Why:** Limits exposure window if token is leaked.

### Token Storage

**Secure storage:**

✅ **Good:**
- Password manager (1Password, Bitwarden, LastPass)
- Encrypted file with GPG
- Secrets management system (HashiCorp Vault)

❌ **Bad:**
- Plain text file
- Email
- Slack/Discord messages
- Unencrypted notes
- Committed to git

**Backup token securely:**
```bash
# Encrypt .env file
gpg -c .env
# Creates .env.gpg (encrypted)

# Decrypt when needed
gpg .env.gpg
```

### Token Rotation

**Rotate every 90 days:**

1. **Create new token** (GitHub → Settings → Tokens)
2. **Update .env:**
   ```bash
   nano /volume1/docker/synology-github-runner/.env
   # Update GITHUB_PAT=ghp_new_token
   ```
3. **Restart runner:**
   ```bash
   docker-compose down && docker-compose up -d
   ```
4. **Revoke old token** in GitHub
5. **Set calendar reminder** for next rotation

**Automate reminders:**
Add to calendar: "Rotate GitHub Runner Token" every 90 days.

### Token Compromise Response

**If token is leaked:**

1. **Immediately revoke token** in GitHub (Settings → Developer settings → Personal access tokens)
2. **Check GitHub Actions logs** for unauthorized runs
3. **Review repository changes** (commits, PRs, releases)
4. **Generate new token** with fresh name
5. **Update .env** and restart runner
6. **Enable 2FA** if not already enabled
7. **Review security practices** to prevent recurrence

## Container Security

### Security Hardening (Built-in)

The docker-compose.yml includes security hardening by default:

```yaml
security_opt:
  - no-new-privileges:true  # Prevent privilege escalation

cap_drop:
  - ALL  # Drop all Linux capabilities

cap_add:
  - CHOWN      # Only add what's needed
  - SETGID
  - SETUID
  - DAC_OVERRIDE

tmpfs:
  - /tmp:mode=1777  # Secure temporary storage (in-memory)
  - /run:mode=755
```

**What this does:**
- ✅ Prevents container from gaining additional privileges
- ✅ Limits Linux capabilities to minimum needed
- ✅ Uses in-memory tmpfs (cleared on restart)
- ✅ Prevents privilege escalation attacks

**Verify security settings:**
```bash
docker inspect github-runner | grep -A 10 SecurityOpt
docker inspect github-runner | grep -A 20 CapDrop
```

### Read-Only Filesystem (Optional)

For maximum security, enable read-only root filesystem:

**Add to docker-compose.yml:**
```yaml
services:
  github-runner:
    read_only: true
    tmpfs:
      - /tmp:mode=1777,size=2g
      - /run:mode=755,size=1g
      - /workspace:mode=755,size=20g  # Writable workspace
```

**Trade-offs:**
- ✅ Enhanced security (can't modify container filesystem)
- ❌ May break some workflows that write outside workspace
- ❌ More complex configuration

**Test thoroughly before enabling in production.**

### Container Image Integrity

**Use specific image versions:**

Instead of `latest`, pin to specific version:
```yaml
image: myoung34/github-runner:2.311.0  # Specific version
# Instead of: myoung34/github-runner:latest
```

**Verify image checksums:**
```bash
# Get image digest
docker inspect myoung34/github-runner:latest | grep Digest

# Verify it matches published checksums
```

**Scan images for vulnerabilities:**
```bash
# Using Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image myoung34/github-runner:latest
```

## Network Security

### Minimal Attack Surface

**No inbound ports needed:**
- ✅ Runner connects **outbound** to GitHub
- ✅ No ports exposed in docker-compose.yml
- ✅ No need to open firewall inbound rules

**Required outbound access:**
- `github.com` - Port 443 (HTTPS)
- `api.github.com` - Port 443 (HTTPS)
- Package registries (npm, PyPI, Maven, etc.) - Port 443/80

### Firewall Configuration

**Recommended firewall rules (outbound only):**

```
ALLOW outbound HTTPS (port 443) to any
ALLOW outbound HTTP (port 80) to any
DENY inbound ALL (no inbound ports needed)
```

**Synology Firewall:**
1. Control Panel → Security → Firewall
2. Edit rules for your NAS
3. Ensure outbound 443/80 allowed
4. No inbound rules needed for runner

### Network Isolation (Advanced)

**For high-security environments, use separate VLAN:**

1. **Create dedicated VLAN** for runner
2. **Restrict VLAN access:**
   - Allow outbound to internet (GitHub API)
   - Block access to internal network
   - Block access to other services on NAS
3. **Configure in Container Manager:**
   - Create custom network
   - Assign runner to isolated network

**Example docker-compose.yml:**
```yaml
services:
  github-runner:
    networks:
      - runner-isolated

networks:
  runner-isolated:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16
```

### DNS Security

**Use trusted DNS servers:**

Control Panel → Network → General → DNS Server

**Recommended:**
- Google: `8.8.8.8`, `8.8.4.4`
- Cloudflare: `1.1.1.1`, `1.0.0.1`
- Quad9: `9.9.9.9`, `149.112.112.112`

**Avoid:**
- ISP DNS (may be unreliable or tracked)
- Public DNS from unknown providers

## Secret Management

### Never Commit Secrets

**Protected by .gitignore:**
- ✅ `.env` file (contains GITHUB_PAT)
- ✅ `workspace/` (may contain secrets)
- ✅ `cache/` (may cache secrets)

**Verify .gitignore:**
```bash
# Check .env is gitignored
git check-ignore .env
# Should output: .env

# Verify .env not in git
git ls-files | grep .env
# Should output nothing
```

**If .env was accidentally committed:**
```bash
# Remove from git history (dangerous - backup first)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch .env" \
  --prune-empty --tag-name-filter cat -- --all

# Force push (careful!)
git push origin --force --all
```

**Then:**
1. Rotate GitHub PAT immediately
2. Review repository access logs
3. Check for unauthorized access

### Secrets in Workflows

**Use GitHub Secrets, not hardcoded values:**

❌ **Bad:**
```yaml
env:
  API_KEY: "sk_live_xxxxxxxxxxxx"  # Exposed in code
```

✅ **Good:**
```yaml
env:
  API_KEY: ${{ secrets.API_KEY }}  # From GitHub Secrets
```

**Add secrets to GitHub:**
1. Repository → Settings → Secrets and variables → Actions
2. Click **New repository secret**
3. Add name and value
4. Click **Add secret**

**Secrets are:**
- ✅ Encrypted at rest
- ✅ Masked in logs
- ✅ Only accessible to workflows
- ❌ Not visible in UI after creation

### File Permissions

**Protect .env file:**
```bash
# Set restrictive permissions (owner read/write only)
chmod 600 .env

# Verify
ls -la .env
# Should show: -rw------- (600)

# Set ownership
chown admin:administrators .env
```

**Check permissions regularly:**
```bash
# Weekly check
find /volume1/docker/synology-github-runner -name ".env" -exec ls -la {} \;
```

## Access Control

### GitHub Repository Access

**Principle of least privilege:**
- ✅ Only add runner to repositories that need it
- ✅ Use separate runners for different trust levels
- ✅ Don't use same runner for public and private repos

**Repository settings:**
1. Settings → Actions → Runners
2. Review which repositories can access runner
3. Remove access for unused repos

### Synology NAS Access

**Limit SSH access:**
```bash
# DSM → Control Panel → Terminal & SNMP
# - Enable SSH only when needed
# - Use strong password or SSH keys
# - Change default port 22 to custom port
# - Disable root login
# - Enable auto block after failed attempts
```

**SSH key authentication (more secure than passwords):**
```bash
# On your computer, generate key
ssh-keygen -t ed25519 -C "github-runner-access"

# Copy to NAS
ssh-copy-id -i ~/.ssh/id_ed25519.pub admin@<your-nas-ip>

# Disable password authentication
# DSM → Control Panel → Terminal & SNMP → Advanced
# Uncheck "Allow password authentication for 'admin'"
```

### Docker Socket Access

**The runner has access to Docker socket** (for Docker-in-Docker builds).

**Security implications:**
- ⚠️ Container can manage other containers
- ⚠️ Potential for container escape
- ⚠️ Workflows can access Docker socket

**Mitigations:**
- ✅ Only run trusted workflows
- ✅ Review workflow code before running
- ✅ Use separate runner for untrusted code
- ✅ Consider Docker socket proxy (advanced)

## Monitoring and Auditing

### Monitor Runner Activity

**Check GitHub Actions logs regularly:**
1. Repository → Actions
2. Review recent workflow runs
3. Look for:
   - Unexpected runs
   - Failed authentications
   - Unusual patterns
   - Runs from unknown users (in org repos)

**Set up notifications:**
1. Repository → Settings → Notifications
2. Enable email for workflow failures
3. Set up Slack/Discord webhooks (optional)

### Monitor Container Activity

**Check container logs for suspicious activity:**
```bash
# Recent logs
docker-compose logs --tail=200 | grep -i "error\|warning\|fail"

# Failed authentication attempts
docker-compose logs | grep -i "auth\|token"

# Unusual network activity
docker logs github-runner 2>&1 | grep -i "connection"
```

**Monitor resource usage:**
```bash
# Real-time monitoring
docker stats github-runner

# Check for unusual spikes in:
# - CPU usage (crypto mining?)
# - Memory usage (memory bomb?)
# - Network I/O (data exfiltration?)
```

### Audit Logging

**Enable container logging:**

In docker-compose.yml:
```yaml
services:
  github-runner:
    logging:
      driver: "json-file"
      options:
        max-size: "50m"
        max-file: "10"
```

**Review logs regularly:**
```bash
# Weekly review
docker-compose logs --since 7d > weekly-logs.txt
grep -i "error\|fail\|unauthorized\|denied" weekly-logs.txt
```

**Long-term log storage:**
```bash
# Archive monthly
mkdir -p /volume1/logs/runner-archive
docker-compose logs > /volume1/logs/runner-archive/logs-$(date +%Y-%m).txt
```

## Security Updates

### Update Runner Image Regularly

**Monthly security updates:**
```bash
# Pull latest image
docker-compose pull

# Check what changed
docker history myoung34/github-runner:latest | head -20

# Apply update
docker-compose down
docker-compose up -d

# Verify successful update
docker-compose logs --tail=50
```

**Subscribe to security updates:**
- Watch GitHub repository: https://github.com/myoung34/docker-github-actions-runner
- Enable notifications for releases

### Update DSM and Container Manager

**Keep Synology software current:**

1. **DSM updates** (monthly):
   - Control Panel → Update & Restore
   - Download and install updates
   - Review release notes for security fixes

2. **Container Manager updates** (when available):
   - Package Center → Installed
   - Update Container Manager

3. **Docker Engine updates** (automatic with DSM):
   - Updated as part of DSM updates

### Update Dependencies

**Update workflow dependencies:**
```yaml
# Keep actions up to date
- uses: actions/checkout@v6  # Not v4
- uses: actions/setup-node@v6  # Not v4
```

**Enable Dependabot:**
Create `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

## Workflow Security

### Code Review

**Review workflow code before running:**
- ✅ Check for hardcoded secrets
- ✅ Review external actions used
- ✅ Verify input validation
- ✅ Check for command injection vulnerabilities
- ✅ Review permissions requested

**Red flags:**
- ❌ Hardcoded credentials
- ❌ `curl | bash` patterns
- ❌ Downloading executables without verification
- ❌ Running code from untrusted sources
- ❌ Exposing secrets in logs

### Pin Action Versions

**Use specific versions, not `@main`:**

❌ **Bad:**
```yaml
- uses: actions/checkout@main  # Mutable, can change
```

✅ **Good:**
```yaml
- uses: actions/checkout@v6  # Specific version

# Even better: pin to commit SHA
- uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab
```

### Least Privilege Workflows

**Limit workflow permissions:**
```yaml
permissions:
  contents: read      # Read-only access to repo
  pull-requests: read # Read PRs

# Don't use:
# permissions: write-all  # Too permissive
```

### Input Validation

**Always validate inputs:**
```yaml
on:
  workflow_dispatch:
    inputs:
      version:
        required: true

jobs:
  deploy:
    steps:
      - name: Validate version
        run: |
          if [[ ! "${{ inputs.version }}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Invalid version format"
            exit 1
          fi
```

## Incident Response

### Security Incident Checklist

**If you suspect a security breach:**

1. **Immediate actions:**
   - [ ] Stop runner container: `docker-compose down`
   - [ ] Revoke GitHub PAT
   - [ ] Change NAS admin password
   - [ ] Review recent workflow runs
   - [ ] Check for unauthorized commits/PRs

2. **Investigation:**
   - [ ] Review container logs
   - [ ] Check GitHub Actions audit log
   - [ ] Review SSH access logs
   - [ ] Check for suspicious files in workspace
   - [ ] Scan for malware

3. **Remediation:**
   - [ ] Rotate all credentials
   - [ ] Update security settings
   - [ ] Apply security patches
   - [ ] Review and update workflows
   - [ ] Document lessons learned

4. **Prevention:**
   - [ ] Implement additional monitoring
   - [ ] Tighten access controls
   - [ ] Update security procedures
   - [ ] Train team on security best practices

### Contact and Reporting

**Report security issues:**
- Repository security: [GitHub Security Advisories](https://github.com/andrelin/synology-github-runner/security/advisories/new)
- Runner image issues: https://github.com/myoung34/docker-github-actions-runner/security

**Don't:**
- ❌ Disclose vulnerabilities publicly before patch available
- ❌ Share exploit code publicly

## Security Best Practices Summary

### Daily
- Monitor workflow runs for anomalies

### Weekly
- Review GitHub Actions logs
- Check runner resource usage
- Verify runner is up to date

### Monthly
- Update runner Docker image
- Review security settings
- Check for DSM updates
- Clean and audit logs

### Quarterly
- Rotate GitHub PAT (or 90 days)
- Conduct security audit
- Review and update workflows
- Test incident response plan

### Annually
- Comprehensive security review
- Update security documentation
- Review and update access controls
- Train team on new security practices

## Additional Resources

- [GitHub Actions Security Best Practices](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Synology Security Advisor](https://www.synology.com/en-us/dsm/feature/security_advisor)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

**Security is not a one-time setup - it's an ongoing process. Stay vigilant!** 🔒