#!/usr/bin/env bash
# Setup OCI Identity Provider for GitHub Actions OIDC
# Creates Identity Provider, group mappings, and IAM policies via OCI CLI
#
# Usage: ./scripts/setup-oci-identity-provider.sh [--compartment-id COMPARTMENT_OCID] [--group-name GROUP_NAME]

set -e

# Default values
COMPARTMENT_ID=""
GROUP_NAME="github-actions-users"
IDENTITY_PROVIDER_NAME="github-actions-oidc"
GITHUB_REPO="${GITHUB_REPO:-SmadjaPaul/homelab}"  # Format: owner/repo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --compartment-id)
      COMPARTMENT_ID="$2"
      shift 2
      ;;
    --group-name)
      GROUP_NAME="$2"
      shift 2
      ;;
    --repo)
      GITHUB_REPO="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Check if OCI CLI is installed
if ! command -v oci &> /dev/null; then
  echo -e "${RED}❌ OCI CLI not found. Install with: brew install oci-cli${NC}"
  exit 1
fi

# Check if OCI is configured
if [ ! -f ~/.oci/config ]; then
  echo -e "${RED}❌ OCI CLI not configured. Run: oci setup config${NC}"
  exit 1
fi

# Get compartment ID if not provided
if [ -z "$COMPARTMENT_ID" ]; then
  echo -e "${YELLOW}⚠️  Compartment ID not provided.${NC}"
  echo "Available compartments:"
  oci iam compartment list --all --query "data[*].{Name:name,OCID:id}" --output table
  read -rp "Enter compartment OCID: " COMPARTMENT_ID
fi

# Get tenancy OCID
TENANCY_OCID=$(grep "^tenancy=" ~/.oci/config | cut -d'=' -f2 | xargs)
REGION=$(grep "^region=" ~/.oci/config | cut -d'=' -f2 | xargs)

echo -e "${GREEN}🚀 Setting up OCI Identity Provider for GitHub Actions OIDC${NC}"
echo "================================================================"
echo "Compartment ID: $COMPARTMENT_ID"
echo "Group Name: $GROUP_NAME"
echo "GitHub Repo: $GITHUB_REPO"
echo "Tenancy OCID: $TENANCY_OCID"
echo "Region: $REGION"
echo ""

# Step 1: Check if Identity Provider already exists
echo -e "${YELLOW}📋 Checking for existing Identity Provider...${NC}"
EXISTING_IDP=$(oci iam identity-provider list \
  --compartment-id "$TENANCY_OCID" \
  --query "data[?name=='$IDENTITY_PROVIDER_NAME'].id" \
  --raw-output 2>/dev/null | head -1 || echo "")

if [ -n "$EXISTING_IDP" ]; then
  echo -e "${GREEN}✅ Identity Provider already exists: $EXISTING_IDP${NC}"
  IDP_OCID="$EXISTING_IDP"
