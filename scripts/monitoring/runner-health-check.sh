#!/bin/bash
# GitHub Self-Hosted Runner - health check
#
# Run every 5 minutes by DSM Task Scheduler, as root, with "send run details by email"
# set to "only when the script terminates abnormally". It checks what keeps jobs from
# running (configuration, container, GitHub's view of the runner, restarts, disk) and
# exits 1, with the email body on stdout, only when an email is wanted: once when a
# problem starts, a daily reminder while it lasts, and once when it recovers.
#
# By hand, without touching the scheduled task's state (a run that decides on an email
# records it, so a plain hand run would take the scheduled task's email):
#   sudo env STATE_FILE=$(mktemp) LOG_FILE=$(mktemp) ALERT_AFTER_FAILURES=1 bash <script>
# Scheduled: bash <project folder>/scripts/monitoring/runner-health-check.sh
#
# Knobs (environment): MAX_DISK_PERCENT (90), ALERT_AFTER_FAILURES (3),
# REMIND_AFTER_SECONDS (86400), DISK_PATH, STATE_FILE, LOG_FILE, RUNNER_DIR.
# What the runner is (REPO_URL, RUNNER_NAME, CONTAINER_NAME, ...) comes from .env only.
# See docs/04-monitoring.md.

set -Eeu -o pipefail

# Appended, never prepended: DSM Task Scheduler runs with a minimal PATH, and DSM
# keeps docker in /usr/local/bin
PATH="$PATH:/usr/local/bin:/usr/bin:/bin"

SCRIPT_PATH=${BASH_SOURCE[0]}
script_dir=${SCRIPT_PATH%/*}
[ "$script_dir" != "$SCRIPT_PATH" ] || script_dir=.
script_dir=$(cd "$script_dir" && pwd)
SCRIPT_PATH="$script_dir/${SCRIPT_PATH##*/}"
RUNNER_DIR=${RUNNER_DIR:-$(cd "$script_dir/../.." && pwd)}
ENV_FILE="$RUNNER_DIR/.env"
STATE_FILE=${STATE_FILE:-$RUNNER_DIR/health-check.state}
LOG_FILE=${LOG_FILE:-$RUNNER_DIR/health-check.log}
LOCK_FILE="$STATE_FILE.lock"
DEFAULT_DATA_DIR=${DEFAULT_DATA_DIR:-/volume1/docker/github-runner}
# Where markers go when TMPDIR is unusable; a test knob
FALLBACK_TMP=${FALLBACK_TMP:-/tmp}

LOCK_STALE_SECONDS=900
MARKER_SECONDS=86400
RESTART_WINDOW_SECONDS=21600
RESTART_WINDOW_COUNT=3
MAX_LOG_LINES=1000
DOCKER_TIMEOUT=(timeout -k 5 20)

EMAIL_PRINTED=0
STORAGE_FILE=''
TEMP_FILES=()
FAILING=()
REASONS=()

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

# shellcheck disable=SC2329 # called by the EXIT trap
on_exit() {
    local rc=$?
    trap - EXIT ERR
    if [ "${#TEMP_FILES[@]}" -gt 0 ]; then
        rm -f "${TEMP_FILES[@]}"
    fi
    if [ "$rc" != 0 ] && [ "$EMAIL_PRINTED" = 0 ]; then
        alert_out_of_band internal "script ended unexpectedly (exit $rc)"
    fi
    exit "$rc"
}

# shellcheck disable=SC2329 # called by the ERR trap
on_error() {
    # In a command substitution, leave the alert to the parent, which sees the failure
    [ "$BASH_SUBSHELL" = 0 ] || exit 1
    trap - ERR
    alert_out_of_band internal "unexpected error at line $1"
}

trap on_exit EXIT
trap 'on_error $LINENO' ERR
# A killed run still ends in an email body, never an empty one
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

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

# knob NAME DEFAULT MINIMUM: the environment's value, or the default when unset, empty or invalid
SETTINGS_REASONS=()
knob() {
    local name=$1 default=$2 minimum=$3 value
    value=${!name:-}
    if [ -z "$value" ]; then
        printf -v "$name" '%s' "$default"
    elif ! is_whole_number "$value" || [ "$value" -lt "$minimum" ]; then
        if [ "$minimum" -gt 0 ]; then
            SETTINGS_REASONS+=("$name must be a whole number of at least $minimum, got '$value'")
        else
            SETTINGS_REASONS+=("$name must be a whole number, got '$value'")
        fi
        printf -v "$name" '%s' "$default"
    fi
}

