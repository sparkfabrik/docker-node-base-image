#!/bin/sh
# Smoke test of the example applications built on the base image.
#
# Usage:
#   [NEXT_IMAGE=example-nextjs] [NEST_IMAGE=example-nestjs] \
#   [NEXT_PORT=3100] [NEST_PORT=3101] ./tests/examples_test.sh
#
# Expects the example images to be already built (just build-examples).
set -eu

NEXT_IMAGE="${NEXT_IMAGE:-example-nextjs}"
NEST_IMAGE="${NEST_IMAGE:-example-nestjs}"
NEXT_PORT="${NEXT_PORT:-3100}"
NEST_PORT="${NEST_PORT:-3101}"

failures=0

pass() { echo "ok: $1"; }
fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

cleanup() {
  docker rm -f example-next-test example-nest-test >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

docker run -d --name example-next-test -p "${NEXT_PORT}:3000" "${NEXT_IMAGE}" >/dev/null
docker run -d --name example-nest-test -p "${NEST_PORT}:3000" "${NEST_IMAGE}" >/dev/null

# Wait until an HTTP endpoint answers, up to 30 seconds.
wait_http() {
  i=0
  while [ "${i}" -lt 30 ]; do
    if curl -sf -o /dev/null "$1"; then
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  return 1
}

# Next.js: serves the page.
if wait_http "http://localhost:${NEXT_PORT}/" \
  && curl -sf "http://localhost:${NEXT_PORT}/" | grep -q "Hello from Next.js"; then
  pass "next.js example serves the page"
else
  fail "next.js example does not serve the expected page"
fi

# NestJS: serves the endpoint.
if wait_http "http://localhost:${NEST_PORT}/" \
  && curl -sf "http://localhost:${NEST_PORT}/" | grep -q "Hello from NestJS"; then
  pass "nestjs example serves the endpoint"
else
  fail "nestjs example does not serve the expected endpoint"
fi

# Permission contract: /app read-only for the runtime user in both examples,
# and only the granted cache path writable in the next.js one.
for name in example-next-test example-nest-test; do
  if docker exec "${name}" node -e 'require("fs").writeFileSync("/app/x","1")' >/dev/null 2>&1; then
    fail "${name}: /app is writable by the runtime user"
  else
    pass "${name}: /app is read-only for the runtime user"
  fi
done

if docker exec example-next-test node -e 'require("fs").writeFileSync("/app/.next/cache/x","1")' >/dev/null 2>&1; then
  pass "example-next-test: .next/cache is writable by the runtime user"
else
  fail "example-next-test: .next/cache is not writable by the runtime user"
fi

echo
if [ "${failures}" -gt 0 ]; then
  echo "${failures} example check(s) failed" >&2
  exit 1
fi
echo "all example checks passed"
