#!/bin/bash
# GitHub Self-Hosted Runner Dashboard
# Purpose: Display real-time runner status and resource usage
# Usage: ./runner-dashboard.sh [--continuous]

set -euo pipefail

CONTAINER_NAME="github-runner"
CONTINUOUS=false

if [[ "${1:-}" == "--continuous" ]]; then
    CONTINUOUS=true
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     GitHub Self-Hosted Runner - Status Dashboard              ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "📅 $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

check_container_status() {
    echo -e "${BLUE}━━━ Container Status ━━━${NC}"

    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "Status:      ${GREEN}✅ Running${NC}"

        # Uptime
        STARTED=$(docker inspect --format='{{.State.StartedAt}}' "$CONTAINER_NAME")
        echo -e "Started:     $STARTED"

        # Restart count
        RESTART_COUNT=$(docker inspect --format='{{.RestartCount}}' "$CONTAINER_NAME")
        if [ "$RESTART_COUNT" -eq 0 ]; then
            echo -e "Restarts:    ${GREEN}$RESTART_COUNT${NC}"
        else
            echo -e "Restarts:    ${YELLOW}$RESTART_COUNT${NC}"
        fi
    else
        echo -e "Status:      ${RED}❌ Not Running${NC}"
        return 1
    fi
    echo ""
}

show_resource_usage() {
    echo -e "${BLUE}━━━ Resource Usage ━━━${NC}"

    # Get stats
    STATS=$(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" "$CONTAINER_NAME" 2>/dev/null)

    if [ -n "$STATS" ]; then
        echo "$STATS" | grep -v "NAME" | while read -r line; do
            NAME=$(echo "$line" | awk '{print $1}')
            CPU=$(echo "$line" | awk '{print $2}')
            MEM_USAGE=$(echo "$line" | awk '{print $3, $4, $5}')
            MEM_PERCENT=$(echo "$line" | awk '{print $6}')
            NET_IO=$(echo "$line" | awk '{print $7, $8, $9}')
            BLOCK_IO=$(echo "$line" | awk '{print $10, $11, $12}')

            # Color-code based on usage
            CPU_NUM=$(echo "$CPU" | sed 's/%//')
            if (( $(echo "$CPU_NUM < 100" | bc -l) )); then
                CPU_COLOR=$GREEN
            elif (( $(echo "$CPU_NUM < 150" | bc -l) )); then
                CPU_COLOR=$YELLOW
            else
                CPU_COLOR=$RED
            fi

            MEM_NUM=$(echo "$MEM_PERCENT" | sed 's/%//')
            if (( $(echo "$MEM_NUM < 70" | bc -l) )); then
                MEM_COLOR=$GREEN
            elif (( $(echo "$MEM_NUM < 90" | bc -l) )); then
                MEM_COLOR=$YELLOW
            else
                MEM_COLOR=$RED
            fi

            echo -e "CPU:         ${CPU_COLOR}${CPU}${NC}"
            echo -e "Memory:      ${MEM_COLOR}${MEM_USAGE} (${MEM_PERCENT})${NC}"
            echo -e "Network I/O: $NET_IO"
            echo -e "Block I/O:   $BLOCK_IO"
        done
    fi
    echo ""
}

show_disk_usage() {
    echo -e "${BLUE}━━━ Disk Usage ━━━${NC}"

    DISK_INFO=$(df -h /volume1 | awk 'NR==2 {printf "Used: %s / %s (%s)", $3, $2, $5}')
    DISK_PERCENT=$(df -h /volume1 | awk 'NR==2 {print $5}' | sed 's/%//')

    if [ "$DISK_PERCENT" -lt 70 ]; then
        DISK_COLOR=$GREEN
    elif [ "$DISK_PERCENT" -lt 80 ]; then
        DISK_COLOR=$YELLOW
    else
        DISK_COLOR=$RED
    fi

    echo -e "/volume1:    ${DISK_COLOR}${DISK_INFO}${NC}"
    echo ""
}

show_runner_connectivity() {
    echo -e "${BLUE}━━━ Runner Connectivity ━━━${NC}"

    # Check GitHub API
    if docker exec "$CONTAINER_NAME" ping -c 1 -W 2 api.github.com >/dev/null 2>&1; then
        echo -e "GitHub API:  ${GREEN}✅ Reachable${NC}"
    else
        echo -e "GitHub API:  ${RED}❌ Unreachable${NC}"
    fi

    # Check runner status from logs
    RECENT_LOGS=$(docker logs --tail 50 "$CONTAINER_NAME" 2>&1)
    if echo "$RECENT_LOGS" | grep -q "Listening for Jobs"; then
        echo -e "Runner:      ${GREEN}✅ Listening for Jobs${NC}"
    else
        echo -e "Runner:      ${YELLOW}⚠️  Not listening (check logs)${NC}"
    fi
    echo ""
}

show_recent_activity() {
    echo -e "${BLUE}━━━ Recent Activity (Last 10 Log Lines) ━━━${NC}"
    docker logs --tail 10 "$CONTAINER_NAME" 2>&1 | sed 's/^/  /'
    echo ""
}

show_health_alerts() {
    ALERT_FILE="/volume1/docker/github-runner/alerts.log"

    if [ -f "$ALERT_FILE" ] && [ -s "$ALERT_FILE" ]; then
        echo -e "${BLUE}━━━ Recent Alerts (Last 5) ━━━${NC}"
        tail -n 5 "$ALERT_FILE" | sed 's/^/  /'
        echo ""
    fi
}

show_quick_commands() {
    echo -e "${BLUE}━━━ Quick Commands ━━━${NC}"
    echo "View logs:       docker logs $CONTAINER_NAME"
    echo "Follow logs:     docker logs -f $CONTAINER_NAME"
    echo "Restart runner:  docker restart $CONTAINER_NAME"
    echo "Stats (live):    docker stats $CONTAINER_NAME"
    echo ""
}

main() {
    while true; do
        print_header

        if check_container_status; then
            show_resource_usage
            show_disk_usage
            show_runner_connectivity
            show_recent_activity
            show_health_alerts
        fi

        show_quick_commands

        if [ "$CONTINUOUS" = false ]; then
            break
        fi

        echo -e "${YELLOW}Refreshing in 10 seconds... (Press Ctrl+C to stop)${NC}"
        sleep 10
    done
}

main
