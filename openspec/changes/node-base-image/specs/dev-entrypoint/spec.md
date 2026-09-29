## Purpose

Defines the development entrypoint of `-dev` images: dependency installation at container start, so the images serve local development directly.

## ADDED Requirements

### Requirement: Installation trigger

The entrypoint SHALL install dependencies before the command when the first argument is `npm`, `yarn`, `pnpm`, or `npx`. It SHALL NOT install beforehand when the command is itself an install (`npm install`, `npm i`, `npm ci`, `yarn`, `yarn install`, `pnpm install`, `pnpm i`) or a query (`--version`, `-v`, `help`). Any other command SHALL run unchanged.

#### Scenario: Dev server command

- **WHEN** the command is `npm run dev` and a lockfile exists
- **THEN** dependencies are installed before `npm run dev` runs

#### Scenario: Plain node command

- **WHEN** the command is `node server.js`
- **THEN** no installation runs

#### Scenario: Corepack command

- **WHEN** the command is `corepack enable`
- **THEN** no installation runs

#### Scenario: Install command

- **WHEN** the command is `npm ci`
- **THEN** `npm ci` runs once and no preliminary installation runs

#### Scenario: Bare yarn

- **WHEN** the command is `yarn` with no arguments
- **THEN** yarn installs once and no preliminary installation runs

#### Scenario: Query command

- **WHEN** the command is `npm --version`
- **THEN** no installation runs

### Requirement: Exec hand-off

The entrypoint SHALL hand off with `exec`, so the command is PID 1.

#### Scenario: Command is PID 1

- **WHEN** the command is `node -p process.pid`
- **THEN** it prints `1`

### Requirement: Package manager detection

The entrypoint SHALL select npm for `package-lock.json`, yarn for `yarn.lock`, and pnpm for `pnpm-lock.yaml`. Yarn and pnpm SHALL run through corepack so `packageManager` is honored. Installation SHALL be frozen by default.

#### Scenario: npm project

- **WHEN** only `package-lock.json` exists
- **THEN** `npm ci` runs

#### Scenario: Yarn project

- **WHEN** only `yarn.lock` exists
- **THEN** yarn installs with its frozen-lockfile option

#### Scenario: pnpm project

- **WHEN** `pnpm-lock.yaml` exists and `packageManager` pins a pnpm version
- **THEN** that pnpm version installs in frozen mode

#### Scenario: No lockfile

- **WHEN** no recognized lockfile exists
- **THEN** a warning is printed, nothing is installed, and the command runs

### Requirement: Ambiguous project

The entrypoint SHALL exit 1 without starting the command when two or more lockfiles exist, or when `packageManager` names a different manager than the lockfile.

#### Scenario: Two lockfiles

- **WHEN** both `package-lock.json` and `yarn.lock` exist
- **THEN** the entrypoint prints an error and exits 1

#### Scenario: Manager mismatch

- **WHEN** `yarn.lock` exists and `package.json` declares `"packageManager": "pnpm@9.0.0"`
- **THEN** the entrypoint prints an error and exits 1

### Requirement: Installation failure

When installation fails, the entrypoint SHALL exit with the package manager's status and SHALL NOT start the command.

#### Scenario: Registry unreachable

- **WHEN** `npm ci` fails
- **THEN** the container exits non-zero and `npm run dev` never starts

### Requirement: Environment variable overrides

The entrypoint SHALL skip installation when `SKIP_DEPS_INSTALL=1`, and skip SHALL win over force. It SHALL install before any command when `FORCE_DEPS_INSTALL=1`. It SHALL run a regular install instead of a frozen one when `DEPS_INSTALL_MODE=update`.

#### Scenario: Skip

- **WHEN** `SKIP_DEPS_INSTALL=1` and the command is `npm run dev`
- **THEN** nothing is installed

#### Scenario: Skip wins over force

- **WHEN** both `SKIP_DEPS_INSTALL=1` and `FORCE_DEPS_INSTALL=1` are set
- **THEN** nothing is installed

#### Scenario: Force

- **WHEN** `FORCE_DEPS_INSTALL=1` and the command is `node server.js`
- **THEN** dependencies are installed first

#### Scenario: Update mode

- **WHEN** `DEPS_INSTALL_MODE=update`, `package.json` adds a dependency, and installation triggers
- **THEN** the install succeeds and the lockfile contains the new dependency

### Requirement: Foreign UID support

The entrypoint SHALL work under `--user` with any UID. It SHALL NOT change file ownership. Package manager and corepack caches SHALL live under `/tmp`.

#### Scenario: Bind mount owned by another user

- **WHEN** the container runs as `--user 1234:1234` on a project owned by that UID
- **THEN** installation succeeds and installed files belong to UID 1234

#### Scenario: Ownership unchanged

- **WHEN** installation runs on a bind-mounted project
- **THEN** files that existed before keep their owner

#### Scenario: Cache location

- **WHEN** installation runs
- **THEN** no file is written under the user's home directory and caches appear under `/tmp`

### Requirement: Shell portability

The entrypoint SHALL be POSIX sh with identical behavior on Debian slim and Alpine.

#### Scenario: Shellcheck

- **WHEN** `shellcheck -s sh` runs on the entrypoint
- **THEN** it reports no findings

#### Scenario: Same behavior on both variants

- **WHEN** the entrypoint test suite runs on the Debian and the Alpine `-dev` images
- **THEN** every scenario passes on both
