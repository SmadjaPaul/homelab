#!/bin/bash
#
# Vérification des secrets GitHub avant déploiement
# Usage: ./scripts/check-secrets.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Vérification des Secrets GitHub${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Liste des secrets requis
declare -A secrets_required
secrets_required=(
    # Cloudflare
    ["CLOUDFLARE_API_TOKEN"]="Token API Cloudflare"
    ["CLOUDFLARE_ZONE_ID"]="Zone ID Cloudflare"
    ["CLOUDFLARE_ACCOUNT_ID"]="Account ID Cloudflare"
    ["CLOUDFLARE_TUNNEL_SECRET"]="Secret pour le tunnel"

    # OCI
    ["OCI_COMPARTMENT_ID"]="OCID du compartment OCI"
    ["OCI_USER_OCID"]="OCID de l'utilisateur"
    ["OCI_CLI_USER"]="Nom d'utilisateur OCI"
    ["OCI_CLI_TENANCY"]="OCID du tenancy"
    ["OCI_CLI_FINGERPRINT"]="Fingerprint de la clé API"
    ["OCI_CLI_KEY_CONTENT"]="Contenu de la clé privée"

    # SSH
    ["SSH_PUBLIC_KEY"]="Clé SSH publique"
    ["TAILSCALE_AUTH_KEY"]="Clé Tailscale"

    # Omni
    ["OMNI_ENDPOINT"]="URL Omni (https://xxx.omni.siderolabs.io:50001)"
    ["OMNI_KEY"]="Clé API Omni"

    # Doppler
    ["DOPPLER_TOKEN"]="Token Doppler infrastructure"

    # Divers
    ["ALERT_EMAIL"]="Email pour les alertes"
)

# Secrets optionnels
declare -A secrets_optional
secrets_optional=(
    ["CLOUDFLARE_TUNNEL_ID"]="ID du tunnel (laisser vide pour en créer un)"
    ["SSH_PRIVATE_KEY"]="Clé SSH privée (optionnel)"
    ["ENABLE_GEO_RESTRICTION"]="Activer restriction géo (true/false)"
    ["ALLOWED_EMAILS"]="Emails autorisés (séparés par des virgules)"
)

echo -e "${YELLOW}Vérification via l'API GitHub...${NC}"
echo ""

# Vérifier si gh CLI est installé
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) n'est pas installé${NC}"
    echo "Installez-le: brew install gh"
    echo ""
    echo "Alternative: vérifiez manuellement dans GitHub:"
    echo "Settings → Secrets and variables → Actions"
    exit 1
fi

# Vérifier si authentifié
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Non authentifié avec GitHub CLI${NC}"
    echo "Lancez: gh auth login"
    exit 1
fi

# Récupérer le repo actuel
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")

if [ -z "$REPO" ]; then
    read -p "Nom du repository (format: owner/repo): " REPO
fi

echo "Repository: $REPO"
echo ""

# Vérifier les secrets requis
echo -e "${BLUE}Secrets Requis:${NC}"
echo "============================================"

missing_required=0
for secret in "${!secrets_required[@]}"; do
    description="${secrets_required[$secret]}"

    if gh secret list -R "$REPO" | grep -q "^$secret\b"; then
        echo -e "${GREEN}✅ $secret${NC}"
    else
        echo -e "${RED}❌ $secret${NC} - $description"
        missing_required=$((missing_required + 1))
    fi
done

echo ""
echo -e "${BLUE}Secrets Optionnels:${NC}"
echo "============================================"

for secret in "${!secrets_optional[@]}"; do
    description="${secrets_optional[$secret]}"

    if gh secret list -R "$REPO" | grep -q "^$secret\b"; then
        echo -e "${GREEN}✅ $secret${NC}"
    else
        echo -e "${YELLOW}⚠️  $secret${NC} - $description"
    fi
done

echo ""
echo "============================================"

if [ $missing_required -eq 0 ]; then
    echo -e "${GREEN}✅ Tous les secrets requis sont configurés!${NC}"
    echo ""
    echo "Vous pouvez lancer le déploiement:"
    echo "  GitHub Actions → 'Deploy Infrastructure' → Run workflow"
    exit 0
else
    echo -e "${RED}❌ $missing_required secret(s) requis manquant(s)${NC}"
    echo ""
    echo "Pour ajouter les secrets manquants:"
    echo "  1. Allez sur https://github.com/$REPO/settings/secrets/actions"
    echo "  2. Cliquez sur 'New repository secret'"
    echo "  3. Ajoutez chaque secret manquant"
    echo ""
    echo "Ou utilisez la commande:"
    echo "  gh secret set NOM_DU_SECRET -b 'valeur' -R $REPO"
    echo ""
    echo "Voir docs/GITHUB_SECRETS.md pour plus de détails"
    exit 1
fi
