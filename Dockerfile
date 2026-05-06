# ── Stage 1: Dependencies ────────────────────────────────────────────────────
FROM node:18-alpine AS deps

WORKDIR /app

# Copy only manifests first to leverage layer caching
COPY package*.json ./

# Install production deps only
RUN npm ci --only=production && npm cache clean --force

# ── Stage 2: Test ─────────────────────────────────────────────────────────────
FROM node:18-alpine AS test

WORKDIR /app

COPY package*.json ./
RUN npm ci && npm cache clean --force

COPY . .

# Run tests — build fails if tests fail
RUN npm run test:ci

# ── Stage 3: Production ───────────────────────────────────────────────────────
FROM node:18-alpine AS production

# Security: run as non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser  -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copy production node_modules from deps stage
COPY --from=deps --chown=appuser:appgroup /app/node_modules ./node_modules

# Copy application source
COPY --chown=appuser:appgroup app/src ./src
COPY --chown=appuser:appgroup app/package*.json ./

# Drop to non-root
USER appuser

# Document the port
EXPOSE 3000

# Health check — Docker will mark container unhealthy if this fails
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Use exec form to receive signals properly
CMD ["node", "src/index.js"]
