#!/usr/bin/env bash
# Exchange GitHub Actions OIDC token for OCI User Principal Session Token (UPST)
# Based on: https://www.ateam-oracle.com/github-actions-oci-a-guide-to-secure-oidc-token-exchange
#
# Usage:
#   ./scripts/oci-oidc-token-exchange.sh \
#     --github-token "$GITHUB_TOKEN" \
#     --oci-tenancy "$OCI_TENANCY" \
#     --oci-user "$OCI_USER" \
#     --oci-fingerprint "$OCI_FINGERPRINT" \
#     --oci-region "$OCI_REGION" \
#     --oci-key-file "$OCI_KEY_FILE"
#
# Outputs:
#   OCI_SESSION_TOKEN: Session token (UPST)
#   OCI_SESSION_KEY: Session private key path

set -e

GITHUB_TOKEN=""
OCI_TENANCY=""
OCI_USER=""
OCI_FINGERPRINT=""
OCI_REGION="eu-paris-1"
OCI_KEY_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --github-token) GITHUB_TOKEN="$2"; shift 2 ;;
    --oci-tenancy) OCI_TENANCY="$2"; shift 2 ;;
    --oci-user) OCI_USER="$2"; shift 2 ;;
    --oci-fingerprint) OCI_FINGERPRINT="$2"; shift 2 ;;
    --oci-region) OCI_REGION="$2"; shift 2 ;;
    --oci-key-file) OCI_KEY_FILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

[[ -z "$GITHUB_TOKEN" ]] && { echo "Error: --github-token required"; exit 1; }
[[ -z "$OCI_TENANCY" ]] && { echo "Error: --oci-tenancy required"; exit 1; }
[[ -z "$OCI_USER" ]] && { echo "Error: --oci-user required"; exit 1; }
[[ -z "$OCI_FINGERPRINT" ]] && { echo "Error: --oci-fingerprint required"; exit 1; }
[[ -z "$OCI_KEY_FILE" ]] && { echo "Error: --oci-key-file required"; exit 1; }

# Decode GitHub OIDC token to get claims
GITHUB_JWT_PAYLOAD=$(echo "$GITHUB_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null || echo "$GITHUB_TOKEN" | cut -d. -f2 | base64 -d)
REPO=$(echo "$GITHUB_JWT_PAYLOAD" | jq -r '.repository // .repo // ""')
REF=$(echo "$GITHUB_JWT_PAYLOAD" | jq -r '.ref // ""')

echo "GitHub OIDC Token Claims:"
echo "  Repository: $REPO"
echo "  Ref: $REF"

# Exchange GitHub OIDC token for OCI UPST via OCI API
# This uses OCI's token exchange API endpoint
# https://docs.oracle.com/en-us/iaas/Content/Identity/api-getstarted/json_web_token_exchange.htm

# Generate request body for token exchange
REQUEST_BODY=$(cat <<EOF
{
  "token": "$GITHUB_TOKEN",
  "scope": "urn:oracle:oci:identity:user:${OCI_USER}"
}
EOF
)

# Exchange token
RESPONSE=$(curl -s -X POST \
  "https://identity.${OCI_REGION}.oraclecloud.com/20160918/oauth2/v1/token" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_BODY" || echo "")

if [[ -z "$RESPONSE" ]]; then
  echo "::warning::Token exchange via API failed, using API key fallback"
  exit 1
fi

UPST_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token // ""')

if [[ -z "$UPST_TOKEN" || "$UPST_TOKEN" == "null" ]]; then
  echo "::warning::Failed to obtain UPST token, using API key fallback"
  exit 1
fi

echo "Successfully obtained OCI UPST token"
echo "UPST_TOKEN=$UPST_TOKEN"
