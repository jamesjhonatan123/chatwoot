#!/bin/sh
set -x

rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

git config --global --add safe.directory /app

ensure_native_build_deps() {
  apk add --no-cache \
    libffi-dev \
    linux-headers \
    openssl-dev \
    pkgconf \
    postgresql-dev
}

install_missing_gems() {
  LOCK_DIR=/gems/.bundle-install.lock

  if bundle check; then
    return 0
  fi

  while ! mkdir "$LOCK_DIR" 2>/dev/null
  do
    echo "Another container is installing gems. Waiting..."
    sleep 2
    bundle check && return 0
  done

  trap 'rmdir "$LOCK_DIR"' EXIT
  ensure_native_build_deps
  bundle install
  rmdir "$LOCK_DIR"
  trap - EXIT
}

install_missing_gems

pnpm store prune
pnpm install --force

echo "Ready to run Vite development server."

exec "$@"
