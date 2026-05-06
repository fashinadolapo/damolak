#!/usr/bin/env bash
# scripts/bootstrap-infra.sh
# Run once on your local machine to initialise and apply Terraform.
# Prerequisites: terraform CLI + AWS CLI configured with sufficient permissions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform"

log()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }

# ── Preflight ─────────────────────────────────────────────────────────────────
command -v terraform &>/dev/null || error "terraform is not installed"
command -v aws       &>/dev/null || error "aws CLI is not installed"

log "AWS identity:"
aws sts get-caller-identity

# ── Terraform ─────────────────────────────────────────────────────────────────
cd "$TF_DIR"

[[ -f terraform.tfvars ]] || \
  error "terraform.tfvars not found. Copy terraform.tfvars.example and fill in your values."

log "Initialising Terraform..."
terraform init

log "Validating configuration..."
terraform validate

log "Planning..."
terraform plan -out=tfplan

read -rp "Apply this plan? (yes/no): " CONFIRM
[[ "$CONFIRM" == "yes" ]] || { log "Aborted."; exit 0; }

log "Applying..."
terraform apply tfplan

echo ""
log "=== Outputs ==="
terraform output

echo ""
log "=== Next Steps ==="
log "1. Add these values as GitHub Repository Secrets:"
log "   AWS_OIDC_ROLE_ARN  →  $(terraform output -raw github_actions_role_arn)"
log "   ECR_REPO_URL       →  $(terraform output -raw ecr_repository_url)"
log "   APP_SERVER_IP      →  $(terraform output -raw app_public_ip)"
log "   AWS_REGION         →  your region (e.g. us-east-1)"
log "   APP_EC2_SSH_KEY    →  contents of your .pem private key"
log ""
log "2. Push to main to trigger the pipeline:"
log "   git commit --allow-empty -m 'chore: trigger deploy' && git push"
log ""
log "3. App will be available at: $(terraform output -raw health_check_url)"
