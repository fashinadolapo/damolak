# --- STAGE 1: Base ---
FROM node:22-alpine AS base
WORKDIR /app
# Enable corepack for modern package managers (pnpm/yarn) if needed
RUN corepack enable

# --- STAGE 2: Dependencies ---
FROM base AS deps
# Copy only files needed for install to maximize layer caching
COPY app/package.json app/package-lock.json* ./
# Use 'npm ci' for a fast, deterministic, and "clean" install
RUN npm ci

# --- STAGE 3: Builder ---
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY app/  .
# Set environment to production during build
ENV NODE_ENV=production
RUN npm run build

# --- STAGE 4: Runner (Production) ---
FROM nginx:1.27-alpine AS production

# 1. Create a non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 2. Setup permissions for Nginx to run as non-root
# Nginx needs access to these directories to manage cache and PIDs
RUN touch /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/run/nginx.pid /var/cache/nginx /var/log/nginx /etc/nginx/conf.d

# 3. Copy custom Nginx config (essential for SPA routing)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 4. Copy build artifacts from builder stage
WORKDIR /usr/share/nginx/html
COPY --from=builder --chown=appuser:appgroup /app/dist .

# 5. Switch to the non-root user
USER appuser

# 6. Expose a non-privileged port (standard for non-root is 8080)
EXPOSE 3000

# 7. Healthcheck to ensure the container is actually serving traffic
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/ || exit 1

CMD ["nginx", "-g", "daemon off;"]