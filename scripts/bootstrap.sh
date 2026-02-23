#!/bin/bash
#
# Bootstrap script pour déployer l'homelab OCI
# Usage: ./scripts/bootstrap.sh

set -e

echo "🚀 Bootstrap Homelab OCI"
echo "========================"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Vérifications
echo -e "${YELLOW}Vérification des prérequis...${NC}"

# Vérifier Doppler
if ! command -v doppler &> /dev/null; then
    echo -e "${RED}❌ Doppler CLI non trouvé. Installez-le:${NC}"
    echo "   curl -sLf https://cli.doppler.com/install.sh | sh"
    exit 1
fi

# Vérifier Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform non trouvé. Installez-le:${NC}"
    echo "   brew install terraform"
    exit 1
fi

# Vérifier kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl non trouvé. Installez-le:${NC}"
    echo "   brew install kubectl"
    exit 1
fi

echo -e "${GREEN}✅ Tous les outils sont présents${NC}"

# Vérifier connexion Doppler
echo -e "${YELLOW}Vérification connexion Doppler...${NC}"
doppler me &> /dev/null || {
    echo -e "${RED}❌ Non connecté à Doppler. Lancez:${NC}"
    echo "   doppler login"
    exit 1
}
echo -e "${GREEN}✅ Connecté à Doppler${NC}"

# Étape 1: Terraform
echo -e "\n${YELLOW}Étape 1/4: Infrastructure Terraform${NC}"
cd terraform/oracle-cloud

if [ ! -f terraform.tfvars ]; then
    echo -e "${RED}❌ terraform.tfvars manquant${NC}"
    echo "   Copiez terraform.tfvars.example vers terraform.tfvars et modifiez-le"
    exit 1
fi

echo "Initialisation Terraform..."
doppler run -- terraform init

echo "Plan Terraform..."
doppler run -- terraform plan -out=tfplan

echo -e "${YELLOW}Voulez-vous appliquer le plan Terraform? (y/n)${NC}"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    doppler run -- terraform apply tfplan
    echo -e "${GREEN}✅ Infrastructure déployée${NC}"
else
    echo -e "${YELLOW}⚠️  Infrastructure non déployée${NC}"
    exit 0
fi

cd ../..

# Étape 2: Configuration kubeconfig
echo -e "\n${YELLOW}Étape 2/4: Configuration kubectl${NC}"
echo "Attendez que les VMs soient prêtes (3-5 minutes)..."
echo "Une fois les VMs déployées, configurez votre kubeconfig avec Omni:"
echo "   omnictl kubeconfig -c oci-hub > ~/.kube/config"

# Étape 3: Bootstrap Flux
echo -e "\n${YELLOW}Étape 3/4: Bootstrap Flux CD${NC}"
echo "Une fois le cluster Kubernetes prêt:"
echo "   kubectl apply -k kubernetes/clusters/oci-hub"

# Étape 4: Secrets Doppler
echo -e "\n${YELLOW}Étape 4/4: Configuration Secrets${NC}"
echo "Créez le secret Doppler dans Kubernetes:"
echo "   kubectl create secret generic doppler-token-secret \\"
echo "     --from-literal=dopplerToken='dp.st.xxxxxx' \\"
echo "     -n flux-system"

echo -e "\n${GREEN}🎉 Bootstrap terminé!${NC}"
echo ""
echo "Prochaines étapes:"
echo "   1. Attendre que les VMs OCI soient prêtes"
echo "   2. Configurer Omni sur la VM hub"
echo "   3. Créer le cluster Talos avec Omni"
echo "   4. Récupérer le kubeconfig"
echo "   5. Déployer Flux avec: kubectl apply -k kubernetes/clusters/oci-hub"
echo ""
echo "Documentation: https://github.com/votre-user/homelab/blob/main/README.md"
