#!/usr/bin/env bash
# Generate OCI session token and upload to GitHub Actions secrets.
# Replaces long-lived API keys in CI with short-lived session tokens.
#
# Prerequisites: OCI CLI installed, gh CLI installed and authenticated.
# Usage:
#   ./scripts/oci-session-auth-to-gh.sh
#   ./scripts/oci-session-auth-to-gh.sh --region eu-paris-1 --exp-time 120
#
# Options:
#   --region REGION    OCI region (default: eu-paris-1)
#   --exp-time MIN     Session expiration in minutes, 5-60 (default: 60)
#   --profile NAME     OCI config profile name (default: github-actions)
#   --repo OWNER/REPO  GitHub repo (default: current gh repo)
#
# After running: a browser window opens to log in to OCI. Then the script
# reads the generated session and sets GitHub secrets:
#   OCI_SESSION_TOKEN, OCI_SESSION_PRIVATE_KEY, OCI_CLI_USER, OCI_CLI_TENANCY,
#   OCI_CLI_FINGERPRINT, OCI_CLI_REGION
#
# Note: Token expires after exp-time. Re-run this script periodically to refresh.
# See: https://docs.oracle.com/en/learn/github-auth-session-token/
set -e

REGION="${OCI_CLI_REGION:-eu-paris-1}"
EXP_TIME=60
PROFILE="github-actions"
REPO=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --region)   REGION="$2"; shift 2 ;;
    --exp-time) EXP_TIME="$2"; shift 2 ;;
    --profile)  PROFILE="$2"; shift 2 ;;
    --repo)     REPO="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ $EXP_TIME -lt 5 || $EXP_TIME -gt 60 ]]; then
  echo "exp-time must be between 5 and 60 minutes."
  exit 1
fi

REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
CONFIG_FILE="${OCI_CONFIG_FILE:-$HOME/.oci/config}"

echo "=== OCI Session Token → GitHub Secrets ==="
echo "Region: $REGION | Expiration: ${EXP_TIME} min | Profile: $PROFILE | Repo: $REPO"
echo ""

if ! command -v oci >/dev/null 2>&1; then
  echo "Error: OCI CLI not found. Install: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm"
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) not found. Install: https://cli.github.com/"
  exit 1
fi

echo "Running: oci session authenticate (browser will open for OCI login)..."
oci session authenticate \
  --region "$REGION" \
  --profile-name "$PROFILE" \
  --session-expiration-in-minutes "$EXP_TIME" \
  --config-file "$CONFIG_FILE"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found: $CONFIG_FILE"
  exit 1
fi

# Parse [PROFILE] section: user, tenancy, region, fingerprint, security_token_file, key_file
get_ini() {
  local file="$1" section="$2" key="$3"
  awk -v sec="[$section]" -v k="$key" '
    $0 == sec { in_sec=1; next }
    in_sec && /^\[/ { exit }
    in_sec && $0 ~ "^" k "=" { sub(/^[^=]+=/, ""); gsub(/^[ \t]+|[ \t]+$/, ""); print; exit }
  ' "$file"
}

expand_path() {
  local p="$1"
  p="${p/#\~/$HOME}"
  [[ "$p" != /* ]] && p="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$p"
  echo "$p"
}

# Session profiles may not have user/fingerprint; fallback to DEFAULT profile
USER_OCID=$(get_ini "$CONFIG_FILE" "$PROFILE" "user")
[[ -z "$USER_OCID" ]] && USER_OCID=$(get_ini "$CONFIG_FILE" "DEFAULT" "user")

TENANCY_OCID=$(get_ini "$CONFIG_FILE" "$PROFILE" "tenancy")
[[ -z "$TENANCY_OCID" ]] && TENANCY_OCID=$(get_ini "$CONFIG_FILE" "DEFAULT" "tenancy")

REGION_VAL=$(get_ini "$CONFIG_FILE" "$PROFILE" "region")
[[ -z "$REGION_VAL" ]] && REGION_VAL=$(get_ini "$CONFIG_FILE" "DEFAULT" "region")

FINGERPRINT=$(get_ini "$CONFIG_FILE" "$PROFILE" "fingerprint")
[[ -z "$FINGERPRINT" ]] && FINGERPRINT=$(get_ini "$CONFIG_FILE" "DEFAULT" "fingerprint")

TOKEN_FILE=$(get_ini "$CONFIG_FILE" "$PROFILE" "security_token_file")
KEY_FILE=$(get_ini "$CONFIG_FILE" "$PROFILE" "key_file")

[[ -z "$TENANCY_OCID" ]] && { echo "Error: Could not find tenancy in profile [$PROFILE] or [DEFAULT]."; exit 1; }
[[ -z "$TOKEN_FILE" || -z "$KEY_FILE" ]] && { echo "Error: Profile [$PROFILE] missing security_token_file or key_file."; exit 1; }

TOKEN_FILE=$(expand_path "$TOKEN_FILE")
KEY_FILE=$(expand_path "$KEY_FILE")
[[ -z "$REGION_VAL" ]] && REGION_VAL="$REGION"

if [[ ! -f "$TOKEN_FILE" || ! -f "$KEY_FILE" ]]; then
  echo "Error: Token or key file not found. Token: $TOKEN_FILE Key: $KEY_FILE"
  exit 1
fi

echo "Setting GitHub secrets for $REPO..."
gh secret set OCI_SESSION_TOKEN --repo "$REPO" < "$TOKEN_FILE"
gh secret set OCI_SESSION_PRIVATE_KEY --repo "$REPO" < "$KEY_FILE"
echo -n "$USER_OCID" | gh secret set OCI_CLI_USER --repo "$REPO"
echo -n "$TENANCY_OCID" | gh secret set OCI_CLI_TENANCY --repo "$REPO"
echo -n "$FINGERPRINT" | gh secret set OCI_CLI_FINGERPRINT --repo "$REPO"
echo -n "$REGION_VAL" | gh secret set OCI_CLI_REGION --repo "$REPO"

echo ""
echo "Done. Secrets set: OCI_SESSION_TOKEN, OCI_SESSION_PRIVATE_KEY, OCI_CLI_USER, OCI_CLI_TENANCY, OCI_CLI_FINGERPRINT, OCI_CLI_REGION"
echo "Token expires in ${EXP_TIME} minutes. Re-run this script to refresh."
echo ""
echo "Optional (if not already set): OCI_COMPARTMENT_ID, OCI_OBJECT_STORAGE_NAMESPACE, SSH_PUBLIC_KEY"
echo "  Use: ./scripts/gh-secrets-setup.sh (skip OCI API key; set compartment, namespace, SSH key only)"
