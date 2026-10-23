# Monitoring

## Overview

A health check, run every 5 minutes by DSM Task Scheduler, emails you once when the runner stops being able to take
jobs, a daily reminder while it stays broken, and once when it recovers. Otherwise it is silent. A dashboard script
shows the runner's state on demand.

Both scripts run from the project folder, the clone of this repository that Container Manager uses
(`/volume1/docker/synology-github-runner` in the [Installation Guide](02-installation.md)), so `git pull` updates
them too. They read the runner's settings from that folder's `.env`.

## Prerequisites

- The runner installed as a Container Manager project from a clone of this repository
- DSM email notifications: **Control Panel → Notification → Email**, with SMTP settings and a recipient, and a test
  email that arrives

## Schedule the Health Check

In DSM, open **Control Panel → Task Scheduler → Create → Scheduled Task → User-defined script**:

- **General:** task name `GitHub Runner Health Check`, user `root` (Docker needs it), enabled
- **Schedule:** daily, every 5 minutes, from 00:00 to 23:55
- **Task Settings:**
  - **Send run details by email:** checked, with your address
  - **Send run details only when the script terminates abnormally:** checked
  - **User-defined script:**

    ```bash
    bash /volume1/docker/synology-github-runner/scripts/monitoring/runner-health-check.sh
    ```

Use your own project folder's path if it isn't `/volume1/docker/synology-github-runner`. With several runner
projects on one NAS, create one task per project, each running the script in its own clone.

> **💡 Tip:** The script exits non-zero only when it wants an email, so "terminates abnormally" means "there is news".

## What the Emails Mean

The subject is DSM's; the body's first line is `Runner health check (github-runner): <kind>`, the kind being one of:

- **PROBLEM:** a check has failed, listed as `- <check>: <reason>`, followed by a `Next step:` line. Container and
  GitHub problems get a grace of 3 runs (about 15 minutes), so a NAS reboot sends nothing. A broken configuration, a
  bad setting or repeated restarts alert at once. A check that starts failing during an incident sends PROBLEM again.
- **REMINDER:** the same problem, still there a day after the last email.
- **RECOVERED:** everything passes again. While the container keeps restarting (3 or more restarts in 6 hours), it
  stays silent rather than reporting a recovery between restarts.

Problems with the monitor itself (`internal`, `lock`, `storage`) arrive as PROBLEM once a day each, sooner if another
check starts failing, with a next step such as running the script by hand. If the script can't keep a marker in
`TMPDIR` or `/tmp`, they arrive on every run.

Example:

```text
Runner health check (github-runner): PROBLEM
- container_running: container github-runner is exited

Next step: docker logs github-runner
```

## What Is Checked

| Check | Fails when |
| --- | --- |
| `settings` | A knob below isn't a whole number |
| `configuration` | `.env` is missing, the scope is enterprise (unsupported), `REPO_URL` (or `ORG_NAME` for organization scope) is empty, or there are no credentials |
| `container_running` | The container is missing, not running (restarting counts), or its healthcheck reports unhealthy |
| `runner_online` | GitHub doesn't list the runner as online, or rejects the token |
| `no_new_restarts` | The container restarted since the last run |
| `disk_space` | The workspace's file system is more than `MAX_DISK_PERCENT` full |

From `.env` it reads `REPO_URL`, `GITHUB_PAT`, `APP_ID`, `APP_PRIVATE_KEY`, `RUNNER_NAME`, `RUNNER_SCOPE`, `ORG_NAME`,
`CONTAINER_NAME`, `RUNNER_WORKDIR` and `RUNNER_DATA_DIR`, as `KEY=value` lines (quotes and inline comments after a
space are fine). It never takes these from the environment.

The online check needs `GITHUB_PAT`: with GitHub App credentials it is skipped, and the container's own healthcheck
covers a runner that stopped. The token is sent to GitHub's API with `curl` and never appears on a command line.

## Knobs

