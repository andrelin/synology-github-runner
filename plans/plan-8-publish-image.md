# Plan 8: Publish the Runner Image to GHCR - plan

**Status:** 🔴 Not Started
**Goal:** Users run a tested, published `ghcr.io/andrelin/synology-github-runner` image instead of building on their
NAS, and the published image stays current without anyone touching it.
**Approach:** A workflow on GitHub-hosted runners builds and tests the image on every change, pull requests included,
in a read-only job. A separate publish job, the only one that can write to the registry and run only for `main` and
release tags of this repository, pushes the image by digest with no tag, re-runs the start-up check against that
digest, attests it, and only then points the tags at it. The Dockerfile pins its base image by digest and `anthropic`
by version, so updates arrive as Renovate pull requests that CI tests and Renovate automerges after a waiting period.
Once the package is public, `docker-compose.yaml` switches from `build:` to the published image.
**Order:** third of the active plans, which land as 7, 2, 8, 6; Task 4 rewrites text Plan 7 added, and Plan 6, which
comes after, writes its docs for the published image from the start.

## Decisions

- **Architecture:** `linux/amd64` only; the docs support only Intel and AMD models, and workflows use the `X64` label.
- **Tags:** pushes to `main` publish `sha-<7-character commit>` and `latest`; a release tag `vX.Y.Z` (digits only, no
  pre-release suffix) publishes `X.Y.Z`, `X.Y` and `X`, and leaves `latest` alone. Every tag points at a digest that
  passed the start-up check. No scheduled rebuilds: updates come through Renovate merges, and published tags never
  change content.
- **Updates:** Renovate keeps automerging digest, patch and minor updates, but only after a 7-day minimum release age
  for the `docker` and `pypi` datasources, timestamp-optional so digest updates without a release time aren't held
  forever. An accepted risk, stated in `docs/07-security.md`. `anthropic`'s own dependencies stay unpinned; re-checking
  the pushed digest covers drift between the test and publish builds.
- **Provenance:** build provenance attestations, verifiable with `gh attestation verify`.
- **On the NAS:** it keeps the image it last pulled; pulling a newer one is a documented manual step.

## Out of scope

- Updating the image on the NAS automatically.
- Local builds through Container Manager: `docker-compose.build.yaml` is for the command line and forks.
- A first release tag. Until one exists, the docs offer only `latest` and `sha-` tags; the first release exercises the
  semver tags.
- Permission blocks for `security.yml` and `weekly-link-check.yml`.

## Global constraints

- This repository's CI stays on GitHub-hosted runners.
- Actions pinned by commit SHA with the version in a comment, as in the existing workflows.
- Least privilege: `publish-image.yml` and `quality.yml` set top-level `permissions: contents: read`; the `publish`
  job's own `permissions` are exactly `contents: read`, `packages: write`, `id-token: write` and `attestations: write`.
- `quality.yml`'s step "Verify runner image starts the runner" and its image tag `runner-under-test` keep their names:
  Plans 2 and 6 anchor on them. New steps go in the order Plan 2 lists.
- Existing installations keep working at every merge: Task 4 merges only after Task 3 has made the package public.
- Nothing personal in tracked files; `ghcr.io/andrelin/synology-github-runner` is this repository's own name.
- Changelog entries under `## [Unreleased]`, merged into an existing heading of the same type and date.
- Find lines in files other plans also edit by their text, never by line number.

## Implementation status

| Task | Status |
| --- | --- |
| 1 · Test and publish workflow | ⏳ PENDING |
| 2 · Pinned Dockerfile and Renovate delay | ⏳ PENDING |
| 3 · First publish (user-run) | ⏳ PENDING |
| 4 · Compose uses the published image | ⏳ PENDING |
| 5 · NAS switch-over (user-run) | ⏳ PENDING |

## File map

