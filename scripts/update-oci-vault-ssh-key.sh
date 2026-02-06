#!/usr/bin/env bash
# Mettre à jour le secret SSH dans OCI Vault avec une clé privée locale
# Usage: ./scripts/update-oci-vault-ssh-key.sh [path-to-private-key]

set -e

PRIV_KEY_FILE="${1:-${HOME}/.ssh/oci_mgmt_key_20260206_110015}"

if [[ ! -f "$PRIV_KEY_FILE" ]]; then
  echo "❌ Error: Clé privée non trouvée: $PRIV_KEY_FILE"
  echo ""
  echo "Usage: $0 [path-to-private-key]"
  echo ""
  echo "Ou utilise le workflow GitHub Actions:"
  echo "  Actions → 'Rotate OCI SSH key' → Run workflow"
  exit 1
fi

echo "=== Mise à jour du secret SSH dans OCI Vault ==="
echo "Clé privée: $PRIV_KEY_FILE"
echo ""

# Vérifier que OCI CLI est installé
if ! command -v oci &> /dev/null; then
  echo "❌ Error: OCI CLI not found. Install: brew install oci-cli"
  exit 1
fi

# Vérifier l'authentification OCI
if ! oci iam region list &>/dev/null; then
  echo "❌ Error: OCI CLI not authenticated. Run: oci setup config"
  exit 1
fi

# Lire le compartment ID depuis les variables d'environnement ou Terraform
COMPARTMENT_ID="${OCI_COMPARTMENT_ID:-}"

# Essayer de récupérer depuis Terraform output si disponible
if [[ -z "$COMPARTMENT_ID" ]]; then
  TF_DIR="$(dirname "$0")/../terraform/oracle-cloud"
  if [[ -d "$TF_DIR" ]]; then
    cd "$TF_DIR" 2>/dev/null || true
    if command -v terraform &>/dev/null && [[ -f terraform.tfstate ]] || [[ -f .terraform/terraform.tfstate ]]; then
      COMPARTMENT_ID=$(terraform output -raw compartment_id 2>/dev/null || true)
      if [[ -n "$COMPARTMENT_ID" ]]; then
        echo "✓ Compartment ID trouvé via Terraform: $COMPARTMENT_ID"
      fi
    fi
    cd - >/dev/null
  fi
fi

# Utiliser le tenancy par défaut si aucun compartment n'est trouvé
if [[ -z "$COMPARTMENT_ID" ]]; then
  echo "⚠️  Aucun compartment ID trouvé, recherche dans tous les compartments..."
  # Lister tous les compartments pour trouver le vault
  COMPARTMENT_ID=""
else
  echo "Compartment ID: $COMPARTMENT_ID"
fi

# Chercher le secret directement (plus simple que de chercher le vault d'abord)
echo "Recherche du secret 'homelab-oci-mgmt-ssh-private-key'..."

# Si on a un compartment ID, chercher dedans
if [[ -n "$COMPARTMENT_ID" ]]; then
  SECRET_ID=$(oci vault secret list \
    --compartment-id "$COMPARTMENT_ID" \
    --name "homelab-oci-mgmt-ssh-private-key" \
    --lifecycle-state ACTIVE \
    --query 'data[0].id' \
    --raw-output 2>/dev/null || true)
else
  # Sinon, utiliser le tenancy depuis la config OCI
  echo "Récupération du tenancy ID depuis la configuration OCI..."
  TENANCY_ID=$(grep "^tenancy" ~/.oci/config 2>/dev/null | head -1 | cut -d'=' -f2 | tr -d ' ')
  if [[ -n "$TENANCY_ID" ]]; then
    echo "Tenancy ID: $TENANCY_ID"
    echo "Recherche du secret dans le tenancy..."
    # Chercher dans le tenancy (compartment racine) avec --all pour pagination
    SECRET_ID=$(oci vault secret list \
      --compartment-id "$TENANCY_ID" \
      --name "homelab-oci-mgmt-ssh-private-key" \
      --lifecycle-state ACTIVE \
      --all \
      --query 'data[0].id' \
      --raw-output 2>/dev/null || true)

    # Si pas trouvé, essayer de chercher dans les compartments enfants
    if [[ -z "$SECRET_ID" || "$SECRET_ID" == "null" ]]; then
      echo "⚠️  Secret non trouvé dans le tenancy racine"
      echo "   Le secret pourrait être dans un sous-compartment"
      echo "   Pour accélérer, définis OCI_COMPARTMENT_ID:"
      echo "   export OCI_COMPARTMENT_ID=\"ocid1.compartment.oc1..xxxxx\""
      exit 1
    fi
  else
    echo "❌ Error: Impossible de récupérer le tenancy ID depuis ~/.oci/config"
    exit 1
  fi
fi

if [[ -z "$SECRET_ID" || "$SECRET_ID" == "null" ]]; then
  echo "❌ Error: Secret 'homelab-oci-mgmt-ssh-private-key' non trouvé dans OCI Vault."
  echo ""
  echo "Le secret doit être créé par Terraform d'abord:"
  echo "  1. Actions → 'Terraform Oracle Cloud' → action=apply, env=production"
  echo "  2. Ou créer le vault manuellement via OCI Console"
  exit 1
fi

echo "✓ Secret trouvé: $SECRET_ID"
echo ""

# Encoder la clé privée en base64
echo "Encodage de la clé privée..."
if base64 --help 2>/dev/null | grep -q '\-w'; then
  BASE64_CONTENT=$(base64 -w 0 < "$PRIV_KEY_FILE")
else
  BASE64_CONTENT=$(base64 < "$PRIV_KEY_FILE" | tr -d '\n')
fi

# Mettre à jour le secret
echo "Mise à jour du secret dans OCI Vault..."
oci vault secret update-base64 \
  --secret-id "$SECRET_ID" \
  --secret-content-content "$BASE64_CONTENT" \
  --force

echo ""
echo "✓ Secret OCI Vault mis à jour avec succès!"
echo ""
echo "Prochaines étapes:"
echo "1. Tester le workflow Terraform:"
echo "   Actions → 'Terraform Oracle Cloud' → action=plan, env=development"
echo ""
echo "2. Si des VMs existent déjà, elles doivent être recréées pour utiliser la nouvelle clé publique:"
echo "   Actions → 'Terraform Oracle Cloud' → action=apply, env=production"
echo "   (Cela mettra à jour les authorized_keys sur les VMs)"
