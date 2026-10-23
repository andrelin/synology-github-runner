# Plan 2: Monitoring - plan

**Status:** 🟢 Complete (2026-10-23)
**Goal:** The owner gets one DSM email when the runner stops being able to take jobs, one when it recovers, and a
daily reminder while it stays broken; otherwise the monitoring is silent. A dashboard script shows the runner's state
on demand, on DSM.
**Approach:** Replace the resource-threshold checks in `scripts/monitoring/runner-health-check.sh` with the signals
that mean "jobs will not run": configuration missing, container down or unhealthy, GitHub reporting the runner
offline, the container restarting, the disk filling up.
The script keeps state between runs and exits non-zero only when an email is wanted, so DSM Task Scheduler's
"email when the script terminates abnormally" sends one email per change.
It runs from inside the repository clone that serves as the Container Manager project, finds that folder from its
own location, and so picks up fixes with `git pull`.
**Order:** second of the active plans, which land as 7, 2, 8, 6. Plan 7 has already rewritten the installer (without
the monitoring copy), added `read_env_value`, the "Run script tests" CI step, the ShellCheck file list and
`CONTAINER_NAME`.

## Why the existing script can't just be scheduled

- The memory check turns `700MiB / 5GiB` into about 14 million percent.
- `check || ((ERRORS++))` returns 1 when `ERRORS` is 0, so `set -e` ends the script at the first failed check.
- The CPU check and the dashboard call `bc`, which DSM does not ship.
- The restart check alerts forever after one restart; the activity check's log line scrolls out after about 25 jobs.
- High CPU and memory during a build are normal, not incidents.

## Out of scope

- The installer (Plan 7, already landed).
- Multi-project setups beyond reading `CONTAINER_NAME`, `RUNNER_SCOPE`, `ORG_NAME`, `RUNNER_DATA_DIR` and
  `RUNNER_WORKDIR` from `.env` (Plan 6, which lands last; reading `RUNNER_DATA_DIR` before it exists is harmless).
- Running the tests on macOS. They need `flock`, `timeout` and GNU `date`, so they run in CI or in a Linux container:

  ```bash
  docker run --rm -v "$PWD:/w" -w /w ubuntu:24.04 bash -c \
    'apt-get update -qq && apt-get install -y -qq jq git >/dev/null &&
     git config --global --add safe.directory /w &&
     for t in tests/*/*.test.sh; do bash "$t" || exit 1; done'
  ```

  This runs as root, so the cases that rely on permissions print `SKIP`.

## Global constraints

- Bash, `set -Eeu -o pipefail`, passes ShellCheck.
- Only tools DSM 7 ships: `curl`, `jq`, `awk`, `sed`, `df`, GNU `date`, `tail`, `mv`, `mktemp`, `timeout`, `flock`,
  `cksum`. Never `bc`.
- `PATH="$PATH:/usr/local/bin:/usr/bin:/bin"`: appended, never prepended, so a caller's entries keep precedence. DSM
  Task Scheduler runs with a minimal `PATH`, and DSM keeps `docker` in `/usr/local/bin`.
- What describes the installation is read from the project's `.env` only, never from the environment, because GitHub
  Actions exports `RUNNER_NAME` into every CI step. Tuning knobs come from the environment.
- Every external call that could hang has a limit: `timeout -k 5 20` for `docker` and `df`, `--max-time 20` for `curl`.
- No command's stderr reaches stdout, which is the email; failures become the reasons below.
- Nothing personal in tracked files (see `CLAUDE.md`). Fixtures use `GITHUB_PAT=ghp_xxx`,
  `REPO_URL=https://github.com/your-username/your-repo` and `ORG_NAME=your-org`.
- Changelog entries go under `## [Unreleased]`, merged into an existing heading of the same type and date; skip one
  another plan already added with the same meaning.
- Find lines in docs other plans also edit by their text (`git grep`), never by line number.
- `RUNNER_SCOPE` follows the upstream image's rule, so no value that registers today is rejected: lowercased, a value
  starting `org` is organization scope, one starting `ent` is enterprise (unsupported), anything else, empty included,
  is repository scope. Plans 6 and 7 use the same rule.

## Implementation status

| Task | Status |
| --- | --- |
| 1 · Health check that alerts once per incident | ✅ DONE |
| 2 · Dashboard that runs on DSM and in CI | ✅ DONE |
| 3 · End-to-end on a NAS (user-run) | ✅ DONE |

