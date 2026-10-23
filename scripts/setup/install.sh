#!/bin/bash
# GitHub Self-Hosted Runner - installer
#
# Prepares the clone it runs from as a Container Manager project folder: checks the
# prerequisites, writes .env, validates the compose file and creates the host folders
# it mounts. Container Manager then creates the project from the clone.
# Requires DSM 7.2 or later with Container Manager (Docker Compose v2).
#
# Usage:
#   sudo ./scripts/setup/install.sh                               # asks for the values
#   sudo INSTALL_REPO_URL=https://github.com/owner/repo \
#     ./scripts/setup/install.sh --non-interactive --token-stdin < token-file
#
# Non-interactive values: INSTALL_REPO_URL, INSTALL_RUNNER_NAME, and the token as the
# first line of stdin with --token-stdin. Re-running changes only the values given.

set -Eeu -o pipefail
# [a-z] means ASCII letters only, whatever the locale's collation
shopt -s globasciiranges

# Appended, never prepended, so the caller's tools keep precedence; DSM keeps docker
# in /usr/local/bin, which sudo's PATH may lack
INSTALL_SYSTEM_PATH=${INSTALL_SYSTEM_PATH-/usr/local/bin:/usr/bin:/bin}
if [ -n "$INSTALL_SYSTEM_PATH" ]; then
    PATH="$PATH:$INSTALL_SYSTEM_PATH"
fi