else
  echo -e "${YELLOW}📝 Creating Identity Provider...${NC}"

  # Create Identity Provider JSON
  IDP_JSON=$(cat <<EOF
{
  "compartmentId": "$TENANCY_OCID",
  "name": "$IDENTITY_PROVIDER_NAME",
  "description": "GitHub Actions OIDC Identity Provider for secure CI/CD authentication",
  "productType": "IDCS",
  "protocol": "SAML2.0",
  "metadataUrl": "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}
EOF
)

  # Create Identity Provider
  IDP_RESPONSE=$(echo "$IDP_JSON" | oci iam identity-provider create \
    --compartment-id "$TENANCY_OCID" \
    --from-json file:///dev/stdin 2>&1 || echo "")

  if echo "$IDP_RESPONSE" | grep -q "already exists\|duplicate"; then
    echo -e "${YELLOW}⚠️  Identity Provider may already exist, checking...${NC}"
    IDP_OCID=$(oci iam identity-provider list \
      --compartment-id "$TENANCY_OCID" \
      --query "data[?name=='$IDENTITY_PROVIDER_NAME'].id" \
      --raw-output | head -1)
  elif echo "$IDP_RESPONSE" | grep -q "id"; then
    IDP_OCID=$(echo "$IDP_RESPONSE" | jq -r '.data.id // empty' 2>/dev/null || echo "")
  else
    echo -e "${RED}❌ Failed to create Identity Provider:${NC}"
    echo "$IDP_RESPONSE"
    exit 1
  fi

  if [ -z "$IDP_OCID" ]; then
    echo -e "${RED}❌ Could not determine Identity Provider OCID${NC}"
    exit 1
  fi

  echo -e "${GREEN}✅ Identity Provider created: $IDP_OCID${NC}"
fi

# Step 2: Create IAM Group if it doesn't exist
echo ""
echo -e "${YELLOW}📋 Checking for IAM Group...${NC}"
EXISTING_GROUP=$(oci iam group list \
  --compartment-id "$TENANCY_OCID" \
  --query "data[?name=='$GROUP_NAME'].id" \
  --raw-output 2>/dev/null | head -1 || echo "")

if [ -n "$EXISTING_GROUP" ]; then
  echo -e "${GREEN}✅ Group already exists: $EXISTING_GROUP${NC}"
  GROUP_OCID="$EXISTING_GROUP"
else
  echo -e "${YELLOW}📝 Creating IAM Group...${NC}"
  GROUP_RESPONSE=$(oci iam group create \
    --compartment-id "$TENANCY_OCID" \
    --name "$GROUP_NAME" \
    --description "GitHub Actions users group for OIDC authentication" \
    --query 'data.id' \
    --raw-output 2>&1 || echo "")

  if [ -n "$GROUP_RESPONSE" ] && [[ "$GROUP_RESPONSE" =~ ^ocid1 ]]; then
    GROUP_OCID="$GROUP_RESPONSE"
    echo -e "${GREEN}✅ Group created: $GROUP_OCID${NC}"
  else
    echo -e "${RED}❌ Failed to create group:${NC}"
    echo "$GROUP_RESPONSE"
    exit 1
  fi
fi

# Step 3: Create IAM Policy for the group
echo ""
echo -e "${YELLOW}📋 Checking for IAM Policy...${NC}"
POLICY_NAME="github-actions-oidc-policy"
POLICY_STATEMENT="Allow group $GROUP_NAME to manage all-resources in compartment id $COMPARTMENT_ID"

EXISTING_POLICY=$(oci iam policy list \
  --compartment-id "$TENANCY_OCID" \
  --query "data[?name=='$POLICY_NAME'].id" \
  --raw-output 2>/dev/null | head -1 || echo "")

if [ -n "$EXISTING_POLICY" ]; then
  echo -e "${GREEN}✅ Policy already exists: $EXISTING_POLICY${NC}"
  echo -e "${YELLOW}⚠️  Updating policy statements...${NC}"
  oci iam policy update \
    --policy-id "$EXISTING_POLICY" \
    --statements "[\"$POLICY_STATEMENT\"]" \
    --version-date "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
    > /dev/null 2>&1 || echo "Note: Policy update may require manual review"
else
  echo -e "${YELLOW}📝 Creating IAM Policy...${NC}"
  POLICY_RESPONSE=$(oci iam policy create \
    --compartment-id "$TENANCY_OCID" \
    --name "$POLICY_NAME" \
    --description "IAM policy for GitHub Actions OIDC authentication" \
    --statements "[\"$POLICY_STATEMENT\"]" \
    --query 'data.id' \
    --raw-output 2>&1 || echo "")

  if [ -n "$POLICY_RESPONSE" ] && [[ "$POLICY_RESPONSE" =~ ^ocid1 ]]; then
    echo -e "${GREEN}✅ Policy created: $POLICY_RESPONSE${NC}"
  else
    echo -e "${YELLOW}⚠️  Policy creation may have failed or already exists:${NC}"
    echo "$POLICY_RESPONSE"
  fi
fi

# Step 4: Create Group Mapping (if supported)
echo ""
echo -e "${YELLOW}📋 Note: Group mapping configuration${NC}"
echo "Group mapping for Identity Provider must be configured via OCI Console:"
echo "1. Navigate to: Identity & Security → Domains → Default Domain → Identity Providers"
echo "2. Select: $IDENTITY_PROVIDER_NAME"
echo "3. Configure group mapping:"
echo "   - Map GitHub repository '$GITHUB_REPO' to group '$GROUP_NAME'"
echo "   - Subject claim: 'sub'"
echo "   - Match: 'repo:$GITHUB_REPO:*'"

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Summary:"
echo "--------"
echo "Identity Provider OCID: $IDP_OCID"
echo "Group OCID: $GROUP_OCID"
echo ""
echo "Next steps:"
echo "1. Configure group mapping in OCI Console (see above)"
echo "2. Test OIDC authentication in GitHub Actions workflow"
echo "3. Verify tokens are exchanged successfully"