## File map

| File | Task 1 | Task 2 |
| --- | --- | --- |
| `scripts/monitoring/runner-health-check.sh` | rewrite | |
| `scripts/monitoring/runner-dashboard.sh` | | modify |
| `tests/monitoring/lib.sh`, `tests/monitoring/stubs/*` | create | modify |
| `tests/monitoring/runner-health-check.test.sh` | create | |
| `tests/monitoring/runner-dashboard.test.sh` | | create |
| `.github/workflows/quality.yml`, `.gitignore` | modify | |
| `docs/04-monitoring.md` | rewrite | modify |
| `docs/06-maintenance.md`, `docs/faq.md`, `CLAUDE.md` | modify | |
| `README.md` | modify | modify |
| `changelog.md` | modify | modify |

## Task 1 · Health check that alerts once per incident

### Interfaces (Task 2 and Plans 6 and 7 rely on these names)

- `RUNNER_DIR`: the project folder, by default the clone root two levels above the script; overridable by environment.
- `read_env_value FILE KEY` sets the globals `ENV_VALUE` and `ENV_VALUE_QUOTE` (`none`, `single` or `double`) and always
  returns 0, also for a missing file or key (value empty, quote `none`). It is called directly, never in `$(...)`, and
  never sources or expands anything. It follows Compose's `.env` reading where users are likely to differ:

  | Line | `ENV_VALUE` | `ENV_VALUE_QUOTE` |
  | --- | --- | --- |
  | `KEY=v`, `export KEY=v`, indented `KEY=v`, `KEY = v`, `KEY=v` + `\r`, `KEY=v` + trailing spaces | `v` | `none` |
  | `KEY=v # note` | `v` | `none` |
  | `KEY=a#b`, and `KEY=a` + tab + `# b` | `a#b`, and `a` + tab + `# b` | `none` |
  | `KEY='a #b'`, `KEY="a #b"` | `a #b` | `single`, `double` |
  | `KEY='a' # note`, `KEY="a"b` | `a` | `single`, `double` |
  | `KEY="a` (unterminated) | `a` | `double` |
  | `KEY=a=b` | `a=b` | `none` |
  | `# KEY=x`, `KEY2=x`, `OLD_KEY=x`, a blank line | not a match | |
  | two `KEY=` lines | the last one's value | |

  An empty value means the key's default. This is Plan 7's function from `scripts/setup/install.sh`, copied verbatim
  into both monitoring scripts; CI checks the copies match.
- From `.env`: `REPO_URL`, `GITHUB_PAT`, `APP_ID`, `APP_PRIVATE_KEY`, `RUNNER_NAME` (default `synology-general-runner`),
  `RUNNER_SCOPE` (default `repo`), `ORG_NAME`, `CONTAINER_NAME` (default `github-runner`), `RUNNER_WORKDIR`,
  `RUNNER_DATA_DIR`.
- Environment knobs, empty meaning unset:
  - whole numbers of at most 10 digits, without leading zeros: `MAX_DISK_PERCENT` (default 90, 0 allowed),
    `ALERT_AFTER_FAILURES` (default 3, at least 1), `REMIND_AFTER_SECONDS` (default 86400; 0 reminds on every failing
    run), `NOW` (default `date +%s`, 0 allowed); an invalid one uses its default and fails the `settings` check;
  - `DISK_PATH`: default `RUNNER_WORKDIR`, else `RUNNER_DATA_DIR`, else `DEFAULT_DATA_DIR` (a test knob, default
    `/volume1/docker/github-runner`) if it exists, else `RUNNER_DIR`;
  - `STATE_FILE` (default `$RUNNER_DIR/health-check.state`) and `LOG_FILE` (default `$RUNNER_DIR/health-check.log`).
- Every age the script measures is `NOW` minus a time it wrote itself (in the state, the lock file or a marker), never a
  file's modification time, so tests control time through `NOW` alone. A stored time later than `NOW` (the clock
  stepped back) counts as `NOW`.
- State file: `KEY=value` lines `FAILURES`, `ALERTED_AT`, `ALERTED_CHECKS`, `CONTAINER_ID`, `RESTART_COUNT` and
  `RESTART_TIMES` (restarts in the last 6 hours, epoch seconds). Read with `read_env_value`, never sourced; anything
  missing or malformed reads as zero or empty, and restart times later than `NOW` are dropped. Both lists are joined
  by `,`. Written to `$STATE_FILE.tmp` in the same directory, then `mv`.