script_dir=${BASH_SOURCE[0]%/*}
[ "$script_dir" != "${BASH_SOURCE[0]}" ] || script_dir=.
RUNNER_DIR=${RUNNER_DIR:-$(cd "$script_dir/../.." && pwd)}
ENV_FILE="$RUNNER_DIR/.env"
ENV_TMP="$ENV_FILE.tmp"
EXAMPLE_FILE="$RUNNER_DIR/.env.example"
COMPOSE_FILE_PATH="$RUNNER_DIR/docker-compose.yaml"

DEFAULT_RUNNER_NAME=synology-general-runner
DEFAULT_CONTAINER_NAME=github-runner

trap 'rm -f "$ENV_TMP"' EXIT
# A subshell leaves the message to the parent, which sees the same failure
trap '[ "$BASH_SUBSHELL" = 0 ] || exit 1; echo "✗ unexpected error at line $LINENO"; exit 1' ERR

print_success() {
    echo "✓ $1"
}

print_warning() {
    echo "⚠ $1"
}

fail() {
    echo "✗ $1"
    exit 1
}

# Reads KEY from a .env file the way Docker Compose does for the forms people write,
# without sourcing or expanding anything. Sets ENV_VALUE and ENV_VALUE_QUOTE (none,
# single or double); a missing file or key gives an empty value. The last match wins.
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

# True when LINE assigns KEY, by the same rules read_env_value matches lines
line_sets_key() {
    local line=$1 key=$2 rest
    line=${line%$'\r'}
    line=${line#"${line%%[![:space:]]*}"}
    case $line in
        export[[:space:]]*)
            line=${line#export}
            line=${line#"${line%%[![:space:]]*}"}
            ;;
    esac
    [ "${line#"$key"}" != "$line" ] || return 1
    rest=${line#"$key"}
    rest=${rest#"${rest%%[![:space:]]*}"}
    case $rest in
        =*) return 0 ;;
        *) return 1 ;;
    esac
}

trim() {
    local value=$1
    value=${value#"${value%%[![:space:]]*}"}
    value=${value%"${value##*[![:space:]]}"}
    printf '%s' "$value"
}

parse_arguments() {
    NON_INTERACTIVE=0
    TOKEN_STDIN=0
    local arg
    for arg in "$@"; do
        case $arg in
            --non-interactive) NON_INTERACTIVE=1 ;;
            --token-stdin) TOKEN_STDIN=1 ;;
            *) fail "Unknown option $arg (use --non-interactive, --token-stdin)" ;;
        esac
    done
    if [ "$TOKEN_STDIN" = 1 ] && [ "$NON_INTERACTIVE" = 0 ]; then
        fail "Unknown option --token-stdin (use --non-interactive, --token-stdin)"
    fi
}

check_project() {
    local missing=0
    [ -e "$RUNNER_DIR/.git" ] || missing=1
    [ -f "$COMPOSE_FILE_PATH" ] || missing=1
    [ -f "$EXAMPLE_FILE" ] || missing=1
    if [ "$missing" = 0 ] && grep -q '^[[:space:]]*build:' "$COMPOSE_FILE_PATH" \
        && [ ! -f "$RUNNER_DIR/Dockerfile" ]; then
        missing=1
    fi
    if [ "$missing" = 1 ]; then
        fail "Run this from a git clone of the repository (see docs/02-installation.md)"
    fi
    print_success "Project folder: $RUNNER_DIR"
}

check_prerequisites() {
    command -v jq > /dev/null 2>&1 || fail "jq not found"
    command -v docker > /dev/null 2>&1 || fail "docker not found: install Container Manager"
    if ! docker compose version > /dev/null 2>&1; then
        fail "Docker Compose v2 not found (docker compose version failed)"
    fi
    if [ "${SKIP_DOCKER_ACCESS_CHECK:-}" != 1 ] && ! docker ps > /dev/null 2>&1; then
        fail "Cannot use Docker: run with sudo"
    fi
    print_success "Docker and Docker Compose v2 available"
    if [ ! -f /etc/synoinfo.conf ]; then
        print_warning "Not running on Synology DSM"
    fi
}

# Values come from the current .env, or from .env.example before one exists
current_value() {
    if [ -f "$ENV_FILE" ]; then
        read_env_value "$ENV_FILE" "$1"
    else
        read_env_value "$EXAMPLE_FILE" "$1"
    fi
}

scope_of() {
    local scope
    scope=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case $scope in
        org*) echo organization ;;
        ent*) echo enterprise ;;
        *) echo repository ;;
    esac
}

SET_KEYS=()
SET_VALUES=()

give_value() {
    local key=$1 value
    value=$(trim "$2")
    [ -n "$value" ] || return 0
    case $value in
        *$'\n'* | *\'*) fail "$key contains a character the installer can't store; edit .env by hand" ;;
    esac
    SET_KEYS+=("$key")
    SET_VALUES+=("$value")
}

# Prints PROMPT and reads one line into ANSWER; a closed stdin is an empty answer
ask() {
    ANSWER=''
    printf '%s' "$1"
    IFS= read -r "${@:2}" ANSWER || true
    echo
}

collect_values() {
    local token=''
    if [ "$NON_INTERACTIVE" = 1 ]; then
        give_value REPO_URL "${INSTALL_REPO_URL:-}"
        if [ "$TOKEN_STDIN" = 1 ]; then
            IFS= read -r token || true
        fi
        give_value GITHUB_PAT "$token"
        give_value RUNNER_NAME "${INSTALL_RUNNER_NAME:-}"
        return 0
    fi

    current_value RUNNER_SCOPE
    if [ "$(scope_of "$ENV_VALUE")" != organization ]; then
        current_value REPO_URL
        ask "Repository the runner serves [$ENV_VALUE]: "
        give_value REPO_URL "$ANSWER"
    fi

    echo "Token: a fine-grained PAT for that repository with Administration: Read and write"
    echo "(a classic PAT with 'repo' also works); for organization scope, a fine-grained PAT"
    echo "for the organization with Self-hosted runners: Read and write. Empty keeps the current one."
    ask "Token (hidden): " -s
    give_value GITHUB_PAT "$ANSWER"

    current_value RUNNER_NAME
    ask "Runner name [${ENV_VALUE:-$DEFAULT_RUNNER_NAME}]: "
    give_value RUNNER_NAME "$ANSWER"
}

format_value() {
    case $1 in
        *[!A-Za-z0-9_./:@+-]*) printf "'%s'" "$1" ;;
        *) printf '%s' "$1" ;;
    esac
}

# Replaces the line read_env_value would read for each given key, or appends one;
# every other line is written back unchanged
write_env() {
    local -a lines=()
    local line last_newline=1 i j found

    if [ ! -f "$ENV_FILE" ]; then
        (umask 077 && cp "$EXAMPLE_FILE" "$ENV_FILE")
        print_success "Created .env from .env.example"
    fi

    if [ "${#SET_KEYS[@]}" -gt 0 ]; then
        while IFS= read -r line || { [ -n "$line" ] && last_newline=0; }; do
            lines+=("$line")
        done < "$ENV_FILE"

        for i in "${!SET_KEYS[@]}"; do
            found=''
            for j in "${!lines[@]}"; do
                if line_sets_key "${lines[j]}" "${SET_KEYS[i]}"; then
                    found=$j
                fi
            done
            line="${SET_KEYS[i]}=$(format_value "${SET_VALUES[i]}")"
            if [ -n "$found" ]; then
                lines[found]=$line
            else
                lines+=("$line")
                last_newline=1
            fi
        done

        rm -f "$ENV_TMP"
        (
            umask 077
            for i in "${!lines[@]}"; do
                if [ "$i" -lt $((${#lines[@]} - 1)) ] || [ "$last_newline" = 1 ]; then
                    printf '%s\n' "${lines[i]}"
                else
                    printf '%s' "${lines[i]}"
                fi
            done > "$ENV_TMP"
        )
        mv "$ENV_TMP" "$ENV_FILE"
        print_success "Updated ${SET_KEYS[*]} in .env"
    fi

    chmod 600 "$ENV_FILE"
    if [ -n "${SUDO_USER:-}" ]; then
        chown "$SUDO_USER" "$ENV_FILE"
    fi
}

check_values() {
    local scope pat_placeholder repo_placeholder

    read_env_value "$EXAMPLE_FILE" REPO_URL
    repo_placeholder=$ENV_VALUE
    read_env_value "$EXAMPLE_FILE" GITHUB_PAT
    pat_placeholder=$ENV_VALUE

    read_env_value "$ENV_FILE" RUNNER_SCOPE
    scope=$(scope_of "$ENV_VALUE")
    case $scope in
        enterprise)
            fail "Enterprise scope is not supported"
            ;;
        organization)
            read_env_value "$ENV_FILE" ORG_NAME
            if [ -z "$ENV_VALUE" ] || [ "$ENV_VALUE" = your-org ]; then
                fail "Set ORG_NAME"
            fi
            ;;
        *)
            read_env_value "$ENV_FILE" REPO_URL
            if [ -z "$ENV_VALUE" ] || [ "$ENV_VALUE" = "$repo_placeholder" ]; then
                fail "Set REPO_URL (the repository the runner serves)"
            fi
            ;;
    esac

    read_env_value "$ENV_FILE" GITHUB_PAT
    if [ -z "$ENV_VALUE" ] || [ "$ENV_VALUE" = "$pat_placeholder" ]; then
        read_env_value "$ENV_FILE" APP_PRIVATE_KEY
        if [ -z "$ENV_VALUE" ]; then
            fail "Set GITHUB_PAT, or APP_ID and APP_PRIVATE_KEY"
        fi
    fi

    read_env_value "$ENV_FILE" CONTAINER_NAME
    CONTAINER_NAME=${ENV_VALUE:-$DEFAULT_CONTAINER_NAME}
    case $CONTAINER_NAME in
        [a-z0-9]*) ;;
        *) fail "CONTAINER_NAME must start with a lowercase letter or digit and use only those, - and _" ;;
    esac
    case $CONTAINER_NAME in
        *[!a-z0-9_-]*) fail "CONTAINER_NAME must start with a lowercase letter or digit and use only those, - and _" ;;
    esac
    print_success "Required values set in .env ($scope scope)"
}

# Runs docker compose on this project only: variables the compose file reads are
# unset first, since a shell variable would override the value in .env
compose() {
    local -a unset_args=()
    local var
    # shellcheck disable=SC2016 # a literal ${ to match in the compose file
    while IFS= read -r var; do
        unset_args+=(-u "${var#\$\{}")
    done < <(grep -o '\${[A-Z_][A-Z0-9_]*' "$COMPOSE_FILE_PATH")
    env "${unset_args[@]}" docker compose --project-directory "$RUNNER_DIR" \
        -f "$COMPOSE_FILE_PATH" "$@"
}

# Compose's own error output is never shown: it can quote values from .env
check_compose() {
    if ! compose config -q > /dev/null 2>&1; then
        fail "docker-compose.yaml or .env is invalid: run 'sudo docker compose config -q' in $RUNNER_DIR to see why (its output can include values from .env)"
    fi
    print_success "docker-compose.yaml and .env are valid"
}

create_directories() {
    local rendered workspace cache dir
    if ! rendered=$(compose config --format json 2> /dev/null); then
        fail "docker-compose.yaml or .env is invalid: run 'sudo docker compose config -q' in $RUNNER_DIR to see why (its output can include values from .env)"
    fi
    workspace=$(printf '%s' "$rendered" | jq -r '
        [.services[]] | first | .environment.RUNNER_WORKDIR as $wd
        | [.volumes[]? | select($wd != null and .target == $wd) | .source] | first // empty')
    cache=$(printf '%s' "$rendered" | jq -r '
        [.services[]] | first
        | [.volumes[]? | select(.target == "/cache") | .source] | first // empty')
    if [ -z "$workspace" ] || [ -z "$cache" ]; then
        fail "docker-compose.yaml has no workspace or /cache mount"
    fi
    for dir in "$workspace" "$cache"; do
        dir="${DATA_ROOT_OVERRIDE:-}$dir"
        (umask 022 && mkdir -p "$dir")
        print_success "Folder ready: $dir"
    done
}

print_next_steps() {
    echo ""
    echo "Next steps:"
    echo "  1. In Container Manager, create a project named $CONTAINER_NAME with path"
    echo "     $RUNNER_DIR, using its existing docker-compose.yaml."
    echo "  2. The runner then appears under the repository's (or organization's)"
    echo "     Settings → Actions → Runners."
    echo "  3. To update, git pull in $RUNNER_DIR, then pull the image as"
    echo "     docs/06-maintenance.md describes."
    echo "  4. Monitoring: see docs/04-monitoring.md"
}

main() {
    parse_arguments "$@"
    check_project
    check_prerequisites
    collect_values
    write_env
    check_values
    check_compose
    create_directories
    print_next_steps
}

main "$@"
