# Plan 1: Repository Integration

**Status:** 🟢 Complete

## Summary

Made the repository's `docker-compose.yaml` match a working Synology Container Manager configuration, so it can be
cloned and used as a Container Manager Project as-is.

- Synology-compatible syntax (`mem_limit`, `memswap_limit`, `cpu_shares`)
- Absolute volume paths under `/volume1/docker/github-runner/`
- Security hardening (`no-new-privileges`, minimal capabilities, `tmpfs`)
- Secrets and per-installation values moved to `.env` (gitignored), with `.env.example` as the template
- Resource limits configurable through `.env`

Setup steps live in the [Installation Guide](../../docs/02-INSTALLATION.md).
