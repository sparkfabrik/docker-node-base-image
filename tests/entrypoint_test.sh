#!/bin/sh
# Behavior tests for the development entrypoint.
#
# Usage:
#   IMAGE_TAG=<dev image:tag> ./tests/entrypoint_test.sh
#
# Projects are created inside the container (no bind mounts), so the script
# behaves identically on macOS and Linux hosts. Installs hit the npm registry.
set -eu

IMAGE_TAG="${IMAGE_TAG:?set IMAGE_TAG to the dev image to test}"

failures=0

pass() { echo "ok: $1"; }
fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

# Run a shell snippet inside a fresh project dir in the container.
# Usage: in_project '<snippet>' [extra docker run args...]
in_project() {
  snippet="$1"
  shift
  docker run --rm --entrypoint /bin/sh "$@" "${IMAGE_TAG}" -c "
    set -eu
    mkdir -p /tmp/proj && cd /tmp/proj
    ${snippet}
  "
}

# 1. npm lockfile: frozen install triggers on a package manager command.
out="$(in_project '
  printf %s "{\"name\":\"t\",\"version\":\"1.0.0\",\"dependencies\":{\"ms\":\"2.1.3\"}}" > package.json
  npm install --package-lock-only --no-audit --no-fund >/dev/null 2>&1
  rm -rf node_modules
  docker-entrypoint.sh npm ls ms --depth=0 2>&1
')" || out="failed"
case "${out}" in
  *"installing dependencies with npm (frozen mode)"*ms@2.1.3*)
    pass "npm lockfile triggers npm ci and the command runs" ;;
  *) fail "npm case output: ${out}" ;;
esac

# 2. yarn lockfile: yarn selected.
out="$(in_project '
  printf %s "{\"name\":\"t\",\"version\":\"1.0.0\"}" > package.json
  touch yarn.lock
  docker-entrypoint.sh yarn --version 2>&1
')" || out="failed"
case "${out}" in
  *"installing dependencies with yarn (frozen mode)"*)
    pass "yarn lockfile selects yarn" ;;
  *) fail "yarn case output: ${out}" ;;
esac

# 3. pnpm lockfile: pnpm selected. pnpm rejects an empty lockfile, so
# generate a real one first.
out="$(in_project '
  printf %s "{\"name\":\"t\",\"version\":\"1.0.0\",\"dependencies\":{\"ms\":\"2.1.3\"}}" > package.json
  pnpm install --lockfile-only --reporter=silent >/dev/null 2>&1
  docker-entrypoint.sh pnpm --version 2>&1
')" || out="failed"
case "${out}" in
  *"installing dependencies with pnpm (frozen mode)"*)
    pass "pnpm lockfile selects pnpm" ;;
  *) fail "pnpm case output: ${out}" ;;
esac

# 4. No lockfile: warn and run the command anyway.
out="$(in_project 'docker-entrypoint.sh npm --version 2>&1')" || out="failed"
case "${out}" in
  *"no lockfile found"*)
    pass "missing lockfile warns and still executes" ;;
  *) fail "no-lockfile case output: ${out}" ;;
esac

# 5. Non-package-manager command: no install attempted.
out="$(in_project '
  touch package-lock.json
  docker-entrypoint.sh node -e "console.log(42)" 2>&1
')" || out="failed"
case "${out}" in
  *installing*) fail "node command should not trigger install: ${out}" ;;
  *42*) pass "arbitrary command skips install" ;;
  *) fail "arbitrary command output: ${out}" ;;
esac

# 6. SKIP_DEPS_INSTALL=1: no install even for package manager commands.
out="$(in_project '
  touch package-lock.json
  docker-entrypoint.sh npm --version 2>&1
' -e SKIP_DEPS_INSTALL=1)" || out="failed"
case "${out}" in
  *installing*) fail "SKIP_DEPS_INSTALL was ignored: ${out}" ;;
  *) pass "SKIP_DEPS_INSTALL skips install" ;;
esac

# 7. FORCE_DEPS_INSTALL=1: install before an arbitrary command.
out="$(in_project '
  printf %s "{\"name\":\"t\",\"version\":\"1.0.0\"}" > package.json
  npm install --package-lock-only --no-audit --no-fund >/dev/null 2>&1
  docker-entrypoint.sh node -e "console.log(42)" 2>&1
' -e FORCE_DEPS_INSTALL=1)" || out="failed"
case "${out}" in
  *"installing dependencies with npm"*42*)
    pass "FORCE_DEPS_INSTALL installs before arbitrary commands" ;;
  *) fail "force case output: ${out}" ;;
esac

# 8. DEPS_INSTALL_MODE=update: non-frozen install.
out="$(in_project '
  printf %s "{\"name\":\"t\",\"version\":\"1.0.0\",\"dependencies\":{\"ms\":\"2.1.3\"}}" > package.json
  touch package-lock.json
  docker-entrypoint.sh npm ls ms --depth=0 2>&1
' -e DEPS_INSTALL_MODE=update)" || out="failed"
case "${out}" in
  *"installing dependencies with npm (update mode)"*ms@2.1.3*)
    pass "DEPS_INSTALL_MODE=update runs a regular install" ;;
  *) fail "update mode output: ${out}" ;;
esac

# 9. Native module: node-gyp toolchain compiles a source-built addon.
out="$(in_project '
  printf %s "{\"name\":\"t\",\"version\":\"1.0.0\"}" > package.json
  npm install --no-save --no-audit --no-fund node-gyp >/dev/null 2>&1
  mkdir -p addon && cd addon
  printf %s "{\"targets\":[{\"target_name\":\"hello\",\"sources\":[\"hello.c\"]}]}" > binding.gyp
  printf "%s\n" "#include <node_api.h>" "static napi_value Init(napi_env env, napi_value exports) { return exports; }" "NAPI_MODULE(hello, Init)" > hello.c
  ../node_modules/.bin/node-gyp rebuild >/dev/null 2>&1 && echo GYP_BUILD_OK
')" || out="failed"
case "${out}" in
  *GYP_BUILD_OK*) pass "node-gyp compiles a native addon from source" ;;
  *) fail "native module case output: ${out}" ;;
esac

echo
if [ "${failures}" -gt 0 ]; then
  echo "${failures} entrypoint test(s) failed for ${IMAGE_TAG}" >&2
  exit 1
fi
echo "all entrypoint tests passed for ${IMAGE_TAG}"
