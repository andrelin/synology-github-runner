#!/bin/bash
# Tests for scripts/monitoring/runner-health-check.sh. Linux only (flock, timeout, GNU date).

# shellcheck disable=SC2119 # run_check takes optional arguments
# shellcheck source=tests/monitoring/lib.sh
. "${BASH_SOURCE[0]%/*}/lib.sh"

email() {
    # email KIND [LINE...]: the expected body
    local kind=$1
    shift
    printf 'Runner health check (%s): %s' "${EMAIL_NAME:-github-runner}" "$kind"
    [ "$#" -eq 0 ] || printf '\n%s' "$@"
}

# 1. Healthy
new_case "healthy"
run_check
expect_rc 0
[ "$(cat "$LOG_FILE")" = "1970-01-01T00:16:40Z OK" ] || fail_case "log: $(cat "$LOG_FILE")"

# 2. Grace, then one email, then silence
new_case "grace and silence"
export FAKE_STATUS=exited
run_check; expect_rc 0; expect_last_log "FAIL 1/3 container_running"
run_check; expect_rc 0; expect_last_log "FAIL 2/3 container_running"
run_check; expect_rc 1; expect_last_log "PROBLEM container_running"
expect_out_exact "$(email PROBLEM "- container_running: container github-runner is exited" "" \
    "Next step: docker logs github-runner")"
run_check; expect_rc 0; expect_last_log "FAIL 4/3 container_running"

# 3. Reminders
reminder_case() {
    # reminder_case NAME [VAR=value]: alerted at NOW=1600 with ALERT_AFTER_FAILURES=3
    new_case "reminder: $1"
    shift
    CASE_ENV=("$@")
    export FAKE_STATUS=exited
    NOW_FIXED=1
    for NOW in 1000 1300 1600; do run_check; done
    expect_rc 1
}
at() {
    NOW=$1
    run_check
    expect_rc "$2"
}
reminder_case "default"
at 87999 0; at 88000 1; expect_out "REMINDER"; expect_last_log "REMINDER container_running"
at 88300 0; at 174400 1
reminder_case "an hour" REMIND_AFTER_SECONDS=3600
at 5199 0; at 5200 1; expect_out "REMINDER"
reminder_case "every run" REMIND_AFTER_SECONDS=0
at 1900 1; at 2200 1; expect_out "REMINDER"

# 4. Recovery
new_case "recovery"
export FAKE_STATUS=exited
expect_runs 0 0 1
unset FAKE_STATUS
run_check; expect_rc 1; expect_out_exact "$(email RECOVERED)"; expect_last_log RECOVERED
run_check; expect_rc 0; expect_last_log OK
export FAKE_STATUS=exited
expect_runs 0 0 1

# 5. Recovering within the grace
new_case "recovering within the grace"
export FAKE_STATUS=exited
expect_runs 0 0
unset FAKE_STATUS
expect_runs 0 0

# 6. Container states
state_case() {
    new_case "container state: $1"
    CASE_ENV=(ALERT_AFTER_FAILURES=1)
}
state_case "unhealthy"
export FAKE_HEALTH=unhealthy
run_check; expect_rc 1; expect_out "- container_running: container github-runner healthcheck reports unhealthy"
state_case "restarting"
export FAKE_STATUS=restarting
run_check; expect_rc 1; expect_out "- container_running: container github-runner is restarting"
state_case "starting"
export FAKE_HEALTH=starting
run_check; expect_rc 0

# 7. Runner offline or missing
offline_case() {
    new_case "offline: $1"
    export FAKE_API_JSON=$2
    expect_runs 0 0 1
    expect_out "- runner_online: runner synology-general-runner is offline or not registered"
}
offline_case "offline" '{"runners":[{"name":"synology-general-runner","status":"offline"}]}'
offline_case "absent" '{"runners":[{"name":"other","status":"online"}]}'
offline_case "near name" '{"runners":[{"name":"synology-general-runner-2","status":"online"}]}'
offline_case "another online" \
    '{"runners":[{"name":"other","status":"online"},{"name":"synology-general-runner","status":"offline"}]}'

# 8. API outcomes
api_case() {
    # api_case NAME REASON: one run with ALERT_AFTER_FAILURES=1; FAKE_* set by the caller after
    new_case "api: $1"
    CASE_ENV=(ALERT_AFTER_FAILURES=1)
    API_REASON=$2
}
api_check() {
    run_check
    expect_rc 1
    expect_out "- runner_online: $API_REASON"
}
for code in 401 403; do
    api_case "$code" "GitHub rejected GITHUB_PAT (HTTP $code): expired, missing rights or rate-limited"
    export FAKE_HTTP_CODE=$code; api_check
