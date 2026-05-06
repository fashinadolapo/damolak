# --- STAGE 1: Base ---
FROM node:22-alpine AS base
WORKDIR /app
RUN corepack enable

# --- STAGE 2: Dependencies ---
FROM base AS deps
# Copy from the 'app' folder where your package files live
COPY app/package.json app/package-lock.json* ./
# Install ONLY production dependencies to keep the image small
RUN npm ci --omit=dev

# --- STAGE 3: Production Runner ---
FROM node:22-alpine AS production

# 1. Security: Run as non-root user (Alpine Node image has 'node' user built-in)
USER node
WORKDIR /app

# 2. Copy dependencies from the deps stage
COPY --from=deps --chown=node:node /app/node_modules ./node_modules

# 3. Copy the application source code
# We copy from 'app/' on the host to the current WORKDIR
COPY --chown=node:node app/ .

# 4. Set production environment
ENV NODE_ENV=production

# 5. Your app listens on a port (usually 3000 for Express)
EXPOSE 3000

# 6. Healthcheck to ensure the API is responding
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/ || exit 1

# 7. Use 'node' directly instead of 'npm start' for better signal handling (SIGTERM)
CMD ["node", "src/index.js"]