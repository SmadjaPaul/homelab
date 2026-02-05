#!/usr/bin/env bash
# Authenticate with Authentik using OAuth2 private_key_jwt and export token for Terraform
# Usage: source ./auth-oauth2.sh
#   Then run: terraform plan/apply

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Configuration
AUTHENTIK_URL="${AUTHENTIK_URL:-https://auth.smadja.dev}"
CLIENT_ID="${AUTHENTIK_OAUTH2_CLIENT_ID:-ci-automation}"
ISSUER_URL="${AUTHENTIK_OAUTH2_ISSUER_URL:-${AUTHENTIK_URL}/application/o/${CLIENT_ID}/}"
SCOPE="${AUTHENTIK_OAUTH2_SCOPE:-goauthentik.io/api}"

# Try to get private key from OCI Vault first, then fallback to local file
PRIVATE_KEY_PEM=""

# Method 1: From OCI Vault (if configured)
if command -v oci &> /dev/null && [ -f ~/.oci/config ]; then
  echo "Attempting to fetch private key from OCI Vault..."
  VAULT_SECRET_OCID=$(oci vault secret list \
    --compartment-id "$(grep '^tenancy=' ~/.oci/config | cut -d'=' -f2 | xargs)" \
    --query "data[?contains(\"secret-name\", 'authentik-private-key-pem')].id" \
    --raw-output 2>/dev/null | head -1 || echo "")

  if [ -n "$VAULT_SECRET_OCID" ]; then
    PRIVATE_KEY_PEM=$(oci vault secret get-secret \
      --secret-id "$VAULT_SECRET_OCID" \
      --query 'data."secret-content".content' \
      --raw-output 2>/dev/null | base64 -d || echo "")
  fi
fi

# Method 2: From environment variable
if [ -z "$PRIVATE_KEY_PEM" ] && [ -n "$AUTHENTIK_PRIVATE_KEY_PEM" ]; then
  PRIVATE_KEY_PEM="$AUTHENTIK_PRIVATE_KEY_PEM"
fi

# Method 3: From local file
if [ -z "$PRIVATE_KEY_PEM" ] && [ -f "$SCRIPT_DIR/.authentik-private-key.pem" ]; then
  PRIVATE_KEY_PEM=$(cat "$SCRIPT_DIR/.authentik-private-key.pem")
fi

# Method 4: From OCI Vault via Terraform output (if available)
if [ -z "$PRIVATE_KEY_PEM" ] && [ -f "$PROJECT_ROOT/terraform/oracle-cloud/.terraform/terraform.tfstate" ]; then
  echo "Attempting to get secret OCID from Terraform state..."
  SECRET_OCID=$(cd "$PROJECT_ROOT/terraform/oracle-cloud" && \
    terraform output -json 2>/dev/null | \
    jq -r '.vault_secrets.value.authentik_private_key_pem // empty' 2>/dev/null || echo "")

  if [ -n "$SECRET_OCID" ] && command -v oci &> /dev/null; then
    PRIVATE_KEY_PEM=$(oci vault secret get-secret \
      --secret-id "$SECRET_OCID" \
      --query 'data."secret-content".content' \
      --raw-output 2>/dev/null | base64 -d || echo "")
  fi
fi

if [ -z "$PRIVATE_KEY_PEM" ]; then
  echo "Error: Could not find Authentik private key." >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  1. Set AUTHENTIK_PRIVATE_KEY_PEM environment variable" >&2
  echo "  2. Place private key in: $SCRIPT_DIR/.authentik-private-key.pem" >&2
  echo "  3. Configure OCI CLI and ensure secret 'homelab-authentik-private-key-pem' exists in OCI Vault" >&2
  echo "" >&2
  echo "To get the private key from OCI Vault:" >&2
  echo "  oci vault secret get-secret --secret-id <SECRET_OCID> --query 'data.\"secret-content\".content' --raw-output | base64 -d" >&2
  exit 1
fi

# Check if client_id is available
if [ -z "$CLIENT_ID" ]; then
  echo "Error: AUTHENTIK_OAUTH2_CLIENT_ID not set. Defaulting to 'ci-automation'." >&2
  CLIENT_ID="ci-automation"
fi

# Install jq if not available
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed." >&2
  echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)" >&2
  exit 1
fi

# Write private key to temp file
TEMP_KEY_FILE=$(mktemp)
trap 'rm -f "$TEMP_KEY_FILE"' EXIT
echo "$PRIVATE_KEY_PEM" > "$TEMP_KEY_FILE"
chmod 600 "$TEMP_KEY_FILE"

# Generate JWT ID (jti) - random UUID
JTI=$(openssl rand -hex 16)

# Get current timestamp
NOW=$(date +%s)
EXP=$((NOW + 60))  # Token expires in 60 seconds

# Create JWT header
HEADER=$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-')

# Create JWT payload
PAYLOAD=$(jq -n \
  --arg iss "$CLIENT_ID" \
  --arg sub "$CLIENT_ID" \
  --arg aud "$ISSUER_URL" \
  --argjson exp "$EXP" \
  --argjson iat "$NOW" \
  --arg jti "$JTI" \
  '{iss: $iss, sub: $sub, aud: $aud, exp: $exp, iat: $iat, jti: $jti}' | \
  base64 | tr -d '=' | tr '/+' '_-')

# Sign JWT (header.payload)
SIGNATURE=$(echo -n "${HEADER}.${PAYLOAD}" | \
  openssl dgst -sha256 -sign "$TEMP_KEY_FILE" | \
  base64 | tr -d '=' | tr '/+' '_-')

# Combine JWT
CLIENT_ASSERTION="${HEADER}.${PAYLOAD}.${SIGNATURE}"

echo "Obtaining Authentik OAuth2 token via private_key_jwt..."

# Request token using client_assertion
TOKEN_RESPONSE=$(curl -s -X POST "${ISSUER_URL}token/" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  -d "client_assertion=${CLIENT_ASSERTION}" \
  -d "scope=${SCOPE}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty' 2>/dev/null || echo "")

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
  ERROR=$(echo "$TOKEN_RESPONSE" | jq -r '.error // "unknown"' 2>/dev/null || echo "parse_error")
  ERROR_DESC=$(echo "$TOKEN_RESPONSE" | jq -r '.error_description // ""' 2>/dev/null || echo "")
  echo "Error: Failed to obtain OAuth2 token via private_key_jwt: $ERROR - $ERROR_DESC" >&2
  echo "Response: $TOKEN_RESPONSE" >&2
  exit 1
fi

# Export variables for Terraform
export AUTHENTIK_URL="$AUTHENTIK_URL"
export AUTHENTIK_TOKEN="$ACCESS_TOKEN"

echo "✓ Authentik OAuth2 token obtained via private_key_jwt"
echo "✓ AUTHENTIK_URL and AUTHENTIK_TOKEN are now set"
echo ""
echo "You can now run:"
echo "  terraform plan"
echo "  terraform apply"
