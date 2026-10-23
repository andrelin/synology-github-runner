#!/bin/bash
# Tests for scripts/setup/install.sh. Each case runs the installer in a fresh copy of
# the repository, with stubs logging the docker, mv, cp, chmod and chown calls.
# Needs a working `docker compose`; without one the cases needing it print SKIP
# (a failure when CI=true).

set -u -o pipefail

REPO_ROOT=$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)
STUB_DIR="$REPO_ROOT/tests/setup/stubs"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failed=0
REPO=https://github.com/your-username/test-repo
DEFAULT_DATA=volume1/docker/github-runner

HAVE_COMPOSE=1
docker compose version > /dev/null 2>&1 || HAVE_COMPOSE=0

# One copy of the tracked and untracked-but-not-ignored files, so a local .env never comes along
TEMPLATE="$WORK/template"
mkdir -p "$TEMPLATE"
git -C "$REPO_ROOT" ls-files -z --cached --others --exclude-standard \
    | while IFS= read -r -d '' f; do [ -e "$REPO_ROOT/$f" ] && printf '%s\0' "$f"; done \
    | tar -C "$REPO_ROOT" --null -T - -cf - | tar -C "$TEMPLATE" -xf -
git -C "$TEMPLATE" init -q

mode_of() {
    stat -c %a "$1" 2> /dev/null || stat -f %Lp "$1"
}

CASE_NAME=''
CASE_ERRORS=0
CASE_SKIPPED=0
OUT=''

fail_case() {
    echo "FAIL [$CASE_NAME]: $1"
    echo "--- output:"
    printf '%s\n' "$OUT"
    CASE_ERRORS=1
    failed=1
}

finish_case() {
    if [ -n "$CASE_NAME" ] && [ "$CASE_ERRORS" = 0 ] && [ "$CASE_SKIPPED" = 0 ]; then
        echo "ok   [$CASE_NAME]"
    fi
}

# new_case NAME: a fresh clone at $CLONE, data root $DATA, stub log $LOG
new_case() {
    finish_case
    CASE_NAME=$1
    CASE_SKIPPED=0
    CASE_DIR=$(mktemp -d "$WORK/case.XXXXXX")
    CLONE="$CASE_DIR/clone"
    DATA="$CASE_DIR/data"
    LOG="$CASE_DIR/stub.log"
    mkdir -p "$DATA"
    cp -R "$TEMPLATE" "$CLONE"
    : > "$LOG"
    CASE_ERRORS=0
    OUT=''
}

needs_compose() {
    if [ "$HAVE_COMPOSE" = 0 ]; then
        echo "SKIP [$CASE_NAME]: docker compose not available"
        CASE_SKIPPED=1
        [ "${CI:-}" != true ] || failed=1
        return 1
    fi
}

# run_install [ARGS...]: runs the copy's installer, stdin passed through; sets OUT and RC.
# Extra environment comes from the array EXTRA_ENV.
EXTRA_ENV=()
run_install() {
    OUT=$(cd "${RUN_FROM:-$CLONE}" && env -u REPO_URL -u GITHUB_PAT -u RUNNER_NAME -u RUNNER_SCOPE \
        -u ORG_NAME -u CONTAINER_NAME -u RUNNER_WORKDIR -u INSTALL_REPO_URL \
        -u INSTALL_RUNNER_NAME -u SUDO_USER \
        PATH="$STUB_DIR:$PATH" STUB_LOG="$LOG" DATA_ROOT_OVERRIDE="$DATA" \
        SKIP_DOCKER_ACCESS_CHECK=1 ${EXTRA_ENV[@]+"${EXTRA_ENV[@]}"} \
        "$BASH" "$CLONE/scripts/setup/install.sh" "$@" 2>&1)
    RC=$?
    EXTRA_ENV=()
    local call
    while IFS= read -r call; do
        case $call in
            "docker compose version" | "docker ps" | "docker compose --project-directory "*" config"*) ;;
            docker*) fail_case "unexpected docker call: $call" ;;
        esac
    done < "$LOG"
}

expect_rc() {
    [ "$RC" = "$1" ] || fail_case "exit $RC, expected $1"
}

expect_out() {
    printf '%s\n' "$OUT" | grep -qF -- "$1" || fail_case "output lacks: $1"
}

expect_no_out() {
    ! printf '%s\n' "$OUT" | grep -qF -- "$1" || fail_case "output has: $1"
}

