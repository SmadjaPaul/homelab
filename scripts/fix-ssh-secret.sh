#!/usr/bin/env bash
# Script de correction rapide pour SSH_PUBLIC_KEY
# Usage: ./scripts/fix-ssh-secret.sh [--generate-new]

set -e

REPO="${GITHUB_REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
GENERATE_NEW=false

[[ "${1:-}" == "--generate-new" ]] && GENERATE_NEW=true

echo "Repository: $REPO"
echo ""

# Vérifier que gh CLI est installé
if ! command -v gh &> /dev/null; then
  echo "❌ Error: gh CLI not found. Install: brew install gh"
  exit 1
fi

# Vérifier que l'utilisateur est authentifié
if ! gh auth status &>/dev/null; then
  echo "❌ Error: Not authenticated to GitHub. Run: gh auth login"
  exit 1
fi

if [[ "$GENERATE_NEW" == "true" ]]; then
  echo "=== Génération d'une nouvelle paire de clés SSH ==="
  KEY_DIR="${HOME}/.ssh"
  KEY_FILE="${KEY_DIR}/oci_mgmt_key_$(date +%Y%m%d_%H%M%S)"

  ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "oci-mgmt-ci-$(date +%Y%m%d)"
  chmod 600 "$KEY_FILE"

  echo ""
  echo "✓ Clés générées:"
  echo "  Private: $KEY_FILE"
  echo "  Public:  ${KEY_FILE}.pub"
  echo ""

  PUB_KEY_FILE="${KEY_FILE}.pub"
  PRIV_KEY_FILE="$KEY_FILE"
else
  echo "=== Utilisation d'une clé existante ==="
  echo -n "Chemin vers la clé publique (.pub): "
  read -r PUB_KEY_FILE

  if [[ ! -f "$PUB_KEY_FILE" ]]; then
    echo "❌ Error: File not found: $PUB_KEY_FILE"
    exit 1
  fi

  # Deviner le chemin de la clé privée
  PRIV_KEY_FILE="${PUB_KEY_FILE%.pub}"
  if [[ ! -f "$PRIV_KEY_FILE" ]]; then
    echo -n "Chemin vers la clé privée: "
    read -r PRIV_KEY_FILE
    if [[ ! -f "$PRIV_KEY_FILE" ]]; then
      echo "❌ Error: File not found: $PRIV_KEY_FILE"
      exit 1
    fi
  fi
fi

# Valider le format de la clé publique
echo ""
echo "=== Validation du format ==="
FIRST_LINE=$(head -1 "$PUB_KEY_FILE")
if echo "$FIRST_LINE" | grep -q -- '-----BEGIN'; then
  echo "❌ Error: Le fichier semble contenir une clé privée, pas une clé publique."
  echo "   La clé publique doit commencer par 'ssh-ed25519' ou 'ssh-rsa'"
  exit 1
fi

if ! echo "$FIRST_LINE" | grep -qE '^ssh-(ed25519|rsa|dss|ecdsa) '; then
  echo "❌ Error: Format invalide. La clé publique doit commencer par 'ssh-ed25519' ou 'ssh-rsa'"
  echo "   Première ligne: $FIRST_LINE"
  exit 1
fi

echo "✓ Format de la clé publique valide"
echo "  $FIRST_LINE"

# Valider la clé privée
if ! ssh-keygen -y -f "$PRIV_KEY_FILE" >/dev/null 2>&1; then
  echo "❌ Error: Clé privée invalide"
  exit 1
fi

# Vérifier que les clés correspondent
PUB_FROM_PRIV=$(ssh-keygen -y -f "$PRIV_KEY_FILE")
PUB_FROM_FILE=$(head -1 "$PUB_KEY_FILE")
if [[ "$PUB_FROM_PRIV" != "$PUB_FROM_FILE" ]]; then
  echo "⚠️  Warning: Les clés publique et privée ne correspondent pas!"
  echo "   Public (file):  $PUB_FROM_FILE"
  echo "   Public (priv):  $PUB_FROM_PRIV"
  echo -n "   Continuer quand même? (y/N): "
  read -r confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    exit 1
  fi
fi

echo "✓ Les clés correspondent"

# Mettre à jour les secrets GitHub
echo ""
echo "=== Mise à jour des secrets GitHub ==="

echo -n "Mise à jour SSH_PUBLIC_KEY... "
gh secret set SSH_PUBLIC_KEY --repo "$REPO" < "$PUB_KEY_FILE"
echo "✓"

echo -n "Mise à jour OCI_MGMT_SSH_PRIVATE_KEY... "
gh secret set OCI_MGMT_SSH_PRIVATE_KEY --repo "$REPO" < "$PRIV_KEY_FILE"
echo "✓"

echo ""
echo "=== Résumé ==="
echo "✓ Secrets GitHub mis à jour"
echo ""
echo "Prochaines étapes:"
echo "1. Tester le workflow Terraform:"
echo "   Actions → 'Terraform Oracle Cloud' → action=plan, env=development"
echo ""
echo "2. Si OCI Vault existe déjà, mettre à jour le secret dans OCI:"
echo "   - Via le workflow 'Rotate OCI SSH key' (recommandé)"
echo "   - Ou manuellement via OCI Console"
echo ""
if [[ "$GENERATE_NEW" == "true" ]]; then
  echo "⚠️  Important: Sauvegarde les clés générées:"
  echo "   Private: $PRIV_KEY_FILE"
  echo "   Public:  $PUB_KEY_FILE"
  echo ""
  echo "   Si tu perds ces clés, tu devras les régénérer et mettre à jour"
  echo "   les authorized_keys sur toutes les VMs OCI."
fi
