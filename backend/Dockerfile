# syntax=docker/dockerfile:1
FROM node:22-alpine AS base
WORKDIR /app
COPY package.json package-lock.json ./

# Production dependencies only.
FROM base AS deps
ENV NODE_ENV=production
RUN npm ci --omit=dev && npm cache clean --force

# Test image: all dependencies + tests (used by docker-compose.test.yml).
FROM base AS test
ENV NODE_ENV=test
RUN npm ci
COPY . .
CMD ["npm", "test"]

# Runtime image.
FROM node:22-alpine AS runtime
ENV NODE_ENV=production \
    PORT=3000 \
    UPLOADS_DIR=/app/uploads
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
COPY migrations ./migrations
COPY scripts ./scripts
# Pre-create the uploads dir owned by `node` so a fresh named volume inherits that ownership.
RUN mkdir -p /app/uploads/.tmp && chown -R node:node /app/uploads
USER node
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${PORT}/api/v1/health" >/dev/null || exit 1
CMD ["node", "src/server.js"]
