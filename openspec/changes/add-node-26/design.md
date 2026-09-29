# Design: Add Node.js 26 to the matrix

## Context

See proposal.md. The `node-base-image` change defines the matrix, the allowlist, and the tag scheme.

## Decisions

- Add the two upstream line 26 tags to the matrix list. Renovate then tracks them like line 24.
- Add `libatomic1` to the Debian allowlist only for lines that link it. Node.js 26 links `libatomic.so.1`; the contract test fails without it.
- Keep `trixie-slim` for 26 even though 22 and 24 stay on `bookworm-slim`: each line follows its own upstream alias.

## Risks / Trade-offs

- [Two Debian releases in the matrix] → the allowlist is per release family; `gcc-N-base` differs between bookworm and trixie, and the contract test catches a wrong name.
