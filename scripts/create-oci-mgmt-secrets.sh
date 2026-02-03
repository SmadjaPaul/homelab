#!/bin/bash
# Create OCI Vault secrets for the management stack
# Usage: ./scripts/create-oci-mgmt-secrets.sh
#
# Requires:
# - OCI CLI configured
# - Terraform state accessible (for Vault/Key OCIDs)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform/oracle-cloud"

echo "=== Fetching Vault configuration from Terraform state ==="

# Get OCIDs from Terraform state
cd "$TF_DIR"
VAULT_ID=$(terraform output -json vault_secrets 2>/dev/null | jq -r '.vault_id')
KEY_ID=$(terraform state show oci_kms_key.homelab_secrets_key 2>/dev/null | grep '^\s*id\s*=' | head -1 | awk -F'"' '{print $2}')
COMPARTMENT_ID=$(terraform output -json vault_secrets 2>/dev/null | jq -r '.vault_id' | cut -d'.' -f5)

# Fallback: use OCI CLI to get compartment (tenancy root)
if [[ -z "$COMPARTMENT_ID" || "$COMPARTMENT_ID" == "null" ]]; then
    # shellcheck disable=SC2016
    COMPARTMENT_ID=$(oci iam compartment list --query 'data[?name==`root`].id' --raw-output 2>/dev/null | tr -d '[]" ' || true)
fi
if [[ -z "$COMPARTMENT_ID" || "$COMPARTMENT_ID" == "null" ]]; then
    COMPARTMENT_ID=$(grep 'tenancy' ~/.oci/config 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d ' ' || true)
fi

if [[ -z "$VAULT_ID" || -z "$KEY_ID" || -z "$COMPARTMENT_ID" ]]; then
    echo "ERROR: Could not retrieve Vault configuration from Terraform state"
    echo "Make sure you have run: terraform -chdir=terraform/oracle-cloud init"
    exit 1
fi

echo "  Vault ID: ${VAULT_ID:0:50}..."
echo "  Key ID: ${KEY_ID:0:50}..."
echo "  Compartment: ${COMPARTMENT_ID:0:50}..."

echo "=== OCI Management Stack - Secret Creation ==="
echo ""

# Function to create or update a secret
create_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local description="$3"

    echo "Creating secret: $secret_name"

    # Check if secret already exists
    EXISTING=$(oci vault secret list \
        --compartment-id "$COMPARTMENT_ID" \
        --name "$secret_name" \
        --lifecycle-state ACTIVE \
        --query 'data[0].id' \
        --raw-output 2>/dev/null || true)

    if [[ -n "$EXISTING" && "$EXISTING" != "null" ]]; then
        echo "  → Secret exists, updating content..."
        oci vault secret update-secret-content \
            --secret-id "$EXISTING" \
            --content "$(echo -n "$secret_value" | base64)" \
            --content-type BASE64 \
            > /dev/null
        echo "  ✓ Updated: $secret_name"
    else
        echo "  → Creating new secret..."
        oci vault secret create-base64 \
            --compartment-id "$COMPARTMENT_ID" \
            --vault-id "$VAULT_ID" \
            --key-id "$KEY_ID" \
            --secret-name "$secret_name" \
            --secret-content-content "$(echo -n "$secret_value" | base64)" \
            --description "$description" \
            > /dev/null
        echo "  ✓ Created: $secret_name"
    fi
}

# Check for required environment variables or generate them
if [[ -z "$POSTGRES_PASSWORD" ]]; then
    echo "Generating POSTGRES_PASSWORD..."
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
fi

if [[ -z "$AUTHENTIK_SECRET_KEY" ]]; then
    echo "Generating AUTHENTIK_SECRET_KEY..."
    AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d '\n')
fi

if [[ -z "$CLOUDFLARE_TUNNEL_TOKEN" ]]; then
    echo ""
    echo "⚠️  CLOUDFLARE_TUNNEL_TOKEN is required!"
    echo ""
    echo "To get the token:"
    echo "1. Go to: https://one.dash.cloudflare.com/"
    echo "2. Networks → Tunnels → Create a tunnel"
    echo "3. Name: homelab-oci-mgmt"
    echo "4. Copy the tunnel token"
    echo ""
    echo "Then run:"
    echo "  export CLOUDFLARE_TUNNEL_TOKEN='your-token'"
    echo "  $0"
    echo ""
    exit 1
fi

echo ""
echo "=== Creating secrets in OCI Vault ==="
echo ""

# Create secrets
create_secret "homelab-postgres-password" "$POSTGRES_PASSWORD" "PostgreSQL password for OCI management stack"
create_secret "homelab-authentik-secret-key" "$AUTHENTIK_SECRET_KEY" "Authentik secret key for session encryption"
create_secret "homelab-cloudflare-tunnel-token" "$CLOUDFLARE_TUNNEL_TOKEN" "Cloudflare Tunnel token for cloudflared"

echo ""
echo "=== All secrets created successfully! ==="
echo ""
echo "Next steps:"
echo "1. Configure Cloudflare Tunnel routes in the dashboard"
echo "2. Run: gh workflow run deploy-oci-mgmt.yml"
echo ""
