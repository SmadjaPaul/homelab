#!/usr/bin/env bash
# Setup GitHub Actions secrets via gh CLI
#
# Usage:
#   ./scripts/gh-secrets-setup.sh                    # interactive prompts
#   ./scripts/gh-secrets-setup.sh --minimal          # only TFstate + Cloudflare
#   TFSTATE_DEV_TOKEN=ghp_xxx ./scripts/gh-secrets-setup.sh  # from env
#
# Optional env vars (skip interactive prompt when set):
#   TFSTATE_DEV_TOKEN, CLOUDFLARE_API_TOKEN,
#   OCI_CLI_USER, OCI_CLI_TENANCY, OCI_CLI_FINGERPRINT, OCI_CLI_REGION,
#   OCI_COMPARTMENT_ID, OCI_CLI_KEY_FILE, SSH_PUBLIC_KEY or SSH_PUBLIC_KEY_FILE
set -e

MINIMAL=false
[[ "${1:-}" == "--minimal" ]] && MINIMAL=true

REPO="${GITHUB_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

echo "Repository: $REPO"
echo ""

# Create environments (development, production) if they don't exist
echo "=== Environnements ==="
for env in development production; do
  if gh api --method GET "repos/$REPO/environments/$env" &>/dev/null; then
    echo "Environment '$env' already exists."
  else
    echo -n "Creating environment '$env'... "
    gh api --method PUT "repos/$REPO/environments/$env" && echo "ok" || echo "failed"
  fi
done
echo ""

echo "=== Secrets (gh secret set) ==="
echo ""

# --- TFstate.dev (obligatoire pour Terraform lock) ---
set_secret() {
  local name="$1"
  local desc="$2"
  local from_file="${3:-}"

  if [[ -n "${!name:-}" ]]; then
    echo -n "Setting $name from environment... "
    echo -n "${!name}" | gh secret set "$name" --repo "$REPO"
    echo "ok"
  elif [[ -n "$from_file" ]]; then
    if [[ -f "${!from_file:-/dev/null}" ]]; then
      echo -n "Setting $name from file \$$from_file... "
      gh secret set "$name" --repo "$REPO" < "${!from_file}"
      echo "ok"
    else
      echo -n "$desc (file path): "
      read -r path
      if [[ -f "$path" ]]; then
        gh secret set "$name" --repo "$REPO" < "$path"
        echo "ok"
      else
        echo "File not found, skipping $name"
      fi
    fi
  else
    echo -n "$desc: "
    read -rs val
    echo
    if [[ -n "$val" ]]; then
      echo -n "$val" | gh secret set "$name" --repo "$REPO"
      echo "ok"
    else
      echo "empty, skipping $name"
    fi
  fi
}

echo "=== 1. TFstate.dev (état Terraform + lock) ==="
set_secret TFSTATE_DEV_TOKEN "TFSTATE_DEV_TOKEN (GitHub PAT avec scope repo)"

echo ""
echo "=== 2. Cloudflare ==="
set_secret CLOUDFLARE_API_TOKEN "CLOUDFLARE_API_TOKEN"

if [[ "$MINIMAL" != true ]]; then
  echo ""
  echo "=== 3. Oracle Cloud (optionnel si tu n'utilises pas le workflow OCI) ==="
  set_secret OCI_CLI_USER "OCI_CLI_USER (User OCID)"
  set_secret OCI_CLI_TENANCY "OCI_CLI_TENANCY (Tenancy OCID)"
  set_secret OCI_CLI_FINGERPRINT "OCI_CLI_FINGERPRINT"
  # Clé privée: lecture depuis fichier recommandée
  if [[ -n "${OCI_CLI_KEY_FILE:-}" ]] && [[ -f "$OCI_CLI_KEY_FILE" ]]; then
    echo -n "Setting OCI_CLI_KEY_CONTENT from OCI_CLI_KEY_FILE... "
    gh secret set OCI_CLI_KEY_CONTENT --repo "$REPO" < "$OCI_CLI_KEY_FILE"
    echo "ok"
  else
    echo "OCI_CLI_KEY_CONTENT: path to PEM file (e.g. ~/.oci/oci_api_key.pem, Enter to skip):"
    read -r keypath
    keypath="${keypath/#\~/$HOME}"
    if [[ -n "$keypath" ]] && [[ -f "$keypath" ]]; then
      gh secret set OCI_CLI_KEY_CONTENT --repo "$REPO" < "$keypath"
      echo "ok"
    else
      echo "skipping OCI_CLI_KEY_CONTENT"
    fi
  fi
  set_secret OCI_CLI_REGION "OCI_CLI_REGION (e.g. eu-paris-1)"
  set_secret OCI_COMPARTMENT_ID "OCI_COMPARTMENT_ID"
  # SSH public key: peut être un fichier
  if [[ -n "${SSH_PUBLIC_KEY_FILE:-}" ]] && [[ -f "$SSH_PUBLIC_KEY_FILE" ]]; then
    echo -n "Setting SSH_PUBLIC_KEY from SSH_PUBLIC_KEY_FILE... "
    gh secret set SSH_PUBLIC_KEY --repo "$REPO" < "$SSH_PUBLIC_KEY_FILE"
    echo "ok"
  else
    set_secret SSH_PUBLIC_KEY "SSH_PUBLIC_KEY (contenu ou Enter pour skip)"
  fi
fi

echo ""
echo "Done. List secrets: gh secret list --repo $REPO"
