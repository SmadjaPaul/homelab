#!/usr/bin/env bash
# Synchronize local Terraform environment with CI configuration
# Ensures local apply works the same way as CI
#
# Usage: ./scripts/sync-local-ci-env.sh [--apply]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$PROJECT_ROOT/terraform/oracle-cloud"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

APPLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --apply)
      APPLY=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}🔄 Synchronizing local environment with CI configuration${NC}"
echo "================================================================"
echo ""

# Check if OCI CLI is configured
if [ ! -f ~/.oci/config ]; then
  echo -e "${YELLOW}⚠️  OCI CLI not configured. Run: oci setup config${NC}"
  exit 1
fi

# Get OCI configuration values
USER_OCID=$(grep "^user=" ~/.oci/config | cut -d'=' -f2 | xargs)
REGION=$(grep "^region=" ~/.oci/config | cut -d'=' -f2 | xargs)

# Get compartment ID from terraform.tfvars or prompt
if [ -f "$TF_DIR/terraform.tfvars" ]; then
  COMPARTMENT_ID=$(grep "^compartment_id" "$TF_DIR/terraform.tfvars" | cut -d'"' -f2 | head -1)
fi

if [ -z "$COMPARTMENT_ID" ]; then
  echo -e "${YELLOW}⚠️  Compartment ID not found in terraform.tfvars${NC}"
  read -rp "Enter compartment OCID: " COMPARTMENT_ID
fi

# Get namespace for backend
echo -e "${YELLOW}📋 Getting Object Storage namespace...${NC}"
NAMESPACE=$(oci os ns get --query 'data' --raw-output 2>/dev/null || echo "")

if [ -z "$NAMESPACE" ]; then
  echo -e "${YELLOW}⚠️  Could not get namespace automatically${NC}"
  read -rp "Enter Object Storage namespace: " NAMESPACE
fi

# Set environment variables (same as CI)
export TF_VAR_compartment_id="$COMPARTMENT_ID"
export TF_VAR_region="$REGION"
export TF_VAR_user_ocid="$USER_OCID"
export TF_VAR_budget_alert_email="smadjapaul02@gmail.com"
export TF_VAR_vault_secrets_managed_in_ci="true"  # Keep secrets, don't destroy them

# Get SSH public key
if [ -f ~/.ssh/oci-homelab.pub ]; then
  SSH_PUBLIC_KEY_CONTENT=$(cat ~/.ssh/oci-homelab.pub)
  export TF_VAR_ssh_public_key="$SSH_PUBLIC_KEY_CONTENT"
else
  echo -e "${YELLOW}⚠️  SSH public key not found at ~/.ssh/oci-homelab.pub${NC}"
  read -rp "Enter SSH public key: " SSH_KEY
  export TF_VAR_ssh_public_key="$SSH_KEY"
fi

# Update backend.tf with namespace (if using OCI backend)
if [ -f "$TF_DIR/backend.tf" ]; then
  echo -e "${YELLOW}📝 Updating backend.tf with namespace...${NC}"
  sed -i.bak "s/YOUR_TENANCY_NAMESPACE/$NAMESPACE/g" "$TF_DIR/backend.tf"
  echo -e "${GREEN}✅ Backend namespace updated${NC}"
fi

# Initialize Terraform
echo ""
echo -e "${YELLOW}📋 Initializing Terraform...${NC}"
cd "$TF_DIR"
terraform init -reconfigure

# Show plan
echo ""
echo -e "${YELLOW}📋 Running Terraform plan...${NC}"
terraform plan -out=tfplan

if [ "$APPLY" = true ]; then
  echo ""
  read -rp "Apply changes? (yes/no): " CONFIRM
  if [ "$CONFIRM" = "yes" ]; then
    echo -e "${GREEN}🚀 Applying Terraform changes...${NC}"
    terraform apply tfplan
    echo -e "${GREEN}✅ Apply complete!${NC}"
  else
    echo "Apply cancelled."
  fi
else
  echo ""
  echo -e "${BLUE}💡 To apply changes, run:${NC}"
  echo "   cd $TF_DIR && terraform apply tfplan"
fi

echo ""
echo -e "${GREEN}✅ Environment synchronized!${NC}"
echo ""
echo "Environment variables set:"
echo "--------------------------"
echo "TF_VAR_compartment_id=$TF_VAR_compartment_id"
echo "TF_VAR_region=$TF_VAR_region"
echo "TF_VAR_user_ocid=$TF_VAR_user_ocid"
echo "TF_VAR_budget_alert_email=$TF_VAR_budget_alert_email"
echo "TF_VAR_vault_secrets_managed_in_ci=true"
echo ""
echo "These variables are set for the current shell session."
echo "To persist them, add to your shell profile or use a .env file."
