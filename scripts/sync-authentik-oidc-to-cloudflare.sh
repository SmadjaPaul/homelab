#!/usr/bin/env bash
# Generate terraform/cloudflare/authentik-oidc.auto.tfvars.json from terraform/authentik
# so Cloudflare Access uses Authentik as IdP (no more one-time PIN by email).
#
# Usage (from repo root):
#   ./scripts/sync-authentik-oidc-to-cloudflare.sh
#   cd terraform/cloudflare && terraform plan && terraform apply
#
# Requires: terraform/authentik already applied, jq
set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUTHENTIK_DIR="$REPO_ROOT/terraform/authentik"
CLOUDFLARE_DIR="$REPO_ROOT/terraform/cloudflare"
OUT_FILE="$CLOUDFLARE_DIR/authentik-oidc.auto.tfvars.json"

if [[ ! -d "$AUTHENTIK_DIR" ]] || [[ ! -d "$CLOUDFLARE_DIR" ]]; then
  echo "Run from repo root. Expected terraform/authentik and terraform/cloudflare."
  exit 1
fi

echo "Reading OIDC config from terraform/authentik..."
OUT=$(terraform -chdir="$AUTHENTIK_DIR" output -json cloudflare_access_oidc 2>/dev/null) || {
  echo "Error: run 'terraform apply' in terraform/authentik first and ensure cloudflare_access_oidc output exists."
  exit 1
}

echo "Writing $OUT_FILE ..."
# Terraform auto.tfvars.json: only needed vars; URLs default in Cloudflare from domain
jq -n \
  --argjson raw "$OUT" \
  '{
    authentik_oidc_enabled: true,
    authentik_oidc_client_id: $raw.client_id,
    authentik_oidc_client_secret: $raw.client_secret,
    authentik_oidc_auth_url: $raw.auth_url,
    authentik_oidc_token_url: $raw.token_url,
    authentik_oidc_certs_url: $raw.certs_url
  }' > "$OUT_FILE"

echo "Done. Next: cd terraform/cloudflare && terraform plan && terraform apply"
echo "File contains secrets; do not commit (authentik-oidc.auto.tfvars.json is in .gitignore)."
