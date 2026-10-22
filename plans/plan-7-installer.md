# Plan 7: An Installer That Works - plan

**Status:** 🔴 Not Started
**Goal:** `scripts/setup/install.sh`, run inside a clone of this repository on the NAS, leaves that clone ready to
become a Container Manager project that starts a runner, and `git pull` keeps it current.
**Approach:** The clone is the project folder, as in the manual installation guide. The installer stops copying files
elsewhere: it checks prerequisites, writes `.env` from `.env.example` safely, validates the compose file, creates the
host directories the compose file mounts (read from the rendered compose file, so it follows whatever variables the
compose file supports), and hands over to Container Manager, which creates and owns the project. A non-interactive
mode lets CI test it.
**Order:** after Plans 2 and 6, before Plan 8 (the active plans land as 2, 6, 7, 8). It copies Plan 2's
`read_env_value`, uses Plan 2's test runner and CI steps, and relies on Plan 6's `CONTAINER_NAME`, `RUNNER_DATA_DIR`
and the compose file's `name:`.

## Why the current installer doesn't work

- It copies only `docker-compose.yaml` and `.env` to `/volume1/docker/github-runner`, but the compose file builds from
  `Dockerfile` and `scripts/`, so the build fails there.
- The README's recommended flow copies the repository with `scp`, so nothing is a git clone and `git pull` can't update.
- It writes the token with `sed -i "s|GITHUB_PAT=.*|...|"`: `|`, `&` or `\` in the value corrupt `.env`, the token is on
  `sed`'s command line, and the unanchored pattern also rewrites comment lines mentioning the key.
- Its default runner name differs from the compose default, and it creates `data/{workspace,cache}`, `config` and
  `logs`, which the compose file never mounts.
- `docs/02-installation.md` creates `workspace/` and `cache/` inside the clone, while the compose file mounts
  `/volume1/docker/github-runner/workspace` and `/cache`.
- The update instructions (`docker-compose pull`, `down`, `up -d` in `docs/06-maintenance.md`, `docs/faq.md` and
  `docs/07-security.md`) never `git pull` or rebuild, so the runner never gets this repository's fixes.

## Out of scope

- Starting the runner from the command line: Container Manager creates the project from the clone, and the installer
  prints how.
- Entering GitHub App credentials or organization settings: users edit those in `.env` by hand, and the installer
  accepts them.
- Monitoring set-up: the installer only points to `docs/04-monitoring.md`.
- Compose commands elsewhere in the docs: once Plan 6 names the project in the compose file, they work from the
  project folder as written.

## Global constraints

- Bash, `set -Eeu -o pipefail`, passes ShellCheck.
- `umask 077` while writing `.env` and its temporary file, so they are private from creation; `umask 022` while
  creating the data directories, so new ones and their new parents get mode 755, since jobs' containers read the
  workspace. Existing directories keep their modes.
- `PATH` gets `INSTALL_SYSTEM_PATH` (default `/usr/local/bin:/usr/bin:/bin`) appended, never prepended; tests set it
  empty to control which tools exist.
- `.env` is read with `read_env_value`, copied exactly from `scripts/monitoring/runner-health-check.sh`; Plan 2's CI
  check then covers the installer's copy too. Missing or empty means the default. `RUNNER_SCOPE` follows the rule in
  Plan 2's global constraints.
- Docker Compose v2 through `docker compose`, which Container Manager on DSM 7.2 provides; the script's header comment
  says DSM 7.2 or later.
- Compose always runs in `RUNNER_DIR` (`--project-directory "$RUNNER_DIR"`), with the variables the compose file reads
  (`git grep -o '\${[A-Z_]*' docker-compose.yaml`) unset in its environment, so shell variables can't override `.env`.
- An `ERR` trap prints `✗ unexpected error at line <n>` and removes the temporary `.env` file.
- Secrets never appear on a command line or in output: the token arrives through a hidden prompt or stdin, reaches
  `awk` only through its environment, and is never echoed. Compose's own error output is never printed, since it can
  quote `.env` values.
- Output: progress lines start with `✓` and warnings with `⚠`; a failure prints exactly one line starting with `✗` and
  exits 1. Everything goes to stdout.
- Nothing personal in tracked files; fixtures use `ghp_xxx` and `https://github.com/your-username/test-repo` (not the
  `.env.example` placeholder, which the installer rejects).
