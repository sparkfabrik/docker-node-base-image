## Purpose

Defines the pipeline that lints, builds, tests, scans, and publishes the matrix to the GitHub Container Registry.

## ADDED Requirements

### Requirement: Single version matrix

Every built, tested, and published tag SHALL derive from one declared list of upstream `node` tags.

#### Scenario: Entry appended to the list

- **WHEN** a tag is appended to the list
- **THEN** lint, build, test, scan, and publish run for both flavors of that entry without other edits

### Requirement: Lint before build

Hadolint and shellcheck SHALL run before any build, and a lint failure SHALL stop the run.

#### Scenario: Lint failure

- **WHEN** hadolint reports a violation
- **THEN** no image is built in that run

### Requirement: Test and scan gates

Contract, entrypoint, example, and vulnerability scan checks SHALL run for every entry, flavor, and architecture. No entry with a failing check SHALL be published.

#### Scenario: Test failure

- **WHEN** a contract test fails for one entry on one architecture
- **THEN** no tag of that entry is published in that run

### Requirement: Negative control

The contract test suite SHALL run against the upstream `node` image of each entry and SHALL fail there.

#### Scenario: Upstream image fails the suite

- **WHEN** the production contract suite runs against `node:24.21.0-alpine3.24`
- **THEN** it reports at least the shell and package manager checks as failed

#### Scenario: Suite passes on upstream

- **WHEN** the contract suite passes against the upstream image
- **THEN** the pipeline fails, because the suite no longer detects hardening

### Requirement: Pinned scanner

The vulnerability scanner version SHALL be pinned and its database cached between runs.

#### Scenario: Scanner version

- **WHEN** the publish workflow is inspected
- **THEN** the scanner is referenced by an exact version, not `latest`

### Requirement: Example integration tests

The NestJS and Next.js examples SHALL build from the local images of the newest LTS entry of each variant and pass their smoke tests on both architectures. A failure SHALL block a pull request. On the default branch, a failure SHALL open an issue and SHALL NOT block publication.

#### Scenario: Example subset

- **WHEN** the pipeline runs with lines 22 and 24 in the matrix
- **THEN** examples build only on the line 24 Alpine and Debian images

#### Scenario: Example failure on a pull request

- **WHEN** the Next.js smoke test fails on a pull request
- **THEN** the pull request check fails

#### Scenario: Example failure on the default branch

- **WHEN** the NestJS build fails on the weekly rebuild because the npm registry is unreachable
- **THEN** the images are still published and an issue reports the failure

### Requirement: Pull request checks

Pull requests SHALL run every check with the publish policy, without registry credentials and without pushing.

#### Scenario: Pull request run

- **WHEN** the pipeline runs for a pull request
- **THEN** images are built, tested, and scanned, and nothing is pushed

### Requirement: Published image is the tested image

Promoted manifests SHALL be the digests that passed tests and scan in the same run. They SHALL be built once with attestations and pushed by digest before testing.

#### Scenario: Digest identity

- **WHEN** an entry is promoted
- **THEN** the digests behind its tags equal the digests tested in that run and already carry SBOM and provenance

#### Scenario: Digest mismatch

- **WHEN** a digest about to be tagged differs from every digest tested in the run
- **THEN** promotion fails and no tag moves

### Requirement: Native multi-arch publication

`linux/amd64` and `linux/arm64` SHALL build on native runners and push by digest. The digests SHALL merge into manifest lists that keep the attestation manifests of each architecture.

#### Scenario: Manifest list

- **WHEN** a publish completes
- **THEN** each tag lists both architectures and `imagetools inspect` returns SBOM and provenance per platform

### Requirement: Publish triggers and serialization

Publication SHALL run on default-branch pushes, a weekly schedule, and manual dispatch, one run at a time. A run SHALL NOT move a rolling tag after a later run completed.

#### Scenario: Overlapping triggers

- **WHEN** a push and the schedule start within minutes
- **THEN** the second waits for the first and rolling tags end on the later run's digests

### Requirement: Registry hygiene

A weekly job SHALL delete untagged package versions older than 7 days. It SHALL NOT delete a manifest referenced by a tagged index. It SHALL NOT run concurrently with a publish.

#### Scenario: Orphan cleanup

- **WHEN** the cleanup runs after a failed publish left orphan digests
- **THEN** the orphans are deleted and every tag still pulls on both architectures

#### Scenario: Dry run before activation

- **WHEN** the cleanup is first configured
- **THEN** it runs in dry-run mode against a test package and lists what it would delete, without deleting

#### Scenario: Cleanup during a publish

- **WHEN** the cleanup is scheduled while a publish runs
- **THEN** the cleanup waits until the publish completes

### Requirement: Least-privilege tokens

The publish job SHALL use the workflow token with `contents: read`, `packages: write`, and `security-events: write`, and no stored registry credential. The cleanup job SHALL request no permission beyond what package deletion needs.

#### Scenario: Publish permissions

- **WHEN** the publish workflow is inspected
- **THEN** it declares exactly `contents: read`, `packages: write`, and `security-events: write`

#### Scenario: Cleanup permissions

- **WHEN** the cleanup workflow is inspected
- **THEN** it declares no `contents: write`, `security-events`, or `id-token` permission

### Requirement: Releases

A release SHALL be created only by merging the release pull request that `release-please` maintains. The release SHALL create a git tag, a GitHub release, and the matching `CHANGELOG.md` entry. Commits typed `chore(deps)` SHALL NOT appear in the changelog.

#### Scenario: Release pull request

- **WHEN** a `feat` or `fix` commit lands on the default branch
- **THEN** the release pull request updates its proposed version and changelog, and no release is created yet

#### Scenario: Release on merge

- **WHEN** a maintainer merges the release pull request
- **THEN** a git tag and a GitHub release are created with the changelog entry

#### Scenario: Dependency chores

- **WHEN** Renovate merges a `chore(deps)` update
- **THEN** the release pull request changelog does not list it
