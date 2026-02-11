#!/bin/bash
# Create or update only the OpenClaw gateway token in OCI Vault.
# Usage: ./scripts/create-openclaw-secret.sh
#        OPENCLAW_GATEWAY_TOKEN='existing-token' ./scripts/create-openclaw-secret.sh  # optional
#
# Requires: OCI CLI configured, Terraform state (oracle-cloud) for Vault/Key OCIDs.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform/oracle-cloud"

echo "=== Fetching Vault configuration from Terraform state ==="
cd "$TF_DIR"
VAULT_ID=$(terraform output -json vault_secrets 2>/dev/null | jq -r '.vault_id')
KEY_ID=$(terraform state show oci_kms_key.homelab_secrets_key 2>/dev/null | grep '^\s*id\s*=' | head -1 | awk -F'"' '{print $2}')
COMPARTMENT_ID=$(terraform state show oci_kms_vault.homelab_secrets 2>/dev/null | grep '^\s*compartment_id\s*=' | head -1 | awk -F'"' '{print $2}')

if [[ -z "$COMPARTMENT_ID" || "$COMPARTMENT_ID" == "null" ]]; then
    COMPARTMENT_ID=$(grep '^tenancy=' ~/.oci/config 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d ' ' || true)
fi
if [[ -z "$COMPARTMENT_ID" || "$COMPARTMENT_ID" == "null" ]]; then
    COMPARTMENT_ID=$(oci iam compartment list --all --query "data[?name=='root'].id" --raw-output 2>/dev/null | head -1 | tr -d '"')
fi

if [[ -z "$VAULT_ID" || -z "$KEY_ID" || -z "$COMPARTMENT_ID" ]]; then
    echo "ERROR: Could not retrieve Vault configuration from Terraform state"
    echo "Run: terraform -chdir=terraform/oracle-cloud init (and apply once)"
    exit 1
fi

echo "  Vault: ${VAULT_ID:0:50}..."

if [[ -z "$OPENCLAW_GATEWAY_TOKEN" ]]; then
    echo "Generating OPENCLAW_GATEWAY_TOKEN..."
    OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32 | tr -d '\n')
fi

SECRET_NAME="homelab-openclaw-gateway-token"
EXISTING=$(oci vault secret list \
    --compartment-id "$COMPARTMENT_ID" \
    --name "$SECRET_NAME" \
    --lifecycle-state ACTIVE \
    --query 'data[0].id' \
    --raw-output 2>/dev/null || true)

if [[ -n "$EXISTING" && "$EXISTING" != "null" ]]; then
    echo "Updating existing secret: $SECRET_NAME"
    oci vault secret update-base64 \
        --secret-id "$EXISTING" \
        --secret-content-content "$(echo -n "$OPENCLAW_GATEWAY_TOKEN" | base64)" \
        --force
    echo "✓ Updated: $SECRET_NAME"
else
    echo "Creating secret: $SECRET_NAME"
    oci vault secret create-base64 \
        --compartment-id "$COMPARTMENT_ID" \
        --vault-id "$VAULT_ID" \
        --key-id "$KEY_ID" \
        --secret-name "$SECRET_NAME" \
        --secret-content-content "$(echo -n "$OPENCLAW_GATEWAY_TOKEN" | base64)" \
        --description "OpenClaw gateway token for CLI/apps"
    echo "✓ Created: $SECRET_NAME"
fi

echo ""
echo "Secrets in this vault (same as console):"
oci vault secret list --compartment-id "$COMPARTMENT_ID" --vault-id "$VAULT_ID" --lifecycle-state ACTIVE --all --query 'data[*].name' --raw-output 2>/dev/null | tr -d '[]"' | tr ',' '\n' | sed 's/^ *//' | sort
echo ""
echo "Done. Next: redeploy OCI mgmt stack so the container gets this token (e.g. push to main or run deploy-oci-mgmt workflow)."
