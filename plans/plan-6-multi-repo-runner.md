# Plan 6: One NAS, Several Repositories - plan

**Status:** 🔴 Not Started
**Goal:** A user with several private repositories can run all their CI on one Synology NAS, by either of the two
setups GitHub allows, both working out of the box and documented.
**Approach:** Fix organization scope, which the compose file and init script break today. Make the compose file run
as several Container Manager projects side by side without sharing a workspace. Then document how to choose between
the two setups and how to set up each.
**Order:** last of the active plans, which land as 7, 2, 8, 6. Plan 7 has already added the compose file's `name:`,
`container_name: ${CONTAINER_NAME:-github-runner}`, the DSM 7.2 minimum and the "container name already in use"
troubleshooting entry; Plan 8 has switched the compose file to the published image, so this plan's docs say "pull the
image" where they once said "rebuild", and its clones share an image rather than a local tag.
**Spec:** GitHub docs, "About self-hosted runners" and "Managing access to self-hosted runners using groups"
(docs.github.com/en/actions/hosting-your-own-runners).

## What GitHub allows

- Runners register at repository, organization or enterprise level. A personal account has no account-level runners,
  so a repository-level runner only takes jobs from its own repository; labels don't change that.
- That leaves two setups for a personal account:
  - **A. One runner per repository:** one Container Manager project per repository. No account changes. Jobs from
    different repositories can build at the same time, so the NAS must fit the sum of the memory limits.
  - **B. A free organization:** transfer the repositories into it and register one org-level runner, which all their
    jobs queue for. Old URLs redirect, but `ghcr.io/<old-owner>/` images and GitHub Pages URLs change owner.
- Public repositories never use these runners: the org's Default runner group excludes them, and that stays off,
  since a fork's pull request could otherwise run code on the NAS.

## Why organization scope is broken today

- The upstream entrypoint builds the org URL from `ORG_NAME`, which `docker-compose.yaml` doesn't pass; its own check
  for a missing `ORG_NAME` exits only a subshell, so registration goes to `https://github.com/` and fails.
- `.env.example` and `docs/03-configuration.md` tell users to put the org URL in `REPO_URL`, which upstream ignores
  for org scope.
- `scripts/init-runner.sh` requires `REPO_URL`, which org scope doesn't need.

## Out of scope

- Enterprise scope: rejected by `init-runner.sh` and documented as unsupported.
- Other docs that use the default container name and paths keep them; the guide says to substitute your own.

## Global constraints

- This repository's own CI stays on GitHub-hosted runners.
- Single-runner setups keep working unchanged: every new variable defaults to today's value, and no `.env` value that
  works today is rejected. `RUNNER_SCOPE` follows the upstream rule Plan 2's global constraints state (`org...` is
  organization, `ent...` enterprise, anything else repository).
- Nothing personal in tracked files: `your-username`, `your-org`, `repo-a`, `repo-b`, tokens `ghp_xxx`.
- Compose fixtures live in `tests/compose/fixtures/` and are named `<name>.env.fixture`, since `.gitignore` ignores
  `*.env`.
  Plan 8 Task 4 already created `defaults.env.fixture` and its rendering step in `quality.yml`; extend both.
- Tasks 1-3 ship in one pull request: docs-only changes don't trigger `quality.yml`, Task 1's docs link to Task 3's
  guide, and the guide relies on Task 2. Before pushing, run markdownlint, cspell and the link check locally, and
  ShellCheck on `scripts/init-runner.sh`.
- CI steps run under `bash -e`, so capture an expected failure (`rc=0; out=$(cmd 2>&1) || rc=$?`). The step order in
  `quality.yml` is the one Plan 2 lists, shared by the active plans.
- Find lines in files other plans also edit by their text, never by line number.
- Credential advice, the same wherever it appears: repository scope, a fine-grained PAT for that repository with
  Administration: Read and write (a classic PAT with `repo` also works); organization scope, a fine-grained PAT for
  that organization with Self-hosted runners: Read and write. A classic PAT would need `admin:org`, which reaches every
  organization the account administers, so the docs don't recommend it.
