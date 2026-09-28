# Tasks

## 1. Production image

- [ ] 1.1 Spike the Alpine assembly with `apk add --root /rootfs --initdb` for the allowlist, compare with the purge approach on size, Trivy package list, and runtime check; record the winner in the "Production runtime" section of design.md and verify `openspec validate --strict` passes
- [ ] 1.2 Write `Dockerfile` stages `strip`, `clean`, `prod` for Debian slim and Alpine from `ARG NODE_IMAGE_TAG` (OS upgrade, `ca-certificates` and `netbase` on Debian, allowlist purge or assembly, maintainer script removal, dangling symlink cleanup, root-owned `/app`, `WORKDIR` before `USER 1000:1000`, `NODE_ENV=production`, OCI labels, `CMD ["node"]`, no `ENTRYPOINT`) and verify `docker build --target prod` succeeds for `24-alpine` and `24-slim`
- [ ] 1.3 Write `tests/image_verify.sh` (POSIX sh) covering the `image-variants` production scenarios: runtime script (file, DNS, TLS, timezone), no shell or package manager executable and no dangling symlink to one, `/app` read-only for UID 1000, UID 1000 default, REPL as PID 1 with no command, `NODE_ENV`, OCI labels, package database detected by Trivy with only retained packages; verify it passes on both variants locally
- [ ] 1.4 Add the `sharp` prebuilt fixture to `tests/` and verify `image_verify.sh` loads it and processes an image on both variants
- [ ] 1.5 Update `.hadolint.yaml` for the new stages (drop the stale DL3066 comment) and verify `hadolint Dockerfile` passes

## 2. Development image and entrypoint

- [ ] 2.1 Write the `dev` stage (git, python3, C and C++ toolchain, `npm install -g npm@${NPM_VERSION}` with `ARG NPM_VERSION`, corepack installed with npm when the upstream image lacks it, corepack shims in `/usr/local/bin`, `/app` owned by 1000, entrypoint, OCI labels) and verify `docker build --target dev` succeeds for `24-alpine` and `24-slim`
- [ ] 2.2 Update `entrypoint.sh` to the `dev-entrypoint` spec: `corepack` removed from triggers, install subcommands and aliases (`npm i`, bare `yarn`, `pnpm i`) and queries excluded, error on two lockfiles or `packageManager` mismatch, caches under `/tmp`; verify `shellcheck -s sh entrypoint.sh` passes
- [ ] 2.3 Extend `tests/entrypoint_test.sh` with the new scenarios (corepack command, explicit `npm ci`, two lockfiles, `packageManager` mismatch, install failure exit status, skip and force together, `--user 1234:1234` on a bind mount) and verify it passes on both `-dev` variants
- [ ] 2.4 Add the `better-sqlite3` fixture and verify `entrypoint_test.sh` compiles it inside both `-dev` variants without extra packages

## 3. Local tooling and examples

- [ ] 3.1 Write `justfile` recipes `build`, `test`, `scan`, `build-examples`, `test-examples`, `lint` that take `NODE_IMAGE_TAG` and tag local images as `sparkfabrik/node:<tag>` and `<tag>-dev`; verify `just lint build test` runs end to end for `24-alpine`
- [ ] 3.2 Switch `examples/nextjs/Dockerfile` from `--chown=node:node` to `--chown=1000:1000` and verify `just build-examples test-examples` passes with `tests/examples_test.sh`

## 4. Publish pipeline

