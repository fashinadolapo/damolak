#!/usr/bin/env bash
# scripts/deploy.sh
# Convenience wrapper used by the Jenkinsfile to deploy on the app server.
# Also useful for manual one-off deployments.

set -euo pipefail

# ── Config (override via env) ─────────────────────────────────────────────────
ECR_URL="${ECR_URL:?ECR_URL is required}"
APP_VERSION="${APP_VERSION:-latest}"
APP_PORT="${APP_PORT:-3000}"
AWS_REGION="${AWS_REGION:?AWS_REGION is required}"
LOG_GROUP="${LOG_GROUP:-/devops-challenge/production/app}"
CONTAINER_NAME="devops-app"
HEALTH_URL="http://localhost:${APP_PORT}/health"
MAX_RETRIES=12
RETRY_DELAY=5

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ── ECR Login ─────────────────────────────────────────────────────────────────
log "Authenticating with ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_URL"

# ── Pull Image ────────────────────────────────────────────────────────────────
FULL_IMAGE="${ECR_URL}:${APP_VERSION}"
log "Pulling image: $FULL_IMAGE"
docker pull "$FULL_IMAGE"

# ── Stop Old Container ────────────────────────────────────────────────────────
log "Stopping old container (if running)..."
docker stop "$CONTAINER_NAME" 2>/dev/null && log "Stopped $CONTAINER_NAME" || true
docker rm   "$CONTAINER_NAME" 2>/dev/null && log "Removed $CONTAINER_NAME" || true

# ── Run New Container ─────────────────────────────────────────────────────────
INSTANCE_ID=$(curl -sf http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")

log "Starting container: $FULL_IMAGE"
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "${APP_PORT}:3000" \
  -e NODE_ENV=production \
  -e APP_VERSION="$APP_VERSION" \
  --log-driver=awslogs \
  --log-opt awslogs-region="$AWS_REGION" \
  --log-opt awslogs-group="$LOG_GROUP" \
  --log-opt awslogs-stream="${INSTANCE_ID}/docker" \
  "$FULL_IMAGE"

# ── Health Check ──────────────────────────────────────────────────────────────
log "Waiting for application to pass health check at $HEALTH_URL..."
for i in $(seq 1 "$MAX_RETRIES"); do
  if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
    log "✅ Application is healthy! (attempt $i/$MAX_RETRIES)"
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.ID}}\t{{.Status}}\t{{.Ports}}"
    exit 0
  fi
  log "Attempt $i/$MAX_RETRIES — not ready yet, retrying in ${RETRY_DELAY}s..."
  sleep "$RETRY_DELAY"
done

log "❌ Application failed health check after $((MAX_RETRIES * RETRY_DELAY))s"
log "Container logs:"
docker logs --tail 50 "$CONTAINER_NAME"
exit 1