# expect_failure MESSAGE: exit 1 and exactly one ✗ line, starting with MESSAGE
expect_failure() {
    expect_rc 1
    local lines
    lines=$(printf '%s\n' "$OUT" | grep -c '^✗')
    [ "$lines" = 1 ] || fail_case "$lines ✗ lines, expected 1"
    printf '%s\n' "$OUT" | grep -q "^✗ $1" || fail_case "no ✗ line starting: $1"
}

env_lines() {
    grep -c "^$1=" "$CLONE/.env"
}

# write_env LINE...: a valid .env from the arguments, one per line
write_env() {
    printf '%s\n' "$@" > "$CLONE/.env"
}

check_dirs() {
    local dir
    for dir in volume1 volume1/docker "$DEFAULT_DATA" "$DEFAULT_DATA/workspace" "$DEFAULT_DATA/cache"; do
        [ -d "$DATA/$dir" ] || { fail_case "missing $dir"; continue; }
        [ "$(mode_of "$DATA/$dir")" = 755 ] || fail_case "$dir mode $(mode_of "$DATA/$dir")"
    done
}

# 1. Fresh copy, non-interactive with a token on stdin
case_fresh() {
    new_case "$1"
    needs_compose || return 0
    EXTRA_ENV=(INSTALL_REPO_URL="$REPO")
    run_install --non-interactive --token-stdin < <(printf 'ghp_xxx\n')
    expect_rc 0
    [ "$(env_lines REPO_URL)" = 1 ] || fail_case "REPO_URL lines: $(env_lines REPO_URL)"
    grep -qx "REPO_URL=$REPO" "$CLONE/.env" || fail_case "REPO_URL value"
    [ "$(env_lines GITHUB_PAT)" = 1 ] || fail_case "GITHUB_PAT lines: $(env_lines GITHUB_PAT)"
    grep -qx "GITHUB_PAT=ghp_xxx" "$CLONE/.env" || fail_case "GITHUB_PAT value"
    [ "$(grep '^RUNNER_NAME=' "$CLONE/.env")" = "$(grep '^RUNNER_NAME=' "$CLONE/.env.example")" ] \
        || fail_case "RUNNER_NAME changed"
    [ "$(mode_of "$CLONE/.env")" = 600 ] || fail_case ".env mode $(mode_of "$CLONE/.env")"
    check_dirs
    expect_out "$CLONE"
    expect_out "project named github-runner"
    expect_out "git pull"
    expect_out "docs/04-monitoring.md"
}
case_fresh "fresh install"

# 2. A token with special characters and no final newline, then one with spaces and \r\n
new_case "token characters"
if needs_compose; then
    # shellcheck disable=SC2016 # the $ is part of the token
    token='ghp_a|b&c\d$e'
    EXTRA_ENV=(INSTALL_REPO_URL="$REPO")
    run_install --non-interactive --token-stdin < <(printf '%s' "$token")
    expect_rc 0
    grep -qxF "GITHUB_PAT='$token'" "$CLONE/.env" || fail_case "token not stored quoted byte for byte"
    expect_no_out "$token"
    ! grep -qF "$token" "$LOG" || fail_case "token in a stub log"
    run_install --non-interactive --token-stdin < <(printf '  ghp_spaced  \r\n')
    expect_rc 0
    grep -qx "GITHUB_PAT=ghp_spaced" "$CLONE/.env" || fail_case "spaces and \\r not dropped"
fi

# 3. Which lines a given key replaces; everything else byte-identical
key_line_case() {
    # key_line_case NAME BEFORE AFTER: .env holds REPO_URL, then BEFORE; afterwards REPO_URL, then AFTER
    new_case "key lines: $1"
    needs_compose || return 0
    printf 'REPO_URL=%s\n%b' "$REPO" "$2" > "$CLONE/.env"
    printf 'REPO_URL=%s\n%b' "$REPO" "$3" > "$CASE_DIR/expected"
    run_install --non-interactive --token-stdin < <(printf 'ghp_new\n')
    expect_rc 0
    cmp -s "$CLONE/.env" "$CASE_DIR/expected" || fail_case ".env differs: $(diff "$CASE_DIR/expected" "$CLONE/.env")"
}
key_line_case "neighbours untouched" \
    '# GITHUB_PAT=commented\nGITHUB_PAT2=keep\nOLD_GITHUB_PAT=keep\nGITHUB_PAT=old\n' \
    '# GITHUB_PAT=commented\nGITHUB_PAT2=keep\nOLD_GITHUB_PAT=keep\nGITHUB_PAT=ghp_new\n'
