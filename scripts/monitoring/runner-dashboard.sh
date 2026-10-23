#!/bin/bash
# GitHub Self-Hosted Runner - status dashboard
#
# Shows the container's state, CPU, memory, disk and the health check's log.
# Usage: sudo bash <project folder>/scripts/monitoring/runner-dashboard.sh [--continuous]
# --continuous redraws every REFRESH_SECONDS (default 10). The container name and the
# workspace come from the project's .env; see docs/04-monitoring.md.

set -Eeu -o pipefail

# Appended, never prepended: DSM keeps docker in /usr/local/bin, which sudo's PATH may lack
PATH="$PATH:/usr/local/bin:/usr/bin:/bin"

script_dir=${BASH_SOURCE[0]%/*}
[ "$script_dir" != "${BASH_SOURCE[0]}" ] || script_dir=.
RUNNER_DIR=${RUNNER_DIR:-$(cd "$script_dir/../.." && pwd)}
ENV_FILE="$RUNNER_DIR/.env"
LOG_FILE=${LOG_FILE:-$RUNNER_DIR/health-check.log}
DEFAULT_DATA_DIR=${DEFAULT_DATA_DIR:-/volume1/docker/github-runner}
DOCKER_TIMEOUT=(timeout -k 5 20)
LOG_STALE_SECONDS=900

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

read_env_value() {
    local file=$1 key=$2 line rest value quote
    ENV_VALUE=''
    ENV_VALUE_QUOTE=none
    [ -r "$file" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
        line=${line%$'\r'}
        line=${line#"${line%%[![:space:]]*}"}
        case $line in
            export[[:space:]]*)
                line=${line#export}
                line=${line#"${line%%[![:space:]]*}"}
                ;;
        esac
        [ "${line#"$key"}" != "$line" ] || continue
        rest=${line#"$key"}
        rest=${rest#"${rest%%[![:space:]]*}"}
        case $rest in
            =*) rest=${rest#=} ;;
            *) continue ;;
        esac
        rest=${rest#"${rest%%[![:space:]]*}"}
        case $rest in
            \'*)
                rest=${rest#\'}
                value=${rest%%\'*}
                quote=single
                ;;
            \"*)
                rest=${rest#\"}
                value=${rest%%\"*}
                quote=double
                ;;
            *)
                value=${rest%% \#*}
                value=${value%"${value##*[![:space:]]}"}
                quote=none
                ;;
        esac
        ENV_VALUE=$value
        # shellcheck disable=SC2034 # read by callers that need to know the quoting
        ENV_VALUE_QUOTE=$quote
    done < "$file"
    return 0
}

is_whole_number() {
    case $1 in
        0) return 0 ;;
        [1-9] | [1-9]*[0-9]) ;;
        *) return 1 ;;
    esac
    case $1 in
        *[!0-9]*) return 1 ;;
    esac
    [ "${#1}" -le 10 ]
}

CONTINUOUS=false
[ "${1:-}" != --continuous ] || CONTINUOUS=true

read_env_value "$ENV_FILE" CONTAINER_NAME
CONTAINER_NAME=${ENV_VALUE:-github-runner}
read_env_value "$ENV_FILE" RUNNER_WORKDIR
RUNNER_WORKDIR=$ENV_VALUE
read_env_value "$ENV_FILE" RUNNER_DATA_DIR
RUNNER_DATA_DIR=$ENV_VALUE

if [ -z "${DISK_PATH:-}" ]; then
    if [ -n "$RUNNER_WORKDIR" ]; then
        DISK_PATH=$RUNNER_WORKDIR
    elif [ -n "$RUNNER_DATA_DIR" ]; then
        DISK_PATH=$RUNNER_DATA_DIR
    elif [ -d "$DEFAULT_DATA_DIR" ]; then
        DISK_PATH=$DEFAULT_DATA_DIR
    else
        DISK_PATH=$RUNNER_DIR
    fi
fi
is_whole_number "${MAX_DISK_PERCENT:-}" || MAX_DISK_PERCENT=90
REFRESH_SECONDS=${REFRESH_SECONDS:-10}
if ! is_whole_number "$REFRESH_SECONDS" || [ "$REFRESH_SECONDS" -lt 1 ]; then
    REFRESH_SECONDS=10
fi
FIXED_NOW=''
! is_whole_number "${NOW:-}" || FIXED_NOW=$NOW

line() {
    # line LABEL VALUE [COLOR]
    if [ -n "${3:-}" ]; then
        printf '%-13s%b%s%b\n' "$1" "$3" "$2" "$NC"
    else
        printf '%-13s%s\n' "$1" "$2"
    fi
}

section() {
    printf '%b━━━ %s ━━━%b\n' "$BLUE" "$1" "$NC"
}

# color_for VALUE YELLOW_FROM RED_FROM: green, yellow or red by threshold, empty for a non-number
color_for() {
    case $(awk -v v="$1" -v y="$2" -v r="$3" 'BEGIN {
            if (v !~ /^[0-9]+(\.[0-9]+)?$/) print "none"
            else if (v + 0 < y + 0) print "green"
            else if (v + 0 < r + 0) print "yellow"
            else print "red"
        }') in
        green) printf '%s' "$GREEN" ;;
        yellow) printf '%s' "$YELLOW" ;;
        red) printf '%s' "$RED" ;;
    esac
}

print_header() {
    clear 2> /dev/null || true
    printf '%b╔════════════════════════════════════════════════════════════════╗%b\n' "$BLUE" "$NC"
    printf '%b║     GitHub Self-Hosted Runner - Status Dashboard               ║%b\n' "$BLUE" "$NC"
    printf '%b╚════════════════════════════════════════════════════════════════╝%b\n' "$BLUE" "$NC"
    echo ""
    echo "📅 $(date -d "@$NOW" '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

# Sets RUNNING=1 when the container runs
show_container() {
    local out rc=0 name status started restarts health first_error=''
    RUNNING=0
    section "Container Status ($CONTAINER_NAME)"
    out=$("${DOCKER_TIMEOUT[@]}" docker inspect --type container \
        --format '{{.Name}}|{{.State.Status}}|{{.State.StartedAt}}|{{.RestartCount}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
        "$CONTAINER_NAME" 2> "$ERR_FILE") || rc=$?
    if [ "$rc" != 0 ]; then
        IFS= read -r first_error < "$ERR_FILE" || true
        case $first_error in
            *"No such container"* | *"No such object"*) line "Status:" "❌ Not Running" "$RED" ;;
            *) line "Status:" "n/a" ;;
        esac
        echo ""
        return 0
    fi
    IFS='|' read -r name status started restarts health <<< "$out" || true
    if [ "$name" != "/$CONTAINER_NAME" ]; then
        line "Status:" "❌ Not Running" "$RED"
        echo ""
        return 0
    fi
    if [ "$status" = running ]; then
        RUNNING=1
        line "Status:" "✅ Running" "$GREEN"
    else
        line "Status:" "❌ Not Running ($status)" "$RED"
    fi
    line "Started:" "$started"
    if [ "$restarts" = 0 ]; then
        line "Restarts:" "$restarts" "$GREEN"
    else
        line "Restarts:" "$restarts" "$YELLOW"
    fi
    case $health in
        healthy) line "Health:" healthy "$GREEN" ;;
        starting) line "Health:" starting "$YELLOW" ;;
        unhealthy) line "Health:" unhealthy "$RED" ;;
        *) line "Health:" "n/a" ;;
    esac
    echo ""
}

show_resources() {
    local out cpu mem_usage mem_percent
    section "Resource Usage"
    if ! out=$("${DOCKER_TIMEOUT[@]}" docker stats --no-stream \
        --format '{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}' "$CONTAINER_NAME" 2> /dev/null); then
        line "CPU:" "n/a"
        line "Memory:" "n/a"
        echo ""
        return 0
    fi
    IFS='|' read -r cpu mem_usage mem_percent <<< "$out" || true
    if [ -n "$(color_for "${cpu%\%}" 100 150)" ]; then
        line "CPU:" "$cpu" "$(color_for "${cpu%\%}" 100 150)"
    else
        line "CPU:" "n/a"
    fi
    if [ -n "$(color_for "${mem_percent%\%}" 70 90)" ]; then
        line "Memory:" "$mem_usage ($mem_percent)" "$(color_for "${mem_percent%\%}" 70 90)"
    else
        line "Memory:" "n/a"
    fi
    echo ""
}

show_disk() {
    local out text percent green_below
    section "Disk Usage"
    if ! out=$("${DOCKER_TIMEOUT[@]}" df -P "$DISK_PATH" 2> /dev/null) \
        || ! text=$(printf '%s\n' "$out" | awk 'NR == 2 && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ {
            printf "%.1f GiB / %.1f GiB", $3 / 1048576, $2 / 1048576; found = 1 }
            END { exit !found }'); then
        line "Disk:" "n/a"
        echo ""
        return 0
    fi
    percent=$(printf '%s\n' "$out" | awk 'NR == 2 { sub(/%$/, "", $5); print $5 }')
    if ! is_whole_number "$percent"; then
        line "Disk:" "n/a"
        echo ""
        return 0
    fi
    green_below=80
    [ "$MAX_DISK_PERCENT" -ge 80 ] || green_below=$MAX_DISK_PERCENT
    if [ "$percent" -lt "$green_below" ]; then
        line "Disk:" "$DISK_PATH: $text ($percent%)" "$GREEN"
    elif [ "$percent" -le "$MAX_DISK_PERCENT" ]; then
        line "Disk:" "$DISK_PATH: $text ($percent%)" "$YELLOW"
    else
        line "Disk:" "$DISK_PATH: $text ($percent%)" "$RED"
    fi
    echo ""
}

# The last line in red when the health check hasn't logged for 15 minutes: the monitor may have stopped
show_health_log() {
    local lines last stamp when
    section "Health-check log"
    if [ ! -s "$LOG_FILE" ]; then
        echo "  no health-check log yet"
        echo ""
        return 0
    fi
    lines=$(tail -n 5 "$LOG_FILE" 2> /dev/null) || lines=''
    last=$(printf '%s\n' "$lines" | tail -n 1)
    printf '%s\n' "$lines" | sed '$d' | sed 's/^/  /'
    stamp=${last%% *}
    if when=$(date -u -d "$stamp" +%s 2> /dev/null) && [[ $stamp == *T*Z ]]; then
        if [ $((NOW - when)) -gt "$LOG_STALE_SECONDS" ]; then
            printf '  %b%s%b\n' "$RED" "$last" "$NC"
            echo ""
            return 0
        fi
    fi
    printf '  %s\n' "$last"
    echo ""
}

show_quick_commands() {
    section "Quick Commands"
    echo "View logs:       sudo docker logs $CONTAINER_NAME"
    echo "Follow logs:     sudo docker logs -f $CONTAINER_NAME"
    echo "Restart runner:  sudo docker restart $CONTAINER_NAME"
    echo "Stats (live):    sudo docker stats $CONTAINER_NAME"
    echo ""
}

draw() {
    local first_error
    NOW=${FIXED_NOW:-$(date +%s)}
    print_header
    if ! "${DOCKER_TIMEOUT[@]}" docker info --format '{{.ServerVersion}}' > /dev/null 2> "$ERR_FILE"; then
        first_error=''
        IFS= read -r first_error < "$ERR_FILE" || true
        echo "Docker not reachable: $first_error"
        return 1
    fi
    show_container
    if [ "$RUNNING" = 1 ]; then
        show_resources
    fi
    show_disk
    show_health_log
    show_quick_commands
}

ERR_FILE=$(mktemp)
trap 'rm -f "$ERR_FILE"' EXIT

while true; do
    draw || exit 1
    [ "$CONTINUOUS" = true ] || break
    printf '%bRefreshing in %s seconds... (Ctrl+C stops)%b\n' "$YELLOW" "$REFRESH_SECONDS" "$NC"
    sleep "$REFRESH_SECONDS"
done
