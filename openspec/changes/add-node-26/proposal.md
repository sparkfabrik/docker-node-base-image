# Proposal: Add Node.js 26 to the matrix

## Why

Node.js 26 becomes active LTS on 2026-10-28. The `image-variants` spec publishes active and maintenance LTS lines, so line 26 must join the matrix on that date.

## What Changes

- Line 26 entries (Debian slim and Alpine, production and `-dev`) in the publish matrix.
- `libatomic1` in the Debian production allowlist, required from Node.js 26.
- Debian variant on `trixie-slim`, the release upstream aliases as `26-slim`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. The matrix grows by data; no requirement changes, so this change sets `skip_specs: true`.

## Impact

- Four new images and their tags: `26.x.y-trixie-slim`, `26-slim`, `26.x.y-alpine3.24`, `26-alpine`, each with `-dev`.
- Depends on the `node-base-image` change being implemented.
- Not before 2026-10-28: a Current line is not published.