key_line_case "last of two replaced" 'GITHUB_PAT=first\nX=1\nGITHUB_PAT=second\n' 'GITHUB_PAT=first\nX=1\nGITHUB_PAT=ghp_new\n'
key_line_case "indented" '  GITHUB_PAT=old\n' 'GITHUB_PAT=ghp_new\n'
key_line_case "export" 'export GITHUB_PAT=old\n' 'GITHUB_PAT=ghp_new\n'
key_line_case "inline comment" 'GITHUB_PAT=old # note\n' 'GITHUB_PAT=ghp_new\n'
key_line_case "appended" 'X=1\n' 'X=1\nGITHUB_PAT=ghp_new\n'
key_line_case "no final newline" 'X=1' 'X=1\nGITHUB_PAT=ghp_new\n'

# 4. A re-run given only a token keeps the other keys
new_case "re-run keeps other keys"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_old" "RUNNER_NAME=custom" "LABELS=a,b"
    run_install --non-interactive --token-stdin < <(printf 'ghp_xxx\n')
    expect_rc 0
    for line in "RUNNER_NAME=custom" "LABELS=a,b" "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx"; do
        grep -qxF "$line" "$CLONE/.env" || fail_case "lost $line"
    done
fi

# 5. Values that must fail, each with one ✗ line
value_case() {
    # value_case NAME MESSAGE [.env lines...]; uses INPUT and VALUE_ENV
    local name=$1 message=$2
    shift 2
    new_case "values: $name"
    needs_compose || return 0
    [ "$#" -eq 0 ] || write_env "$@"
    EXTRA_ENV=(${VALUE_ENV[@]+"${VALUE_ENV[@]}"})
    run_install --non-interactive --token-stdin < <(printf '%s' "${INPUT:-}")
    expect_failure "$message"
    INPUT=''
    VALUE_ENV=()
}
VALUE_ENV=()
INPUT=''
value_case "empty GITHUB_PAT" "Set GITHUB_PAT, or APP_ID and APP_PRIVATE_KEY" "REPO_URL=$REPO" "GITHUB_PAT="
INPUT=ghp_xxx
value_case "empty REPO_URL" "Set REPO_URL" "REPO_URL=" "GITHUB_PAT=ghp_xxx"
INPUT=ghp_xxx
value_case "placeholder REPO_URL" "Set REPO_URL (the repository the runner serves)"
VALUE_ENV=(INSTALL_REPO_URL="$REPO")
value_case "placeholder GITHUB_PAT" "Set GITHUB_PAT, or APP_ID and APP_PRIVATE_KEY"
value_case "enterprise" "Enterprise scope is not supported" "RUNNER_SCOPE=enterprise" "GITHUB_PAT=ghp_xxx"
value_case "upper case name" "CONTAINER_NAME must start" "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx" "CONTAINER_NAME=Runner.B"
value_case "leading dash" "CONTAINER_NAME must start" "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx" "CONTAINER_NAME=-runner"
VALUE_ENV=(INSTALL_REPO_URL="$REPO"$'\n'"X=1")
INPUT=ghp_xxx
value_case "newline in a value" "REPO_URL contains a character the installer can't store"
[ "$HAVE_COMPOSE" = 0 ] || [ ! -e "$CLONE/.env" ] || fail_case ".env created"

new_case "underscore name passes"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx" "CONTAINER_NAME=runner_b"
    run_install --non-interactive < /dev/null
    expect_rc 0
fi

# 6. Not a clone, options and missing tools
not_clone_case() {
    new_case "not a clone: $1"
    rm -rf "${CLONE:?}/$1"
    run_install --non-interactive < /dev/null
    expect_failure "Run this from a git clone of the repository (see docs/02-installation.md)"
}
not_clone_case .git
not_clone_case .env.example
not_clone_case docker-compose.yaml

