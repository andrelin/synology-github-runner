# Phase 6: Monitoring Setup - Installation Guide

## Overview

This guide will help you set up comprehensive monitoring for your GitHub self-hosted runner on Synology NAS.

**Components:**
- ✅ Health check script (automated monitoring)
- ✅ Dashboard script (manual status viewing)
- ✅ DSM Task Scheduler integration
- ✅ Alert logging system

**Estimated Time:** 30 minutes

---

## Step 1: Copy Scripts to Synology NAS

### 1.1 Create Scripts Directory

SSH into your Synology NAS:

```bash
ssh admin@<your-nas-ip>
```

Create the scripts directory:

```bash
mkdir -p /volume1/scripts
mkdir -p /volume1/docker/github-runner/logs
```

### 1.2 Upload Scripts

From your local machine, copy the scripts to the NAS:

```bash
# Option A: Using scp
scp runner-health-check.sh admin@<your-nas-ip>:/volume1/scripts/
scp runner-dashboard.sh admin@<your-nas-ip>:/volume1/scripts/

# Option B: Using rsync
rsync -avz runner-health-check.sh admin@<your-nas-ip>:/volume1/scripts/
rsync -avz runner-dashboard.sh admin@<your-nas-ip>:/volume1/scripts/
```

### 1.3 Set Permissions

SSH back into the NAS and set executable permissions:

```bash
ssh admin@<your-nas-ip>
chmod +x /volume1/scripts/runner-health-check.sh
chmod +x /volume1/scripts/runner-dashboard.sh
```

---

## Step 2: Test Scripts Manually

### 2.1 Test Health Check Script

```bash
sudo /volume1/scripts/runner-health-check.sh
```

**Expected Output:**
```
[2026-01-29 13:00:00] Starting health check for 'github-runner'...
[2026-01-29 13:00:01] ✅ All health checks passed
```

**If there are errors:**
- Check that the container name matches (default: `github-runner`)
- Verify Docker is accessible: `docker ps`
- Check logs: `cat /volume1/docker/github-runner/health-check.log`

### 2.2 Test Dashboard Script

```bash
/volume1/scripts/runner-dashboard.sh
```

**Expected Output:**
```
╔════════════════════════════════════════════════════════════════╗
║     GitHub Self-Hosted Runner - Status Dashboard              ║
╚════════════════════════════════════════════════════════════════╝

📅 2026-01-29 13:00:00

━━━ Container Status ━━━
Status:      ✅ Running
Started:     2026-01-28T20:00:00.000000000Z
Restarts:    0

━━━ Resource Usage ━━━
CPU:         45.2%
Memory:      2.1GiB / 5GiB (42%)
Network I/O: 1.2MB / 3.4MB
Block I/O:   450MB / 1.2GB
...
```

**Continuous Mode:**
```bash
/volume1/scripts/runner-dashboard.sh --continuous
```

This will refresh the dashboard every 10 seconds. Press Ctrl+C to stop.

---

## Step 3: Schedule Health Checks with DSM Task Scheduler

### 3.1 Open Task Scheduler

1. Log into DSM web interface
2. Open **Control Panel** → **Task Scheduler**

### 3.2 Create Scheduled Task

Click **Create** → **Scheduled Task** → **User-defined script**

#### Basic Settings
- **Task Name:** `GitHub Runner Health Check`
- **User:** `root` (required for Docker access)
- **Enabled:** ✅ Checked

#### Schedule Settings
- **Run on the following days:** Daily
- **First run time:** 00:00
- **Frequency:** Every 5 minutes
- **Last run time:** 23:55

#### Task Settings
- **Send run details by email:** (Optional - configure if you want email alerts)
- **User-defined script:**

```bash
/volume1/scripts/runner-health-check.sh
```

#### Notification Settings (Optional)
- **Send run details only when the script terminates abnormally:** ✅ Checked
- This will email you if the health check fails

### 3.3 Save and Enable

Click **OK** to save the task. The health check will now run every 5 minutes.

---

## Step 4: Configure Alert Notifications (Optional)

### 4.1 Email Notifications via DSM

**Enable Email Notifications:**
1. Go to **Control Panel** → **Notification** → **Email**
2. Configure SMTP settings (Gmail, Outlook, etc.)
3. Add recipient email addresses
4. Test the email configuration

**Enable Task Scheduler Notifications:**
1. Go back to **Task Scheduler**
2. Edit your health check task
3. Check **Send run details by email**
4. Select **Send run details only when the script terminates abnormally**

Now you'll receive emails when the health check fails.

### 4.2 View Alert Logs Manually

Alert logs are stored at: `/volume1/docker/github-runner/alerts.log`

```bash
# View recent alerts
tail -f /volume1/docker/github-runner/alerts.log

# View all alerts
cat /volume1/docker/github-runner/alerts.log
```

---

## Step 5: Create Dashboard Shortcuts (Optional)

### 5.1 Add to Shell Profile

Add aliases to your shell profile for quick access:

```bash
# SSH into NAS
ssh admin@<your-nas-ip>

# Add to ~/.bashrc or ~/.zshrc
cat >> ~/.bashrc << 'EOF'
# GitHub Runner Monitoring
alias runner-status='/volume1/scripts/runner-dashboard.sh'
alias runner-watch='/volume1/scripts/runner-dashboard.sh --continuous'
alias runner-logs='docker logs -f github-runner'
alias runner-health='sudo /volume1/scripts/runner-health-check.sh'
EOF

# Reload profile
source ~/.bashrc
```

