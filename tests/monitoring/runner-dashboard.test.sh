#!/bin/bash
# Tests for scripts/monitoring/runner-dashboard.sh. Linux only (timeout, GNU date).

# shellcheck disable=SC2119 # run_check takes optional arguments
# shellcheck source=tests/monitoring/lib.sh
. "${BASH_SOURCE[0]%/*}/lib.sh"

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'

dash_case() {
    new_case "$1"
    SCRIPT=$DASHBOARD
}

# label_line LABEL: the output line starting with LABEL
label_line() {
    printf '%s\n' "$OUT" | grep -m 1 "^$1"
}

expect_color() {
    # expect_color LABEL COLOR|none
    local text
    text=$(label_line "$1")
    [ -n "$text" ] || { fail_case "no $1 line"; return; }
    case $2 in
        none) [[ $text != *$'\033['[0-9]* ]] || fail_case "$1 colored: $text" ;;
        *) [[ $text == *"$2"* ]] || fail_case "$1 not in the expected color: $(printf '%q' "$text")" ;;
    esac
}

expect_line_has() {
    local text
    text=$(label_line "$1")
    [[ $text == *"$2"* ]] || fail_case "$1 line lacks '$2': $text"
}

# 1. CPU and memory colors
for pair in "99.99 $GREEN" "100 $YELLOW" "149.99 $YELLOW" "150 $RED"; do
    dash_case "CPU ${pair%% *}"
    export FAKE_CPU="${pair%% *}%"
    run_check; expect_rc 0; expect_color "CPU:" "${pair#* }"
done
for pair in "69.99 $GREEN" "70 $YELLOW" "89.99 $YELLOW" "90 $RED"; do
    dash_case "memory ${pair%% *}"
    export FAKE_MEM="${pair%% *}%"
    run_check; expect_rc 0; expect_color "Memory:" "${pair#* }"
done
dash_case "CPU and memory not numbers"
export FAKE_CPU=-- FAKE_MEM=--
run_check; expect_rc 0
expect_line_has "CPU:" "n/a"; expect_color "CPU:" none
expect_line_has "Memory:" "n/a"; expect_color "Memory:" none

# 2. Disk colors
disk_case() {
    # disk_case PERCENT COLOR [MAX_DISK_PERCENT]
    dash_case "disk $1% with limit ${3:-default}"
    export FAKE_DF_PERCENT=$1
    [ -z "${3:-}" ] || CASE_ENV=(MAX_DISK_PERCENT="$3")
    run_check; expect_rc 0; expect_color "Disk:" "$2"
}
disk_case 79 "$GREEN"; disk_case 80 "$YELLOW"; disk_case 90 "$YELLOW"; disk_case 91 "$RED"
disk_case 91 "$YELLOW" 95; disk_case 96 "$RED" 95
disk_case 69 "$GREEN" 70; disk_case 70 "$YELLOW" 70; disk_case 71 "$RED" 70
disk_case 91 "$RED" abc
dash_case "df fails"
export FAKE_DF_FAIL=1
run_check; expect_rc 0; expect_line_has "Disk:" "n/a"
dash_case "disk sizes"
CASE_ENV=(DISK_PATH=/volume1/x)
run_check; expect_line_has "Disk:" "/volume1/x: 0.1 GiB / 1.0 GiB (10%)"
dash_case "the use column decides"
export FAKE_DF_USED=524288 FAKE_DF_PERCENT=91
run_check; expect_color "Disk:" "$RED"

# 3. Health and failing calls
for pair in "healthy $GREEN" "starting $YELLOW" "unhealthy $RED"; do
    dash_case "health ${pair%% *}"
    export FAKE_HEALTH=${pair%% *}
    run_check; expect_rc 0; expect_color "Health:" "${pair#* }"
done
dash_case "no healthcheck"
export FAKE_HEALTH=none
run_check; expect_line_has "Health:" "n/a"
dash_case "inspect fails"
export FAKE_INSPECT_FAIL=1
run_check; expect_rc 0; expect_line_has "Status:" "n/a"
dash_case "stats fails"
export FAKE_STATS_FAIL=1
run_check; expect_rc 0; expect_line_has "CPU:" "n/a"; expect_line_has "Memory:" "n/a"

