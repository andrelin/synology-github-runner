#!/usr/bin/env python3
"""Checks that Renovate will keep the Dockerfile's pins current.

Usage: scripts/ci/check-renovate-manager.py [renovate.json] [Dockerfile]

The regex custom manager for the Dockerfile must match exactly once, for anthropic on
pypi at the version the Dockerfile installs, and one package rule must hold docker and
pypi updates for 7 days (timestamp-optional, so digest updates without a release time
still arrive).
"""

import json
import re
import sys


def fail(message):
    print(f"❌ {message}")
    sys.exit(1)


def main(config_path=".github/renovate.json", dockerfile_path="Dockerfile"):
    with open(config_path, encoding="utf-8") as handle:
        config = json.load(handle)
    with open(dockerfile_path, encoding="utf-8") as handle:
        dockerfile = handle.read()

    installed = re.search(r"anthropic==(\S+)", dockerfile)
    if not installed:
        fail("the Dockerfile does not pin anthropic to an exact version")

    managers = [
        manager for manager in config.get("customManagers", [])
        if manager.get("customType") == "regex"
        and any("Dockerfile" in pattern for pattern in manager.get("managerFilePatterns", []))
    ]
    if len(managers) != 1:
        fail(f"expected one regex manager for the Dockerfile, found {len(managers)}")

    matches = []
    for pattern in managers[0]["matchStrings"]:
        # Renovate's named groups (?<name>...) are Python's (?P<name>...)
        python_pattern = re.sub(r"\(\?<([A-Za-z]+)>", r"(?P<\1>", pattern)
        matches += [match.groupdict() for match in re.finditer(python_pattern, dockerfile)]
    expected = {"datasource": "pypi", "depName": "anthropic", "currentValue": installed.group(1)}
    if matches != [expected]:
        fail(f"the manager matches {matches}, expected [{expected}]")

    rules = [
        rule for rule in config.get("packageRules", [])
        if set(rule.get("matchDatasources", [])) >= {"docker", "pypi"}
        and rule.get("minimumReleaseAge") == "7 days"
        and rule.get("minimumReleaseAgeBehaviour") == "timestamp-optional"
    ]
    if len(rules) != 1:
        fail(f"expected one package rule holding docker and pypi for 7 days, found {len(rules)}")

    print(f"✓ Renovate tracks anthropic {installed.group(1)} and holds image updates for 7 days")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
