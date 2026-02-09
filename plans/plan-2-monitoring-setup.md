# Plan 2: Monitoring Setup

**Status:** 🟡 Ready to Start (Plan 1 complete)
**Priority:** High
**Estimated Duration:** 2-3 hours

## Overview

Complete the monitoring and alerting setup for the self-hosted GitHub runner on Synology NAS.

## What's Already Done

### ✅ Scripts Created

- `scripts/monitoring/runner-health-check.sh` - Comprehensive health monitoring
  - 8 automated checks (container status, memory, CPU, disk, connectivity)
  - Configurable thresholds
  - Automatic log rotation
  - Alert logging

- `scripts/monitoring/runner-dashboard.sh` - Real-time status display
  - Color-coded output
  - Resource usage metrics
  - Recent activity log
  - Continuous mode support

### ✅ Documentation Written

- `docs/04-MONITORING.md` - Complete setup guide
  - Installation instructions
  - DSM Task Scheduler configuration
  - Email notification setup
  - Troubleshooting section

## What Still Needs to Be Done

## Step 1: Install and Test Scripts (30 minutes)

**Tasks:**

1. [ ] Copy scripts to Synology NAS at `/volume1/scripts/`
2. [ ] Set executable permissions
3. [ ] Test health check script manually
4. [ ] Test dashboard script
5. [ ] Verify log file creation and permissions
6. [ ] Test with simulated failure (stop container)

**Verification:**

```bash
# On Synology
sudo /volume1/scripts/runner-health-check.sh
# Should output: ✅ All health checks passed

/volume1/scripts/runner-dashboard.sh
# Should display formatted dashboard
```

## Step 2: Schedule Health Checks (15 minutes)

**Tasks:**

1. [ ] Open DSM Control Panel → Task Scheduler
2. [ ] Create scheduled task:
   - Name: "GitHub Runner Health Check"
   - User: root
   - Schedule: Every 5 minutes
   - Script: `/volume1/scripts/runner-health-check.sh`
3. [ ] Enable task
4. [ ] Wait 5 minutes and verify first run
5. [ ] Check logs: `cat /volume1/docker/github-runner/health-check.log`

**Verification:**

```bash
# Check task ran
ls -lh /volume1/docker/github-runner/health-check.log
tail -20 /volume1/docker/github-runner/health-check.log
```

## Step 3: Configure Email Alerts (Optional, 15 minutes)

**Tasks:**

1. [ ] Configure SMTP in DSM (Control Panel → Notification → Email)
2. [ ] Test email configuration
3. [ ] Update Task Scheduler task:
   - Enable "Send run details by email"
   - Select "Send run details only when script terminates abnormally"
4. [ ] Test by simulating failure

**Verification:**

```bash
# Simulate failure
docker stop github-runner

# Wait for health check to run (up to 5 minutes)
# Check you received email alert

# Restart runner
docker start github-runner
```

## Step 4: Create Convenience Aliases (5 minutes)

**Tasks:**

1. [ ] SSH into Synology
2. [ ] Add aliases to `~/.bashrc` or `~/.zshrc`
3. [ ] Test aliases

**Script:**

```bash
cat >> ~/.bashrc << 'EOF'
# GitHub Runner Monitoring
alias runner-status='/volume1/scripts/runner-dashboard.sh'
alias runner-watch='/volume1/scripts/runner-dashboard.sh --continuous'
alias runner-logs='docker logs -f github-runner'
alias runner-health='sudo /volume1/scripts/runner-health-check.sh'
alias runner-restart='docker restart github-runner'
EOF

source ~/.bashrc
```

**Verification:**

```bash
# Test aliases
runner-status
runner-health
```

## Step 5: Threshold Tuning (24-48 hour observation)

**Tasks:**

1. [ ] Monitor for 24-48 hours
2. [ ] Review alert log for false positives
3. [ ] Adjust thresholds if needed in `runner-health-check.sh`:
   - `MAX_MEMORY_PERCENT` (default: 90)
   - `MAX_CPU_PERCENT` (default: 150)
   - `MAX_DISK_PERCENT` (default: 80)
4. [ ] Document final thresholds in configuration

**Verification:**

```bash
# Check for alerts
cat /volume1/docker/github-runner/alerts.log

# Review patterns
tail -100 /volume1/docker/github-runner/health-check.log | grep -E "(ALERT|WARNING)"
```

## Step 6: Documentation Update (10 minutes)

**Tasks:**

1. [ ] Update `plans/implementation-history.md`:
   - Mark Plan 2 as complete
   - Add final configuration details
   - Document any threshold adjustments
2. [ ] Update main README with monitoring features
3. [ ] Create quick reference card (optional)

## Success Criteria

- [x] Health check script exists and works
- [x] Dashboard script exists and works
- [ ] Health checks run automatically every 5 minutes
- [ ] Logs are created and rotated properly
- [ ] Alerts are generated for failures
- [ ] Email notifications work (optional but recommended)
- [ ] Convenience aliases set up
- [ ] No false positive alerts after 24-48 hours
- [ ] Documentation complete and accurate

## Testing Checklist

### Manual Tests

- [ ] Health check passes when runner is healthy
- [ ] Health check fails when runner is stopped
- [ ] Dashboard shows accurate resource usage
- [ ] Dashboard continuous mode works (refreshes every 10s)
- [ ] Logs are created with correct permissions
- [ ] Log rotation works (keeps last 1000 lines)

### Automated Tests

- [ ] Scheduled task runs every 5 minutes
- [ ] Logs show successful executions
- [ ] Alerts are logged when thresholds exceeded
- [ ] Email sent when health check fails (if configured)

### Edge Cases

- [ ] Behavior when disk is full
- [ ] Behavior when network is down
- [ ] Behavior when Docker daemon restarts
- [ ] Behavior when DSM is updating

## Timeline

**Immediate (Today):**

- Plan 2.1: Install and test scripts
- Plan 2.2: Schedule health checks
- Plan 2.3: Configure email alerts

**Observation Period (24-48 hours):**

- Plan 2.5: Monitor and tune thresholds

**Final (After observation):**

- Plan 2.4: Set up aliases (can be done earlier)
- Plan 2.6: Update documentation

## Notes

- Scripts are already production-ready
- Documentation is complete
- Just need to deploy and configure
- Main work is DSM Task Scheduler setup
- Email alerts are optional but highly recommended
- Threshold tuning is critical for reducing false positives

## Next Actions

1. SSH into Synology NAS
2. Follow `docs/04-MONITORING.md` step-by-step
3. Complete phases 6.1-6.4 today
4. Let health checks run for 24-48 hours
5. Review and tune (phase 6.5)
6. Finalize documentation (phase 6.6)

## Related Files

- `scripts/monitoring/runner-health-check.sh` - Health monitoring script
- `scripts/monitoring/runner-dashboard.sh` - Status dashboard script
- `docs/04-MONITORING.md` - Complete setup guide
- `plans/implementation-history.md` - Original Plan 2 planning
