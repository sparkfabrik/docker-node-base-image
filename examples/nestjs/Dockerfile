# syntax=docker/dockerfile:1

# Example: NestJS on the SparkFabrik Node.js base image.
# BASE_IMAGE defaults to the local build; CI/consumers would use
# ghcr.io/sparkfabrik/docker-node-base-image.
ARG BASE_IMAGE=docker-node-base-image
ARG BASE_TAG=24-alpine3.23

FROM ${BASE_IMAGE}:${BASE_TAG}-dev AS build

COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build
# Runtime dependencies only for the production stage.
RUN npm ci --omit=dev

FROM ${BASE_IMAGE}:${BASE_TAG}

# Everything root-owned: the app never writes to /app at runtime.
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./package.json

ENV PORT=3000
EXPOSE 3000

CMD ["node", "dist/main.js"]
