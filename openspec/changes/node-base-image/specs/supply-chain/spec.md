## Purpose

Defines the supply chain guarantees: SBOM, provenance, vulnerability posture, freshness, and automated updates.

## ADDED Requirements

### Requirement: SBOM attestation

Every tag SHALL carry, per architecture, an SPDX SBOM attached as an attestation manifest. The SBOM SHALL list `node` at the matrix version and every OS package in the image.

#### Scenario: Node.js in the SBOM

- **WHEN** a consumer reads the SBOM of `24.21.0-alpine3.24` with `docker buildx imagetools inspect <tag> --format '{{json (index .SBOM "linux/amd64").SPDX}}'`
- **THEN** it contains package `node` at version `24.21.0`

#### Scenario: OS packages in the SBOM

- **WHEN** the SBOM package list is compared with the image package database
- **THEN** every OS package appears in both

### Requirement: Provenance attestation

Every tag SHALL carry, per architecture, a SLSA provenance attestation naming the repository, the commit, and the workflow run.

#### Scenario: Provenance retrieval

- **WHEN** a consumer runs `docker buildx imagetools inspect <tag> --format '{{json (index .Provenance "linux/amd64").SLSA}}'`
- **THEN** the provenance names this repository, the build commit, and the run

### Requirement: Vulnerability scanning gate

Every image of both flavors SHALL be scanned on pull requests and before promotion. Any fixable finding SHALL fail the entry. Every finding SHALL be reported to code scanning.

#### Scenario: Fixable finding

- **WHEN** the scanner reports a fixable vulnerability in either flavor
- **THEN** the entry is not published

#### Scenario: Scan on pull request

- **WHEN** an update pull request introduces a fixable vulnerability
- **THEN** the pull request check fails before merge

#### Scenario: Unfixable only

- **WHEN** only unfixable findings are reported
- **THEN** publication proceeds and the findings appear in code scanning

### Requirement: Time-boxed ignore entries

A fixable finding MAY be ignored only by an entry naming the vulnerability, an expiry date, and a reference. An entry missing a field or past its expiry SHALL fail the scan.

#### Scenario: Valid entry

- **WHEN** an entry names the vulnerability, a future expiry, and a reference
- **THEN** the finding does not fail the scan

#### Scenario: Incomplete entry

- **WHEN** an entry lacks an expiry date
- **THEN** the scan fails

#### Scenario: Expired entry

- **WHEN** an entry has expired and the finding persists
- **THEN** the scan fails

### Requirement: Scheduled rebuilds

Every entry SHALL be rebuilt at least weekly from the latest upstream digest, then tested, scanned, and republished.

#### Scenario: Upstream fix

- **WHEN** upstream rebuilds with an OS package fix
- **THEN** the next scheduled run publishes images containing it

### Requirement: Update pull requests

The SparkFabrik GitHub App SHALL author all update pull requests, so the pipeline runs on them without manual approval. Upstream `node` bumps SHALL come as one pull request per Node.js line, covering its matrix entries and, for the line that holds it, the Dockerfile default. Distro release changes, the `-dev` npm version, and GitHub Actions SHALL come as separate pull requests.

#### Scenario: Upstream patch release

- **WHEN** upstream publishes `24.21.1-alpine3.24` and `24.21.1-bookworm-slim`
- **THEN** one pull request updates both line 24 entries and the Dockerfile default

#### Scenario: Pipeline runs unattended

- **WHEN** the App opens an update pull request
- **THEN** lint, build, test, and scan run without a maintainer approving the workflow

#### Scenario: Alpine release bump

- **WHEN** upstream publishes `24.21.0-alpine3.25`
- **THEN** a separate pull request proposes it

#### Scenario: npm release

- **WHEN** npm publishes a new version
- **THEN** a pull request updates `NPM_VERSION`

#### Scenario: Action release

- **WHEN** a pinned GitHub Action publishes a new version
- **THEN** a pull request updates its digest

### Requirement: Automerge policy

Node.js version, npm, and GitHub Actions updates SHALL merge automatically when every required check passes. A failed check SHALL leave the pull request open. Distro release changes SHALL NOT merge automatically.

#### Scenario: Green update

- **WHEN** a Node.js version update passes every check
- **THEN** it merges without human action and the publish runs

#### Scenario: Red update

- **WHEN** an update fails the scan gate
- **THEN** it stays open with the failing check visible

#### Scenario: Distro change

- **WHEN** a distro release pull request passes every check
- **THEN** it stays open until a maintainer merges it