- Changelog entries under `## [Unreleased]`, merged into an existing heading of the same type and date.
- Compose test cases unset `RUNNER_WORKDIR`, `RUNNER_DATA_DIR`, `CONTAINER_NAME`, `ORG_NAME`, `RUNNER_SCOPE` and
  `REPO_URL` first, since shell variables override `--env-file`, and never assert `RUNNER_NAME`.

## Implementation status

| Task | Status |
| --- | --- |
| 1 · Organization scope works | ⏳ PENDING |
| 2 · Several projects on one NAS | ⏳ PENDING |
| 3 · Guide: choosing and setting up | ⏳ PENDING |
| 4 · End-to-end (user-run) | ⏳ PENDING |

## File map

| File | 1 | 2 | 3 |
| --- | --- | --- | --- |
| `docker-compose.yaml`, `.env.example`, `.github/workflows/quality.yml`, `tests/compose/fixtures/` | modify | modify | |
| `scripts/init-runner.sh`, `docs/01-prerequisites.md` | modify | | |
| `docs/03-configuration.md` | modify | modify | |
| `docs/05-troubleshooting.md`, `scripts/setup/install.sh`, `tests/setup/install.test.sh` | | modify | |
| `docs/09-multi-repo-setup.md` | | | create |
| `README.md` | modify | modify | modify |
| `docs/faq.md`, `CLAUDE.md` | | | modify |
| `changelog.md` | modify | modify | modify |

## Task 1 · Organization scope works

**Interfaces:** the `.env` variable `ORG_NAME` (organization login), passed to the container as
`ORG_NAME=${ORG_NAME:-}`.

**The change:**

- `docker-compose.yaml`: pass `ORG_NAME`; `REPO_URL` becomes `${REPO_URL:-}`.
- `scripts/init-runner.sh`: validation runs first, before the startup delay and the waits, so a configuration error
  shows at once even without network. Empty counts as unset. Each failure exits 1:
  - organization scope without `ORG_NAME`: `ERROR: ORG_NAME is not set (required for organization scope)`;
  - repository scope without `REPO_URL`: `ERROR: REPO_URL is not set (required for repository scope)`;
  - enterprise scope: `ERROR: enterprise scope is not supported`;
  - the existing credential check and its message stay. `REPO_URL`'s format isn't checked.
  On success it prints `Runner scope: organization <ORG_NAME>` or `Runner scope: repository <REPO_URL>`.
- `.env.example`: `REPO_URL` is described as the repository for repository scope, with the placeholder value; the
  credential lines give the credential advice; the GitHub App step says to install the app on the repository or the
  organization; the `RUNNER_SCOPE` block keeps `RUNNER_SCOPE=repo` active and explains organization scope
  (`RUNNER_SCOPE=org` plus `ORG_NAME`, `REPO_URL` unused, a link to the guide), ending in commented
  `# RUNNER_SCOPE=org` and `# ORG_NAME=your-org`; the runners-page hint adds the organization URL.
- `docs/03-configuration.md`: the org-URL-in-`REPO_URL` advice goes; new `RUNNER_SCOPE` and `ORG_NAME` sections; the
  `GITHUB_PAT` section gives the credential advice.
- Every other place that tells users which token rights to give, found with
  `git grep -n -i -E 'scopes?|workflow' -- README.md docs/ .env.example` (today in `README.md`,
  `docs/00-quick-start.md`, `docs/01-prerequisites.md` and `docs/02-installation.md`, several times each): the
  credential advice. Afterwards `git grep -n -i -E 'repo.{0,6}(and|,).{0,6}workflow' -- README.md docs/ .env.example`
  finds nothing.
- `changelog.md`: "Fixed": organization scope never registered; `ORG_NAME` is now passed through and checked.

**Tests:** a CI step "Verify organization scope", reusing the image `runner-under-test`; each container runs with
`DEBUG_ONLY=true` and `ACCESS_TOKEN=unused` and is removed afterwards.

