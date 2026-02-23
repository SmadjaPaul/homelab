#!/bin/bash
#
# Script de déploiement complet - Préparation
# Usage: ./scripts/prepare-deployment.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Préparation du Déploiement${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Vérifier que nous sommes dans le bon dossier
if [ ! -f "doppler.yaml" ]; then
    echo -e "${RED}❌ Erreur: Exécutez ce script depuis la racine du projet${NC}"
    exit 1
fi

# ============================================================================
# ÉTAPE 1: Vérification des Outils
# ============================================================================
echo -e "${YELLOW}[1/8] Vérification des outils...${NC}"

for cmd in terraform kubectl helm talosctl doppler oci curl jq; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}❌ $cmd n'est pas installé${NC}"
        echo "Installez: brew install $cmd"
        exit 1
    fi
    echo -e "${GREEN}✅ $cmd${NC}"
done

# ============================================================================
# ÉTAPE 2: Vérification Doppler
# ============================================================================
echo ""
echo -e "${YELLOW}[2/8] Vérification Doppler...${NC}"

if ! doppler me &> /dev/null; then
    echo -e "${RED}❌ Non connecté à Doppler${NC}"
    echo "Lancez: doppler login"
    exit 1
fi

echo -e "${GREEN}✅ Connecté à Doppler${NC}"

# Vérifier les projets existants
echo ""
echo "Projets Doppler:"
doppler projects list 2>/dev/null | head -20 || echo "Aucun projet (normal si premier déploiement)"

# ============================================================================
# ÉTAPE 3: Vérification OCI CLI
# ============================================================================
echo ""
echo -e "${YELLOW}[3/8] Vérification OCI CLI...${NC}"

if ! oci iam compartment get --compartment-id "$(oci iam compartment list --query 'data[?name==`root`].id | [0]' --raw-output)" &> /dev/null; then
    echo -e "${RED}❌ OCI CLI non configuré${NC}"
    echo "Lancez: oci session authenticate"
    exit 1
fi

echo -e "${GREEN}✅ OCI CLI configuré${NC}"

# Récupérer le namespace
export OCI_NAMESPACE=$(oci os ns get --query data --raw-output)
echo "Namespace OCI: $OCI_NAMESPACE"

# ============================================================================
# ÉTAPE 4: Setup Doppler Projects
# ============================================================================
echo ""
echo -e "${YELLOW}[4/8] Setup Doppler Projects...${NC}"

read -p "Créer les projets Doppler? (y/n): " setup_doppler
if [[ $setup_doppler =~ ^[Yy]$ ]]; then
    ./scripts/setup-doppler.sh
fi

# ============================================================================
# ÉTAPE 5: Vérification Terraform
# ============================================================================
echo ""
echo -e "${YELLOW}[5/8] Vérification Terraform...${NC}"

cd terraform/oracle-cloud

if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}❌ terraform.tfvars manquant${NC}"
    echo "Créez-le à partir de terraform.tfvars.example"
    exit 1
fi

echo -e "${GREEN}✅ terraform.tfvars existe${NC}"

# Vérifier les variables critiques
if grep -q "compartment_id" terraform.tfvars; then
    echo -e "${GREEN}✅ compartment_id configuré${NC}"
else
    echo -e "${RED}❌ compartment_id manquant${NC}"
fi

if grep -q "ssh_public_key" terraform.tfvars; then
    echo -e "${GREEN}✅ ssh_public_key configuré${NC}"
else
    echo -e "${RED}❌ ssh_public_key manquant${NC}"
fi

# Init Terraform
echo ""
echo "Initialisation Terraform..."
doppler run -- terraform init

cd ../..

# ============================================================================
# ÉTAPE 6: Vérification des Secrets
# ============================================================================
echo ""
echo -e "${YELLOW}[6/8] Vérification des secrets...${NC}"

echo ""
echo -e "${BLUE}Vérifiez que ces secrets sont configurés dans GitHub:${NC}"
echo ""
echo "Settings → Secrets and variables → Actions"
echo ""
cat << 'EOF'
Secrets requis:
================
OMNI_ENDPOINT=https://xxx.omni.siderolabs.io:50001
OMNI_KEY=omni-key-xxx
DOPPLER_TOKEN=dp.st.xxx
CLOUDFLARE_API_TOKEN=xxx
CLOUDFLARE_ZONE_ID=xxx
CLOUDFLARE_ACCOUNT_ID=xxx
CLOUDFLARE_TUNNEL_SECRET=xxx
CLOUDFLARE_TUNNEL_ID=(laisser vide pour créer)
OCI_COMPARTMENT_ID=ocid1.compartment...
OCI_USER_OCID=ocid1.user...
SSH_PUBLIC_KEY=ssh-ed25519...
TAILSCALE_AUTH_KEY=tskey-auth...
EOF

# ============================================================================
# ÉTAPE 7: Plan Terraform
# ============================================================================
echo ""
echo -e "${YELLOW}[7/8] Plan Terraform...${NC}"

cd terraform/oracle-cloud
echo ""
echo "Génération du plan Terraform..."
doppler run -- terraform plan -out=tfplan -input=false 2>&1 | tee /tmp/terraform-plan.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Plan Terraform généré avec succès${NC}"
else
    echo ""
    echo -e "${RED}❌ Erreur dans le plan Terraform${NC}"
    echo "Vérifiez les erreurs ci-dessus"
    exit 1
fi

cd ../..

# ============================================================================
# ÉTAPE 8: Résumé
# ============================================================================
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}  Préparation Terminée !${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${YELLOW}Prochaines étapes:${NC}"
echo ""
echo "1. Vérifier les secrets GitHub (voir liste ci-dessus)"
echo ""
echo "2. Lancer le déploiement:"
echo -e "   ${GREEN}./scripts/deploy.sh${NC}"
echo ""
echo "   OU via GitHub Actions:"
echo "   GitHub → Actions → 'Full Bootstrap' → Run workflow"
echo ""
echo "3. Suivre les logs:"
echo "   GitHub → Actions → <workflow> → <job>"
echo ""
echo "Durée estimée: 40 minutes"
echo ""