| File | 1 | 2 | 4 |
| --- | --- | --- | --- |
| `.github/workflows/publish-image.yml` | create | | |
| `.github/workflows/quality.yml` | modify | modify | modify |
| `scripts/ci/verify-image.sh`, `scripts/ci/check-workflow-permissions.py`, `tests/ci/fixtures/*.yml` | create | | |
| `scripts/ci/check-renovate-manager.py` | | create | |
| `Dockerfile`, `.github/renovate.json`, `docs/07-security.md` | | modify | |
| `docker-compose.yaml`, `.env.example`, `docker-compose.build.yaml` (new), `tests/compose/fixtures/` | | | modify |
| `README.md`, `contributing.md`, `docs/00-quick-start.md`, `docs/01-prerequisites.md` | | | modify |
| `docs/02-installation.md`, `docs/03-configuration.md` | | | modify |
| `docs/06-maintenance.md`, `docs/07-security.md`, `docs/faq.md`, `docs/restart-reliability-fix.md` | | | modify |
| `scripts/setup/install.sh` | | | modify |
| `CLAUDE.md` (repository tree) | modify | modify | modify |
| `changelog.md` | modify | modify | modify |

## Task 1 · Test and publish workflow

**Interfaces:** `scripts/ci/verify-image.sh <image-ref>` runs the image for at most `VERIFY_TIMEOUT` seconds (default
120) with `DEBUG_ONLY=true`, no startup delay, `RUNNER_WORKDIR=/tmp`, a placeholder `REPO_URL` and
`ACCESS_TOKEN=unused`, removes the container whatever happens, prints its output, and exits 0 only if the container
exited 0 and printed `Running ./bin/Runner.Listener run`. `quality.yml`'s "Verify runner image starts the runner"
builds `runner-under-test` and calls it.

**`quality.yml`:**

- Top-level `permissions: contents: read`.
- "Verify the image check can fail": three images built from `runner-under-test`: one that prints nothing and exits 0,
  one that prints the marker and exits 1, and one that sleeps forever (checked with `VERIFY_TIMEOUT=5`). The script
  must fail on all three, and no container may be left behind.