fail_check() {
    FAILING+=("$1")
    REASONS+=("$2")
}

is_failing() {
    local check
    for check in ${FAILING[@]+"${FAILING[@]}"}; do
        [ "$check" != "$1" ] || return 0
    done
    return 1
}

# The checks failing, deduplicated, joined by commas
failing_list() {
    local check list=''
    for check in ${FAILING[@]+"${FAILING[@]}"}; do
        case ",$list," in
            *",$check,"*) ;;
            *) list=${list:+$list,}$check ;;
        esac
    done
    printf '%s' "$list"
}

next_step() {
    local checks=",$1,"
    case $checks in
        *,internal,* | *,lock,*) echo "Next step: run sudo bash $SCRIPT_PATH by hand to see the error"; return ;;
    esac
    case $checks in
        *,configuration,*) echo "Next step: edit $RUNNER_DIR/.env"; return ;;
    esac
    case $checks in
        *,settings,*) echo "Next step: fix the environment variables in the scheduled task"; return ;;
    esac
    case $checks in
        *,storage,*) echo "Next step: check free space and permissions for ${STORAGE_FILE%/*}"; return ;;
    esac
    if [ "$checks" = ",disk_space," ]; then
        echo "Next step: free space on $DISK_PATH"
        return
    fi
    echo "Next step: docker logs $CONTAINER_NAME"
}

# print_email KIND [CHECK REASON]...: the email body on stdout
print_email() {
    local kind=$1 checks=''
    shift
    echo "Runner health check ($CONTAINER_NAME): $kind"
    EMAIL_PRINTED=1
    [ "$kind" != RECOVERED ] || return 0
    while [ "$#" -ge 2 ]; do
        echo "- $1: $2"
        checks=${checks:+$checks,}$1
        shift 2
    done
    echo ""
    next_step "$checks"
}

# Markers for out-of-band alerts live outside the state's folder, which may be the problem
marker_dirs() {
    local base
    for base in "${TMPDIR:-}" "$FALLBACK_TMP"; do
        [ -n "$base" ] || continue
        printf '%s\n' "${base%/}/runner-health-check"
    done
}

usable_marker_dir() {
    local base dir
    if [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ] && [ -w "$TMPDIR" ]; then
        base=${TMPDIR%/}
    else
        base=$FALLBACK_TMP
    fi
    dir="$base/runner-health-check"
    if [ ! -e "$dir" ] && [ ! -L "$dir" ]; then
        mkdir -m 700 "$dir" 2> /dev/null || return 1
    fi
    [ -d "$dir" ] && [ ! -L "$dir" ] && [ -O "$dir" ] && [ -w "$dir" ] || return 1
    printf '%s' "$dir"
}

state_key() {
    local sum
    if sum=$(printf '%s' "$STATE_FILE" | cksum 2> /dev/null); then
        printf '%s' "${sum%% *}"
    else
        printf 'nocksum'
    fi
}

# alert_out_of_band KIND REASON: an alert about the monitor itself, not logged and sent at
# most once a day per kind, unless a check fails that the last one didn't list
alert_out_of_band() {
    local kind=$1 reason=$2 dir marker stored_time stored_checks now checks check new=0
    trap - ERR
    now=${NOW:-}
    is_whole_number "$now" || now=$(date +%s)
    checks=$(failing_list)
    if dir=$(usable_marker_dir); then
        marker="$dir/$kind-$(state_key).marker"
        if [ -f "$marker" ] && { IFS= read -r stored_time && IFS= read -r stored_checks || true; } < "$marker"; then
            is_whole_number "${stored_time:-}" || stored_time=0
            [ "$stored_time" -le "$now" ] || stored_time=$now
            for check in ${checks//,/ }; do
                case ",${stored_checks:-}," in
                    *",$check,"*) ;;
                    *) new=1 ;;
                esac
            done
            if [ $((now - stored_time)) -lt "$MARKER_SECONDS" ]; then
                if [ "$new" = 0 ]; then
                    EMAIL_PRINTED=1
                    exit 0
                fi
                # Within the day the marker remembers every check it has reported
                for check in ${stored_checks//,/ }; do
                    case ",$checks," in
                        *",$check,"*) ;;
                        *) checks=${checks:+$checks,}$check ;;
                    esac
                done
            fi
        fi
        printf '%s\n%s\n' "$now" "$checks" > "$marker" 2> /dev/null || true
    fi
    local -a lines=("$kind" "$reason")
    local i
    for i in "${!FAILING[@]}"; do
        lines+=("${FAILING[i]}" "${REASONS[i]}")
    done
    print_email PROBLEM "${lines[@]}"
    exit 1
}

