#!/bin/bash
# shellcheck disable=SC2034,SC2119,SC2120 # variables and optional arguments for the test files
# Shared harness for the monitoring tests: a fresh project folder per case, stubs for
# docker, curl, df, jq, timeout and bc first on PATH, and the checks every run must pass.
# Needs Linux (flock, timeout, GNU date); see docs/04-monitoring.md for running it in a container.

set -u -o pipefail

REPO_ROOT=$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)
STUB_DIR="$REPO_ROOT/tests/monitoring/stubs"
HEALTH_CHECK="$REPO_ROOT/scripts/monitoring/runner-health-check.sh"
DASHBOARD="$REPO_ROOT/scripts/monitoring/runner-dashboard.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failed=0
CASE_NAME=''
CASE_ERRORS=0
OUT=''
RC=0

DEFAULT_ENV=(
    "REPO_URL=https://github.com/your-username/your-repo"
    "GITHUB_PAT=ghp_xxx"
    "RUNNER_NAME=synology-general-runner"
)

is_root() {
    [ "$(id -u)" = 0 ]
}

fail_case() {
    echo "FAIL [$CASE_NAME]: $1"
    printf '%s\n' "--- stdout (exit $RC):" "$OUT"
    CASE_ERRORS=1
    failed=1
}

finish_case() {
    if [ -n "$CASE_NAME" ] && [ "$CASE_ERRORS" = 0 ]; then
        echo "ok   [$CASE_NAME]"
    fi
    CASE_NAME=''
}

skip_case() {
    echo "SKIP [$CASE_NAME]: $1"
    CASE_NAME=''
}

# new_case NAME: a fresh RUNNER_DIR with the default .env, its own state, log and TMPDIR, NOW=1000
new_case() {
    finish_case
    CASE_NAME=$1
    CASE_ERRORS=0
    CASE_DIR=$(mktemp -d "$WORK/case.XXXXXX")
    RUNNER_DIR="$CASE_DIR/runner"
    STATE_FILE="$RUNNER_DIR/health-check.state"
    LOG_FILE="$RUNNER_DIR/health-check.log"
    CASE_TMP="$CASE_DIR/tmp"
    STUB_LOG="$CASE_DIR/stub.log"
    mkdir -p "$RUNNER_DIR" "$CASE_TMP"
    : > "$STUB_LOG"
    : > "$CASE_DIR/curl.stdin"
    write_env
    NOW=1000
    NOW_FIXED=0
    CASE_ENV=()
    SCRIPT=$HEALTH_CHECK
    DASHBOARD_RC=0
    mkdir -p "$CASE_DIR/fallback-tmp"
    local var
    for var in $(compgen -v FAKE_); do
        unset "$var"
    done
}

# write_env [LINE...]: the default .env lines plus these, written with printf so $ stays literal
write_env() {
    printf '%s\n' "${DEFAULT_ENV[@]}" "$@" > "$RUNNER_DIR/.env"
}

# run_check [ARGS...]: runs $SCRIPT once with the case's environment; sets OUT and RC.
# Exported FAKE_* variables steer the stubs; CASE_ENV holds extra VAR=value pairs.
run_check() {
    local stderr="$CASE_DIR/stderr"
    OUT=$(env -u RUNNER_NAME -u CONTAINER_NAME -u DISK_PATH -u MAX_DISK_PERCENT \
        -u ALERT_AFTER_FAILURES -u REMIND_AFTER_SECONDS -u REFRESH_SECONDS -u TERM \
        PATH="$STUB_DIR:$PATH" STUB_LOG="$STUB_LOG" TMPDIR="$CASE_TMP" \
        RUNNER_DIR="$RUNNER_DIR" STATE_FILE="$STATE_FILE" LOG_FILE="$LOG_FILE" \
        DEFAULT_DATA_DIR="$CASE_DIR/no-default-data" FALLBACK_TMP="$CASE_DIR/fallback-tmp" NOW="$NOW" \
        ${CASE_ENV[@]+"${CASE_ENV[@]}"} "$BASH" "$SCRIPT" "$@" 2> "$stderr")
    RC=$?
    STDERR=$(cat "$stderr")
    check_run
    [ "$NOW_FIXED" = 1 ] || NOW=$((NOW + 300))
}

# The checks every run passes
check_run() {
    local line
    if printf '%s\n' "$OUT" | grep -q STUBERR; then
        fail_case "a tool's stderr reached stdout"
    fi
    if grep -q '^bc' "$STUB_LOG"; then
        fail_case "bc was called"
    fi
    while IFS= read -r line; do
        case $line in
            "docker[t] "* | "df[t] "*) ;;
            docker* | df*) fail_case "not run through timeout -k 5 20: $line" ;;
            curl*) [[ $line == *"--max-time 20"* ]] || fail_case "curl without --max-time 20: $line" ;;
        esac
    done < "$STUB_LOG"
    if [ "$SCRIPT" = "$DASHBOARD" ] && [ "$RC" != "$DASHBOARD_RC" ]; then
        fail_case "dashboard exit $RC, expected $DASHBOARD_RC"
    fi
    if [ "$SCRIPT" = "$HEALTH_CHECK" ] || [ "${SCRIPT##*/}" = runner-health-check.sh ]; then
        if [ -d "$CASE_TMP" ] && [ ! -L "$CASE_TMP" ]; then
            local leftover
            leftover=$(cd "$CASE_TMP" && find . -mindepth 1 ! -path ./runner-health-check \
                ! -path './runner-health-check/*.marker')
            [ -z "$leftover" ] || fail_case "left in TMPDIR: $leftover"
        fi
        if [ "$RC" = 0 ] && [ -n "$OUT" ]; then
            fail_case "stdout not empty on exit 0"
        fi
        if [ "$RC" = 1 ] && [[ $OUT != "Runner health check ("* ]]; then
            fail_case "email does not start with the subject line"
        fi
    fi
}

expect_rc() {
    [ "$RC" = "$1" ] || fail_case "exit $RC, expected $1"
}

expect_out() {
    printf '%s\n' "$OUT" | grep -qF -- "$1" || fail_case "stdout lacks: $1"
}

expect_no_out() {
    ! printf '%s\n' "$OUT" | grep -qF -- "$1" || fail_case "stdout has: $1"
}

expect_out_exact() {
    [ "$OUT" = "$1" ] || fail_case "stdout differs from: $1"
}

# expect_runs RC...: runs once per code, expecting each
expect_runs() {
    local rc
    for rc in "$@"; do
        run_check
        expect_rc "$rc"
    done
}

last_log() {
    tail -n 1 "$LOG_FILE" 2> /dev/null
}

expect_last_log() {
    local line
    line=$(last_log)
    [ "${line#* }" = "$1" ] || fail_case "last log line '$line', expected event '$1'"
}

expect_log_count() {
    local n=0
    [ ! -f "$LOG_FILE" ] || n=$(wc -l < "$LOG_FILE")
    [ "$n" = "$1" ] || fail_case "log has $n lines, expected $1"
}

state_value() {
    grep "^$1=" "$STATE_FILE" 2> /dev/null | tail -n 1 | cut -d= -f2-
}