- Exit 0 with empty stdout when no email is wanted; exit 1 with the email body on stdout when one is:
  - line 1 `Runner health check (<CONTAINER_NAME>): PROBLEM`, `REMINDER` or `RECOVERED`; RECOVERED is that line only;
  - PROBLEM and REMINDER list one `- <check>: <reason>` line per failing check, a blank line, and one `Next step:` line,
    the first that applies: `run sudo bash <script path> by hand to see the error` (`internal` or `lock`);
    `edit <RUNNER_DIR>/.env` (`configuration`); `fix the environment variables in the scheduled task` (`settings`);
    `check free space and permissions for <directory of the file>` (`storage`); `free space on <DISK_PATH>` (only
    `disk_space` failing); otherwise `docker logs <CONTAINER_NAME>`.
- One log line per run, appended to `LOG_FILE`: `<date -u -d @NOW +%Y-%m-%dT%H:%M:%SZ> <event>`, the event being `OK`,
  `FAIL <n>/<ALERT_AFTER_FAILURES> <checks>`, `PROBLEM <checks>`, `REMINDER <checks>` or `RECOVERED`, checks joined
  by `,`, with `; online check skipped (<why>)` appended when that applies. The line is appended with `>>`; the log
  is then trimmed to its last 1000 lines through `$LOG_FILE.tmp` and `mv`.

### Run structure

1. An `ERR` trap turns any unexpected failure at top level into the out-of-band alert
   `internal: unexpected error at line <n>`. Bash disables the trap inside functions called from an `if`, so every
   check handles its own commands' failures. Some failures skip the `ERR` trap (an unset variable under `set -u`, a
   bad arithmetic expression, a signal), so the `EXIT` trap, which also removes the run's temporary files, turns any
   non-zero exit that hasn't printed an email into the out-of-band alert `internal: script ended unexpectedly (exit
   <n>)`. DSM never gets a non-zero exit with an empty body.
2. Knobs are validated, and `jq`, `flock`, `timeout`, `cksum` and `curl` must be on `PATH`, else the out-of-band alert
   `internal: <tool> not found`. The API response file is created with `mktemp` in `TMPDIR` (no fallback), so an
   unusable `TMPDIR` is an internal error.
3. Lock: open `$STATE_FILE.lock` without truncating it (`exec 9<>`) and `flock -n` it, so hand runs with their own
   `STATE_FILE` never collide with the scheduled one; only once it holds the lock does a run replace the file's
   content with its `NOW`. If another run holds it and the stored time is over 900 seconds before `NOW`, out-of-band
   `lock: held for over 15 minutes by a run that has not finished`; if it holds it otherwise (an empty or unreadable
   time counts as recent), a note on stderr and exit 0 without logging. `flock` failing for another reason is
   `lock: flock failed (<status>)`. Failing to create, open or write the lock file is the out-of-band
   `storage: cannot write <lock file>`.
4. Read `.env`, run the checks, apply the incident logic. Write the log line, then the state. If the log can't be
   written, the state is left as it was, so no email decision is lost; the run becomes the out-of-band alert
   `storage: cannot write <file>`, listing the other failing checks too. The same if the state can't be written.

**Out-of-band alerts** (`internal`, `lock`, `storage`) have PROBLEM as their first line, aren't logged, and are sent at
most once per 24 hours per kind and `STATE_FILE`: a marker file `<kind>-<first field of cksum of the STATE_FILE
path>.marker` records the `NOW` it was written and the checks failing then (none, when the checks didn't run). Markers
live in a `runner-health-check` directory under `TMPDIR` when that is a writable directory, else under `/tmp`; the
script creates it mode 700 and uses it only if it is a real directory (not a symlink) owned by the running user; with
no usable directory, the alert is sent every run. While a marker is under 86400 seconds old, its kind stays silent
unless a check fails that the marker doesn't list. A run that writes log and state deletes its markers from both
places, without a RECOVERED email.

### The checks, in order

1. `settings`: one failure per invalid knob, `<KNOB> must be a whole number, got '<value>'`.
2. `configuration`, the first that applies; when it fails, checks 3-6 are skipped:
   - `.env not found in <RUNNER_DIR>`; `enterprise scope is not supported` (scope rule in the global constraints);
   - `REPO_URL is empty` (repository scope) or `ORG_NAME is empty` (organization scope);
   - `no credentials: set GITHUB_PAT, or APP_ID and APP_PRIVATE_KEY` unless `GITHUB_PAT` or `APP_PRIVATE_KEY` is set
     (the rule `init-runner.sh` uses).
3. `container_running`: `docker inspect --type container`; passes only when the status is `running` and the health is
   not `unhealthy` (a container in restart backoff reports Running true, so the status decides). Reasons:
   `docker did not answer within 20 s` (`timeout` exit 124 or 137), `container <name> not found`,
   `docker failed: <first stderr line>`, `container <name> is <status>`,
   `container <name> healthcheck reports unhealthy`.
4. `runner_online`: skipped, passing and logged, without `GITHUB_PAT` (`no GITHUB_PAT`) or, in repository scope only,
   when `REPO_URL` doesn't start with `https://github.com/` (`REPO_URL is not on github.com`). Otherwise it fetches
   `https://api.github.com/repos/<owner>/<repo>/actions/runners?per_page=100` (owner and repository from `REPO_URL`,
   without a trailing `/` or `.git`) or `https://api.github.com/orgs/<ORG_NAME>/actions/runners?per_page=100`; runners
   past the first 100 aren't looked at. The URL and token go to `curl` through `--config -` on stdin, never on a
   command line. Reasons: `GitHub API unreachable (curl exit <n>)`; `GitHub rejected GITHUB_PAT (HTTP <code>): expired,
   missing rights or rate-limited` for 401 and 403; `GitHub API returned 404: check REPO_URL or ORG_NAME`;
   `GitHub API returned HTTP <code>`; `unexpected API response` when the body isn't JSON with a `runners` array;
   `runner <name> is offline or not registered` unless a runner with exactly that name is `online`.