# 4. Every run with Docker reachable exits 0: the harness checks each dashboard run's exit code

# 5. Container missing, and Docker unreachable
dash_case "no container"
export FAKE_DOCKER_MISSING=1
run_check; expect_rc 0; expect_line_has "Status:" "❌ Not Running"
dash_case "near name only"
export FAKE_CONTAINER_NAME=github-runner-2
run_check; expect_rc 0; expect_line_has "Status:" "❌ Not Running"
dash_case "docker unreachable"
export FAKE_DOCKER_UNREACHABLE=1
DASHBOARD_RC=1
run_check; expect_rc 1
expect_out "Docker not reachable: Cannot connect to the Docker daemon"

# 6. CONTAINER_NAME from .env
dash_case "CONTAINER_NAME"
write_env "CONTAINER_NAME=github-runner-b"
export FAKE_CONTAINER_NAME=github-runner-b
run_check; expect_rc 0; expect_line_has "Status:" "✅ Running"
while IFS= read -r call; do
    case $call in
        "docker[t] inspect"* | "docker[t] stats"*)
            [[ $call == *" github-runner-b" ]] || fail_case "call not for github-runner-b: $call" ;;
    esac
done < "$STUB_LOG"

# 7. The health-check log section
log_section() {
    printf '%s\n' "$OUT" | sed -n '/Health-check log/,/Quick Commands/p' | sed '1d;$d' | sed '/^$/d'
}
dash_case "log missing"
run_check; [ "$(log_section)" = "  no health-check log yet" ] || fail_case "log section: $(log_section)"
dash_case "log empty"
: > "$LOG_FILE"
run_check; [ "$(log_section)" = "  no health-check log yet" ] || fail_case "log section: $(log_section)"
dash_case "log one line"
NOW_FIXED=1
NOW=2000
echo "1970-01-01T00:30:00Z OK" > "$LOG_FILE"
run_check; [ "$(log_section)" = "  1970-01-01T00:30:00Z OK" ] || fail_case "log section: $(log_section)"
dash_case "log last 5 of 6"
NOW_FIXED=1
NOW=2000
for i in 1 2 3 4 5 6; do echo "1970-01-01T00:30:00Z line $i"; done > "$LOG_FILE"
run_check
[ "$(log_section | wc -l)" = 5 ] && [[ $(log_section) != *"line 1"* ]] || fail_case "log section: $(log_section)"
dash_case "LOG_FILE elsewhere"
echo "1970-01-01T00:30:00Z elsewhere" > "$CASE_DIR/other.log"
CASE_ENV=(LOG_FILE="$CASE_DIR/other.log")
run_check; expect_out "elsewhere"
stale_case() {
    # stale_case AGE COLOR
    dash_case "log line $1 seconds old"
    NOW_FIXED=1
    NOW=$((1800 + $1))
    echo "1970-01-01T00:30:00Z OK" > "$LOG_FILE"
    run_check
    if [ "$2" = red ]; then
        [[ $(log_section) == *"$RED"* ]] || fail_case "not red"
    else
        [[ $(log_section) != *$'\033['* ]] || fail_case "colored"
    fi
}
stale_case 901 red
stale_case 900 plain
dash_case "malformed last line"
NOW_FIXED=1
NOW=999999
echo "not a timestamp" > "$LOG_FILE"
run_check; [ "$(log_section)" = "  not a timestamp" ] || fail_case "log section: $(log_section)"

# 8. Continuous mode
dash_case "continuous"
OUT=$(env PATH="$STUB_DIR:$PATH" STUB_LOG="$STUB_LOG" TMPDIR="$CASE_TMP" RUNNER_DIR="$RUNNER_DIR" \
    REFRESH_SECONDS=1 timeout 3 "$BASH" "$DASHBOARD" --continuous 2> /dev/null)
draws=$(printf '%s\n' "$OUT" | grep -c "Status Dashboard")
[ "$draws" -ge 2 ] || fail_case "drew $draws times"

finish_case
exit $failed
