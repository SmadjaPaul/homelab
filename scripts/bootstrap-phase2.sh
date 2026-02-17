#!/bin/bash
#
# Bootstrap Phase 2 & 3: Configuration Omni + Kubernetes
# Usage: ./scripts/bootstrap-phase2.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Bootstrap Phase 2 & 3${NC}"
echo -e "${BLUE}  Omni Configuration + K8s Bootstrap${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Vérifier prérequis
echo -e "${YELLOW}[Check] Vérification des prérequis...${NC}"

for cmd in terraform kubectl doppler; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}❌ $cmd n'est pas installé${NC}"
        exit 1
    fi
done

# Vérifier connexion Doppler
doppler me &> /dev/null || {
    echo -e "${RED}❌ Non connecté à Doppler. Lancez: doppler login${NC}"
    exit 1
}

echo -e "${GREEN}✅ Tous les outils sont présents${NC}"
echo ""

# Récupérer IP Hub
echo -e "${YELLOW}[Info] Récupération des IPs depuis Terraform...${NC}"
cd terraform/oracle-cloud

if [ ! -f terraform.tfstate ]; then
    echo -e "${RED}❌ Terraform state non trouvé. Avez-vous lancé 'terraform apply'?${NC}"
    exit 1
fi

HUB_IP=$(terraform output -raw hub_public_ip 2>/dev/null || echo "")
K8S_CP_IP=$(terraform output -raw k8s_control_plane_ip 2>/dev/null || echo "10.0.1.10")

cd ../..

if [ -z "$HUB_IP" ]; then
    echo -e "${RED}❌ Impossible de récupérer l'IP du Hub. Terraform appliqué?${NC}"
    exit 1
fi

echo -e "${GREEN}✅ IPs récupérées:${NC}"
echo "  Hub VM:     $HUB_IP"
echo "  K8s CP:     $K8S_CP_IP"
echo ""