Set these as environment variables in the scheduled task's script line, for example
`MAX_DISK_PERCENT=85 bash .../runner-health-check.sh`:

| Variable | Default | Meaning |
| --- | --- | --- |
| `MAX_DISK_PERCENT` | 90 | Disk use above which `disk_space` fails |
| `ALERT_AFTER_FAILURES` | 3 | Failing runs before PROBLEM |
| `REMIND_AFTER_SECONDS` | 86400 | Time between reminders (0 reminds on every failing run) |
| `DISK_PATH` | `RUNNER_WORKDIR`, else `RUNNER_DATA_DIR`, else `/volume1/docker/github-runner` if it exists, else the project folder | The path whose file system is checked |
| `STATE_FILE` | `<project folder>/health-check.state` | What the script remembers between runs |
| `LOG_FILE` | `<project folder>/health-check.log` | One line per run, the last 1000 kept |

## Run It by Hand

To see what the scheduled task would report, without touching its state:

```bash
cd /volume1/docker/synology-github-runner
state=$(mktemp) log=$(mktemp)
sudo env STATE_FILE="$state" LOG_FILE="$log" ALERT_AFTER_FAILURES=1 \
  bash scripts/monitoring/runner-health-check.sh
echo "exit $?"   # 0 and no output: healthy
sudo rm -f "$state" "$state.lock" "$log"
```

Put the variables after `sudo env`: `sudo` drops variables set in front of it. Don't run it by hand without
`STATE_FILE`: a hand run records any email it prints, and the scheduled task then stays silent about it.

## Is the Monitor Alive?

The log's last line is at most 5 minutes old while the task runs:

```bash
tail -n 3 /volume1/docker/synology-github-runner/health-check.log
```

```text
2026-01-29T12:55:00Z OK
2026-01-29T13:00:00Z FAIL 1/3 container_running
2026-01-29T13:05:00Z OK
```

## Dashboard

```bash
cd /volume1/docker/synology-github-runner
sudo bash scripts/monitoring/runner-dashboard.sh               # once
sudo bash scripts/monitoring/runner-dashboard.sh --continuous  # every 10 seconds; Ctrl+C stops
```

It shows the container's status, restarts, health, CPU and memory, the disk use of the workspace's file system, and
the last 5 lines of the health-check log, the last one in red when it is more than 15 minutes old (the monitor may have
stopped). `REFRESH_SECONDS` sets the `--continuous` interval.

## Upgrading From the Old Scripts

Earlier versions copied the scripts to `/volume1/scripts` and logged alerts to `alerts.log`:

1. Point the scheduled task at the clone's script, as above, with the email settings above.
2. Remove any crontab entry that runs `/volume1/scripts/runner-health-check.sh`.
3. Delete `/volume1/scripts/runner-health-check.sh`, `/volume1/scripts/runner-dashboard.sh`,
   `/volume1/docker/github-runner/alerts.log` and `/volume1/docker/github-runner/health-check.log`; the new log lives in
   the project folder.

## Troubleshooting

**An email every 5 minutes:** the task runs an old copy of the script; point it at the clone.

**`No such file or directory` every 5 minutes:** the task's script line names a folder that doesn't exist; use your
project folder's path (`ls /volume1/docker/*/scripts/monitoring/runner-health-check.sh` lists the candidates).

**No email when the runner is down:** check the task's email settings and DSM's test email, then run the script by
hand as above: it should exit 1 and print the problem.

**`internal: jq not found` (or `flock`, `timeout`, `cksum`, `curl`):** the tool is missing from the task's `PATH` and
from `/usr/local/bin`, `/usr/bin` and `/bin`, where the script also looks. DSM 7.2 ships all of them; check that
`command -v jq` finds it over SSH.

**`lock: held for over 15 minutes`:** a run hangs; `ps aux | grep runner-health-check` shows it.

**`storage: cannot write ...`:** the project folder is full or not writable by root; the email names the folder.
