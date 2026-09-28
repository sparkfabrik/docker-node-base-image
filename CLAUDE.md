# CLAUDE.md

SparkFabrik Node.js base image, published as `ghcr.io/sparkfabrik/node`
(`-slim` and `-alpine` per Node.js LTS, each with a production and a `-dev`
flavor).

Public repository: never mention internal SparkFabrik projects, customers, or
internal tracker paths in committed files or commit messages.

## Workflow

- Spec-driven with [OpenSpec](https://github.com/Fission-AI/OpenSpec): read
  `openspec/changes/node-base-image/` first; progress it with `/opsx:continue`,
  `/opsx:apply`, `/opsx:verify`.
- Commit with the `sf-commit-convention` skill; no issue references.

## Commands

- Entrypoint tests: `IMAGE_TAG=<dev image:tag> ./tests/entrypoint_test.sh`
- Example smoke tests: `./tests/examples_test.sh` (build the examples first)
- Dockerfile lint: `hadolint Dockerfile`
