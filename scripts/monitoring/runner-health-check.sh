#!/bin/bash
# GitHub Self-Hosted Runner Health Check
# Purpose: Monitor runner container health and resource usage
# Schedule: Run every 5 minutes via DSM Task Scheduler

set -euo pipefail

# Configuration
CONTAINER_NAME="github-runner"
LOG_FILE="/volume1/docker/github-runner/health-check.log"
ALERT_FILE="/volume1/docker/github-runner/alerts.log"
MAX_LOG_LINES=1000

# Resource thresholds
MAX_MEMORY_PERCENT=90  # Alert if container uses >90% of memory limit
MAX_CPU_PERCENT=150    # Alert if CPU usage >150% (1.5 cores on 2-core system)
MAX_DISK_PERCENT=80    # Alert if disk usage >80%

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

alert() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1" | tee -a "$LOG_FILE" "$ALERT_FILE"
}

# Trim log files if they get too large
trim_logs() {
    if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt "$MAX_LOG_LINES" ]; then
        tail -n $MAX_LOG_LINES "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

# Check 1: Container exists and is running
check_container_running() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        alert "Container '$CONTAINER_NAME' is not running!"

        # Check if container exists but is stopped
        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            alert "Container exists but is stopped. Status: $(docker inspect --format='{{.State.Status}}' $CONTAINER_NAME)"
        else
            alert "Container does not exist!"
        fi
        return 1
    fi
    return 0
}

# Check 2: Container status
check_container_status() {
    STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
    if [ "$STATUS" != "running" ]; then
        alert "Container status is '$STATUS' (expected: running)"
        return 1
    fi
    return 0
}

# Check 3: Container restart count
check_restart_count() {
    RESTART_COUNT=$(docker inspect --format='{{.RestartCount}}' "$CONTAINER_NAME" 2>/dev/null || echo "0")
    if [ "$RESTART_COUNT" -gt 0 ]; then
        alert "Container has restarted $RESTART_COUNT times"
        return 1
    fi
    return 0
}

# Check 4: Memory usage
check_memory_usage() {
    # Get memory stats (in MB)
    MEMORY_STATS=$(docker stats --no-stream --format "{{.MemUsage}}" "$CONTAINER_NAME" 2>/dev/null || echo "0MiB / 0MiB")
    MEMORY_USED=$(echo "$MEMORY_STATS" | awk '{print $1}' | sed 's/MiB//;s/GiB/*1024/')
    MEMORY_LIMIT=$(echo "$MEMORY_STATS" | awk '{print $3}' | sed 's/MiB//;s/GiB/*1024/')

    if [ "$MEMORY_LIMIT" != "0" ]; then
        MEMORY_PERCENT=$(awk "BEGIN {printf \"%.0f\", ($MEMORY_USED / $MEMORY_LIMIT) * 100}")

        if [ "$MEMORY_PERCENT" -gt "$MAX_MEMORY_PERCENT" ]; then
            alert "Memory usage is ${MEMORY_PERCENT}% (${MEMORY_STATS}) - exceeds threshold of ${MAX_MEMORY_PERCENT}%"
            return 1
        fi
    fi
    return 0
}

# Check 5: CPU usage
check_cpu_usage() {
    CPU_PERCENT=$(docker stats --no-stream --format "{{.CPUPerc}}" "$CONTAINER_NAME" 2>/dev/null | sed 's/%//' || echo "0")

    if [ -n "$CPU_PERCENT" ] && [ "$CPU_PERCENT" != "0" ]; then
        if (( $(echo "$CPU_PERCENT > $MAX_CPU_PERCENT" | bc -l) )); then
            alert "CPU usage is ${CPU_PERCENT}% - exceeds threshold of ${MAX_CPU_PERCENT}%"
            return 1
        fi
    fi
    return 0
}

# Check 6: Disk usage
check_disk_usage() {
    DISK_USAGE=$(df -h /volume1 | awk 'NR==2 {print $5}' | sed 's/%//')

    if [ "$DISK_USAGE" -gt "$MAX_DISK_PERCENT" ]; then
        alert "Disk usage is ${DISK_USAGE}% - exceeds threshold of ${MAX_DISK_PERCENT}%"
        return 1
    fi
    return 0
}

# Check 7: Runner connectivity to GitHub
check_github_connectivity() {
    # Check if container can reach GitHub API
    if ! docker exec "$CONTAINER_NAME" ping -c 1 -W 2 api.github.com >/dev/null 2>&1; then
        alert "Cannot reach api.github.com from container"
        return 1
    fi
    return 0
}

# Check 8: Workflow activity (optional - check if runner is idle for too long)
check_runner_activity() {
    # Check recent logs for "Listening for Jobs" (indicates runner is connected)
    RECENT_LOGS=$(docker logs --tail 50 "$CONTAINER_NAME" 2>&1)
    if ! echo "$RECENT_LOGS" | grep -q "Listening for Jobs"; then
        alert "Runner may not be listening for jobs. Check logs: docker logs $CONTAINER_NAME"
        return 1
    fi

    return 0
}

# Main execution
main() {
    trim_logs

    ERRORS=0

    # Run all checks
    log "Starting health check for '$CONTAINER_NAME'..."

    check_container_running || ((ERRORS++))
    check_container_status || ((ERRORS++))
    check_restart_count || ((ERRORS++))
    check_memory_usage || ((ERRORS++))
    check_cpu_usage || ((ERRORS++))
    check_disk_usage || ((ERRORS++))
    check_github_connectivity || ((ERRORS++))
    check_runner_activity || ((ERRORS++))

    if [ $ERRORS -eq 0 ]; then
        log "✅ All health checks passed"
        exit 0
    else
        log "❌ Health check failed with $ERRORS error(s)"
        exit 1
    fi
}

# Run main function
main
