#!/usr/bin/env bash
# Découvre les slugs des flows et le nom du certificat Authentik pour les
# variables Terraform. À lancer avec un token **admin** (pas le token Outpost).
#
# Usage: AUTHENTIK_TOKEN=<token_admin> ./scripts/discover-authentik-slugs.sh
#        ou: export AUTHENTIK_TOKEN=... && ./scripts/discover-authentik-slugs.sh
set -e
BASE_URL="${AUTHENTIK_URL:-https://auth.smadja.dev}"
TOKEN="${AUTHENTIK_TOKEN:-}"

if [[ -z "$TOKEN" ]]; then
  echo "Usage: AUTHENTIK_TOKEN=<token> $0"
  echo "Token must be from an admin user (API Access), not an Outpost service account."
  exit 1
fi

echo "Fetching flows from $BASE_URL ..."
FLOWS=$(curl -sS -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v3/flows/instances/?page_size=100")
echo "Fetching certificate key pairs..."
CERTS=$(curl -sS -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v3/crypto/certificatekeypairs/")

# Flows: find by designation
AUTHN_SLUG=$(echo "$FLOWS" | jq -r '.results[] | select(.designation == "authentication") | .slug' | head -1)
AUTHZ_SLUG=$(echo "$FLOWS" | jq -r '.results[] | select(.designation == "authorization") | .slug' | head -1)
INVAL_SLUG=$(echo "$FLOWS" | jq -r '.results[] | select(.designation == "invalidation") | .slug' | head -1)
CERT_NAME=$(echo "$CERTS" | jq -r '.results[0].name // empty')

if [[ -z "$AUTHN_SLUG" || -z "$AUTHZ_SLUG" || -z "$INVAL_SLUG" ]]; then
  echo "Could not find flows (token may lack permissions or instance has no default flows)."
  echo "Flows found:"
  echo "$FLOWS" | jq -r '.results[]? | "  \(.designation // "?") | \(.slug) | \(.name)"' 2>/dev/null || true
  exit 1
fi

echo ""
echo "Add these to terraform.tfvars or run terraform with -var=... :"
echo ""
echo "authentik_flow_slug_authentication = \"$AUTHN_SLUG\""
echo "authentik_flow_slug_authorization   = \"$AUTHZ_SLUG\""
echo "authentik_flow_slug_invalidation    = \"$INVAL_SLUG\""
if [[ -n "$CERT_NAME" ]]; then
  echo "authentik_certificate_key_pair_name = \"$CERT_NAME\""
else
  echo "# authentik_certificate_key_pair_name = \"authentik Self-signed Certificate\"  # (no cert found via API)"
fi
echo ""
