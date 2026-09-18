# CLAUDE.md

Guidance for AI agents working in this repository.

## What this repository is

The official SparkFabrik Node.js base image, published to the GitHub Container
Registry. It provides `-slim` and `-alpine` variants for each supported Node.js
LTS version, each in a minimal production flavor and a `-dev` flavor with a
development entrypoint that installs project dependencies at container start.

Current status: specification phase. No image code exists yet.

## Workflow

This project uses [OpenSpec](https://github.com/Fission-AI/OpenSpec) for
spec-driven development. The active change lives in
`openspec/changes/node-base-image/` (proposal, specs, design), to be created
with `/opsx:new`.

- Read the change artifacts before implementing anything.
- Use the `/opsx:*` commands to progress the change (`/opsx:continue`,
  `/opsx:apply`, `/opsx:verify`).
- Implementation must satisfy the behavior specs under
  `openspec/changes/node-base-image/specs/`.

## Conventions

- This is a public repository: never reference internal SparkFabrik projects,
  customers, or internal tracker paths in committed files or commit messages.
- Commits follow Conventional Commits with the mandatory `Assisted-by` trailer.
- The Dockerfile is single and parameterized by the `NODE_IMAGE_TAG` build
  argument; the CI matrix supplies the version list.
- Images follow the Docker Hardened Images philosophy (minimal runtime,
  unprivileged user by default, no shell or package manager in production tags,
  published SBOM and provenance) but build from official upstream Node.js
  images, not from `dhi/node`.
- Shell scripts that ship inside the image must be POSIX sh compatible (no
  bashisms): they run on both Debian slim and Alpine.