done
api_case 404 "GitHub API returned 404: check REPO_URL or ORG_NAME"; export FAKE_HTTP_CODE=404; api_check
api_case 500 "GitHub API returned HTTP 500"; export FAKE_HTTP_CODE=500; api_check
api_case "curl timeout" "GitHub API unreachable (curl exit 28)"; export FAKE_CURL_EXIT=28; api_check
for body in '<html>rate limit</html>' '{}' '[]' '{"runners":"x"}'; do
    api_case "body $body" "unexpected API response"; export FAKE_API_JSON=$body; api_check
done
api_case "no runners" "runner synology-general-runner is offline or not registered"
export FAKE_API_JSON='{"runners":[]}'; api_check

# 9. Request shape
request_case() {
    # request_case NAME URL [.env lines]
    local name=$1 url=$2
    shift 2
    new_case "request: $name"
    write_env "$@"
    run_check
    expect_rc 0
    grep -qxF "url = \"$url\"" "$CASE_DIR/curl.stdin" || fail_case "curl stdin: $(cat "$CASE_DIR/curl.stdin")"
    grep -qF 'Authorization: Bearer ghp_xxx' "$CASE_DIR/curl.stdin" || fail_case "no Authorization header"
    ! grep -q '^curl.*ghp_xxx' "$STUB_LOG" || fail_case "token in curl's arguments"
}
REPO_API="https://api.github.com/repos/your-username/your-repo/actions/runners?per_page=100"
ORG_API="https://api.github.com/orgs/your-org/actions/runners?per_page=100"
request_case "repository" "$REPO_API"
for suffix in .git/ .git /; do
    request_case "REPO_URL ending $suffix" "$REPO_API" "REPO_URL=https://github.com/your-username/your-repo$suffix"
done
request_case "org" "$ORG_API" "RUNNER_SCOPE=org" "ORG_NAME=your-org"
request_case "Organization" "$ORG_API" "RUNNER_SCOPE=Organization" "ORG_NAME=your-org"

# 10. Online check skipped
new_case "skipped without a PAT"
DEFAULT_ENV=("REPO_URL=https://github.com/your-username/your-repo" "RUNNER_NAME=synology-general-runner")
write_env "APP_ID=1" "APP_PRIVATE_KEY=x"
run_check; expect_rc 0; expect_last_log "OK; online check skipped (no GITHUB_PAT)"
grep -q '^curl' "$STUB_LOG" && fail_case "curl called"
DEFAULT_ENV=("REPO_URL=https://github.com/your-username/your-repo" "GITHUB_PAT=ghp_xxx" "RUNNER_NAME=synology-general-runner")
new_case "skipped off github.com"
write_env "REPO_URL=https://www.github.com/your-username/your-repo"
run_check; expect_rc 0; expect_last_log "OK; online check skipped (REPO_URL is not on github.com)"
grep -q '^curl' "$STUB_LOG" && fail_case "curl called"
new_case "org scope ignores REPO_URL"
write_env "REPO_URL=https://example.com/x" "RUNNER_SCOPE=org" "ORG_NAME=your-org"
run_check; expect_rc 0; expect_last_log OK
grep -q '^curl' "$STUB_LOG" || fail_case "curl not called"