new_case "not a clone: a build without a Dockerfile"
rm "$CLONE/Dockerfile"
awk '{ print } /^  github-runner:$/ { print "    build: ." }' "$CLONE/docker-compose.yaml" > "$CASE_DIR/c.yaml"
grep -q '^    build: \.$' "$CASE_DIR/c.yaml" || fail_case "no build line added"
mv "$CASE_DIR/c.yaml" "$CLONE/docker-compose.yaml"
run_install --non-interactive < /dev/null
expect_failure "Run this from a git clone of the repository (see docs/02-installation.md)"

new_case "no Dockerfile passes the project check"
if needs_compose; then
    rm "$CLONE/Dockerfile"
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx"
    run_install --non-interactive < /dev/null
    expect_rc 0
fi

new_case "unknown option"
run_install --force < /dev/null
expect_failure "Unknown option --force (use --non-interactive, --token-stdin)"

new_case "token-stdin alone"
run_install --token-stdin < /dev/null
expect_failure "Unknown option --token-stdin"

# A PATH of links to only the tools a case keeps, with no system fallback
only_tools() {
    local tool
    mkdir -p "$CASE_DIR/bin"
    for tool in "$@"; do
        ln -s "$(command -v "$tool")" "$CASE_DIR/bin/$tool"
    done
}
missing_tool_case() {
    local missing=$1 message=$2 tool
    new_case "missing $missing"
    local -a keep=()
    for tool in jq docker env grep tr cp mv chmod chown mkdir rm cat; do
        [ "$tool" = "$missing" ] || keep+=("$tool")
    done
    only_tools "${keep[@]}"
    OUT=$(cd "$CLONE" && env -i HOME="$HOME" PATH="$CASE_DIR/bin" INSTALL_SYSTEM_PATH= \
        "$BASH" "$CLONE/scripts/setup/install.sh" --non-interactive < /dev/null 2>&1)
    RC=$?
    expect_failure "$message"
}
missing_tool_case docker "docker not found"
missing_tool_case jq "jq not found"

# 7. App credentials instead of a PAT
new_case "app credentials"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=" "APP_ID=1" "APP_PRIVATE_KEY=x"
    run_install --non-interactive < /dev/null
    expect_rc 0
    grep -qx "GITHUB_PAT=" "$CLONE/.env" || fail_case "GITHUB_PAT changed"
fi

# 8. Scope
scope_case() {
    # scope_case NAME RC MESSAGE .env-lines...
    local name=$1 rc=$2 message=$3
    shift 3
    new_case "scope: $name"
    needs_compose || return 0
    write_env "$@"
    run_install --non-interactive < /dev/null
    if [ "$rc" = 0 ]; then
        expect_rc 0
    else
        expect_failure "$message"
    fi
}
scope_case "org" 0 "" "RUNNER_SCOPE=org" "ORG_NAME=example-org" "GITHUB_PAT=ghp_xxx"
scope_case "ORG" 0 "" "RUNNER_SCOPE=ORG" "ORG_NAME=example-org" "GITHUB_PAT=ghp_xxx"
scope_case "org without ORG_NAME" 1 "Set ORG_NAME" "RUNNER_SCOPE=org" "GITHUB_PAT=ghp_xxx"
scope_case "org with the example ORG_NAME" 1 "Set ORG_NAME" "RUNNER_SCOPE=org" "ORG_NAME=your-org" "GITHUB_PAT=ghp_xxx"
scope_case "empty scope is repository" 1 "Set REPO_URL" "RUNNER_SCOPE=" "GITHUB_PAT=ghp_xxx"
scope_case "repository" 0 "" "RUNNER_SCOPE=repository" "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx"

# 9. Directories from the rendered compose file
new_case "custom RUNNER_WORKDIR"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx" "RUNNER_WORKDIR=/volume1/custom/workspace"
    run_install --non-interactive < /dev/null
    expect_rc 0
    [ -d "$DATA/volume1/custom/workspace" ] || fail_case "custom workspace missing"
    [ -d "$DATA/$DEFAULT_DATA/cache" ] || fail_case "default cache missing"
    [ ! -e "$DATA/$DEFAULT_DATA/workspace" ] || fail_case "default workspace created"
fi

new_case "existing workspace mode kept"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx"
    mkdir -p "$DATA/$DEFAULT_DATA/workspace"
    chmod 700 "$DATA/$DEFAULT_DATA/workspace"
    run_install --non-interactive < /dev/null
    expect_rc 0
    [ "$(mode_of "$DATA/$DEFAULT_DATA/workspace")" = 700 ] || fail_case "workspace mode changed"
fi