5. `no_new_restarts`: compares the container's ID and restart count with the state. A new ID (first run, recreated
   container) or a lower count with the same ID (Docker resets it on a manual start) sets a new baseline and passes. A
   count higher by n records n restarts at `NOW` and fails with `container restarted`. Restart times more than 21600
   seconds before `NOW` drop out (exactly 21600 is kept). If `docker` fails, the state is left alone and the check
   passes, since `container_running` reports it.
6. `disk_space`: the use percentage of `DISK_PATH` from `df -P`. `df failed for <DISK_PATH>`, or
   `<DISK_PATH> is <n>% full (limit <MAX>%)` above `MAX_DISK_PERCENT`.

**As built, after review:** run structure step 4 writes the new state to `$STATE_FILE.tmp` first, then the log line,
then moves the state into place, so a run whose state can't be saved logs nothing. HUP, INT and TERM have their own
trap, so a killed run still sends `internal: script ended unexpectedly (exit 143)`, exiting non-zero. Within its 24
hours a marker accumulates every check it has reported, and a storage alert lists only checks the incident logic would
report (none still in their grace). `FALLBACK_TMP` (default `/tmp`) is a test knob for the marker fallback.
`ALERT_AFTER_FAILURES=0` reads `ALERT_AFTER_FAILURES must be a whole number of at least 1, got '0'`.
`docs/04-monitoring.md`'s upgrade section still names `/volume1/scripts/runner-*.sh`, the copies to delete, so the grep
for them finds that section only. A `jq` missing from `PATH` is tested with a copy of the script whose appended `PATH`
points at a folder without `jq`, since CI's `/usr/bin` has one. The checks were verified against DSM 7.2's own tools:
bash 4.4, `jq` 1.5, util-linux `flock` and GNU coreutils.

### Incident logic

The restart window is active while 3 or more restart times are recorded.

- Failing run: `FAILURES += 1`. Not yet alerted: PROBLEM if `configuration` or `settings` failed, `FAILURES` reached
  `ALERT_AFTER_FAILURES`, or the restart window is active. Already alerted: PROBLEM again if a check fails that wasn't
  alerted yet; else REMINDER once `REMIND_AFTER_SECONDS` have passed since the last email; else silent. Each email
  records its `NOW` and adds the failing checks to the alerted set.
- Passing run: `FAILURES=0`. If alerted and the restart window is not active: RECOVERED, clearing the alert. While the
  window is active it stays alerted and silent, so a container restarting every 10-30 minutes isn't reported as
  recovered between restarts.
- A reboot keeps the runner offline for up to about 6 minutes, inside the default grace of 3 five-minute runs.