# 11. Configuration
config_case() {
    # config_case NAME REASON .env-lines... (a missing .env when the first line is NONE)
    local name=$1 reason=$2
    shift 2
    new_case "configuration: $name"
    reason=${reason//@RUNNER_DIR@/$RUNNER_DIR}
    if [ "${1:-}" = NONE ]; then
        rm "$RUNNER_DIR/.env"
    else
        printf '%s\n' "$@" > "$RUNNER_DIR/.env"
    fi
    NOW_FIXED=1
    run_check
    expect_rc 1
    expect_out_exact "$(email PROBLEM "- configuration: $reason" "" "Next step: edit $RUNNER_DIR/.env")"
    [ ! -s "$STUB_LOG" ] || fail_case "tools called: $(cat "$STUB_LOG")"
    NOW=1300; run_check; expect_rc 0
    NOW=87399; run_check; expect_rc 0
    NOW=87400; run_check; expect_rc 1; expect_out REMINDER
}
PAT=GITHUB_PAT=ghp_xxx
config_case "no .env" ".env not found in @RUNNER_DIR@" NONE
config_case "empty REPO_URL" "REPO_URL is empty" "REPO_URL=" "$PAT"
config_case "org without ORG_NAME" "ORG_NAME is empty" "RUNNER_SCOPE=org" "$PAT"
config_case "enterprise" "enterprise scope is not supported" "RUNNER_SCOPE=enterprise" "$PAT"
config_case "no credentials" "no credentials: set GITHUB_PAT, or APP_ID and APP_PRIVATE_KEY" \
    "REPO_URL=https://github.com/your-username/your-repo"
config_case "APP_ID alone" "no credentials: set GITHUB_PAT, or APP_ID and APP_PRIVATE_KEY" \
    "REPO_URL=https://github.com/your-username/your-repo" "APP_ID=1"
new_case "configuration: repository scope word"
write_env "RUNNER_SCOPE=repository"
run_check; expect_rc 0
new_case "configuration: APP_PRIVATE_KEY alone"
printf '%s\n' "REPO_URL=https://github.com/your-username/your-repo" "APP_PRIVATE_KEY=x" > "$RUNNER_DIR/.env"
run_check; expect_rc 0

# 12. Defaults for empty values; the environment never describes the installation
new_case "empty values take defaults"
write_env "RUNNER_SCOPE=" "CONTAINER_NAME=" "RUNNER_NAME="
run_check; expect_rc 0
grep -qxF "url = \"$REPO_API\"" "$CASE_DIR/curl.stdin" || fail_case "not repository scope"
grep -q '^docker\[t\] inspect .* github-runner$' "$STUB_LOG" || fail_case "container name not the default"
new_case "CONTAINER_NAME in the environment is ignored"
CASE_ENV=(CONTAINER_NAME=x)
run_check; expect_rc 0
grep -q '^docker\[t\] inspect .* github-runner$' "$STUB_LOG" || fail_case "environment CONTAINER_NAME used"

# 13. .env parsing: each line appended after the defaults; only the expected name is online
parse_case() {
    # parse_case LINE EXPECTED_RUNNER_NAME
    new_case "parse: $1"
    printf '%s\n%b\n' "$(printf '%s\n' "${DEFAULT_ENV[@]}")" "$1" > "$RUNNER_DIR/.env"
    export FAKE_API_JSON="{\"runners\":[{\"name\":\"$2\",\"status\":\"online\"}]}"
    CASE_ENV=(ALERT_AFTER_FAILURES=1)
    run_check
    expect_rc 0
}
parse_case 'RUNNER_NAME=v' v
parse_case 'export RUNNER_NAME=v' v
parse_case '  RUNNER_NAME=v' v
parse_case 'RUNNER_NAME = v' v
parse_case 'RUNNER_NAME=v\r' v
parse_case 'RUNNER_NAME=v   ' v
parse_case 'RUNNER_NAME=v # note' v
parse_case 'RUNNER_NAME=a#b' 'a#b'
parse_case "RUNNER_NAME='a #b'" 'a #b'
parse_case 'RUNNER_NAME="a #b"' 'a #b'
parse_case "RUNNER_NAME='a' # note" a
parse_case 'RUNNER_NAME="a"b' a
parse_case 'RUNNER_NAME="a' a
parse_case 'RUNNER_NAME=a=b' 'a=b'
parse_case '# RUNNER_NAME=x' synology-general-runner
parse_case 'RUNNER_NAME2=x' synology-general-runner
parse_case 'OLD_RUNNER_NAME=x' synology-general-runner
parse_case '' synology-general-runner
parse_case 'RUNNER_NAME=first\nRUNNER_NAME=second' second
new_case "parse: a tab before # stays in the value"
printf 'GITHUB_PAT=ghp_xxx\tx\n' >> "$RUNNER_DIR/.env"
run_check; expect_rc 0
grep -qF "Authorization: Bearer ghp_xxx"$'\t'"x" "$CASE_DIR/curl.stdin" || fail_case "token not read with the tab"
new_case "parse: quote kinds"
sed -n '/^read_env_value() {/,/^}/p' "$HEALTH_CHECK" > "$CASE_DIR/fn.sh"
for row in "KEY=v|v|none" "KEY='a #b'|a #b|single" 'KEY="a #b"|a #b|double' 'KEY="a|a|double'; do
    IFS='|' read -r line value quote <<< "$row"
    printf '%s\n' "$line" > "$CASE_DIR/q.env"
    # shellcheck source=/dev/null
    got=$(. "$CASE_DIR/fn.sh"; read_env_value "$CASE_DIR/q.env" KEY; printf '%s|%s' "$ENV_VALUE" "$ENV_VALUE_QUOTE")
    [ "$got" = "$value|$quote" ] || fail_case "$line: got $got"
done
new_case "parse: RUNNER_NAME in the environment loses to .env"
write_env "RUNNER_NAME=from-env-file"
export FAKE_API_JSON='{"runners":[{"name":"from-env-file","status":"online"}]}'
CASE_ENV=(RUNNER_NAME=from-environment ALERT_AFTER_FAILURES=1)
run_check; expect_rc 0

# 14. Docker failures
docker_case() {
    new_case "docker: $1"
    CASE_ENV=(ALERT_AFTER_FAILURES=1)
}
docker_case "missing"
export FAKE_DOCKER_MISSING=1
run_check; expect_rc 1; expect_out "- container_running: container github-runner not found"
docker_case "timeout"
export FAKE_DOCKER_EXIT=124
run_check; expect_rc 1; expect_out "- container_running: docker did not answer within 20 s"
docker_case "killed by timeout"
export FAKE_DOCKER_EXIT=137
run_check; expect_rc 1; expect_out "- container_running: docker did not answer within 20 s"
docker_case "daemon error"
export FAKE_DOCKER_EXIT=1 FAKE_DOCKER_STDERR="Cannot connect to the Docker daemon"
run_check; expect_rc 1; expect_out "- container_running: docker failed: Cannot connect to the Docker daemon"
expect_no_out "second line"

# 15. Restarts
new_case "restarts"
NOW_FIXED=1
NOW=1000; run_check; expect_rc 0
restart_at() {
    # restart_at NOW COUNT RC [passing run 300 s later]
    export FAKE_RESTARTS=$2
    NOW=$1; run_check; expect_rc "$3"
}
restart_at 1300 1 0; expect_last_log "FAIL 1/3 no_new_restarts"
NOW=1600; run_check; expect_rc 0
restart_at 2500 2 0
NOW=2800; run_check; expect_rc 0
restart_at 3700 3 1; expect_out "- no_new_restarts: container restarted"
NOW=4000; run_check; expect_rc 0; expect_last_log OK
NOW=22900; run_check; expect_rc 0
[ "$(state_value RESTART_TIMES)" = "1300,2500,3700" ] || fail_case "times $(state_value RESTART_TIMES)"
NOW=22901; run_check; expect_rc 1; expect_out_exact "$(email RECOVERED)"
[ "$(state_value RESTART_TIMES)" = "2500,3700" ] || fail_case "times $(state_value RESTART_TIMES)"
new_case "restarts: three at once"
run_check
export FAKE_RESTARTS=3
run_check; expect_rc 1; expect_out "no_new_restarts"
new_case "restarts: lower count resets the baseline"
export FAKE_RESTARTS=5
run_check
export FAKE_RESTARTS=0
run_check; expect_rc 0; [ "$(state_value RESTART_COUNT)" = 0 ] || fail_case "baseline not reset"
[ -z "$(state_value RESTART_TIMES)" ] || fail_case "a restart recorded"
new_case "restarts: docker failure leaves the state"
export FAKE_RESTARTS=2
run_check
before=$(grep -E '^(CONTAINER_ID|RESTART_COUNT|RESTART_TIMES)=' "$STATE_FILE")
export FAKE_DOCKER_EXIT=1
run_check
[ "$(grep -E '^(CONTAINER_ID|RESTART_COUNT|RESTART_TIMES)=' "$STATE_FILE")" = "$before" ] || fail_case "state changed"
is_failing_log=$(last_log)
[[ $is_failing_log == *"no_new_restarts"* ]] && fail_case "restart check failed on a docker error"
new_case "restarts: recreated container"
export FAKE_RESTARTS=4
run_check
export FAKE_CONTAINER_ID=def456 FAKE_RESTARTS=0
run_check; expect_rc 0
[ "$(state_value CONTAINER_ID)" = def456 ] && [ "$(state_value RESTART_COUNT)" = 0 ] || fail_case "baseline not reset"

# 16. Disk
new_case "disk at the limit"
export FAKE_DF_PERCENT=90
CASE_ENV=(ALERT_AFTER_FAILURES=1)
run_check; expect_rc 0
new_case "disk over the limit"
export FAKE_DF_PERCENT=91
CASE_ENV=(ALERT_AFTER_FAILURES=1 DISK_PATH=/volume1/x)
run_check; expect_rc 1
expect_out "- disk_space: /volume1/x is 91% full (limit 90%)"
expect_out "Next step: free space on /volume1/x"
new_case "df fails"
export FAKE_DF_FAIL=1
CASE_ENV=(ALERT_AFTER_FAILURES=1 DISK_PATH=/volume1/x)
run_check; expect_rc 1; expect_out "- disk_space: df failed for /volume1/x"

# 17. New failing checks during an incident
new_case "a new check during an incident"
CASE_ENV=(ALERT_AFTER_FAILURES=1)
export FAKE_DF_PERCENT=95
run_check; expect_rc 1
run_check; expect_rc 0
export FAKE_HEALTH=unhealthy
run_check; expect_rc 1; expect_last_log "PROBLEM container_running,disk_space"
unset FAKE_HEALTH
run_check; expect_rc 0
export FAKE_HEALTH=unhealthy
run_check; expect_rc 0

# 18. Next-step precedence
precedence_case() {
    new_case "next step: $1"
    CASE_ENV=(ALERT_AFTER_FAILURES=1)
}
precedence_case "configuration and settings"
write_env "REPO_URL="
CASE_ENV+=(MAX_DISK_PERCENT=abc)
run_check; expect_rc 1; expect_out "Next step: edit $RUNNER_DIR/.env"
precedence_case "settings and disk"
CASE_ENV+=(MAX_DISK_PERCENT=abc)
export FAKE_DF_PERCENT=95
run_check; expect_rc 1; expect_out "Next step: fix the environment variables in the scheduled task"
precedence_case "disk and container"
export FAKE_DF_PERCENT=95 FAKE_STATUS=exited
run_check; expect_rc 1; expect_out "Next step: docker logs github-runner"
precedence_case "storage and disk"
if is_root; then
    skip_case "running as root"
else
    run_check
    export FAKE_DF_PERCENT=95
    chmod 500 "$RUNNER_DIR"
    run_check; expect_rc 1
    expect_out "- storage: cannot write"
    expect_out "- disk_space:"
    expect_out "Next step: check free space and permissions for $RUNNER_DIR"
    chmod 700 "$RUNNER_DIR"
fi
precedence_case "internal"
CASE_ENV+=(TMPDIR=/nonexistent/dir)
run_check; expect_rc 1; expect_out "Next step: run sudo bash $HEALTH_CHECK by hand to see the error"

# 19. Another container name
new_case "CONTAINER_NAME"
write_env "CONTAINER_NAME=github-runner-b"
export FAKE_CONTAINER_NAME=github-runner-b FAKE_STATUS=exited
CASE_ENV=(ALERT_AFTER_FAILURES=1)
EMAIL_NAME=github-runner-b
run_check; expect_rc 1
expect_out_exact "$(email PROBLEM "- container_running: container github-runner-b is exited" "" \
    "Next step: docker logs github-runner-b")"
EMAIL_NAME=''
grep -q '^docker\[t\] inspect .* github-runner-b$' "$STUB_LOG" || fail_case "docker not asked for github-runner-b"

# 20. Settings
setting_case() {
    # setting_case KNOB VALUE: invalid, so a settings failure and the default otherwise
    new_case "setting: $1=$2"
    CASE_ENV=("$1=$2")
    run_check
    expect_rc 1
    expect_out "- settings: $1 must be a whole number"
    expect_out "got '$2'"
    expect_out "Next step: fix the environment variables in the scheduled task"
}
for knob in MAX_DISK_PERCENT ALERT_AFTER_FAILURES REMIND_AFTER_SECONDS NOW; do
    for value in abc 08 -1 12345678901; do
        setting_case "$knob" "$value"
    done
done
setting_case MAX_DISK_PERCENT 90%
setting_case REMIND_AFTER_SECONDS 1d
setting_case ALERT_AFTER_FAILURES 0
for valid in MAX_DISK_PERCENT=0 REMIND_AFTER_SECONDS=0 NOW=0 ALERT_AFTER_FAILURES=1234567890 MAX_DISK_PERCENT=; do
    new_case "setting valid: $valid"
    CASE_ENV=("$valid")
    export FAKE_DF_PERCENT=0
    run_check
    [[ $OUT != *"- settings:"* ]] || fail_case "settings failure for a valid value"
done

# 21. Storage
if is_root; then
    new_case "storage"
    skip_case "running as root"
else
    new_case "storage: read-only state folder"
    STATE_DIR="$CASE_DIR/state"
    mkdir -p "$STATE_DIR"
    STATE_FILE="$STATE_DIR/health-check.state"
    NOW_FIXED=1
    run_check; expect_rc 0
    before=$(cat "$STATE_FILE")
    chmod 500 "$STATE_DIR"
    NOW=1300; run_check; expect_rc 1
    expect_out "- storage: cannot write $STATE_FILE"
    expect_out "Next step: check free space and permissions for $STATE_DIR"
    NOW=87699; run_check; expect_rc 0
    NOW=87700; run_check; expect_rc 1
    export FAKE_STATUS=exited
    CASE_ENV=(ALERT_AFTER_FAILURES=1)
    NOW=87800; run_check; expect_rc 1; expect_out "- container_running:"
    unset FAKE_STATUS
    CASE_ENV=()
    [ "$(cat "$STATE_FILE")" = "$before" ] || fail_case "state changed while read-only"
    chmod 700 "$STATE_DIR"
    NOW=87900; run_check; expect_rc 0
    ls "$CASE_TMP"/runner-health-check/storage-*.marker > /dev/null 2>&1 && fail_case "marker not cleared"

    new_case "storage: alternating checks alert once each"
    STATE_DIR="$CASE_DIR/state"
    mkdir -p "$STATE_DIR"
    STATE_FILE="$STATE_DIR/health-check.state"
    CASE_ENV=(ALERT_AFTER_FAILURES=1)
    run_check
    chmod 500 "$STATE_DIR"
    sent=0
    for i in 1 2 3 4 5 6; do
        unset FAKE_STATUS FAKE_DF_PERCENT
        if [ $((i % 2)) = 1 ]; then export FAKE_STATUS=exited; else export FAKE_DF_PERCENT=95; fi
        run_check
        [ "$RC" = 0 ] || sent=$((sent + 1))
    done
    chmod 700 "$STATE_DIR"
    [ "$sent" = 2 ] || fail_case "$sent storage emails, expected 2"

    new_case "storage: checks in their grace period aren't listed"
    STATE_DIR="$CASE_DIR/state"
    mkdir -p "$STATE_DIR"
    STATE_FILE="$STATE_DIR/health-check.state"
    run_check
    chmod 500 "$STATE_DIR"
    export FAKE_STATUS=exited
    run_check; expect_rc 1; expect_no_out "container_running"
    chmod 700 "$STATE_DIR"

    new_case "storage: read-only log"
    run_check
    before=$(cat "$STATE_FILE")
    chmod 400 "$LOG_FILE"
    run_check; expect_rc 1; expect_out "- storage: cannot write $LOG_FILE"
    [ "$(cat "$STATE_FILE")" = "$before" ] || fail_case "state written although the log failed"

    new_case "storage: two state files keep separate markers"
    mkdir -p "$CASE_DIR/a" "$CASE_DIR/b"
    STATE_FILE="$CASE_DIR/a/s"; run_check
    STATE_FILE="$CASE_DIR/b/s"; run_check
    chmod 500 "$CASE_DIR/a" "$CASE_DIR/b"
    STATE_FILE="$CASE_DIR/a/s"; run_check; expect_rc 1
    STATE_FILE="$CASE_DIR/b/s"; run_check; expect_rc 1
    chmod 700 "$CASE_DIR/a" "$CASE_DIR/b"
    [ "$(find "$CASE_TMP/runner-health-check" -name 'storage-*.marker' | wc -l)" = 2 ] || fail_case "markers not separate"
fi

# 22. Lock
hold_lock() {
    # hold_lock TIME: writes TIME into the lock file and holds it from a background sleep
    printf '%s\n' "$1" > "$STATE_FILE.lock"
    rm -f "$CASE_DIR/locked"
    (exec 8<> "$STATE_FILE.lock" && flock -n 8 && : > "$CASE_DIR/locked" && exec sleep 30) &
    LOCK_PID=$!
    local i
    for i in $(seq 50); do
        [ ! -e "$CASE_DIR/locked" ] || return 0
        sleep 0.1
    done
    fail_case "could not hold the lock"
}
release_lock() {
    kill "$LOCK_PID" 2> /dev/null
    wait "$LOCK_PID" 2> /dev/null
}
lock_case() {
    # lock_case NAME TIME RC
    new_case "lock: $1"
    NOW_FIXED=1
    NOW=1000
    run_check
    local before
    before=$(cat "$STATE_FILE")
    NOW=2000
    hold_lock "$2"
    run_check
    release_lock
    expect_rc "$3"
    expect_log_count 1
    [ "$(cat "$STATE_FILE")" = "$before" ] || fail_case "state changed"
}
lock_case "recent" 1500 0
lock_case "empty time" "" 0
lock_case "time after NOW" 5000 0
lock_case "901 seconds" 1099 1; expect_out "- lock: held for over 15 minutes by a run that has not finished"
expect_out "Next step: run sudo bash $HEALTH_CHECK by hand to see the error"
lock_case "900 seconds" 1100 0
new_case "lock: flock fails"
mkdir -p "$CASE_DIR/bin"
printf '#!/bin/bash\nexit 127\n' > "$CASE_DIR/bin/flock"
chmod +x "$CASE_DIR/bin/flock"
CASE_ENV=(PATH="$CASE_DIR/bin:$STUB_DIR:$PATH")
run_check; expect_rc 1; expect_out "- lock: flock failed (127)"
expect_log_count 0
if is_root; then
    new_case "lock"
    skip_case "running as root"
else
    new_case "lock: cannot create the lock file"
    mkdir -p "$CASE_DIR/ro"
    chmod 500 "$CASE_DIR/ro"
    STATE_FILE="$CASE_DIR/ro/s"
    run_check; expect_rc 1; expect_out "- storage: cannot write $CASE_DIR/ro/s.lock"
    chmod 700 "$CASE_DIR/ro"
fi

# 23. Internal errors
new_case "internal: TMPDIR is a file"
: > "$CASE_DIR/tmpfile"
CASE_TMP="$CASE_DIR/tmpfile"
NOW_FIXED=1
run_check; expect_rc 1; expect_out "- internal: unexpected error at line"
NOW=1300; run_check; expect_rc 0
ls "$CASE_DIR"/fallback-tmp/runner-health-check/internal-*.marker > /dev/null 2>&1 || fail_case "no marker in the fallback"
CASE_TMP="$CASE_DIR/tmp"
NOW=1600; run_check; expect_rc 0
ls "$CASE_DIR"/fallback-tmp/runner-health-check/internal-*.marker > /dev/null 2>&1 && fail_case "fallback marker not cleared"

new_case "internal: jq not found"
mkdir -p "$CASE_DIR/sys" "$CASE_DIR/stubs"
for tool in bash cat date mktemp flock timeout cksum curl tr awk tail mv rm mkdir grep paste id env sleep; do
    real=$(command -v "$tool") && ln -s "$real" "$CASE_DIR/sys/$tool"
done
sed "s|^PATH=\"\$PATH:/usr/local/bin:/usr/bin:/bin\"|PATH=\"\$PATH:$CASE_DIR/sys\"|" "$HEALTH_CHECK" \
    > "$CASE_DIR/runner-health-check.sh"
SCRIPT="$CASE_DIR/runner-health-check.sh"
CASE_ENV=(PATH="$CASE_DIR/sys")
run_check; expect_rc 1; expect_out "- internal: jq not found"

new_case "internal: an unset variable"
awk '{ print } /^knob MAX_DISK_PERCENT/ { print "echo \"$UNDEFINED_VARIABLE\" > /dev/null" }' "$HEALTH_CHECK" \
    > "$CASE_DIR/runner-health-check.sh"
SCRIPT="$CASE_DIR/runner-health-check.sh"
run_check; expect_rc 1; expect_out "- internal: script ended unexpectedly (exit 1)"

new_case "internal: symlinked marker folder"
mkdir -p "$CASE_DIR/elsewhere"
ln -s "$CASE_DIR/elsewhere" "$CASE_TMP/runner-health-check"
CASE_ENV=(PATH="$CASE_DIR/bin:$STUB_DIR:$PATH")
mkdir -p "$CASE_DIR/bin"
printf '#!/bin/bash\nexit 127\n' > "$CASE_DIR/bin/flock"
chmod +x "$CASE_DIR/bin/flock"
run_check; expect_rc 1
run_check; expect_rc 1
[ -z "$(ls -A "$CASE_DIR/elsewhere")" ] || fail_case "marker written through the symlink"

new_case "internal: a killed run still emails"
export FAKE_DOCKER_EXIT=''
mkdir -p "$CASE_DIR/bin"
printf '#!/bin/bash\nsleep 30\n' > "$CASE_DIR/bin/docker"
chmod +x "$CASE_DIR/bin/docker"
CASE_ENV=(PATH="$CASE_DIR/bin:$STUB_DIR:$PATH")
# shellcheck disable=SC2016 # expanded by the inner bash
OUT=$(env PATH="$CASE_DIR/bin:$STUB_DIR:$PATH" STUB_LOG="$STUB_LOG" TMPDIR="$CASE_TMP" RUNNER_DIR="$RUNNER_DIR" \
    STATE_FILE="$STATE_FILE" LOG_FILE="$LOG_FILE" FALLBACK_TMP="$CASE_DIR/fallback-tmp" NOW=1000 \
    "$BASH" -c '"$BASH" "$1" & pid=$!; sleep 1; kill -TERM "$pid"; wait "$pid"' _ "$HEALTH_CHECK" 2> /dev/null)
RC=$?
# The exit code depends on where the signal lands; DSM needs only non-zero and a body
[ "$RC" != 0 ] || fail_case "exit 0 after a kill"
expect_out "- internal: script ended unexpectedly (exit 143)"

# 24. Garbage state, and a round trip
new_case "garbage state"
# shellcheck disable=SC2016 # a literal $(...) that must never run
printf '%s\n' 'FAILURES=$(touch '"$CASE_DIR"'/pwned)' 'ALERTED_AT=abc' 'ALERTED_CHECKS=a b;c' \
    'RESTART_COUNT=-1' 'RESTART_TIMES=9999999,x,500' > "$STATE_FILE"
run_check; expect_rc 0
[ ! -e "$CASE_DIR/pwned" ] || fail_case "state executed"
[ "$(state_value FAILURES)" = 0 ] || fail_case "FAILURES $(state_value FAILURES)"
[ "$(state_value ALERTED_AT)" = 0 ] || fail_case "ALERTED_AT $(state_value ALERTED_AT)"
[ -z "$(state_value ALERTED_CHECKS)" ] || fail_case "ALERTED_CHECKS $(state_value ALERTED_CHECKS)"
[ "$(state_value RESTART_TIMES)" = 500 ] || fail_case "RESTART_TIMES $(state_value RESTART_TIMES)"
new_case "state round trip"
printf '%s\n' FAILURES=2 ALERTED_AT=900 ALERTED_CHECKS=container_running,disk_space CONTAINER_ID=abc123 \
    RESTART_COUNT=3 RESTART_TIMES=700,800,900 > "$STATE_FILE"
export FAKE_RESTARTS=3 FAKE_STATUS=exited FAKE_DF_PERCENT=95
run_check; expect_rc 0
[ "$(cat "$STATE_FILE")" = "$(printf '%s\n' FAILURES=3 ALERTED_AT=900 ALERTED_CHECKS=container_running,disk_space \
    CONTAINER_ID=abc123 RESTART_COUNT=3 RESTART_TIMES=700,800,900)" ] || fail_case "state: $(cat "$STATE_FILE")"

# 25. Log trim
for lines in 999 1000 1001; do
    new_case "log trim from $lines"
    seq 1 "$lines" | sed 's/^/old /' > "$LOG_FILE"
    run_check; expect_rc 0
    expect_log_count 1000
    [ "$(head -n 1 "$LOG_FILE")" = "old $((lines - 998))" ] || fail_case "oldest kept: $(head -n 1 "$LOG_FILE")"
done

# 26. A PATH of only the stubs
new_case "stubs-only PATH"
CASE_ENV=(PATH="$STUB_DIR")
run_check; expect_rc 0

# 27. Defaults from the script's own location
defaults_case() {
    # defaults_case NAME EXPECTED_DISK_PATH [.env lines]
    local name=$1 expected=$2
    shift 2
    new_case "defaults: $name"
    mkdir -p "$RUNNER_DIR/scripts/monitoring"
    cp "$HEALTH_CHECK" "$RUNNER_DIR/scripts/monitoring/"
    write_env "$@"
    OUT=$(env -u RUNNER_DIR -u STATE_FILE -u LOG_FILE -u DISK_PATH -u RUNNER_NAME \
        PATH="$STUB_DIR:$PATH" STUB_LOG="$STUB_LOG" TMPDIR="$CASE_TMP" NOW=1000 \
        DEFAULT_DATA_DIR="${DEFAULT_DATA:-$CASE_DIR/no-default-data}" \
        "$BASH" "$RUNNER_DIR/scripts/monitoring/runner-health-check.sh" 2> /dev/null)
    RC=$?
    expect_rc 0
    [ -f "$RUNNER_DIR/health-check.state" ] && [ -f "$RUNNER_DIR/health-check.log" ] || fail_case "state or log not in RUNNER_DIR"
    expected=${expected//@RUNNER_DIR@/$RUNNER_DIR}
    grep -q "^df\[t\] -P $expected$" "$STUB_LOG" || fail_case "df not asked for $expected: $(grep '^df' "$STUB_LOG")"
}
defaults_case "workdir" /volume1/w "RUNNER_WORKDIR=/volume1/w" "RUNNER_DATA_DIR=/volume1/d"
defaults_case "data dir" /volume1/d "RUNNER_DATA_DIR=/volume1/d"
mkdir -p "$WORK/default-data"
DEFAULT_DATA="$WORK/default-data"
defaults_case "default data dir" "$WORK/default-data"
DEFAULT_DATA=''
defaults_case "runner dir" "@RUNNER_DIR@"

finish_case
exit $failed
