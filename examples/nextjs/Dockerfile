# syntax=docker/dockerfile:1

# Example: Next.js (standalone output) on the SparkFabrik Node.js base image.
# BASE_IMAGE defaults to the local build; CI/consumers would use
# ghcr.io/sparkfabrik/node.
ARG BASE_IMAGE=sparkfabrik/node
ARG BASE_TAG=24-alpine

FROM ${BASE_IMAGE}:${BASE_TAG}-dev AS build

ENV NEXT_TELEMETRY_DISABLED=1

COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build
# Ensure the cache directory exists so the production stage can copy it even
# when the build produced nothing cacheable.
RUN mkdir -p .next/cache

FROM ${BASE_IMAGE}:${BASE_TAG}

# Application code stays root-owned (read-only for the runtime user).
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
# Only the cache directory is writable by the runtime user: this is the
# per-path write grant the base image README documents.
COPY --from=build --chown=node:node /app/.next/cache ./.next/cache

ENV PORT=3000
EXPOSE 3000

CMD ["node", "server.js"]
