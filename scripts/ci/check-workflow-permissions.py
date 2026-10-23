#!/usr/bin/env python3
"""Checks the least-privilege rules for this repository's image workflows.

Usage: scripts/ci/check-workflow-permissions.py <workflow.yml>...

Every file: no schedule, pull_request_target or workflow_run trigger, top-level
permissions exactly `contents: read`, and every `uses:` pinned to a commit SHA.
A file named publish-image.yml (or a fixture copied from it, under tests/ci/fixtures/)
also needs: no permissions on the `test` job, the `publish` job's exact `if`, and
exactly its four permissions. Exits 1 on the first failed rule, printing its name.
"""

import re
import sys

import yaml

FORBIDDEN_TRIGGERS = ("schedule", "pull_request_target", "workflow_run")
PUBLISH_IF = (
    "github.repository == 'andrelin/synology-github-runner' && github.event_name == 'push' && "
    "(github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v'))"
)
PUBLISH_PERMISSIONS = {
    "contents": "read",
    "packages": "write",
    "id-token": "write",
    "attestations": "write",
}
PINNED = re.compile(r"^[^@\s]+@[0-9a-f]{40}$")


def fail(rule, detail):
    print(f"rule {rule} failed: {detail}")
    sys.exit(1)


def uses_values(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "uses" and isinstance(value, str):
                yield value
            else:
                yield from uses_values(value)
    elif isinstance(node, list):
        for item in node:
            yield from uses_values(item)


def squash(text):
    return re.sub(r"\s+", " ", str(text)).strip()


def check(path):
    with open(path, encoding="utf-8") as handle:
        workflow = yaml.safe_load(handle)

    # YAML 1.1 reads the `on:` key as True
    triggers = workflow.get("on", workflow.get(True)) or {}
    if isinstance(triggers, str):
        triggers = {triggers: None}
    elif isinstance(triggers, list):
        triggers = {name: None for name in triggers}
    for trigger in FORBIDDEN_TRIGGERS:
        if trigger in triggers:
            fail("forbidden-trigger", f"{path} is triggered by {trigger}")

    if workflow.get("permissions") != {"contents": "read"}:
        fail("top-level-permissions", f"{path} has top-level permissions {workflow.get('permissions')!r}")

    for uses in uses_values(workflow.get("jobs", {})):
        if not uses.startswith("./") and not PINNED.match(uses):
            fail("pinned-actions", f"{path} uses {uses} without a commit SHA")

    name = path.rsplit("/", 1)[-1]
    if name == "publish-image.yml" or "/tests/ci/fixtures/" in f"/{path}":
        jobs = workflow.get("jobs", {})
        if "permissions" in jobs.get("test", {}):
            fail("test-job-permissions", f"{path}: the test job sets its own permissions")
        publish = jobs.get("publish", {})
        if squash(publish.get("if", "")) != PUBLISH_IF:
            fail("publish-if", f"{path}: the publish job's if is {publish.get('if')!r}")
        if publish.get("permissions") != PUBLISH_PERMISSIONS:
            fail("publish-permissions", f"{path}: the publish job's permissions are {publish.get('permissions')!r}")


def main(paths):
    if not paths:
        print(__doc__)
        return 2
    for path in paths:
        check(path)
        print(f"✓ {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