# ============================================================================
# PHASE 2: Configuration Omni
# ============================================================================
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  PHASE 2: Configuration Omni${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

echo -e "${YELLOW}Étapes manuelles requises:${NC}"
echo ""
echo "1. Accéder à l'interface Omni:"
echo -e "   ${GREEN}https://$HUB_IP:50001${NC}"
echo ""
echo "2. Accepter le certificat auto-signé (c'est normal)"
echo ""
echo "3. Créer le premier utilisateur admin:"
echo "   - Username: admin (ou votre choix)"
echo "   - Password: (mot de passe fort)"
echo ""
echo "4. Créer un cluster:"
echo "   - Name: ${GREEN}oci-hub${NC}"
echo "   - Kubernetes version: 1.31.0 (ou dernière stable)"
echo "   - Talos version: v1.9.0 (ou dernière stable)"
echo ""
echo "5. Générer une image Talos:"
echo "   - Aller dans 'Download'"
echo "   - Choisir 'Oracle Cloud'"
echo "   - Attendre la génération"
echo "   - Copier l'${YELLOW}OCID${NC} de l'image"
echo ""

read -r -p "Avez-vous l'OCID de l'image Talos? (y/n): " has_ocid

if [[ ! $has_ocid =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  Revenez quand vous avez l'OCID${NC}"
    exit 0
fi

read -p "Entrez l'OCID de l'image Talos: " talos_image_id

echo ""
echo -e "${YELLOW}[Action] Mise à jour de terraform.tfvars...${NC}"

# Vérifier si talos_image_id existe déjà
cd terraform/oracle-cloud
if grep -q "^talos_image_id" terraform.tfvars; then
    # Remplacer
    sed -i.bak "s|^talos_image_id.*|talos_image_id = \"$talos_image_id\"|" terraform.tfvars
else
    # Ajouter
    echo "" >> terraform.tfvars
    echo "# Image Talos générée par Omni" >> terraform.tfvars
    echo "talos_image_id = \"$talos_image_id\"" >> terraform.tfvars
fi

echo -e "${GREEN}✅ terraform.tfvars mis à jour${NC}"
echo ""

echo -e "${YELLOW}[Action] Ré-application de Terraform pour déployer Talos...${NC}"
echo "Cela peut prendre 2-3 minutes..."
echo ""

doppler run -- terraform apply -auto-approve

echo ""
echo -e "${GREEN}✅ VMs Talos déployées avec l'image${NC}"
echo ""

# ============================================================================
# Attendre que les VMs soient prêtes
# ============================================================================
echo -e "${YELLOW}[Wait] Attente que les VMs Talos soient prêtes (30s)...${NC}"
sleep 30

# ============================================================================
# PHASE 3: Bootstrap Kubernetes
# ============================================================================
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  PHASE 3: Bootstrap Kubernetes${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

echo -e "${YELLOW}[Action] Récupération du kubeconfig...${NC}"
echo ""
echo "Commande à exécuter sur la VM Hub:"
echo -e "${GREEN}  omnictl kubeconfig -c oci-hub${NC}"
echo ""

# Tenter de récupérer automatiquement via SSH
echo -e "${YELLOW}Tentative de récupération automatique...${NC}"

if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$HUB_IP "omnictl kubeconfig -c oci-hub" > /tmp/kubeconfig-oci-hub 2>/dev/null; then
    echo -e "${GREEN}✅ kubeconfig récupéré automatiquement${NC}"
    cp /tmp/kubeconfig-oci-hub ~/.kube/config
    export KUBECONFIG=~/.kube/config
else
    echo -e "${YELLOW}⚠️  Récupération automatique échouée${NC}"
    echo "Récupérez manuellement le kubeconfig:"
    echo "  1. SSH sur le Hub: ssh ubuntu@$HUB_IP"
    echo "  2. Exécutez: omnictl kubeconfig -c oci-hub"
    echo "  3. Copiez le contenu dans ~/.kube/config"
    echo ""
    read -p "Appuyez sur Entrée quand le kubeconfig est configuré..."
fi

echo ""
echo -e "${YELLOW}[Check] Vérification du cluster...${NC}"

if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}❌ Impossible de contacter le cluster${NC}"
    echo "Vérifiez votre kubeconfig:"
    echo "  export KUBECONFIG=~/.kube/config"
    echo "  kubectl get nodes"
    exit 1
fi

echo -e "${GREEN}✅ Cluster accessible${NC}"
kubectl get nodes
echo ""

echo -e "${YELLOW}[Action] Installation de Flux CD...${NC}"
flux install --components=source-controller,kustomize-controller,helm-controller,notification-controller

echo -e "${GREEN}✅ Flux installé${NC}"
echo ""

echo -e "${YELLOW}[Action] Création du secret Doppler...${NC}"

# Vérifier si le secret existe déjà
if kubectl get secret doppler-token-infrastructure -n flux-system &> /dev/null; then
    echo -e "${YELLOW}⚠️  Secret déjà existant, suppression...${NC}"
    kubectl delete secret doppler-token-infrastructure -n flux-system
fi

# Créer un token temporaire ou utiliser un existant
read -p "Voulez-vous créer un nouveau token Doppler? (y/n): " create_token

if [[ $create_token =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[Action] Génération du token Doppler...${NC}"
    INFRA_TOKEN=$(doppler configs tokens create prd "bootstrap-$(date +%Y%m%d-%H%M%S)" -p infrastructure --plain 2>/dev/null)

    if [ -z "$INFRA_TOKEN" ]; then
        echo -e "${RED}❌ Impossible de générer le token${NC}"
        echo "Créez-le manuellement:"
        echo "  doppler configs tokens create prd bootstrap -p infrastructure --plain"
        exit 1
    fi
else
    read -s -p "Entrez le token Doppler existant: " INFRA_TOKEN
    echo ""
fi

kubectl create secret generic doppler-token-infrastructure \
  --from-literal=dopplerToken="$INFRA_TOKEN" \
  -n flux-system

echo -e "${GREEN}✅ Secret Doppler créé${NC}"
echo ""

echo -e "${YELLOW}[Action] Déploiement External Secrets Operator...${NC}"
kubectl apply -k kubernetes/apps/infrastructure/external-secrets

echo ""
echo -e "${YELLOW}[Wait] Attente que External Secrets soit prêt (30s)...${NC}"
sleep 30

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}  ✅ Phase 2 & 3 Terminées!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${YELLOW}Prochaine étape: Phase 4 (GitOps)${NC}"
echo ""
echo "Déployer l'infrastructure core:"
echo -e "  ${GREEN}kubectl apply -k kubernetes/clusters/oci-hub${NC}"
echo ""
echo "Ou étape par étape:"
echo -e "  ${GREEN}kubectl apply -k kubernetes/apps/infrastructure/cert-manager${NC}"
echo -e "  ${GREEN}kubectl apply -k kubernetes/apps/infrastructure/cloudflare-tunnel${NC}"
echo -e "  ${GREEN}kubectl apply -k kubernetes/apps/infrastructure/traefik${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Avant de déployer, assurez-vous que:"
echo "  - Les secrets Cloudflare sont dans Doppler (infrastructure)"
echo "  - Les secrets Tailscale sont dans Doppler (infrastructure)"
echo ""