1. Starts, with `STARTUP_DELAY_SECONDS=0` and `RUNNER_WORKDIR=/tmp`, within 120 seconds, printing
   `Running ./bin/Runner.Listener run` and the scope line: `RUNNER_SCOPE=org` with `ORG_NAME=your-org` and no
   `REPO_URL` → `Runner scope: organization your-org`; `RUNNER_SCOPE=ORG` → the same; an empty `RUNNER_SCOPE` and
   `RUNNER_SCOPE=repository` with `REPO_URL` → `Runner scope: repository https://github.com/your-username/your-repo`.
2. Fails at once, with `--network none`, the default startup delay and `RUNNER_WORKDIR=/nonexistent`, under
   `timeout 20`, so any wait before validation fails the case: organization scope without `ORG_NAME`, and repository
   scope without `REPO_URL`, each both unset and passed empty; organization scope with a `REPO_URL` but no `ORG_NAME`;
   `RUNNER_SCOPE=enterprise` and `RUNNER_SCOPE=Ent`; organization scope with `ACCESS_TOKEN` overridden to empty. Each
   exits 1 with its message.
3. Compose, in the same step: `org.env.fixture` (`RUNNER_SCOPE=org`, `ORG_NAME=your-org`, `GITHUB_PAT=ghp_xxx`, no
   `REPO_URL`) renders `ORG_NAME`, `RUNNER_SCOPE` and an empty `REPO_URL` in the service's environment, the test that
   fails if Compose stops passing `ORG_NAME`.

## Task 2 · Several projects on one NAS

**Interfaces:** the `.env` variables `CONTAINER_NAME` (default `github-runner`) and `RUNNER_DATA_DIR` (default
`/volume1/docker/github-runner`), the workspace and cache living under the latter. Plan 2's scripts and Plan 7's
installer read both from the same `.env`.

**The change:**

- `docker-compose.yaml`:
  - the cache volume under `RUNNER_DATA_DIR`;
  - `RUNNER_WORKDIR`, both in the environment and on both sides of its mount (identical for Docker-in-Docker), defaults
    to `$RUNNER_DATA_DIR/workspace` through
    `${RUNNER_WORKDIR:-${RUNNER_DATA_DIR:-/volume1/docker/github-runner}/workspace}`. Task 4 step 2 confirms DSM's
    Compose resolves it; if it doesn't, that's a new task, not a silent fallback.
- `.env.example`: the `RUNNER_WORKDIR=` line is commented out, noting the default and that it must differ between
  projects (an existing `.env` that sets it keeps its path). A commented "Running several runners" block:
  - a second project is a second clone, for example `/volume1/docker/synology-github-runner-repo-b`, with its own
    `.env` setting `CONTAINER_NAME=github-runner-repo-b`, `RUNNER_DATA_DIR=/volume1/docker/github-runner-repo-b`
    (no trailing `/`), `RUNNER_NAME=synology-repo-b` and its `REPO_URL`, and no `RUNNER_WORKDIR`;
  - `CONTAINER_NAME` is also the Compose project name, so it uses lowercase letters, digits, `-` and `_` only, and the
    Container Manager project gets the same name;
  - set both name and data folder, since the name alone leaves the workspace shared;
  - fit all projects' `RUNNER_MEMORY` into the NAS;
  - create the folders first:
    `sudo mkdir -p /volume1/docker/github-runner-repo-b/workspace /volume1/docker/github-runner-repo-b/cache`
    or run the installer in the second clone;
  - keep the clones on the same commit, so their compose files match; they all pull the same image.
- `docs/03-configuration.md`: `CONTAINER_NAME` and `RUNNER_DATA_DIR` sections (unique per project, set together, the
  naming rule), and how to see an existing container's project name:
  `sudo docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' github-runner`.
- `docs/05-troubleshooting.md`: the workspace-path section's hardcoded `/volume1/docker/github-runner/workspace` says
  `$RUNNER_DATA_DIR/workspace` (default shown), and the fix it suggests is setting `RUNNER_DATA_DIR` (or
  `RUNNER_WORKDIR`).
