## Purpose

Defines the published variant matrix, what each flavor contains and excludes, and the runtime posture consumers build on.

## ADDED Requirements

### Requirement: Image name

Images SHALL be published as `ghcr.io/sparkfabrik/node`, with the `org.opencontainers.image.source` label pointing to this repository.

#### Scenario: Consumer reference

- **WHEN** a consumer writes `FROM ghcr.io/sparkfabrik/node:24-alpine`
- **THEN** the pull resolves to the production Alpine image of the current Node.js 24 entry

### Requirement: Variant matrix

For every supported Node.js line the registry SHALL publish one Debian slim and one Alpine variant, each in a production and a `-dev` flavor. The distro release SHALL be the one upstream aliases as `<major>-slim` and `<major>-alpine`; other upstream releases SHALL NOT be published. Supported lines SHALL be the active and maintenance LTS lines.

#### Scenario: Four images per line

- **WHEN** line 24 is in the matrix
- **THEN** production and `-dev` images exist for both `24-slim` and `24-alpine`

#### Scenario: Alternative upstream release

- **WHEN** upstream publishes `24-alpine3.24` and `24-alpine3.23`, aliasing `24-alpine` to `alpine3.24`
- **THEN** no `alpine3.23` tag is published for line 24

#### Scenario: Current line

- **WHEN** a Node.js line is Current and not yet LTS
- **THEN** no tag is published for it

#### Scenario: Line reaches upstream EOL

- **WHEN** a line passes its upstream EOL date
- **THEN** no new builds are published for it and existing tags stay unchanged

### Requirement: Production flavor contents

The production flavor SHALL contain the Node.js runtime, its shared libraries, the OpenMP runtime, CA certificates, timezone data, and the OS package database. OS packages SHALL be at the latest version available at build time. The flavor SHALL NOT contain a shell, a package manager, `npm`, `yarn`, `pnpm`, `corepack`, a compiler toolchain, or the development entrypoint.

#### Scenario: No shell or package manager

- **WHEN** the filesystem is inspected
- **THEN** no `sh`, `bash`, `apt`, `apk`, `npm`, `yarn`, `pnpm`, or `corepack` executable exists and no dangling symlink points to one

#### Scenario: No toolchain or dev entrypoint

- **WHEN** the filesystem is inspected
- **THEN** no `gcc`, `make`, `python3`, or `docker-entrypoint.sh` exists

#### Scenario: Runtime works

- **WHEN** a script reads a file, resolves DNS, opens TLS, and formats a date in a named timezone
- **THEN** it completes successfully

#### Scenario: Prebuilt native module loads

- **WHEN** a script requires the `sharp` prebuilt module and resizes an image
- **THEN** it completes successfully

#### Scenario: OpenMP runtime present

- **WHEN** the package database is read
- **THEN** it lists `libgomp1` on Debian or `libgomp` on Alpine

#### Scenario: Package database matches the filesystem

- **WHEN** a vulnerability scanner analyzes the image
- **THEN** it detects the distribution and lists only packages whose files are present

#### Scenario: Fixable OS vulnerability upstream

- **WHEN** the upstream image carries an OS package with a fix available in the distribution
- **THEN** the production image contains the fixed version

### Requirement: Development flavor contents

The `-dev` flavor SHALL contain a POSIX shell, the system package manager, git, `npm`, `yarn` and `pnpm` through corepack, a toolchain that compiles common native modules, and the development entrypoint.

#### Scenario: Tools present

- **WHEN** `sh -c 'command -v git npm corepack yarn pnpm'` runs in the `-dev` image
- **THEN** every command resolves

#### Scenario: Native module compiles

- **WHEN** a project depending on `better-sqlite3` installs inside the `-dev` image
- **THEN** compilation succeeds without additional packages

#### Scenario: Consumer installs OS packages

- **WHEN** a consumer Dockerfile on a `-dev` tag declares `USER root` and installs a package
- **THEN** the installation succeeds

#### Scenario: Build utility for a non-Node project

- **WHEN** a PHP project Dockerfile uses a `-dev` tag as a stage, runs `npm ci && npm run build`, and copies the output into its own image
- **THEN** the assets build without installing Node.js in the PHP image

### Requirement: Non-root by default

Every image SHALL run as UID 1000, GID 1000, declared numerically.

#### Scenario: Kubernetes runAsNonRoot

- **WHEN** a pod sets `runAsNonRoot: true` without `runAsUser`
- **THEN** the kubelet admits the container and the process runs as UID 1000

### Requirement: Working directory

The working directory SHALL be `/app`. It SHALL be writable by UID 1000 in `-dev` and root-owned and read-only in production.

#### Scenario: Dev working directory

- **WHEN** the default user writes to `/app` in a `-dev` container
- **THEN** the write succeeds

#### Scenario: Production working directory

- **WHEN** the default user writes to `/app` in a production container
- **THEN** the write fails with a permission error

### Requirement: Production process contract

Production SHALL set `NODE_ENV=production` and `CMD ["node"]` in exec form. It SHALL define no `ENTRYPOINT`, no init process, and no `HEALTHCHECK`. The container command SHALL be PID 1 and own signal handling.

#### Scenario: Environment

- **WHEN** `node -p process.env.NODE_ENV` runs in a production container
- **THEN** it prints `production`

#### Scenario: No command

- **WHEN** a container starts without a command
- **THEN** the Node.js REPL is PID 1

#### Scenario: Consumer command

- **WHEN** a consumer image declares `CMD ["node", "dist/main.js"]`
- **THEN** `node dist/main.js` is PID 1 with unchanged arguments

#### Scenario: Image configuration

- **WHEN** the image configuration is inspected
- **THEN** `Entrypoint` and `Healthcheck` are empty

#### Scenario: Application handles SIGTERM

- **WHEN** a script with a `SIGTERM` handler receives `docker stop`
- **THEN** the container exits before the kill timeout with the handler's exit status

#### Scenario: Shell-form command

- **WHEN** a consumer declares `CMD node server.js`
- **THEN** the container fails to start because no shell exists

### Requirement: Consumer documentation

The README SHALL state that the application must handle `SIGTERM`, link nodejs/docker-node docs/BestPractices.md, and name `docker run --init` as the alternative.

#### Scenario: README section

- **WHEN** a consumer reads the README
- **THEN** it finds the `SIGTERM` obligation, the upstream link, and `docker run --init`

### Requirement: OCI image metadata

Every image SHALL carry `org.opencontainers.image.source`, `version`, `revision`, `created`, `licenses`, and `description`.

#### Scenario: Labels present

- **WHEN** a consumer inspects a published tag
- **THEN** all six labels are set

#### Scenario: Version label

- **WHEN** an image is built after release `v1.2.0`
- **THEN** `org.opencontainers.image.version` is `1.2.0`

#### Scenario: Rebuild without release

- **WHEN** the weekly rebuild runs with no new release since `v1.2.0`
- **THEN** `org.opencontainers.image.version` stays `1.2.0` and `revision` names the build commit

#### Scenario: Source and revision

- **WHEN** a consumer reads `source` and `revision`
- **THEN** they point to this repository and to the build commit

### Requirement: Multi-architecture

Every tag SHALL be a manifest list with `linux/amd64` and `linux/arm64`.

#### Scenario: Pull on arm64

- **WHEN** a consumer pulls on an arm64 host
- **THEN** the native image is selected without emulation
