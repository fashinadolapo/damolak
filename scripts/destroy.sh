#!/usr/bin/env bash
# scripts/bootstrap-infra.sh
# Run once on your local machine to initialize and apply Terraform.
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
aws sts get-caller-identity --profile agrovesto-dev

# ── Terraform ─────────────────────────────────────────────────────────────────
cd "$TF_DIR"

log "destroying Terraform..."
terraform destroy -auto-approve

echo ""
log "=== Destroying Terraform... ==="