- `scripts/setup/install.sh`: when `CONTAINER_NAME` isn't `github-runner` but the workspace or the cache is the default
  one under `/volume1/docker/github-runner`, warn
  `⚠ This project shares the default workspace or cache: set RUNNER_DATA_DIR (see docs/09-multi-repo-setup.md)`;
  the run still exits 0. Its tests add: `RUNNER_DATA_DIR` alone creates its `workspace` and `cache`; the warning prints
  for `CONTAINER_NAME=github-runner-b` alone and with only its own `RUNNER_WORKDIR`, and not with its own
  `RUNNER_DATA_DIR`, nor for the default name; `RUNNER_DATA_DIR` joins the variables the tests unset.
- `changelog.md`: "Added" `RUNNER_DATA_DIR`; "Changed" `RUNNER_WORKDIR` is commented out in `.env.example` and
  defaults to `$RUNNER_DATA_DIR/workspace`.

**Tests:** a CI step "Verify compose variables", rendering each fixture with `docker compose --env-file <fixture>
config --format json` and checking the project name, the container name, `RUNNER_WORKDIR`, and the workspace and cache
mounts (picked by target, not position):

| Fixture | Project and container | Workspace (source = target = `RUNNER_WORKDIR`) | Cache source |
| --- | --- | --- | --- |
| `defaults` (only `REPO_URL`, `GITHUB_PAT`) | `github-runner` | `/volume1/docker/github-runner/workspace` | `/volume1/docker/github-runner/cache` |
| `repo-b` (`CONTAINER_NAME`, `RUNNER_DATA_DIR`) | `github-runner-repo-b` | `/volume1/docker/github-runner-repo-b/workspace` | `/volume1/docker/github-runner-repo-b/cache` |
| `workdir-only` | `github-runner` | `/volume1/custom/workspace` | `/volume1/docker/github-runner/cache` |
| `workdir-and-data` (repo-b's `RUNNER_DATA_DIR`) | `github-runner` | `/volume1/custom/workspace` | `/volume1/docker/github-runner-repo-b/cache` |
| `empty-values` (all three empty) | `github-runner` | `/volume1/docker/github-runner/workspace` | `/volume1/docker/github-runner/cache` |
| `name-only` | `github-runner-repo-b` | `/volume1/docker/github-runner/workspace` (shared, as warned) | `/volume1/docker/github-runner/cache` |
| a temporary copy of `.env.example` with repo-b's `RUNNER_DATA_DIR` appended | `github-runner` | `/volume1/docker/github-runner-repo-b/workspace` | `/volume1/docker/github-runner-repo-b/cache` |

Fixture files are `<name>.env.fixture`, each with `REPO_URL=https://github.com/your-username/your-repo` and
`GITHUB_PAT=ghp_xxx` plus: `repo-b` `CONTAINER_NAME=github-runner-repo-b` and
`RUNNER_DATA_DIR=/volume1/docker/github-runner-repo-b`; `workdir-only` `RUNNER_WORKDIR=/volume1/custom/workspace`;
`workdir-and-data` both of those `RUNNER_*` values; `empty-values` `CONTAINER_NAME=`, `RUNNER_DATA_DIR=` and
`RUNNER_WORKDIR=`; `name-only` `CONTAINER_NAME=github-runner-repo-b`. The last row proves `.env.example` no longer
pins the workspace.

## Task 3 · Guide: choosing and setting up

**`docs/09-multi-repo-setup.md`:**

1. Why a personal account can't share one repository-level runner, so pick A or B.
2. A comparison of the two: account changes, credential rights, concurrent builds, memory, what moves on transfer,
   and public repositories (neither: they stay on GitHub-hosted runners).
3. Setup A: a second clone, its `.env` (when copying another project's, change `CONTAINER_NAME` and
   `RUNNER_DATA_DIR` and delete any `RUNNER_WORKDIR` line), its folders, its Container Manager project named after its
   `CONTAINER_NAME`, memory sizing, and "keep the clones on the same commit, so their compose files match; they all
   pull the same image". Monitoring: one health-check task per project, each running its
   own clone's script, which reads that clone's `.env` and `CONTAINER_NAME`.
4. Setup B: create the organization, transfer the repositories, create the organization PAT, set `RUNNER_SCOPE=org`
   and `ORG_NAME`, pull the image and recreate the project, and find the
   runner under the organization's Settings → Actions → Runners. Workflows keep `runs-on: [self-hosted, Linux, X64]`;
   runner names are unique per organization.
5. Moving from a repository runner to B: stopping the container deregisters it; remove it by hand if it lingers.
6. Troubleshooting: Task 1's messages quoted verbatim; jobs never starting for a public repository (expected; keep
   them on GitHub-hosted runners and leave public repositories off the runner group); 403 on registration (the
   credential lacks the organization permission); "container name already in use" (the Container Manager project and
   `CONTAINER_NAME` differ: rename one to match).

