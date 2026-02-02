#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# OCI Vault Secrets Setup — Populate secrets in OCI Vault
#
# This script updates secret values in OCI Vault. Secrets must already exist
# (created by Terraform). Run after `terraform apply` on oracle-cloud module.
#
# Usage:
#   ./scripts/oci-vault-secrets-setup.sh                  # Interactive prompts
#   ./scripts/oci-vault-secrets-setup.sh --from-gh        # Copy from GitHub Secrets
#   ./scripts/oci-vault-secrets-setup.sh --list           # List current secrets
#
# Prerequisites:
#   - OCI CLI configured (~/.oci/config)
#   - Terraform oracle-cloud applied (secrets exist in Vault)
#   - gh CLI (for --from-gh option)
#
# Secrets managed:
#   - homelab-cloudflare-api-token    : Cloudflare API Token
#   - homelab-tfstate-dev-token       : GitHub PAT for TFstate.dev
#   - homelab-omni-db-user            : Omni PostgreSQL user
#   - homelab-omni-db-password        : Omni PostgreSQL password
#   - homelab-omni-db-name            : Omni PostgreSQL database name
#   - homelab-oci-mgmt-ssh-private-key: SSH private key for OCI management VM
# -----------------------------------------------------------------------------
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# OCI Vault configuration (from Terraform output)
get_vault_info() {
  cd "$PROJECT_ROOT/terraform/oracle-cloud"
  terraform output -json vault_secrets 2>/dev/null || echo '{}'
}

VAULT_INFO=$(get_vault_info)
VAULT_ID=$(echo "$VAULT_INFO" | jq -r '.vault_id // empty')

if [[ -z "$VAULT_ID" ]]; then
  echo -e "${RED}Error: Could not get vault_id from Terraform output.${NC}"
  echo "Make sure you have run 'terraform apply' in terraform/oracle-cloud/"
  exit 1
fi

# Secret OCIDs from Terraform output
get_secret_ocid() {
  local secret_name="$1"
  echo "$VAULT_INFO" | jq -r ".secrets.${secret_name} // empty"
}

# List secrets and their current status
list_secrets() {
  echo -e "${GREEN}=== OCI Vault Secrets ===${NC}"
  echo "Vault ID: $VAULT_ID"
  echo ""

  local secrets=(
    "cloudflare_api_token:homelab-cloudflare-api-token"
    "tfstate_dev_token:homelab-tfstate-dev-token"
    "omni_db_user:homelab-omni-db-user"
    "omni_db_password:homelab-omni-db-password"
    "omni_db_name:homelab-omni-db-name"
    "oci_mgmt_ssh_private_key:homelab-oci-mgmt-ssh-private-key"
  )

  for item in "${secrets[@]}"; do
    local tf_name="${item%%:*}"
    local secret_name="${item##*:}"
    local ocid
    ocid=$(get_secret_ocid "$tf_name")

    if [[ -n "$ocid" ]]; then
      # Get secret metadata
      local state
      state=$(oci vault secret get --secret-id "$ocid" --query 'data."lifecycle-state"' --raw-output 2>/dev/null || echo "UNKNOWN")
      echo -e "  ${GREEN}✓${NC} $secret_name ($state)"
    else
      echo -e "  ${RED}✗${NC} $secret_name (not found in Terraform output)"
    fi
  done
}

# Update a secret value in OCI Vault
update_secret() {
  local secret_ocid="$1"
  local secret_value="$2"
  local secret_name="$3"

  if [[ -z "$secret_ocid" ]]; then
    echo -e "${RED}Error: Secret OCID not found for $secret_name${NC}"
    return 1
  fi

  # Encode value as base64
  local content_base64
  content_base64=$(echo -n "$secret_value" | base64)

  echo -n "Updating $secret_name... "

  # Create new secret version
  if oci vault secret update-base64 \
    --secret-id "$secret_ocid" \
    --secret-content-content "$content_base64" \
    >/dev/null 2>&1; then
    echo -e "${GREEN}ok${NC}"
  else
    echo -e "${RED}failed${NC}"
    return 1
  fi
}

# Read secret value from user (supports multiline for SSH keys)
read_secret_value() {
  local prompt="$1"
  local is_multiline="${2:-false}"
  local value=""

  if [[ "$is_multiline" == "true" ]]; then
    echo -e "${YELLOW}$prompt (paste content, then press Ctrl+D on empty line):${NC}"
    value=$(cat)
  else
    echo -n "$prompt: "
    read -rs value
    echo ""
  fi

  echo "$value"
}

