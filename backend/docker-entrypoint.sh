#!/bin/sh
# Applies pending Prisma migrations, then starts the API.
# Set RUN_MIGRATIONS=false to skip (e.g. when running several replicas and
# migrating from a one-off job instead).
set -e

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  echo "[entrypoint] Applying database migrations (prisma migrate deploy)..."
  ./node_modules/.bin/prisma migrate deploy
fi

echo "[entrypoint] Starting API..."
exec node dist/main.js
