# Implementation History

This repository started as the self-hosted runner setup for a Kotlin Multiplatform project and was extracted into a
generic guide. The original setup went through preparation, Docker setup, runner installation, workflow migration,
security hardening, and resource and concurrency tuning. These are the lessons from it that shaped the guide.

## Lessons Learned

### Size build tools to the container, not the dev machine

The first CI runs hit out-of-memory errors because Gradle used the heap configured for local development.
CI now sets its own limits in the workflow environment, and local `gradle.properties` stays tuned for the dev machine:

```yaml
env:
  GRADLE_OPTS: "-Xmx3g -XX:MaxMetaspaceSize=512m"
  ORG_GRADLE_PROJECT_org.gradle.workers.max: "2"
```

Rule of thumb: give the JVM about 60% of the container's memory limit.

### Run memory-heavy jobs one after another

Two Gradle jobs in parallel need more memory than a typical NAS container limit allows.
Chain them with `needs:` so they run sequentially; see [Workflows Guide](../docs/08-workflows.md).

### Only top-level workflows get concurrency groups

When an orchestrator workflow and the reusable workflows it calls share a concurrency group, GitHub cancels the run
with "deadlock detected for concurrency group".
Put `concurrency:` on top-level workflows only, never on `workflow_call` workflows, and use
`cancel-in-progress: false` to queue jobs instead of cancelling them.

### Hardening has limits when the runner builds containers

`no-new-privileges`, `cap_drop: ALL` with selective `cap_add`, and `tmpfs` mounts all work.
Restricting network access to the GitHub API does not: the runner needs the Docker socket and dependency downloads.
See [Security Guide](../docs/07-security.md).

### Recreating the container strands in-progress jobs

Applying new container settings interrupts running jobs, which then hang in GitHub until cancelled
(`gh run cancel` or the Actions UI).