### Tests (`tests/monitoring/runner-health-check.test.sh`, helpers in `tests/monitoring/lib.sh`)

The harness gives every case a fresh `mktemp -d` as `RUNNER_DIR` with the default fixture `.env` (`REPO_URL`,
`GITHUB_PAT`, `RUNNER_NAME=synology-general-runner`), its own `STATE_FILE`, `LOG_FILE` and `TMPDIR`, and `NOW=1000`; it
adds 300 to `NOW` after each run unless a case sets `NOW`. Stubs for `docker`, `curl`, `df`, `jq`, `timeout` and `bc`
come first on `PATH`, log their arguments, and are steered by `FAKE_*` variables the harness clears between cases;
`jq` and `timeout` pass through to the real tools unless told to fail. By default the container is running and
healthy, the runner online, and `df` reports 1048576 1K-blocks with 104858 used (10%); the `bc` stub fails loudly. A
case that needs a broken `flock` puts its own stub first on `PATH`. Every `.env` is written with `printf`, so `$` stays
literal. After every run the harness asserts: nothing from a tool's stderr in stdout, `bc` never called, every `docker`
and `df` call made through `timeout -k 5 20`, every `curl` call with `--max-time 20`, only markers left in `TMPDIR`,
empty stdout on exit 0, and stdout starting `Runner health check (` on exit 1. Cases that rely on permissions print
`SKIP` as root. Each test file ends with `exit $failed`. Before committing, flip one expected exit code and see the file
fail.

Cases, as runs and their exit codes:

1. Healthy: exit 0, the log holding exactly `1970-01-01T00:16:40Z OK`.
2. Grace and silence: container exited, 4 runs → 0, 0, 1, 0; logs `FAIL 1/3 container_running`, `FAIL 2/3 ...`,
   `PROBLEM container_running`, `FAIL 4/3 ...`; the email is exactly the PROBLEM line,
   `- container_running: container github-runner is exited`, a blank line and `Next step: docker logs github-runner`.
3. Reminder: alerted at `NOW=1600` as in case 2; silent at `NOW=87999`, REMINDER at 88000, silent at 88300, REMINDER
   again at 174400. With `REMIND_AFTER_SECONDS=3600`, the reminder comes at 5200; with `0`, on every failing run.
4. Recovery: alerted, container back → exactly the RECOVERED line, log `RECOVERED`, then `OK`; a new failure gets the
   full grace again.
5. Recovering within the grace sends nothing.
6. Container states, each with `ALERT_AFTER_FAILURES=1`: health `unhealthy` alerts; Running `true` with status
   `restarting` alerts (`container github-runner is restarting`); health `starting` passes.
7. Runner offline, absent, only `synology-general-runner-2` online, or another runner online while ours is offline:
   each alerts on the third run with the offline reason.
8. API outcomes, one each with `ALERT_AFTER_FAILURES=1`, each with its exact reason from check 4: 401, 403, 404, 500,
   curl timeout (`curl exit 28`); `unexpected API response` for a 200 with an HTML body, `{}`, `[]` and
   `{"runners":"x"}`; `{"runners":[]}` is `offline or not registered`.
9. Request shape: curl's stdin holds
   `url = "https://api.github.com/repos/your-username/your-repo/actions/runners?per_page=100"` and
   `Authorization: Bearer ghp_xxx`, also for a `REPO_URL` ending in `.git/`, in `.git` and in `/`; org scope
   (`RUNNER_SCOPE=org` and `RUNNER_SCOPE=Organization`) holds
   `url = "https://api.github.com/orgs/your-org/actions/runners?per_page=100"`; the token never in curl's arguments.
10. Online check skipped without a PAT (`APP_ID=1` and `APP_PRIVATE_KEY=x` set), log `OK; online check skipped (no
    GITHUB_PAT)`, and for `REPO_URL=https://www.github.com/...`, log `OK; online check skipped (REPO_URL is not on
    github.com)`; curl never called. In org scope, a non-github.com `REPO_URL` doesn't skip.
11. Configuration, one case each: no `.env`, empty `REPO_URL`, org scope without `ORG_NAME`, `RUNNER_SCOPE=enterprise`,
    no credentials, `APP_ID` without `APP_PRIVATE_KEY`. Each alerts on the first run with exactly one reason and
    `Next step: edit`, calls no tool, stays silent on run 2, and reminds 86400 seconds after run 1. Passing:
    `RUNNER_SCOPE=repository` (repository scope); `APP_PRIVATE_KEY` without `APP_ID` or `GITHUB_PAT`.
