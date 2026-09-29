# Proposal: Official SparkFabrik Node.js base image

## Why

SparkFabrik projects each maintain their own Node.js Dockerfiles, duplicating base setup, entrypoints, and security posture. The company ships an official PHP base image; this change creates the Node.js equivalent, built and hardened in-house so the supply chain stays under SparkFabrik control.

## What Changes

- Public repository `sparkfabrik/docker-node-base-image`, image `ghcr.io/sparkfabrik/node`.
- One parameterized Dockerfile: Debian slim and Alpine per supported LTS line, from the official `node` images.
- DHI philosophy without `dhi/node`: minimal runtime, non-root, no shell or package manager in production, SBOM and provenance published.
- Production and `-dev` flavors; `-dev` adds package managers, the native toolchain, and an entrypoint that installs dependencies at start from the lockfile.
- Tags: rolling per line and variant, immutability by digest.
- GitHub Actions: native multi-arch, push by digest, attestations, scan gate, weekly rebuild. Modeled on `sparkfabrik/http-proxy`.
- Renovate through a SparkFabrik GitHub App, automerge on green.

## Capabilities

### New Capabilities

- `image-variants`: matrix, flavor contents, non-root posture.
- `dev-entrypoint`: dependency installation at start, detection, overrides.
- `tag-distribution`: tag scheme, digest pinning, Renovate tracking.
- `build-publish-pipeline`: lint, test, scan, multi-arch publish to GHCR.
- `supply-chain`: attestations, vulnerability gate, rebuilds, automated updates.

### Modified Capabilities

None. Greenfield repository.

## Impact

- New content: Dockerfile, entrypoint, workflows, Renovate config, tests, examples, docs.
- Consumers replace per-project Node.js Dockerfiles; PHP projects use the image to build frontend assets.
- Dependencies: official `node` images, GitHub arm64 runners, GHCR, a SparkFabrik GitHub App.
- Production ships no shell: debugging uses `docker debug`, `kubectl debug`, or a sidecar sharing namespaces.
- Out of scope: consumers needing OS packages at runtime; a `-full` flavor is a possible later extension.
