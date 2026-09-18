#!/bin/sh
# Development entrypoint: install project dependencies at container start,
# then hand off to the container command as PID 1.
#
# Installation triggers when the first command argument is a Node.js package
# manager or runner (npm, yarn, pnpm, npx, corepack). The package manager is
# selected from the project lockfile and yarn/pnpm run through corepack, so a
# `packageManager` pin in package.json wins.
#
# Environment overrides:
#   SKIP_DEPS_INSTALL=1    never install, run the command directly
#   FORCE_DEPS_INSTALL=1   install before any command
#   DEPS_INSTALL_MODE=update   regular install instead of frozen-lockfile
set -eu

log() {
  echo "entrypoint: $*" >&2
}

should_install() {
  if [ "${SKIP_DEPS_INSTALL:-0}" = "1" ]; then
    return 1
  fi
  if [ "${FORCE_DEPS_INSTALL:-0}" = "1" ]; then
    return 0
  fi
  case "${1:-}" in
    npm | yarn | pnpm | npx | corepack) return 0 ;;
    *) return 1 ;;
  esac
}

install_deps() {
  if [ -f package-lock.json ]; then
    pm=npm
  elif [ -f yarn.lock ]; then
    pm=yarn
  elif [ -f pnpm-lock.yaml ]; then
    pm=pnpm
  else
    log "no lockfile found in $(pwd), skipping dependency install"
    return 0
  fi

  mode="${DEPS_INSTALL_MODE:-frozen}"
  log "installing dependencies with ${pm} (${mode} mode)"

  case "${pm}" in
    npm)
      if [ "${mode}" = "update" ]; then
        npm install
      else
        npm ci
      fi
      ;;
    yarn)
      if [ "${mode}" = "update" ]; then
        yarn install
      elif yarn --version 2>/dev/null | grep -q '^1\.'; then
        yarn install --frozen-lockfile
      else
        yarn install --immutable
      fi
      ;;
    pnpm)
      if [ "${mode}" = "update" ]; then
        pnpm install
      else
        pnpm install --frozen-lockfile
      fi
      ;;
  esac
}

if should_install "$@"; then
  install_deps
fi

exec "$@"