- Credential advice as Plan 6 states it, wherever the installer or its docs mention token rights.
- Changelog entries under `## [Unreleased]`, merged into an existing heading of the same type and date.
- Task 2 ships in the same pull request as Task 1, since docs-only changes don't trigger `quality.yml`.

## Implementation status

| Task | Status |
| --- | --- |
| 1 · Installer prepares the clone | ⏳ PENDING |
| 2 · Install and update docs follow one layout | ⏳ PENDING |
| 3 · End-to-end on a NAS (user-run) | ⏳ PENDING |

## File map

| File | Task 1 | Task 2 |
| --- | --- | --- |
| `scripts/setup/install.sh` | rewrite | |
| `tests/setup/install.test.sh`, `tests/setup/stubs/*` | create | |
| `README.md`, `docs/00-quick-start.md`, `docs/02-installation.md` | | modify |
| `docs/06-maintenance.md`, `docs/faq.md`, `docs/07-security.md` | | modify |
| `.env.example`, `docs/09-multi-repo-setup.md` | | modify |
| `CLAUDE.md` (repository tree: `tests/setup/`) | modify | |
| `changelog.md` | modify | modify |

## Task 1 · Installer prepares the clone

**Interfaces:**

- `sudo ./scripts/setup/install.sh [--non-interactive [--token-stdin]]`, from any directory. Another argument, or
  `--token-stdin` without `--non-interactive`, gives `✗ Unknown option <arg> (use --non-interactive, --token-stdin)`.
  The project folder is `RUNNER_DIR`, the clone root two levels above the script, overridable by environment as in
  Plan 2.
- Interactive (default): prompts on stdin for `REPO_URL`, the token (hidden; the prompt states the credential advice)
  and `RUNNER_NAME` (offering the current value, else `synology-general-runner`); an empty answer keeps the current
  value, and stdin ending early counts as empty answers.
- In organization scope, the interactive mode doesn't ask for `REPO_URL`.
- `--non-interactive`: never prompts. Non-empty `INSTALL_REPO_URL` and `INSTALL_RUNNER_NAME` set those keys (the prefix
  avoids `RUNNER_NAME`, which GitHub Actions exports). With `--token-stdin`, the token is stdin's first line, with or
  without a final newline; empty stdin means no token, never an error.
- Given values, the token included, have surrounding whitespace and `\r` removed.
- Test knobs: `DATA_ROOT_OVERRIDE`, prefixed to the data directories created and printed (not to `RUNNER_DIR`), and
  `SKIP_DOCKER_ACCESS_CHECK=1`.

**Steps, in order:**

1. Project: `RUNNER_DIR` holds `.git`, `docker-compose.yaml` and `.env.example`, and `Dockerfile` when
   `docker-compose.yaml` has a line matching `^[[:space:]]*build:`; else
   `✗ Run this from a git clone of the repository (see docs/02-installation.md)`.
2. Prerequisites: `jq` on `PATH` (`✗ jq not found`); `docker` on `PATH` (`✗ docker not found: install Container
   Manager`); `docker compose version`
   (`✗ Docker Compose v2 not found (docker compose version failed)`); `docker ps` unless skipped
   (`✗ Cannot use Docker: run with sudo`). Without `/etc/synoinfo.conf`, `⚠ Not running on Synology DSM`.