`docs/faq.md`: the two multi-runner questions point at the guide, dropping "Share runner across repos in same org";
new question "Should I create an organization?". `README.md`: the guide in the documentation index. `CLAUDE.md`: the
guide in the repository tree. `changelog.md`: "Added" the guide.

**Tests:** the local doc checks pass, CI passes on the shared pull request, and each of Task 1's three `ERROR:`
messages is found by `grep -F` in both `scripts/init-runner.sh` and the guide.

## Task 4 · End-to-end (user-run)

After the pull request merges, every clone on that commit. The user creates the prerequisites and runs or approves each
step. An existing runner project on the NAS is never switched or edited; its running container keeps the image it was
created from, since the test projects only pull the published image.

**Prerequisites:** two private test repositories (`repo-a`, `repo-b`) with a `workflow_dispatch` workflow that runs
`pwd`, `date -u` and `sleep 60`, and a fine-grained PAT limited to them; for step 4, a throwaway organization with one
such private repository and a PAT for that organization only.

1. **A:** two clones, `/volume1/docker/synology-github-runner-repo-a` and `-repo-b`, each with a `.env` per the guide
   (`CONTAINER_NAME=github-runner-repo-a` or `-repo-b`, `RUNNER_DATA_DIR=/volume1/docker/github-runner-repo-a` or
   `-repo-b`), their folders, and Container Manager projects with those names.
2. In the repo-b clone, check the paths without printing the token (the full output contains it; never paste it):

   ```bash
   sudo docker compose config --format json 2>/dev/null | jq '{name, services: [.services[] |
     {container_name, workdir: .environment.RUNNER_WORKDIR, volumes: [.volumes[] | {source, target}]}]}'
   ```

   Expect `github-runner-repo-b` as name and container, its workspace on both sides and in `RUNNER_WORKDIR`, and its
   cache. A literal `${` means the NAS's Compose doesn't resolve nested defaults. No output means Compose failed: run
   `sudo docker compose config -q` alone to see why, and don't paste its output anywhere, since it can quote `.env`.
3. Dispatch both test workflows at once: both run, each on its own runner, each `pwd` under its own workspace, and
   their start and end times overlap.
4. **B:** a third clone, `/volume1/docker/synology-github-runner-org-test`, with
   `CONTAINER_NAME=github-runner-org-test`, `RUNNER_DATA_DIR=/volume1/docker/github-runner-org-test`,
   `RUNNER_SCOPE=org`, `ORG_NAME` and the organization PAT; the runner appears under the organization and runs its test
   workflow. Then, in that clone:

   ```bash
   sudo env STATE_FILE=$(mktemp) LOG_FILE=$(mktemp) ALERT_AFTER_FAILURES=1 \
     bash scripts/monitoring/runner-health-check.sh        # expect exit 0, no output
   d=$(sudo mktemp -d); sudo cp .env "$d/.env"
   printf '\nRUNNER_NAME=no-such-runner\n' | sudo tee -a "$d/.env" >/dev/null   # the last line wins
   sudo env RUNNER_DIR="$d" STATE_FILE=$(mktemp) LOG_FILE=$(mktemp) ALERT_AFTER_FAILURES=1 \
     bash scripts/monitoring/runner-health-check.sh
   # expect exit 1 with "runner no-such-runner is offline or not registered"
   sudo rm -rf "$d"                                        # the copy holds the token
   ```

5. Clean up: remove the three test projects and check their runners are gone from GitHub; delete the clones and data
   folders; delete the organization and test repositories; revoke both PATs.

Record outcomes in generic terms only ("two projects ran jobs concurrently in separate workspaces"): never names,
addresses, paths, container names, other services, the model or software versions from the NAS.
