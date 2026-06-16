#!/bin/sh

set -x

# Remove a potentially pre-existing server.pid for Rails.
rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

echo "Waiting for postgres to become ready...."

# Let DATABASE_URL env take presedence over individual connection params.
# This is done to avoid printing the DATABASE_URL in the logs
$(docker/entrypoints/helpers/pg_database_url.rb)
PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"

until $PG_READY
do
  sleep 2;
done

echo "Database ready to accept connections."

# Git is used during boot/dev tooling; mounted volumes can trip ownership checks.
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

BUNDLE="bundle check"

until $BUNDLE
do
  sleep 2;
done

# Execute the main process of the container
exec "$@"