3. `.env`: reject a given value containing a newline or a single quote before writing anything
   (`✗ <KEY> contains a character the installer can't store; edit .env by hand`). Copy `.env.example` if `.env` is
   missing; never overwrite an existing one. Each given key replaces the line `read_env_value` would read for it (the
   last match, dropping any `export`, indentation and inline comment), or is appended; other lines, comments included,
   stay byte-identical. Values outside `[A-Za-z0-9_./:@+-]` are written single-quoted. Written through `.env.tmp` and
   `mv`. Every run then sets `.env` to mode 600 and, under `sudo`, owner `SUDO_USER`, even when no key changed.
4. Required values on the result, compared with `.env.example`'s placeholders read at run time (no placeholder token
   in the script, which the secret scan would flag):
   - `✗ Enterprise scope is not supported`;
   - repository scope: `✗ Set REPO_URL (the repository the runner serves)` when empty or the placeholder; organization
     scope: `✗ Set ORG_NAME` when empty or `your-org` (the commented example in `.env.example`);
   - `✗ Set GITHUB_PAT, or APP_ID and APP_PRIVATE_KEY` unless `GITHUB_PAT` is set and not the placeholder, or
     `APP_PRIVATE_KEY` is set;
   - `✗ CONTAINER_NAME must start with a lowercase letter or digit and use only those, - and _` (it is the Compose
     project name).
5. Compose: `docker compose config -q`, output discarded; on failure
   `✗ docker-compose.yaml or .env is invalid: run 'sudo docker compose config -q' in <RUNNER_DIR> to see why (its output
   can include values from .env)`.
6. Directories: from the rendered compose file (`docker compose config --format json`, kept in memory, never printed,
   read with `jq`), the source of the workspace mount (its target equals the rendered service's
   `environment.RUNNER_WORKDIR`) and of the `/cache` mount; `✗ docker-compose.yaml has no workspace or /cache mount`
   if either is missing. Create each and print it. When `CONTAINER_NAME` isn't `github-runner` but the workspace or the
   cache is the default one under `/volume1/docker/github-runner`, warn
   `⚠ This project shares the default workspace or cache: set RUNNER_DATA_DIR (see docs/09-multi-repo-setup.md)`.
7. Next steps: create a Container Manager project named `<CONTAINER_NAME>` (default `github-runner`) with path
   `<RUNNER_DIR>` and its existing `docker-compose.yaml`; the runner then appears under the repository's or
   organization's Settings → Actions → Runners; to update, `git pull` and rebuild the project; monitoring is in
   `docs/04-monitoring.md`.

Re-running is safe: it changes only the keys it is given, creates only missing directories, and leaves existing
directories' modes alone.

