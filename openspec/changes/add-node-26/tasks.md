# Tasks

## 1. Line 26

- [ ] 1.1 On or after 2026-10-28, confirm in `nodejs/Release/schedule.json` that line 26 is active LTS
- [ ] 1.2 Add `libatomic1` and the trixie `gcc-N-base` to the Debian allowlist for line 26, and verify `ldd /usr/local/bin/node` in the `strip` stage resolves every library
- [ ] 1.3 Add the upstream `26.x.y-trixie-slim` and `26.x.y-alpine3.24` tags to the matrix list, and verify the pull request pipeline passes for all four line 26 images
- [ ] 1.4 After merge, verify `26-slim`, `26-alpine`, and their `-dev` tags pull on both architectures with SBOM and provenance
- [ ] 1.5 Add the line to `CHANGELOG.md` under Added, and verify the README tag table lists it
