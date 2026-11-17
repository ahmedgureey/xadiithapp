# syntax=docker/dockerfile:1.7
# Xadiis App API - production image (NestJS + Prisma)
# Build:  docker build -t xadiis-api .
# Run:    docker run --env-file .env -p 3000:3000 xadiis-api

ARG NODE_IMAGE=node:24-alpine

# ---------------------------------------------------------------------------
# 1) Build stage: install all deps, generate Prisma client, compile TS
# ---------------------------------------------------------------------------
FROM ${NODE_IMAGE} AS build
WORKDIR /app
ENV CHECKPOINT_DISABLE=1 \
    PRISMA_HIDE_UPDATE_MESSAGE=1
# openssl is required by Prisma's query/schema engines on Alpine (musl).
RUN apk add --no-cache openssl

COPY package.json package-lock.json ./
COPY prisma ./prisma
RUN npm ci --no-audit --no-fund

COPY tsconfig.json tsconfig.build.json tsconfig.seed.json nest-cli.json ./
COPY src ./src
RUN npx prisma generate \
 && npm run build \
 && npm prune --omit=dev --no-audit --no-fund

# ---------------------------------------------------------------------------
# 2) Runtime stage: production deps + compiled output only, non-root user
# ---------------------------------------------------------------------------
FROM ${NODE_IMAGE} AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    PORT=3000 \
    CHECKPOINT_DISABLE=1 \
    PRISMA_HIDE_UPDATE_MESSAGE=1 \
    NPM_CONFIG_UPDATE_NOTIFIER=false
RUN apk add --no-cache openssl tini

COPY --from=build --chown=node:node /app/package.json /app/package-lock.json ./
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --from=build --chown=node:node /app/dist-seed ./dist-seed
COPY --from=build --chown=node:node /app/prisma ./prisma
COPY --chown=node:node docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod 0755 ./docker-entrypoint.sh

# Run as the unprivileged "node" user shipped with the official image.
USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${PORT:-3000}/api/v1/health" > /dev/null || exit 1

# tini reaps zombies and forwards SIGTERM so Nest shuts down gracefully.
ENTRYPOINT ["/sbin/tini", "--", "./docker-entrypoint.sh"]