**Tests** (`tests/setup/install.test.sh`, run by Plan 2's "Test monitoring scripts" step, ending with `exit $failed`).
Each case copies the repository's tracked and untracked-but-not-ignored files
(`git ls-files -z --cached --others --exclude-standard`, so a local `.env` never comes along) into a fresh `mktemp -d`
outside the repository (removed by an `EXIT` trap), runs `git init` there, and runs that copy's installer with
`DATA_ROOT_OVERRIDE` set to another temporary folder and `SKIP_DOCKER_ACCESS_CHECK=1`, after unsetting `REPO_URL`,
`GITHUB_PAT`, `RUNNER_NAME`, `RUNNER_SCOPE`, `ORG_NAME`, `CONTAINER_NAME`, `RUNNER_DATA_DIR`, `RUNNER_WORKDIR`,
`INSTALL_REPO_URL` and `INSTALL_RUNNER_NAME`. Stubs log their calls and pass through to the real tools: `docker` (can
fail `compose version` or `ps`), `mv` (can fail; records the mode before acting), `cp` (records the destination's mode
after copying) and `chmod` (records the mode before acting), `chown` (records only), and `sed` and `awk` (record their
arguments). Cases that remove a tool set `INSTALL_SYSTEM_PATH=` and give `PATH` a folder of links to only the tools they
keep. Without a working `docker compose`, the cases needing it print `SKIP`, and with `CI=true` that fails the file.
Every case asserts Docker was asked only for `compose version`, `ps` and `compose config`, never `up`, `build`, `pull`
or `run`.

1. Fresh, `--non-interactive --token-stdin` with `INSTALL_REPO_URL`: exit 0; `.env` has exactly one
   `REPO_URL=https://github.com/your-username/test-repo` and one `GITHUB_PAT=ghp_xxx` line, `RUNNER_NAME` as in
   `.env.example`, mode 600; the default workspace and cache exist, mode 755, parents too; the output names the
   project path, the project name `github-runner`, `git pull`, and `docs/04-monitoring.md`.
2. A token with `|&\$` and no final newline is stored byte for byte, quoted, and appears in no output and in no stub's
   log; a `\r\n` ending and surrounding spaces are dropped.
3. Key lines, each with the rest of `.env` byte-identical afterwards: commented keys, `GITHUB_PAT2=` and
   `OLD_GITHUB_PAT=` untouched; with two `GITHUB_PAT=` lines only the last replaced; an indented or `export` line
   replaced by a plain `GITHUB_PAT=` line; `GITHUB_PAT=old # note` replaced without the comment.
4. Re-run on an existing `.env` with other keys, given only a token: the other keys kept.
5. Values, each exiting 1 with one `✗` line: an existing `.env` with `GITHUB_PAT=` empty and no token given; an empty
   `REPO_URL`; the placeholder `REPO_URL`; a fresh copy given no token (the placeholder `GITHUB_PAT`);
   `RUNNER_SCOPE=enterprise`; `CONTAINER_NAME=Runner.B`; `CONTAINER_NAME=-runner`; `INSTALL_REPO_URL` with a newline.
   `CONTAINER_NAME=runner_b` passes.
6. Not a clone, without `.git`, `.env.example` or `docker-compose.yaml`; a copied compose file given a `build:` line
   and no `Dockerfile` fails, and one without `build:` and without `Dockerfile` passes this step (both edit the copy,
   so the case doesn't depend on the repository's compose file); an unknown option; `--token-stdin` alone; `docker`
   absent (`✗ docker not found`); `jq` absent (`✗ jq not found`).
7. App credentials with an empty `GITHUB_PAT` pass and leave it empty.
8. Organization scope with `ORG_NAME` passes, also as `RUNNER_SCOPE=ORG`; without `ORG_NAME` fails with
   `✗ Set ORG_NAME`. An empty `RUNNER_SCOPE` and `RUNNER_SCOPE=repository` are repository scope.
9. Directories: `RUNNER_WORKDIR` set creates that directory and the default cache, not the default workspace;
   `RUNNER_DATA_DIR` alone creates its `workspace` and `cache`. The shared warning prints for
   `CONTAINER_NAME=github-runner-b` alone and with only its own `RUNNER_WORKDIR`, and not with its own
   `RUNNER_DATA_DIR`, nor for the default name; the run exits 0 either way. A re-run leaves an existing workspace's mode
   700 alone. A compose copy without the `/cache` mount gives `✗ docker-compose.yaml has no workspace or /cache mount`.
   With `CONTAINER_NAME=github-runner-b`, the next steps name that project.
10. Run from `/`: same as case 1.
11. Interactive: answers set the values and the token shows in no output; empty answers or closed stdin keep `.env`
    byte-identical; a runner name answer sets it. Non-interactive `INSTALL_RUNNER_NAME` sets it; a value with a single
    quote fails and creates no `.env`.
12. Broken compose (the `.env` line `BROKEN=${secret-value`, an unclosed `${` whose Compose error quotes the line):
    exit 1, exactly one `✗` line, `docker-compose.yaml or .env is invalid`, and `secret-value` nowhere in the output.
13. Owner: with `SUDO_USER` set, `.env` is handed to that user; without it, `chown` isn't called.
14. Private from creation: the `.env` copied from `.env.example` is mode 600 before any `chmod`.
15. Docker access, without `SKIP_DOCKER_ACCESS_CHECK`: a failing `ps` gives `✗ Cannot use Docker`; a failing
    `compose version` gives `✗ Docker Compose v2 not found`.
16. Unexpected error: the `mv` stub failing gives `✗ unexpected error at line`, and no temporary file is left.
17. Outside DSM (as in CI), the `⚠ Not running on Synology DSM` line is printed and the run still exits 0.

`changelog.md`: "Fixed": the installer prepares the clone as the Container Manager project, writes `.env` safely, and
creates the directories the compose file mounts. "Removed": copying to `/volume1/docker/github-runner`.

## Task 2 · Install and update docs follow one layout

- `README.md`, "Option 1: Automated Installation": `cd /volume1/docker`, `git clone
  https://github.com/andrelin/synology-github-runner.git`, `cd synology-github-runner`, `sudo
  ./scripts/setup/install.sh`, then the Container Manager project as printed. The `scp` copy goes, and so do "Install
  monitoring scripts" and "Start the runner" from the list of what the installer does.
- `docs/02-installation.md`: the data directories are `/volume1/docker/github-runner/workspace` and `/cache`, created
  with `mkdir -p`, with the installer as the shortcut; the directory-structure section, the "don't delete
  workspace/ or cache/" note and the troubleshooting `ls` point at that folder. A new "Coming from the old installer"
  subsection, for a `/volume1/docker/github-runner` folder that is not a git clone (no `.git` in it; a clone there
  already is the new layout, and nothing needs doing). The runner is offline while you do it. In Container Manager,
  delete any project named `github-runner` that points at that folder (keeping the folder); move that folder's `.env`
  into the clone; delete the old `docker-compose.yaml` and `.env.example` copies and the empty `config/` and `logs/`
  folders; the old `data/` folder can go too, since the compose file never used it; keep `workspace/` and `cache/`
  there, which the compose file mounts; then create the project from the clone.
- `docs/00-quick-start.md`: the same data-path correction, and the installer as an alternative.
- The update procedure, wherever the docs give one (`git grep -n 'docker-compose pull'` in `docs/06-maintenance.md`,
  `docs/faq.md` and `docs/07-security.md`): `git pull` in the project folder, then Build in Container Manager (or
  `sudo docker compose up -d --build` in the project folder), while the runner is idle. The pulls of the base image
  in those procedures go too: the build pulls it.
- `.env.example`'s "Running several runners" block and `docs/09-multi-repo-setup.md`'s Setup A: create the second
  project's folders by running the installer in its clone, `mkdir -p` remaining the manual alternative.
- `changelog.md`: "Fixed": the installation guide created the data directories inside the clone, and the update
  instructions never pulled this repository's changes.

**Tests:** markdownlint, cspell and the link check pass locally and in CI;
`git grep -n 'docker-compose pull' -- README.md docs/` finds nothing.

## Task 3 · End-to-end on a NAS (user-run)

Apart from the optional step 1, an existing runner project on the NAS stays untouched; its running container keeps the
image it was created from even though the test project rebuilds the same local tag. The user runs these, with a private
test repository and a fine-grained PAT limited to it:

1. Only on a NAS that still has a `/volume1/docker/github-runner` folder from the old installer (no `.git` in it), and
   only if the user agrees to the runner going offline meanwhile: follow "Coming from the old installer" and check the
   runner comes back Idle. Then clone into `/volume1/docker/synology-github-runner-install-test`; create its `.env` from
   `.env.example` with `CONTAINER_NAME=github-runner-install-test` and
   `RUNNER_DATA_DIR=/volume1/docker/github-runner-install-test`.
2. Run the installer interactively with the test repository and PAT: exit 0, the project named
   `github-runner-install-test`, its workspace and cache created, no shared-workspace warning.
3. Create the Container Manager project as printed: the runner shows Idle in the test repository.
4. `git pull` and Build in the test project: the runner comes back Idle.
5. Remove the project, both folders and the test runner, and revoke the PAT.

Record the outcome in generic terms only: never names, addresses, paths, container names, other services, the model or
software versions from the NAS.