new_case "no /cache mount"
if needs_compose; then
    grep -v ':/cache' "$CLONE/docker-compose.yaml" > "$CASE_DIR/c.yaml"
    mv "$CASE_DIR/c.yaml" "$CLONE/docker-compose.yaml"
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx"
    run_install --non-interactive < /dev/null
    expect_failure "docker-compose.yaml has no workspace or /cache mount"
fi

new_case "next steps name the project"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx" "CONTAINER_NAME=github-runner-b"
    run_install --non-interactive < /dev/null
    expect_rc 0
    expect_out "project named github-runner-b"
fi

# read_env_value, sourced alone: each line appended after a decoy, so the last match wins
new_case "read_env_value"
sed -n '/^read_env_value() {/,/^}/p' "$REPO_ROOT/scripts/setup/install.sh" > "$CASE_DIR/fn.sh"
parse_case() {
    # parse_case LINE VALUE QUOTE
    local got
    printf 'KEY=decoy\n%b\n' "$1" > "$CASE_DIR/parse.env"
    # shellcheck source=/dev/null
    got=$(. "$CASE_DIR/fn.sh"; read_env_value "$CASE_DIR/parse.env" KEY; printf '%s|%s' "$ENV_VALUE" "$ENV_VALUE_QUOTE")
    [ "$got" = "$2|$3" ] || fail_case "line '$1': got '$got', expected '$2|$3'"
}
parse_case 'KEY=v' v none
parse_case 'export KEY=v' v none
parse_case '  KEY=v' v none
parse_case 'KEY = v' v none
parse_case 'KEY=v\r' v none
parse_case 'KEY=v   ' v none
parse_case 'KEY=v # note' v none
parse_case 'KEY=a#b' 'a#b' none
parse_case 'KEY=a\t# b' "a"$'\t'"# b" none
parse_case "KEY='a #b'" 'a #b' single
parse_case 'KEY="a #b"' 'a #b' double
parse_case "KEY='a' # note" a single
parse_case 'KEY="a"b' a double
parse_case 'KEY="a' a double
parse_case 'KEY=a=b' 'a=b' none
parse_case '# KEY=x' decoy none
parse_case 'KEY2=x' decoy none
parse_case 'OLD_KEY=x' decoy none
parse_case '' decoy none
# shellcheck source=/dev/null
got=$(. "$CASE_DIR/fn.sh"; read_env_value "$CASE_DIR/missing.env" KEY; printf '%s|%s' "$ENV_VALUE" "$ENV_VALUE_QUOTE")
[ "$got" = "|none" ] || fail_case "missing file: got '$got'"

# 10. Run from another directory
new_case "run from /"
if needs_compose; then
    EXTRA_ENV=(INSTALL_REPO_URL="$REPO")
    RUN_FROM=/ run_install --non-interactive --token-stdin < <(printf 'ghp_xxx\n')
    expect_rc 0
    grep -qx "GITHUB_PAT=ghp_xxx" "$CLONE/.env" || fail_case "token not written"
    check_dirs
fi

# 11. Interactive answers
new_case "interactive answers"
if needs_compose; then
    run_install < <(printf '%s\nghp_secret_answer\nmy-runner\n' "$REPO")
    expect_rc 0
    for line in "REPO_URL=$REPO" "GITHUB_PAT=ghp_secret_answer" "RUNNER_NAME=my-runner"; do
        grep -qxF "$line" "$CLONE/.env" || fail_case "answer not stored: $line"
    done
    expect_no_out ghp_secret_answer
fi

new_case "interactive empty answers keep .env"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx" "# comment" "  LABELS=x # note"
    cp "$CLONE/.env" "$CASE_DIR/before"
    run_install < <(printf '\n\n\n')
    expect_rc 0
    cmp -s "$CLONE/.env" "$CASE_DIR/before" || fail_case ".env changed by empty answers"
    run_install < /dev/null
    expect_rc 0
    cmp -s "$CLONE/.env" "$CASE_DIR/before" || fail_case ".env changed by closed stdin"
fi

new_case "interactive org scope skips REPO_URL"
if needs_compose; then
    write_env "RUNNER_SCOPE=org" "ORG_NAME=example-org" "GITHUB_PAT=ghp_xxx"
    run_install < <(printf '\nnamed-runner\n')
    expect_rc 0
    expect_no_out "Repository the runner serves"
    grep -qx "RUNNER_NAME=named-runner" "$CLONE/.env" || fail_case "second answer was not the runner name"