# Interactive setup
interactive_setup() {
  echo -e "${GREEN}=== OCI Vault Secrets Setup (Interactive) ===${NC}"
  echo ""
  echo "This will update secret values in OCI Vault."
  echo "Press Enter to skip a secret (keep current value)."
  echo ""

  # Cloudflare API Token
  local cf_ocid
  cf_ocid=$(get_secret_ocid "cloudflare_api_token")
  if [[ -n "$cf_ocid" ]]; then
    echo -n "Cloudflare API Token (Enter to skip): "
    read -rs cf_token
    echo ""
    [[ -n "$cf_token" ]] && update_secret "$cf_ocid" "$cf_token" "homelab-cloudflare-api-token"
  fi

  # TFstate.dev Token
  local tf_ocid
  tf_ocid=$(get_secret_ocid "tfstate_dev_token")
  if [[ -n "$tf_ocid" ]]; then
    echo -n "TFstate.dev Token / GitHub PAT (Enter to skip): "
    read -rs tf_token
    echo ""
    [[ -n "$tf_token" ]] && update_secret "$tf_ocid" "$tf_token" "homelab-tfstate-dev-token"
  fi

  # Omni DB User
  local omni_user_ocid
  omni_user_ocid=$(get_secret_ocid "omni_db_user")
  if [[ -n "$omni_user_ocid" ]]; then
    echo -n "Omni DB User (Enter to skip): "
    read -r omni_user
    [[ -n "$omni_user" ]] && update_secret "$omni_user_ocid" "$omni_user" "homelab-omni-db-user"
  fi

  # Omni DB Password
  local omni_pass_ocid
  omni_pass_ocid=$(get_secret_ocid "omni_db_password")
  if [[ -n "$omni_pass_ocid" ]]; then
    echo -n "Omni DB Password (Enter to skip): "
    read -rs omni_pass
    echo ""
    [[ -n "$omni_pass" ]] && update_secret "$omni_pass_ocid" "$omni_pass" "homelab-omni-db-password"
  fi

  # Omni DB Name
  local omni_name_ocid
  omni_name_ocid=$(get_secret_ocid "omni_db_name")
  if [[ -n "$omni_name_ocid" ]]; then
    echo -n "Omni DB Name (Enter to skip): "
    read -r omni_name
    [[ -n "$omni_name" ]] && update_secret "$omni_name_ocid" "$omni_name" "homelab-omni-db-name"
  fi

  # SSH Private Key
  local ssh_ocid
  ssh_ocid=$(get_secret_ocid "oci_mgmt_ssh_private_key")
  if [[ -n "$ssh_ocid" ]]; then
    echo ""
    echo -e "${YELLOW}SSH Private Key for OCI Management VM${NC}"
    echo "Option 1: Provide file path"
    echo "Option 2: Paste key content"
    echo -n "File path (or Enter to paste): "
    read -r ssh_path

    if [[ -n "$ssh_path" ]] && [[ -f "$ssh_path" ]]; then
      local ssh_key
      ssh_key=$(cat "$ssh_path")
      update_secret "$ssh_ocid" "$ssh_key" "homelab-oci-mgmt-ssh-private-key"
    elif [[ -z "$ssh_path" ]]; then
      echo "Paste SSH private key (Ctrl+D when done):"
      local ssh_key
      ssh_key=$(cat)
      [[ -n "$ssh_key" ]] && update_secret "$ssh_ocid" "$ssh_key" "homelab-oci-mgmt-ssh-private-key"
    fi
  fi

  echo ""
  echo -e "${GREEN}Done!${NC}"
}

# Copy from GitHub Secrets (requires gh CLI)
from_github_secrets() {
  echo -e "${GREEN}=== Copy from GitHub Secrets to OCI Vault ===${NC}"
  echo ""

  if ! command -v gh &>/dev/null; then
    echo -e "${RED}Error: gh CLI not installed${NC}"
    exit 1
  fi

  local repo
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)

  if [[ -z "$repo" ]]; then
    echo -e "${RED}Error: Could not determine GitHub repo${NC}"
    exit 1
  fi

  echo "Repository: $repo"
  echo ""
  echo -e "${YELLOW}Note: GitHub Secrets cannot be read via API.${NC}"
  echo "This option will guide you to manually copy each secret."
  echo ""

  echo "GitHub Secrets to copy to OCI Vault:"
  echo "  CLOUDFLARE_API_TOKEN    -> homelab-cloudflare-api-token"
  echo "  TFSTATE_DEV_TOKEN       -> homelab-tfstate-dev-token"
  echo "  OMNI_DB_USER            -> homelab-omni-db-user"
  echo "  OMNI_DB_PASSWORD        -> homelab-omni-db-password"
  echo "  OMNI_DB_NAME            -> homelab-omni-db-name"
  echo "  OCI_MGMT_SSH_PRIVATE_KEY-> homelab-oci-mgmt-ssh-private-key"
  echo ""
  echo "Run this script without arguments for interactive mode."
}

# Main
case "${1:-}" in
  --list)
    list_secrets
    ;;
  --from-gh)
    from_github_secrets
    ;;
  --help|-h)
    echo "Usage: $0 [--list|--from-gh|--help]"
    echo ""
    echo "Options:"
    echo "  --list     List current secrets and their status"
    echo "  --from-gh  Guide to copy from GitHub Secrets"
    echo "  --help     Show this help"
    echo ""
    echo "Without arguments: interactive mode to update secrets"
    ;;
  *)
    interactive_setup
    ;;
esac
