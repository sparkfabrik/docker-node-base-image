# Design: Official SparkFabrik Node.js base image

## Context

See proposal.md for motivation. The originating request asks for:

- `FROM node:$TAG` with `-slim` and `-alpine` variants.
- An SBOM, vulnerability reporting, and zero vulnerabilities.
- A GitHub Actions publish pipeline and the dependency-installing dev entrypoint.
- Renovate compatibility and a DHI-inspired distribution model.

The team chose the DHI philosophy without `dhi/node` as base. Precedents are the PHP base image and the `http-proxy` publish workflow.

## Goals / Non-Goals

**Goals:**

- One Dockerfile for the whole matrix.
- Production without shell, package manager, or compiler, running as a non-root user.
- SBOM and provenance on every tag.
- Tags pinnable by line, version, or digest, all Renovate-updatable.
- Updates merged automatically on green.

**Non-Goals:**

- Third-party hardened bases.
- Application OS packages at runtime. A `-full` flavor is a possible later extension.
- Windows images and cosign signing.

## Decisions

### Image and Dockerfile

- The image is `ghcr.io/sparkfabrik/node`. The `org.opencontainers.image.source` label links it to this repository. Rejected: the repository name, too long for every `FROM`.
- One Dockerfile takes `ARG NODE_IMAGE_TAG`, an upstream tag such as `24.21.0-alpine3.24`. Stages are `prod` and `dev`; the CI matrix supplies the tag list. Rejected: per-version directories, and separate version and variant arguments.
- The `ARG` default tracks one entry: the Alpine variant of the newest active LTS line. The Renovate pull request for that line updates it.

### Production runtime

- `strip` starts from `node:${NODE_IMAGE_TAG}`. It creates a root-owned `/app`, removes npm, yarn, and corepack, upgrades OS packages, and on Debian adds `ca-certificates` and `netbase`. Its last command purges every package outside the allowlist.
- `clean` starts from upstream again and strips package metadata, docs except `copyright`, dangling symlinks, and the upstream entrypoint from `/rootfs`.
- `prod` is `FROM scratch` with `/rootfs` in one layer. It sets `WORKDIR /app` before `USER 1000:1000`, `NODE_ENV=production`, labels, and `CMD ["node"]`.
- Debian allowlist: `base-files base-passwd libc6 libgcc-s1 libstdc++6 gcc-N-base libgomp1 ca-certificates netbase tzdata`. Node.js 26 adds `libatomic1` in change `add-node-26`.
- Alpine allowlist: `musl libgcc libstdc++ libgomp ca-certificates-bundle alpine-baselayout-data tzdata`.
- The package database stays, so scanners see exactly the retained packages.
- A spike on Node 24 gave 132 MB on Alpine and 153 MB on Debian, with zero fixable CVEs. The first task tries `apk add --root --initdb` for Alpine instead of the purge.
- Rejected: `rm` without purge, because scanners then report ghost packages. Rejected: Node.js binaries on a bare distro, because the request asks for `node:$TAG`. Rejected: distroless, Debian only.

### Process model

- Production has no init process and no `ENTRYPOINT`. `node` is PID 1, and the application handles `SIGTERM`.
- Next.js standalone and NestJS with `enableShutdownHooks()` already handle it. Other applications add a handler or use `docker run --init`.
- Rejected: `dumb-init`, because it hides a missing handler instead of fixing the application.
- Both flavors run as numeric UID 1000, so Kubernetes verifies `runAsNonRoot` without `runAsUser`. Rejected: root by default with a `-rootless` opt-in.

### Dev flavor and entrypoint

- `dev` starts from the same upstream image and adds git, python3, and a C and C++ toolchain.
- It pins npm with `ARG NPM_VERSION` and installs corepack with npm from Node 25. `/app` belongs to UID 1000.
- The entrypoint contract lives in the `dev-entrypoint` spec. Skip wins over force because an opt-out must be reliable. Corepack is not a trigger because it manages the package manager, not the project.

### Tags

- The tag scheme lives in the `tag-distribution` spec: two rolling tags per entry, exact reproduction by digest.
- Rejected: `latest` and the `<node-version>-<ref|latest>` model. `latest` hides the Node.js line and the variant, so a consumer cannot tell what they run. A ref suffix would add a third tag family that digest pinning already covers.
- Rejected: dated build tags (unreadable), repository semver, and git SHA suffixes.
- One distro release per variant, the one upstream aliases. Launch lines are 22 and 24. Line 26 joins on 2026-10-28 through the separate change `add-node-26`, and a line leaves at upstream EOL.

### Vulnerabilities

- The request asks for zero vulnerabilities. The gate fails on any fixable finding and reports unfixable ones, because base-OS CVEs without an upstream fix cannot be closed here. This is a deliberate deviation.
- Trivy reports every finding to code scanning, which covers the request for vulnerability reporting.
- The `dev` flavor also upgrades OS packages and pins npm, since `npm@latest` would break "publish what you tested".

### CI

- Pull requests lint, build with `--load` on native amd64 and arm64 runners, test, and scan. Nothing is pushed.
- Main, the weekly schedule, and dispatch build once and push by digest. They test and scan that digest, then promote it with `imagetools create`.
- Provenance uses `mode=max` rather than `true`, so build arguments and materials are recorded.
- Publishes are serialized by a `concurrency` group. A weekly multi-arch aware job cleans untagged versions older than 7 days.
- Rejected: one QEMU build, which is slow and proves nothing about arm64. Rejected: rebuilding after tests, which publishes an untested image.

### Updates

- Renovate runs self-hosted through the SparkFabrik GitHub App (`renovatebot/github-action`, `actions/create-github-app-token`). An App identity lets bot pull requests run workflows unattended.
- Managers: `dockerfile` for the `ARG`, regex for the matrix and for distro bumps, the npm datasource for `NPM_VERSION`, and digest pinning for Actions.
- Rejected: the Mend App, which needs third-party write access. Rejected: Dependabot, which cannot resolve `FROM node:${ARG}`.

### Layout

`Dockerfile`, `entrypoint.sh`, `tests/` (POSIX sh), `examples/`, `.github/workflows/`, `renovate.json`, `justfile` (same recipes as CI), `README.md`, `CHANGELOG.md`.

## Risks / Trade-offs

- [Purge or allowlist drift breaks `node`] → contract test with `sharp` on every entry and architecture.
- [Unfixable Debian CVEs, or a fixable one with no upstream release] → gate on fixable only; time-boxed ignore entries.
- [Rolling tags move on rebuild] → `pinDigests` and the rebuild policy are documented.
- [Consumers needing OS packages or `npm run` in prod] → out of scope; migration documented.