12. Empty `RUNNER_SCOPE`, `CONTAINER_NAME` and `RUNNER_NAME` take their defaults (seen in the API URL, the docker
    arguments and the runner looked up); `CONTAINER_NAME=x` exported in the environment with none in `.env` is ignored.
13. `.env` parsing: each row of the table in the Interfaces, appended after the default lines, with `FAKE_API_JSON`
    listing only the expected runner name online (or curl's stdin checked for a token row), so any other parse fails
    the run; `ENV_VALUE_QUOTE` checked by sourcing the function alone in a subshell; `RUNNER_NAME` exported in the
    environment loses to `.env`.
14. Docker failures, one each: container missing, timeout, daemon error with its first stderr line.
15. Restarts, from a baseline at `NOW=1000`, with passing runs between them so the grace count never reaches 3:
    restarts at 1300, 2500 and 3700; the first two fail once each without alerting, the third alerts through the
    window; it stays alerted while the window holds and recovers once a restart is more than 21600 seconds old (on
    both sides of the boundary); a rise of 3 in one run alerts at once; a lower count resets the baseline without a
    restart; a docker failure leaves the state alone; a recreated container resets the baseline.
16. Disk: at the limit passes, one above alerts with `Next step: free space on <DISK_PATH>`, a failing `df` alerts.
17. A new failing check during an incident sends PROBLEM again; one already alerted that passes and fails again doesn't.
18. Next-step precedence, each pair failing together with `ALERT_AFTER_FAILURES=1`: `configuration` and `settings` →
    `edit`; `settings` and `disk_space` → `fix the environment variables`; `disk_space` and `container_running` →
    `docker logs`; `storage` and `disk_space` → `check free space and permissions`; `internal` and `lock` alerts →
    `run sudo bash`.
19. `CONTAINER_NAME=github-runner-b`: every docker call, the subject line and the next step use it.
20. Settings, each with `- settings:` and `Next step: fix the environment variables in the scheduled task`, running
    on with the default: `abc`, `08`, `-1` and an 11-digit number for each of the four knobs; `90%` for
    `MAX_DISK_PERCENT`; `1d` for `REMIND_AFTER_SECONDS`; `0` for `ALERT_AFTER_FAILURES`. Valid, no `settings` failure:
    `0` for the other three knobs, a 10-digit number, and an empty export (the default).
21. Storage (`SKIP` as root): after a first run has created the lock file, a read-only state directory alerts once with
    `Next step: check free space and permissions for <that directory>`, stays silent while the marker is under 86400
    seconds old, alerts again after, alerts at once for a newly failing check, and clears its marker once writable. A
    read-only log alone alerts too, and the state file is then unchanged. Two `STATE_FILE`s keep separate markers.
22. Lock: with no lock file yet and a read-only directory (`SKIP` as root) → `storage: cannot write <lock file>`; held
    with a recent time, an empty time, or a time later than `NOW` → silent, no log, state unchanged; held with a time
    901 seconds old → alert, 900 → silent; a `flock` stub exiting 127 → `lock: flock failed (127)`. Out-of-band
    alerts add no log line.
23. Internal error: `TMPDIR` pointing at a regular file makes the top-level `mktemp` fail → PROBLEM with
    `- internal: unexpected error at line`, then silent; the marker goes to `/tmp` (the case removes it), and the next
    run with a usable `TMPDIR` deletes it. A `jq` removed from `PATH` gives `internal: jq not found`. A copy of the
    script with an unset variable referenced at top level exits 1 with `internal: script ended unexpectedly (exit 1)`.
    The marker directory replaced by a symlink is not used, and the alert is sent every run.
24. Garbage state, including a `$(...)` line, restart times in the future and non-numbers: read as zero or dropped,
    never executed. State written by one run reads back identically in the next (`ALERTED_CHECKS` with two checks,
    `RESTART_TIMES` with three times).
25. Log trim: 999, 1000 and 1001 lines before a run leave 1000, 1000 and 1000, the oldest dropped.
26. A `PATH` holding only the stubs still finds the system tools.
27. Defaults, run from a copy of the script at `$RUNNER_DIR/scripts/monitoring/` with no path variables set: state and
    log land in `RUNNER_DIR`; `DISK_PATH` is `RUNNER_WORKDIR` when set, else `RUNNER_DATA_DIR`, else `DEFAULT_DATA_DIR`
    when it exists, else `RUNNER_DIR`, each seen in `df`'s arguments.

### CI (`.github/workflows/quality.yml`)

- Plan 7's "Run script tests" step picks up `tests/monitoring/` without a change. Directly after it: "Check
  read_env_value copies match", which finds every script
  defining it (`git grep -l '^read_env_value() {' -- scripts/`, so the installer is covered too),
  extracts each from that line to the first line that is exactly `}`, fails if fewer than two are found or any extract
  is empty, and fails if they differ; flip one character
  locally to see it fail. The order shared by the active plans, inserting only steps whose plan has landed:
  "Verify runner image starts the runner", "Verify the image check can fail" (8), "Check Dockerfile pins" (8),
  "Verify organization scope" (6), "Verify compose variables" (6), "Run script tests" (7) and the check above (2),
  "Check publish workflow permissions" (8).

### Docs and housekeeping (same task)

- `docs/04-monitoring.md`, rewritten as `# Monitoring`: DSM email set-up as the prerequisite; the Task Scheduler task
  (root, every 5 minutes, `bash <project folder>/scripts/monitoring/runner-health-check.sh`, email only on abnormal
  termination, one task per project); what PROBLEM, REMINDER and RECOVERED mean; what is checked and which `.env`
  values are read (`KEY=value` lines; inline comments after a space are fine); the knobs; that the online check needs
  `GITHUB_PAT` and the container healthcheck covers App credentials; running it by hand with
  `sudo env STATE_FILE=$(mktemp) LOG_FILE=$(mktemp) ALERT_AFTER_FAILURES=1 bash ...` (variables after `sudo env`, which
  otherwise drops them); the dashboard; upgrading from the old `/volume1/scripts` copy (point the task at the clone,
  remove crontab entries, delete the copies and `alerts.log`); checking the monitor is alive from the log's last line.
  The old copy, threshold, alias and `alerts.log` sections go.
- Every mention of `/volume1/scripts/runner-health-check.sh` or `runner-dashboard.sh` in `docs/`, `README.md` and
  `CLAUDE.md` (`git grep`) points at `<project folder>/scripts/monitoring/` instead, and afterwards
  `git grep -n '/volume1/scripts/runner-' -- README.md docs/ CLAUDE.md` finds nothing; the crontab block in
  `docs/06-maintenance.md` that runs `runner-health-check.sh` becomes a pointer to `docs/04-monitoring.md` (the
  `docker system prune` crontab stays). The `scp file.sh` privacy examples in
  `CLAUDE.md` stay.
- `README.md`: the architecture diagram shows `health-check.log` for `alerts.log`.
- `CLAUDE.md`: `tests/monitoring/` joins the tree.
- `.gitignore`: `health-check.state` and `health-check.state.lock` (`*.log` and `*.tmp` are already ignored);
  `git check-ignore health-check.state health-check.state.lock health-check.log health-check.state.tmp` lists all four.
- `changelog.md`: "Fixed" the health check emailing every run and stopping at its first failure; "Changed" what it
  checks, once-per-incident alerts with a daily reminder, running from the clone; "Removed" the CPU, memory and log
  checks and `alerts.log`.

## Task 2 · Dashboard that runs on DSM and in CI

**Interfaces:** consumes Task 1's harness, stubs, `RUNNER_DIR` rule and `read_env_value` (copied, not sourced). The
test helper `run_dashboard` runs it once without `--continuous` and without `TERM`.

**The change** to `scripts/monitoring/runner-dashboard.sh`:

- `PATH`, `RUNNER_DIR`, `.env` values, `DEFAULT_DATA_DIR`, `DISK_PATH`, `MAX_DISK_PERCENT` (invalid → 90), `NOW` and
  `LOG_FILE` as in Task 1.
  Every `docker` and `df` call is time-limited; a failing one shows `n/a` on its line instead of ending the script.
- `clear` may fail without a terminal; colors are printed whether or not there is one.
- `--continuous` redraws every `REFRESH_SECONDS` (default 10, the current interval; an invalid value uses 10).
- Docker unreachable: `Docker not reachable: <first error line>`, exit 1. Otherwise the container is found by exact
  name.
- CPU and memory compared with `awk`, never `bc`: CPU green below 100, yellow below 150, else red; memory green below
  70, yellow below 90, else red; a non-number shows `n/a`.
- Disk: `<DISK_PATH>: <used> GiB / <total> GiB (<n>%)`, sizes to one decimal, `<n>` being `df -P`'s use percentage as
  in the health check; green below `min(80, MAX_DISK_PERCENT)`, yellow up to `MAX_DISK_PERCENT`, red above.
- `Health:` replaces the "Listening for Jobs" log check: `healthy` green, `starting` yellow, `unhealthy` red, none
  `n/a`.
- `Health-check log:` replaces the `alerts.log` section: the last 5 lines of `LOG_FILE`, or `no health-check log yet`
  when it is missing or empty; the last line in red when its timestamp is more than 900 seconds before `NOW`, since the
  monitor itself may have stopped; a last line whose timestamp doesn't parse is shown uncolored.

**Tests** (`tests/monitoring/runner-dashboard.test.sh`), each reading only the line with the named label:

1. CPU colors at 99.99, 100, 149.99, 150; memory at 69.99, 70, 89.99, 90; `--` shows `n/a` uncolored.
2. Disk colors at 79, 80, 90, 91 by default; with `MAX_DISK_PERCENT=95`, 91 yellow and 96 red; with 70, 69 green, 70
   yellow, 71 red; with `abc`, 91 red. A failing `df` shows `n/a` and exits 0; the default stub numbers read
   `0.1 GiB / 1.0 GiB`; a `df` reporting 91% use for 50% of the blocks shows red (the use column decides).
3. Health colors; a failing inspect, or a failing `docker stats` (CPU and memory), shows `n/a` and exits 0.
4. Every run with Docker reachable exits 0, never calls `bc`, and makes every `docker` and `df` call through `timeout`.
5. No container, or only a near name, shows `❌ Not Running`; Docker unreachable exits 1 with the message.
6. `CONTAINER_NAME` from `.env` is the name every `inspect` and `stats` call uses.
7. The log section, with `NOW` set: missing, empty, one line, the last 5 of 6, a `LOG_FILE` elsewhere; a last line 901
   seconds old in red, 900 not; a malformed last line uncolored.
8. `--continuous` with `REFRESH_SECONDS=1` under `timeout 3` draws at least twice.

`docs/04-monitoring.md`'s dashboard section; `README.md`'s sample dashboard output with the new `Health:`, disk and
log lines; `changelog.md` ("Fixed": the dashboard failed on DSM and without a terminal; it reads the health-check log
and the container name from `.env`).

## Task 3 · End-to-end on a NAS (user-run)

After the pull request merges. The user runs or approves each step; step 3 stops the runner, step 5 reboots the NAS.

1. `git pull` in the project folder; the hand run from the docs exits 0 with no output.
2. The dashboard shows the container, CPU, memory, disk, health and log lines.
3. Create the scheduled task as documented and stop the container: one PROBLEM email within 20 minutes (possibly a
   second naming `runner_online` once GitHub marks the runner offline), then nothing for 20 minutes. The email body
   holds the reason lines and the next step, and no stray tool output.
4. Start it: one RECOVERED email within 10 minutes of the runner showing Idle.
5. Reboot the NAS: no email.
6. The hand run with `MAX_DISK_PERCENT=0` exits 1 naming `disk_space`.

Record the outcome in generic terms only ("one email per incident, none on reboot"): never names, addresses, paths,
container names, other services, the model or software versions from the NAS.

**As built:** one email per incident, none on reboot.

- Steps 1, 2 and 6 passed. The hand run and the dashboard ran through a `docker` wrapper calling `sudo docker`, as
  the account had sudo for Docker only.
- A first scheduled task pointed at a folder that didn't exist and emailed every run with status 127. The monitoring
  guide now says to use your own project folder and has a troubleshooting entry for it.
- Step 3: stopping the container gave `FAIL 1/3`, `FAIL 2/3`, then one PROBLEM email naming both `container_running`
  and `runner_online` (GitHub marked the runner offline within the grace period). The body held only the reason lines
  and the next step. The next four runs sent nothing.
- Step 4: one RECOVERED email at the first run after the runner showed Idle.
- Step 5: after a reboot the container restarted by itself with a restart count of 0. One run caught the runner
  before GitHub listed it online (`FAIL 1/3`), the next was `OK`, and no email was sent.