clear_markers() {
    local dir key
    key=$(state_key)
    while IFS= read -r dir; do
        [ -d "$dir" ] && [ ! -L "$dir" ] || continue
        rm -f "$dir"/*-"$key".marker 2> /dev/null || true
    done < <(marker_dirs)
}

# ---------------------------------------------------------------------------
# Settings, tools and the lock
# ---------------------------------------------------------------------------

read_env_value "$ENV_FILE" CONTAINER_NAME
CONTAINER_NAME=${ENV_VALUE:-github-runner}

knob MAX_DISK_PERCENT 90 0
knob ALERT_AFTER_FAILURES 3 1
knob REMIND_AFTER_SECONDS 86400 0
if [ -n "${NOW:-}" ] && ! is_whole_number "$NOW"; then
    SETTINGS_REASONS+=("NOW must be a whole number, got '$NOW'")
    NOW=''
fi
NOW=${NOW:-$(date +%s)}

for tool in jq flock timeout cksum curl; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        alert_out_of_band internal "$tool not found"
    fi
done

API_FILE=$(mktemp)
TEMP_FILES+=("$API_FILE")
ERR_FILE=$(mktemp)
TEMP_FILES+=("$ERR_FILE")

if ! { exec 9<> "$LOCK_FILE"; } 2> /dev/null; then
    STORAGE_FILE=$LOCK_FILE
    alert_out_of_band storage "cannot write $LOCK_FILE"
fi
lock_status=0
flock -n 9 2> /dev/null || lock_status=$?
if [ "$lock_status" = 1 ]; then
    lock_time=''
    IFS= read -r lock_time < "$LOCK_FILE" 2> /dev/null || true
    if is_whole_number "$lock_time" && [ "$lock_time" -le "$NOW" ] \
        && [ $((NOW - lock_time)) -gt "$LOCK_STALE_SECONDS" ]; then
        alert_out_of_band lock "held for over 15 minutes by a run that has not finished"
    fi
    echo "Another health check run holds $LOCK_FILE; skipping this run" >&2
    EMAIL_PRINTED=1
    exit 0
elif [ "$lock_status" != 0 ]; then
    alert_out_of_band lock "flock failed ($lock_status)"
fi
if ! { printf '%s\n' "$NOW" > "$LOCK_FILE"; } 2> /dev/null; then
    STORAGE_FILE=$LOCK_FILE
    alert_out_of_band storage "cannot write $LOCK_FILE"
fi

# ---------------------------------------------------------------------------
# The checks
# ---------------------------------------------------------------------------

read_env_value "$ENV_FILE" REPO_URL
REPO_URL=$ENV_VALUE
read_env_value "$ENV_FILE" GITHUB_PAT
GITHUB_PAT=$ENV_VALUE
read_env_value "$ENV_FILE" APP_PRIVATE_KEY
APP_PRIVATE_KEY=$ENV_VALUE
read_env_value "$ENV_FILE" RUNNER_NAME
RUNNER_NAME=${ENV_VALUE:-synology-general-runner}
read_env_value "$ENV_FILE" RUNNER_SCOPE
RUNNER_SCOPE=${ENV_VALUE:-repo}
read_env_value "$ENV_FILE" ORG_NAME
ORG_NAME=$ENV_VALUE
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

scope=$(printf '%s' "$RUNNER_SCOPE" | tr '[:upper:]' '[:lower:]')
case $scope in
    org*) scope=organization ;;
    ent*) scope=enterprise ;;
    *) scope=repository ;;
esac

ONLINE_SKIPPED=''
CONTAINER_ID=''
CONTAINER_RESTARTS=''

check_settings() {
    local reason
    for reason in ${SETTINGS_REASONS[@]+"${SETTINGS_REASONS[@]}"}; do
        fail_check settings "$reason"
    done
}

check_configuration() {
    if [ ! -f "$ENV_FILE" ]; then
        fail_check configuration ".env not found in $RUNNER_DIR"
    elif [ "$scope" = enterprise ]; then
        fail_check configuration "enterprise scope is not supported"
    elif [ "$scope" = repository ] && [ -z "$REPO_URL" ]; then
        fail_check configuration "REPO_URL is empty"
    elif [ "$scope" = organization ] && [ -z "$ORG_NAME" ]; then
        fail_check configuration "ORG_NAME is empty"
    elif [ -z "$GITHUB_PAT" ] && [ -z "$APP_PRIVATE_KEY" ]; then
        fail_check configuration "no credentials: set GITHUB_PAT, or APP_ID and APP_PRIVATE_KEY"
    else
        return 0
    fi
    return 1
}

check_container_running() {
    local out rc=0 status health first_error
    out=$("${DOCKER_TIMEOUT[@]}" docker inspect --type container \
        --format '{{.Id}} {{.State.Status}} {{.RestartCount}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
        "$CONTAINER_NAME" 2> "$ERR_FILE") || rc=$?
    if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then
        fail_check container_running "docker did not answer within 20 s"
        return 0
    elif [ "$rc" != 0 ]; then
        first_error=''
        IFS= read -r first_error < "$ERR_FILE" || true
        case $first_error in
            *"No such container"* | *"No such object"*)
                fail_check container_running "container $CONTAINER_NAME not found" ;;
            *) fail_check container_running "docker failed: $first_error" ;;
        esac
        return 0
    fi
    read -r CONTAINER_ID status CONTAINER_RESTARTS health <<< "$out" || true
    if [ "$status" != running ]; then
        fail_check container_running "container $CONTAINER_NAME is $status"
    elif [ "$health" = unhealthy ]; then
        fail_check container_running "container $CONTAINER_NAME healthcheck reports unhealthy"
    fi
}

check_runner_online() {
    local url owner_repo code rc=0
    if [ -z "$GITHUB_PAT" ]; then
        ONLINE_SKIPPED="no GITHUB_PAT"
        return 0
    fi
    if [ "$scope" = organization ]; then
        url="https://api.github.com/orgs/$ORG_NAME/actions/runners?per_page=100"
    else
        case $REPO_URL in
            https://github.com/*) ;;
            *) ONLINE_SKIPPED="REPO_URL is not on github.com"; return 0 ;;
        esac
        owner_repo=${REPO_URL#https://github.com/}
        owner_repo=${owner_repo%/}
        owner_repo=${owner_repo%.git}
        owner_repo=${owner_repo%/}
        url="https://api.github.com/repos/$owner_repo/actions/runners?per_page=100"
    fi
    # The token goes to curl on stdin, never on a command line
    code=$(printf 'url = "%s"\nheader = "Authorization: Bearer %s"\nheader = "Accept: application/vnd.github+json"\n' \
        "$(curl_quote "$url")" "$(curl_quote "$GITHUB_PAT")" \
        | curl --silent --max-time 20 --config - --output "$API_FILE" --write-out '%{http_code}' 2> /dev/null) || rc=$?
    if [ "$rc" != 0 ]; then
        fail_check runner_online "GitHub API unreachable (curl exit $rc)"
        return 0
    fi
    case $code in
        200) ;;
        401 | 403)
            fail_check runner_online "GitHub rejected GITHUB_PAT (HTTP $code): expired, missing rights or rate-limited"
            return 0 ;;
        404)
            fail_check runner_online "GitHub API returned 404: check REPO_URL or ORG_NAME"
            return 0 ;;
        *)
            fail_check runner_online "GitHub API returned HTTP $code"
            return 0 ;;
    esac
    if ! jq -e 'type == "object" and (.runners | type == "array")' "$API_FILE" > /dev/null 2>&1; then
        fail_check runner_online "unexpected API response"
    elif ! jq -e --arg name "$RUNNER_NAME" 'any(.runners[]; .name == $name and .status == "online")' \
        "$API_FILE" > /dev/null 2>&1; then
        fail_check runner_online "runner $RUNNER_NAME is offline or not registered"
    fi
}

curl_quote() {
    local value=${1//\\/\\\\}
    printf '%s' "${value//\"/\\\"}"
}

# Restart times are kept for RESTART_WINDOW_SECONDS; a new container ID or a lower
# count (Docker resets it on a manual start) sets a new baseline
check_no_new_restarts() {
    local i added
    [ -n "$CONTAINER_ID" ] && is_whole_number "$CONTAINER_RESTARTS" || return 0
    if [ "$CONTAINER_ID" != "$STATE_CONTAINER_ID" ] || [ "$CONTAINER_RESTARTS" -lt "$STATE_RESTART_COUNT" ]; then
        STATE_CONTAINER_ID=$CONTAINER_ID
        STATE_RESTART_COUNT=$CONTAINER_RESTARTS
        return 0
    fi
    added=$((CONTAINER_RESTARTS - STATE_RESTART_COUNT))
    STATE_RESTART_COUNT=$CONTAINER_RESTARTS
    if [ "$added" -gt 0 ]; then
        for ((i = 0; i < added; i++)); do
            RESTART_TIMES+=("$NOW")
        done
        fail_check no_new_restarts "container restarted"
    fi
}

check_disk_space() {
    local out percent
    if ! out=$("${DOCKER_TIMEOUT[@]}" df -P "$DISK_PATH" 2> /dev/null); then
        fail_check disk_space "df failed for $DISK_PATH"
        return 0
    fi
    percent=$(printf '%s\n' "$out" | awk 'NR == 2 { sub(/%$/, "", $5); print $5 }')
    if ! is_whole_number "$percent"; then
        fail_check disk_space "df failed for $DISK_PATH"
    elif [ "$percent" -gt "$MAX_DISK_PERCENT" ]; then
        fail_check disk_space "$DISK_PATH is $percent% full (limit $MAX_DISK_PERCENT%)"
    fi
}

# ---------------------------------------------------------------------------
# State: KEY=value lines, read without sourcing; anything malformed reads as empty
# ---------------------------------------------------------------------------

state_number() {
    read_env_value "$STATE_FILE" "$1"
    if is_whole_number "$ENV_VALUE"; then
        printf '%s' "$ENV_VALUE"
    else
        printf '0'
    fi
}

state_word() {
    read_env_value "$STATE_FILE" "$1"
    case $ENV_VALUE in
        *[!A-Za-z0-9_,]*) printf '' ;;
        *) printf '%s' "$ENV_VALUE" ;;
    esac
}

STATE_FAILURES=$(state_number FAILURES)
STATE_ALERTED_AT=$(state_number ALERTED_AT)
[ "$STATE_ALERTED_AT" -le "$NOW" ] || STATE_ALERTED_AT=$NOW
STATE_ALERTED_CHECKS=$(state_word ALERTED_CHECKS)
STATE_CONTAINER_ID=$(state_word CONTAINER_ID)
STATE_RESTART_COUNT=$(state_number RESTART_COUNT)
RESTART_TIMES=()
read_env_value "$STATE_FILE" RESTART_TIMES
for restart_time in ${ENV_VALUE//,/ }; do
    if is_whole_number "$restart_time" && [ "$restart_time" -le "$NOW" ]; then
        RESTART_TIMES+=("$restart_time")
    fi
done

# ---------------------------------------------------------------------------
# Run the checks and decide on an email
# ---------------------------------------------------------------------------

check_settings
if check_configuration; then
    check_container_running
    check_runner_online
    check_no_new_restarts
    check_disk_space
fi

kept_times=()
for restart_time in ${RESTART_TIMES[@]+"${RESTART_TIMES[@]}"}; do
    if [ $((NOW - restart_time)) -le "$RESTART_WINDOW_SECONDS" ]; then
        kept_times+=("$restart_time")
    fi
done
RESTART_TIMES=(${kept_times[@]+"${kept_times[@]}"})
window_active=0
[ "${#RESTART_TIMES[@]}" -lt "$RESTART_WINDOW_COUNT" ] || window_active=1

checks=$(failing_list)
email=''
failures=$STATE_FAILURES
alerted_at=$STATE_ALERTED_AT
alerted_checks=$STATE_ALERTED_CHECKS

if [ -n "$checks" ]; then
    failures=$((failures + 1))
    if [ -z "$alerted_checks" ]; then
        if is_failing configuration || is_failing settings || [ "$failures" -ge "$ALERT_AFTER_FAILURES" ] \
            || [ "$window_active" = 1 ]; then
            email=PROBLEM
        fi
    else
        for check in ${checks//,/ }; do
            case ",$alerted_checks," in
                *",$check,"*) ;;
                *) email=PROBLEM ;;
            esac
        done
        if [ -z "$email" ] && [ $((NOW - alerted_at)) -ge "$REMIND_AFTER_SECONDS" ]; then
            email=REMINDER
        fi
    fi
    if [ -n "$email" ]; then
        alerted_at=$NOW
        for check in ${checks//,/ }; do
            case ",$alerted_checks," in
                *",$check,"*) ;;
                *) alerted_checks=${alerted_checks:+$alerted_checks,}$check ;;
            esac
        done
    fi
else
    failures=0
    if [ -n "$alerted_checks" ] && [ "$window_active" = 0 ]; then
        email=RECOVERED
        alerted_checks=''
        alerted_at=0
    fi
fi

case ${email:-none} in
    PROBLEM | REMINDER) event="$email $checks" ;;
    RECOVERED) event=RECOVERED ;;
    *)
        if [ -n "$checks" ]; then
            event="FAIL $failures/$ALERT_AFTER_FAILURES $checks"
        else
            event=OK
        fi
        ;;
esac
[ -z "$ONLINE_SKIPPED" ] || event="$event; online check skipped ($ONLINE_SKIPPED)"

# ---------------------------------------------------------------------------
# State, then log: the new state is written to a temporary file first, so a run whose
# state can't be saved logs nothing; if the log can't be written, the state stays as it was
# ---------------------------------------------------------------------------

restart_list=''
for restart_time in ${RESTART_TIMES[@]+"${RESTART_TIMES[@]}"}; do
    restart_list=${restart_list:+$restart_list,}$restart_time
done
if ! {
    printf 'FAILURES=%s\nALERTED_AT=%s\nALERTED_CHECKS=%s\nCONTAINER_ID=%s\nRESTART_COUNT=%s\nRESTART_TIMES=%s\n' \
        "$failures" "$alerted_at" "$alerted_checks" "$STATE_CONTAINER_ID" "$STATE_RESTART_COUNT" "$restart_list" \
        > "$STATE_FILE.tmp"
} 2> /dev/null; then
    rm -f "$STATE_FILE.tmp" 2> /dev/null || true
    STORAGE_FILE=$STATE_FILE
fi

if [ -z "$STORAGE_FILE" ]; then
    log_line="$(date -u -d "@$NOW" +%Y-%m-%dT%H:%M:%SZ) $event"
    if ! { printf '%s\n' "$log_line" >> "$LOG_FILE"; } 2> /dev/null; then
        STORAGE_FILE=$LOG_FILE
    elif [ "$(awk 'END { print NR }' "$LOG_FILE" 2> /dev/null || echo 0)" -gt "$MAX_LOG_LINES" ]; then
        if ! { tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"; } 2> /dev/null; then
            rm -f "$LOG_FILE.tmp" 2> /dev/null || true
            STORAGE_FILE=$LOG_FILE
        fi
    fi
    if [ -n "$STORAGE_FILE" ]; then
        rm -f "$STATE_FILE.tmp" 2> /dev/null || true
    elif ! { mv "$STATE_FILE.tmp" "$STATE_FILE"; } 2> /dev/null; then
        rm -f "$STATE_FILE.tmp" 2> /dev/null || true
        STORAGE_FILE=$STATE_FILE
    fi
fi

if [ -n "$STORAGE_FILE" ]; then
    # Checks still in their grace period aren't news yet
    case ${email:-none} in
        PROBLEM | REMINDER) ;;
        *) FAILING=() REASONS=() ;;
    esac
    alert_out_of_band storage "cannot write $STORAGE_FILE"
fi
clear_markers

if [ -n "$email" ]; then
    email_args=()
    if [ "$email" != RECOVERED ]; then
        for i in "${!FAILING[@]}"; do
            email_args+=("${FAILING[i]}" "${REASONS[i]}")
        done
    fi
    print_email "$email" ${email_args[@]+"${email_args[@]}"}
    exit 1
fi
exit 0