Now you can use:
- `runner-status` - Show current status
- `runner-watch` - Live dashboard (refreshes every 10s)
- `runner-logs` - Follow runner logs
- `runner-health` - Run health check manually

---

## Step 6: Monitor Logs and Adjust Thresholds

### 6.1 Log Files

**Health Check Log:**
- Path: `/volume1/docker/github-runner/health-check.log`
- Rotates automatically (keeps last 1000 lines)

**Alert Log:**
- Path: `/volume1/docker/github-runner/alerts.log`
- Contains only alerts/warnings

**View Logs:**
```bash
# Health check log
tail -f /volume1/docker/github-runner/health-check.log

# Alerts only
tail -f /volume1/docker/github-runner/alerts.log
```

### 6.2 Adjust Thresholds

Edit the health check script to adjust alert thresholds:

```bash
nano /volume1/scripts/runner-health-check.sh
```

**Default Thresholds:**
```bash
MAX_MEMORY_PERCENT=90  # Alert if container uses >90% of memory limit
MAX_CPU_PERCENT=150    # Alert if CPU usage >150%
MAX_DISK_PERCENT=80    # Alert if disk usage >80%
```

Change these values based on your observed usage patterns.

---

## Step 7: Verify Monitoring is Working

### 7.1 Wait for First Scheduled Run

The health check will run automatically every 5 minutes. Wait 5 minutes and check:

```bash
# Check that the log file was created
ls -lh /volume1/docker/github-runner/health-check.log

# View recent entries
tail /volume1/docker/github-runner/health-check.log
```

### 7.2 Simulate a Failure (Optional)

Test that alerts work by temporarily stopping the runner:

```bash
# Stop the runner
docker stop github-runner

# Wait 5 minutes for health check to run
# Check alert log
cat /volume1/docker/github-runner/alerts.log

# Restart the runner
docker start github-runner
```

You should see alerts in the log file and (if configured) receive an email.

---

## Troubleshooting

### Health Check Script Fails

**Issue:** "Cannot find container 'github-runner'"
- **Fix:** Update `CONTAINER_NAME` in the script to match your container name
- Check actual name: `docker ps --format '{{.Names}}'`

**Issue:** Permission denied when running script
- **Fix:** Run with sudo: `sudo /volume1/scripts/runner-health-check.sh`
- Or add your user to docker group: `sudo synogroup --add docker $USER`

**Issue:** bc: command not found
- **Fix:** Install bc package via DSM Package Center → Developer Tools

### Task Scheduler Not Running

**Issue:** Task shows "Last Result: 127" or "Command not found"
- **Fix:** Use absolute paths in the script: `/volume1/scripts/runner-health-check.sh`
- Verify script has execute permissions: `ls -l /volume1/scripts/`

**Issue:** Task runs but no logs generated
- **Fix:** Check log directory permissions: `ls -ld /volume1/docker/github-runner/`
- Create directory if missing: `mkdir -p /volume1/docker/github-runner/logs`

### Email Notifications Not Working

**Issue:** No emails received when health check fails
- **Fix:** Verify SMTP settings in Control Panel → Notification
- Test email: Control Panel → Notification → Send test email
- Check Task Scheduler notification settings

---

## Success Criteria

✅ Health check script runs every 5 minutes
✅ Dashboard shows real-time runner status
✅ Logs are created and rotated automatically
✅ Alerts are generated when thresholds exceeded
✅ Email notifications work (if configured)
✅ No false positives in alert log

---

## Next Steps

After monitoring is set up:

1. **Observe for 24-48 hours** - Watch for patterns and false alerts
2. **Tune thresholds** - Adjust based on normal usage patterns
3. **Update runner plan** - Mark Phase 6 as COMPLETE
4. **Document** - Add monitoring details to project documentation

---

## Quick Reference

### Common Commands

```bash
# View dashboard
/volume1/scripts/runner-dashboard.sh

# Live dashboard (auto-refresh)
/volume1/scripts/runner-dashboard.sh --continuous

# Run health check manually
sudo /volume1/scripts/runner-health-check.sh

# View logs
tail -f /volume1/docker/github-runner/health-check.log
tail -f /volume1/docker/github-runner/alerts.log

# View runner logs
docker logs -f github-runner

# Restart runner
docker restart github-runner

# Check runner resource usage
docker stats github-runner
```

### Log Locations

| Log File | Path |
|----------|------|
| Health Check | `/volume1/docker/github-runner/health-check.log` |
| Alerts | `/volume1/docker/github-runner/alerts.log` |
| Runner Logs | `docker logs github-runner` |

### Monitoring Thresholds

| Metric | Threshold | Action |
|--------|-----------|--------|
| Memory | >90% | Alert |
| CPU | >150% | Alert |
| Disk | >80% | Alert |
| Container Down | N/A | Alert + Email |
| GitHub Unreachable | N/A | Alert |

---

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review logs: `tail -f /volume1/docker/github-runner/health-check.log`
3. Test manually: `sudo /volume1/scripts/runner-health-check.sh`
4. Check DSM Task Scheduler history for errors