fi

new_case "non-interactive runner name"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx"
    EXTRA_ENV=(INSTALL_RUNNER_NAME=nas-runner)
    run_install --non-interactive < /dev/null
    expect_rc 0
    grep -qx "RUNNER_NAME=nas-runner" "$CLONE/.env" || fail_case "runner name not set"
fi

new_case "single quote rejected"
if needs_compose; then
    EXTRA_ENV=(INSTALL_REPO_URL="$REPO" INSTALL_RUNNER_NAME="it's")
    run_install --non-interactive < /dev/null
    expect_failure "RUNNER_NAME contains a character the installer can't store; edit .env by hand"
    [ ! -e "$CLONE/.env" ] || fail_case ".env created"
fi

# 12. A broken .env: Compose's error would quote the value
new_case "broken compose"
if needs_compose; then
    # shellcheck disable=SC2016 # an unclosed ${ that Compose rejects
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx" 'BROKEN=${secret-value'
    run_install --non-interactive < /dev/null
    expect_failure "docker-compose.yaml or .env is invalid"
    expect_no_out secret-value
fi

# 13. Owner
new_case "owner"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx"
    EXTRA_ENV=(SUDO_USER=someone)
    run_install --non-interactive < /dev/null
    expect_rc 0
    grep -qx "chown someone $CLONE/.env" "$LOG" || fail_case "not handed to SUDO_USER"
    : > "$LOG"
    run_install --non-interactive < /dev/null
    ! grep -q '^chown' "$LOG" || fail_case "chown without SUDO_USER"
fi

# 14. Private from creation
new_case "private from creation"
if needs_compose; then
    EXTRA_ENV=(INSTALL_REPO_URL="$REPO")
    run_install --non-interactive --token-stdin < <(printf 'ghp_xxx\n')
    expect_rc 0
    grep -q "^cp 600 .*/.env.example $CLONE/.env$" "$LOG" || fail_case "copied .env not 600 before chmod"
    grep -q "^mv 600 $CLONE/.env.tmp" "$LOG" || fail_case ".env.tmp not 600"
fi

# 15. Docker access
new_case "docker ps fails"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx"
    EXTRA_ENV=(SKIP_DOCKER_ACCESS_CHECK= FAKE_PS_FAIL=1)
    run_install --non-interactive < /dev/null
    expect_failure "Cannot use Docker: run with sudo"
fi

new_case "compose version fails"
EXTRA_ENV=(SKIP_DOCKER_ACCESS_CHECK= FAKE_COMPOSE_VERSION_FAIL=1)
run_install --non-interactive < /dev/null
expect_failure "Docker Compose v2 not found (docker compose version failed)"

# 16. Unexpected error
new_case "unexpected error"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_old"
    EXTRA_ENV=(FAKE_MV_FAIL=1)
    run_install --non-interactive --token-stdin < <(printf 'ghp_xxx\n')
    expect_failure "unexpected error at line"
    [ ! -e "$CLONE/.env.tmp" ] || fail_case ".env.tmp left behind"
fi

new_case "failure in a subshell prints one line"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx"
    : > "$DATA/volume1"
    run_install --non-interactive < /dev/null
    expect_failure "unexpected error at line"
fi

new_case "relative invocation"
if needs_compose; then
    write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx"
    OUT=$(cd "$CLONE" && env -u SUDO_USER PATH="$STUB_DIR:$PATH" STUB_LOG="$LOG" DATA_ROOT_OVERRIDE="$DATA" \
        SKIP_DOCKER_ACCESS_CHECK=1 "$BASH" ./scripts/setup/install.sh --non-interactive < /dev/null 2>&1)
    RC=$?
    expect_rc 0
    expect_out "Project folder: $CLONE"
fi

# 17. Outside DSM
new_case "outside DSM"
if needs_compose; then
    if [ -f /etc/synoinfo.conf ]; then
        echo "SKIP [$CASE_NAME]: running on DSM"
        CASE_SKIPPED=1
    else
        write_env "REPO_URL=$REPO" "GITHUB_PAT=ghp_xxx"
        run_install --non-interactive < /dev/null
        expect_rc 0
        expect_out "⚠ Not running on Synology DSM"
        fi
fi

finish_case
exit $failed
