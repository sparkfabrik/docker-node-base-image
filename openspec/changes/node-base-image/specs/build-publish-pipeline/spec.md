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
