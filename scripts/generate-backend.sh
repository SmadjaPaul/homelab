#!/bin/bash
# Generate Terraform backend config from Doppler secrets
# Usage: doppler run -- ./scripts/generate-backend.sh

set -e

if [ -z "$OCI_OBJECT_STORAGE_NAMESPACE" ]; then
    echo "Error: OCI_OBJECT_STORAGE_NAMESPACE not set"
    echo "Run with: doppler run -- ./scripts/generate-backend.sh"
    exit 1
fi

if [ -z "$OCI_CLI_REGION" ]; then
    OCI_CLI_REGION="eu-paris-1"
fi

cat > terraform/oke/backend.hcl <<EOF
# Auto-generated from Doppler secrets
# Do not commit this file to git

bucket   = "terraform-states"
key      = "oke/terraform.tfstate"
region   = "$OCI_CLI_REGION"
endpoint = "https://${OCI_OBJECT_STORAGE_NAMESPACE}.compat.objectstorage.${OCI_CLI_REGION}.oraclecloud.com"

skip_region_validation      = true
skip_credentials_validation = true
skip_metadata_api_check     = true
force_path_style            = true
EOF

echo "✅ Backend config generated: terraform/oke/backend.hcl"
echo ""
echo "Next steps:"
echo "  cd terraform/oke"
echo "  terraform init -backend-config=backend.hcl"
