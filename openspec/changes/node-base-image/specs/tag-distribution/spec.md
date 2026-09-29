## Purpose

Defines the tag scheme: which tags exist, when they move, how consumers pin an exact build by digest, and how Renovate tracks them.

## ADDED Requirements

### Requirement: Two rolling tags per entry

Every tag SHALL name a Node.js version and a variant; no bare version tag and no `latest` SHALL exist. For each entry built from upstream `<major>.<minor>.<patch>-<suffix>` (for example `24.21.0-alpine3.24` or `24.21.0-bookworm-slim`), the registry SHALL publish exactly two rolling tags: the full upstream tag and `<major>-<alpine|slim>`. Each SHALL have a `-dev` counterpart published by the same run.

#### Scenario: Alpine entry

- **WHEN** the entry from upstream `24.21.0-alpine3.24` is published
- **THEN** `24.21.0-alpine3.24` and `24-alpine` exist, and `24`, `latest`, `24.21-alpine3.24`, and `24-alpine3.24` do not

#### Scenario: Debian entry

- **WHEN** the entry from upstream `24.21.0-bookworm-slim` is published
- **THEN** `24.21.0-bookworm-slim` and `24-slim` exist

#### Scenario: Dev counterparts

- **WHEN** a run publishes `24-alpine`
- **THEN** the same run publishes `24-alpine-dev`

#### Scenario: Patch release

- **WHEN** `24.21.1-alpine3.24` replaces `24.21.0-alpine3.24` in the matrix
- **THEN** `24-alpine` moves to the new build and `24.21.0-alpine3.24` stays at its last digest

### Requirement: Exact reproduction by digest

The registry SHALL NOT publish immutable tags; exact reproduction SHALL rely on digests. Every publish SHALL record its tag-to-digest map in the run summary. Previous digests SHALL remain pullable after tags move.

#### Scenario: Weekly rebuild

- **WHEN** the schedule republishes `24.21.0-alpine3.24`
- **THEN** the tag points to the new digest and the previous digest still pulls by `@sha256:`

#### Scenario: Consumer pins by digest

- **WHEN** a Dockerfile references `24-alpine@sha256:<previous>` and Renovate runs with `pinDigests: true`
- **THEN** the build uses the previous image and Renovate proposes the new digest in a pull request

#### Scenario: Run summary

- **WHEN** a publish run completes
- **THEN** its summary lists every tag it pushed with the digest it points to

### Requirement: Renovate compatibility

Tags SHALL be parseable by the Renovate Dockerfile manager with default Docker versioning.

#### Scenario: Version update

- **WHEN** a consumer pins `24.21.0-alpine3.24` and `24.21.1-alpine3.24` is published
- **THEN** Renovate proposes `24.21.1-alpine3.24`

#### Scenario: Distro release change

- **WHEN** a consumer pins `24.21.0-alpine3.24` and `24.21.0-alpine3.25` is published
- **THEN** Renovate does not propose the Alpine change