- [ ] 4.1 Write `.github/workflows/publish.yml` with the matrix (lines 22 and 24, both variants) as one env list surfaced through a job output, and a `lint` job (hadolint, shellcheck); verify the workflow parses with `actionlint`
- [ ] 4.2 Add the pull request path: native amd64 and arm64 runners, `--load` build of both flavors, `image_verify.sh`, `entrypoint_test.sh`, `examples_test.sh`, Trivy scan failing on any fixable finding with SARIF upload; verify a draft pull request runs green without registry credentials
- [ ] 4.3 Add the default-branch, weekly schedule, and dispatch path: build once per flavor and architecture with `provenance: mode=max`, `sbom: true`, `push-by-digest=true`, then pull each digest and run tests and scan on it; verify the run summary shows the tested digests
- [ ] 4.4 Add promotion with `docker buildx imagetools create` into `<full tag>` and `<major>-<variant>` for both flavors, write the tag-to-digest mapping to the run summary, and set the `concurrency` group with `cancel-in-progress: false` and job permissions `contents: read`, `packages: write`, `security-events: write`; verify `imagetools inspect` on a published tag lists both platforms with SBOM and provenance
- [ ] 4.5 Add the SBOM assertion to the publish path (the SBOM of each pushed digest lists package `node` at the matrix version) and verify it fails on a digest whose SBOM lacks it
- [ ] 4.6 Add `.trivyignore.yaml` support with `expired_at` and a check that fails the scan on an expired entry; verify with a fixture entry dated in the past
- [ ] 4.7 Add the weekly registry cleanup job with a multi-arch aware action deleting untagged versions older than 7 days, in the same concurrency group with the minimal permissions its README requires; verify after a run that every published tag still pulls on both architectures

## 5. Automated updates

- [ ] 5.1 Install the SparkFabrik GitHub App on the repository, confirm it grants Contents, Pull requests, Checks, Commit statuses, Workflows write and Metadata read, and verify the App id and private key are stored as repository secrets
- [ ] 5.2 Write `renovate.json`: `dockerfile` manager for `ARG NODE_IMAGE_TAG`, regex `customManagers` for the workflow matrix with `datasourceTemplate: docker`, `depNameTemplate: node`, `versioningTemplate: docker`, a second regex manager with `loose` versioning for distro bumps without automerge, npm datasource for `NPM_VERSION`, GitHub Actions digest pinning, `packageRules` grouping per Node.js major with `automerge: true`; verify with `renovate-config-validator`
- [ ] 5.3 Write `.github/workflows/renovate.yml` running `renovatebot/github-action` on a schedule with a token from `actions/create-github-app-token`; verify a dry run (`RENOVATE_DRY_RUN=full`) lists the expected dependencies
- [ ] 5.4 Configure branch protection on the default branch requiring the lint, test, and scan checks, and verify an update pull request opened by the App runs the pipeline without manual approval and merges on green

## 6. Documentation

- [ ] 6.1 Write `README.md` in the `man` style: image name and tags, variants, what prod contains and excludes, consumer patterns (multi-stage on `-dev`, `CMD` exec form, `SIGTERM` handler with reference to nodejs/docker-node BestPractices, `docker run --init`, `.next/cache` chown, Prisma 6 and `libssl`), digest pinning with Renovate `pinDigests`, debugging without a shell, rebuild policy, out-of-scope consumers; verify every command in the README runs as written against a local build
- [ ] 6.2 Write `CHANGELOG.md` (Keep a Changelog 1.1.0) with an `Unreleased` section listing the initial lines and tag scheme, and verify the format with a markdown lint pass
- [ ] 6.3 Update `CLAUDE.md` commands section to the `just` recipes and verify each listed command exists in the `justfile`

## 7. Matrix lifecycle

- [ ] 7.1 Document in the README how a line is retired at upstream EOL (remove its matrix entries, keep existing tags), and verify the steps against line 22's EOL date 2027-04-30

## 8. Integration

- [ ] 8.1 Run the first publish from the default branch and verify, for every tag of the matrix: manifest list with `linux/amd64` and `linux/arm64`, SBOM and provenance readable with `imagetools inspect`, `node` version in the SBOM, run summary with the tag-to-digest mapping
- [ ] 8.2 Build both examples from the published `ghcr.io/sparkfabrik/node` tags and verify `examples_test.sh` passes against them
- [ ] 8.3 Trigger the weekly schedule by dispatch and verify the rolling tags move, the previous digests stay pullable, and `docker pull ghcr.io/sparkfabrik/node:24-alpine@sha256:<previous>` succeeds