- "Check publish workflow permissions": `scripts/ci/check-workflow-permissions.py <file>...` (PyYAML, preinstalled on
  `ubuntu-latest`; the `on:` key parses as `True`) exits 1 on the first failed rule:
  - for every file: no `schedule`, `pull_request_target` or `workflow_run` trigger; top-level `permissions` exactly
    `contents: read`; every `uses:` pinned to a 40-character SHA;
  - for `publish-image.yml` only: the `test` job has no `permissions` of its own; the `publish` job's `if` is exactly
    `github.repository == 'andrelin/synology-github-runner' && github.event_name == 'push' && (github.ref ==
    'refs/heads/main' || startsWith(github.ref, 'refs/tags/v'))` (whitespace aside) and its permissions exactly the
    four in the global constraints.
  Each failure prints `rule <name> failed`. The step runs it on both workflows (expect 0), then on the fixtures in
  `tests/ci/fixtures/`, each a copy of `publish-image.yml` breaking one rule (expect exit 1 and that rule's name):
  one per forbidden trigger, top-level permissions with one extra and with `contents: read` missing, `permissions` on
  `test`, a changed `if`, publish permissions with one extra and one missing, and one unpinned `uses:`.

**`publish-image.yml`** (`name: Publish Image`):

- Triggers: `push` to `main` and `pull_request`, both for changes to `Dockerfile`, `scripts/init-runner.sh`,
  `scripts/entrypoint-wrapper.sh`, `scripts/ci/verify-image.sh` or the workflow itself; `push` of tags matching
  `v[0-9]+.[0-9]+.[0-9]+`; `workflow_dispatch` (which runs `test` only, since `publish` requires a push).
- Job `test` (30-minute limit): build with Buildx for `linux/amd64`, loaded locally as `candidate`, with the GitHub
  Actions cache; then `scripts/ci/verify-image.sh candidate`.
- Job `publish` (`needs: test`, 30-minute limit, the `if` and permissions above), with its own concurrency group
  `publish-image-${{ github.ref }}` and `cancel-in-progress: false`, so a newer `main` push may replace a pending
  `main` publish but nothing replaces a pending tag publish:
  1. Log in to `ghcr.io` with `GITHUB_TOKEN`.
  2. `docker/metadata-action` with `flavor: latest=false` and the tag rules from "Decisions" (`sha` and `latest` only
     on the default branch; three `semver` patterns), plus the OCI labels for source, description (`Self-hosted GitHub
     Actions runner image for Synology NAS`) and license (`MIT`). Then compute the expected tags from `github.ref` and
     `github.sha` alone (on `main`: `sha-<first 7>` and `latest`; on `refs/tags/vX.Y.Z`: `X.Y.Z`, `X.Y`, `X`), and fail
     unless metadata-action's tags, as full `ghcr.io/andrelin/synology-github-runner:<tag>` references, are exactly
     those. Then fail if `sha-<first 7>` or `X.Y.Z` already exists in the registry, so a re-run never changes what a
     published tag points at. On `main`, drop `latest` from the tags when `github.sha` is no longer the head of `main`
     (`git ls-remote origin refs/heads/main`), so an older run finishing late can't move `latest` back.
  3. Push by digest only (`push-by-digest=true`, `name-canonical=true`), with the labels and the cache.
  4. `scripts/ci/verify-image.sh ghcr.io/andrelin/synology-github-runner@<digest>`.
  5. `actions/attest-build-provenance` for that digest, pushed to the registry.
  6. `docker buildx imagetools create` with one `-t` per tag, from that digest.
  7. Each tag resolves to the pushed digest (compare without quotes); fail otherwise.
- `CLAUDE.md`: `scripts/ci/`, `tests/ci/` and the workflow in the tree. `changelog.md`: "Added": the image is built,
  tested and published to GHCR.

**Tests:** both new `quality.yml` steps run on every pull request that `quality.yml` doesn't skip; the `test` job runs
on the pull request that adds the workflow; after merge, the publish job's checks in steps 2 and 7 verify the result
on `main`.

## Task 2 · Pinned Dockerfile and Renovate delay

**The change:**

- `FROM myoung34/github-runner:latest@sha256:<digest>`, the multi-architecture index digest (the form Renovate's
  docker manager updates).
- `anthropic==<current version>` in the `pip3 install` line, directly under
  `# renovate: datasource=pypi depName=anthropic`.
- `.github/renovate.json`: a regex custom manager for `Dockerfile` that reads that comment and the version on the next
  line, and a package rule giving `docker` and `pypi` `minimumReleaseAge: "7 days"` with
  `minimumReleaseAgeBehaviour: "timestamp-optional"`.
- `docs/07-security.md`, "Image updates": what is pinned, that Renovate updates and automerges after 7 days once CI
  passes, that this trades review for a runner nobody maintains, that `anthropic`'s dependencies aren't pinned, and how
  to check a pulled image's provenance with `gh attestation verify`.
- `CLAUDE.md`: `scripts/ci/check-renovate-manager.py` in the tree. `changelog.md`: "Changed": the base image and
  `anthropic` are pinned and updated by Renovate.

**Tests** ("Check Dockerfile pins" in `quality.yml`):

1. The `FROM` line carries a `sha256` digest and `anthropic` an exact version.
2. `scripts/ci/check-renovate-manager.py` applies the manager's regex to `Dockerfile` (named groups translated to
   Python's) and requires exactly one match, for `anthropic` on `pypi` with the Dockerfile's version, and one package
   rule covering both datasources with `minimumReleaseAge` `7 days` and `minimumReleaseAgeBehaviour`
   `timestamp-optional`.
3. `renovate-config-validator` from `renovate@<exact version>` (the version current at implementation time, written
   into the step) accepts the config (it rejects a misspelled option); the custom manager uses the file-pattern key
   that version documents.

The `test` job of `publish-image.yml` builds and verifies the pinned image on this pull request.

## Task 3 · First publish (user-run)

After Tasks 1-2 merge and the first publish on `main` succeeds. The user changes the package settings; an agent may
only prepare commands.

1. Make the package public (Profile → Packages → `synology-github-runner` → Package settings → Change visibility).
2. `DOCKER_CONFIG=$(mktemp -d) docker pull ghcr.io/andrelin/synology-github-runner:latest` succeeds without credentials.
3. `gh attestation verify oci://ghcr.io/andrelin/synology-github-runner:latest --repo andrelin/synology-github-runner`
   succeeds.
4. Within two weeks, the Renovate dashboard lists the base image and `anthropic`; an update waiting on release age is
   expected.

Task 4 merges only after steps 1-3 pass.

## Task 4 · Compose uses the published image

A separate pull request, opened after Task 3.

- `docker-compose.yaml`: `image: ghcr.io/andrelin/synology-github-runner:${RUNNER_IMAGE_TAG:-latest}` replaces the
  `build:` block and the local image name.
- `.env.example`: a commented `# RUNNER_IMAGE_TAG=latest`: `latest` follows `main`, a `sha-` tag pins one build, and
  release versions have no `v` once releases exist.
- `docker-compose.build.yaml`: builds from the clone as `synology-github-runner:local`, used with
  `docker compose -f docker-compose.yaml -f docker-compose.build.yaml up -d --build`; `contributing.md` documents it
  for local changes and forks.
- Docs: every place that describes building the image describes pulling it. Find them with
  `git grep -n -i -E 'build|rebuild' -- README.md docs/` and change those about the runner image (not Gradle or job
  builds): `README.md`, `docs/00-quick-start.md`, `docs/02-installation.md`, `docs/03-configuration.md`,
  `docs/06-maintenance.md`, `docs/07-security.md`, `docs/faq.md`, `docs/restart-reliability-fix.md`. The "Project Build
  Fails" troubleshooting becomes "Image Pull Fails" (no network, or the package not public). The update procedure
  becomes `git pull`, then `sudo docker compose pull && sudo docker compose up -d` in the project folder while the
  runner is idle, saying plainly that the NAS keeps its last pulled image until then. `docs/01-prerequisites.md`'s
  internet-access list adds `ghcr.io`.
- Text Plan 7 added: the installer's next step "to update, `git pull` and rebuild the project" becomes "to update,
  `git pull`, then pull the image as `docs/06-maintenance.md` describes".
- `CLAUDE.md`: `docker-compose.build.yaml` in the tree. `changelog.md`: "Changed": the image is pulled from GHCR;
  forks that change the `Dockerfile` must use `docker-compose.build.yaml`, or they run the published image.

**Tests** (in `quality.yml`'s "Validate docker-compose.yaml" step, with `RUNNER_IMAGE_TAG` unset first, using Plan 6's
`tests/compose/fixtures/defaults.env.fixture` and new `<name>.env.fixture` files beside it):

1. Defaults: the image is `ghcr.io/andrelin/synology-github-runner:latest` and there is no `build` key.
2. `image-tag.env.fixture` (`RUNNER_IMAGE_TAG=1.2.0`) gives `:1.2.0`; `image-tag-empty.env.fixture` gives `:latest`.
3. With `docker-compose.build.yaml` added: the build context is the checkout and the image
   `synology-github-runner:local`.
4. In `README.md`, `docs/`, `.env.example` and `scripts/setup/install.sh`, `git grep -n -i -E` finds none of
   `same local image tag`, `git pull.? and rebuild`, `rebuild the project`, `Build in Container Manager` and
   `up -d --build` (`contributing.md`, which documents the build overlay, isn't searched).

## Task 5 · NAS switch-over (user-run)

After Task 4 merges, on a NAS running the runner as a Container Manager project from a clone, while the runner is idle.
The user runs or approves each step, for each runner project on the NAS.

1. `git pull`, then the documented pull and `up -d` in the project folder.
2. `sudo docker inspect -f '{{.Config.Image}}' <CONTAINER_NAME>` shows the published image, and the runner is Idle.
3. If a Container Manager project action pulls a newer image, add its menu path to `docs/06-maintenance.md` in a
   follow-up pull request.
4. Once every project is switched, remove the old local `synology-github-runner:latest` image.

Record outcomes in generic terms only: never names other than this repository's, addresses, paths, container names,
other services, the model or software versions from the NAS.
