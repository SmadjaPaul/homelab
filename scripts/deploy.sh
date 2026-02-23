#!/bin/bash
#
# Déploiement Complet - Local
# Usage: ./scripts/deploy.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CLUSTER_NAME="oci-hub"
TF_PLAN="tfplan"
START_TIME=$(date +%s)

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Déploiement Complet - Homelab${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Fonction pour afficher le temps écoulé
show_time() {
    local end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    echo -e "${BLUE}Temps écoulé: ${minutes}m${seconds}s${NC}"
}

# Fonction pour les erreurs
error_exit() {
    echo -e "${RED}❌ ERREUR: $1${NC}"
    show_time
    exit 1
}

# ============================================================================
# PHASE 1: Cloudflare
# ============================================================================
phase1_cloudflare() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  PHASE 1/4: Cloudflare${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""

    cd terraform/cloudflare

    echo -e "${YELLOW}[1/3] Initialisation...${NC}"
    doppler run -- terraform init -input=false || error_exit "Terraform init Cloudflare"

    echo -e "${YELLOW}[2/3] Plan...${NC}"
    doppler run -- terraform plan -out=$TF_PLAN -input=false || error_exit "Terraform plan Cloudflare"

    echo -e "${YELLOW}[3/3] Apply...${NC}"
    doppler run -- terraform apply -input=false $TF_PLAN || error_exit "Terraform apply Cloudflare"

    # Récupérer les outputs
    TUNNEL_ID=$(terraform output -raw tunnel_id 2>/dev/null || echo "")
    CNAME_TARGET=$(terraform output -raw cname_target 2>/dev/null || echo "")

    echo -e "${GREEN}✅ Cloudflare déployé${NC}"
    echo "  Tunnel ID: $TUNNEL_ID"
    echo "  CNAME Target: $CNAME_TARGET"

    cd ../..
    show_time
}

# ============================================================================
# PHASE 2: OCI Infrastructure (VMs Temporaires)
# ============================================================================
phase2_oci() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  PHASE 2/4: OCI Infrastructure (VMs)${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""

    cd terraform/oracle-cloud

    echo -e "${YELLOW}[1/3] Initialisation...${NC}"
    doppler run -- terraform init -input=false || error_exit "Terraform init OCI"

    echo -e "${YELLOW}[2/3] Plan...${NC}"
    doppler run -- terraform plan -out=$TF_PLAN -input=false || error_exit "Terraform plan OCI"

    echo -e "${YELLOW}[3/3] Apply...${NC}"
    echo "Création des VMs (sans Talos pour l'instant)..."
    doppler run -- terraform apply -input=false $TF_PLAN || error_exit "Terraform apply OCI"

    # Récupérer les outputs
    HUB_IP=$(terraform output -raw hub_public_ip 2>/dev/null || echo "")

    echo -e "${GREEN}✅ VMs OCI créées${NC}"
    echo "  Hub IP: $HUB_IP"
    echo ""
    echo -e "${YELLOW}Attente que les VMs soient accessibles (60s)...${NC}"
    sleep 60

    cd ../..
    show_time
}

# ============================================================================
# PHASE 3: Omni Bootstrap
# ============================================================================
phase3_omni() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  PHASE 3/4: Omni Bootstrap${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""

    echo -e "${YELLOW}⚠️  Cette phase nécessite Omni configuré${NC}"
    echo ""

    if [ -z "$OMNI_ENDPOINT" ] || [ -z "$OMNI_KEY" ]; then
        echo -e "${YELLOW}Variables OMNI_ENDPOINT et OMNI_KEY non définies${NC}"
        echo ""
        echo "1. Créez un compte sur https://omni.siderolabs.io"
        echo "2. Notez l'endpoint (ex: https://xxx.omni.siderolabs.io:50001)"
        echo "3. Générez une clé API dans Omni UI → Settings → Keys"
        echo "4. Exportez:"
        echo "   export OMNI_ENDPOINT=https://xxx.omni.siderolabs.io:50001"
        echo "   export OMNI_KEY=omni-key-xxx"
        echo ""
        read -p "Avez-vous configuré Omni? (y/n): " omni_ready

        if [[ ! $omni_ready =~ ^[Yy]$ ]]; then
            echo "Configurez Omni d'abord, puis relancez."
            exit 0
        fi
    fi

    echo -e "${YELLOW}[1/5] Création du cluster Omni...${NC}"
    if ! omnictl cluster get $CLUSTER_NAME &> /dev/null; then
        omnictl cluster create \
            --name $CLUSTER_NAME \
            --kubernetes-version "1.31.0" \
            --talos-version "v1.9.0" \
            --control-plane-count 1 \
            --worker-count 2 || error_exit "Création cluster Omni"
        echo -e "${GREEN}✅ Cluster créé${NC}"
    else
        echo -e "${YELLOW}⚠️  Cluster existe déjà${NC}"
    fi

    echo -e "${YELLOW}[2/5] Génération de l'image Talos...${NC}"
    echo "Téléchargement depuis Omni (peut prendre quelques minutes)..."

    mkdir -p /tmp/talos-images
    cd /tmp/talos-images

    # Télécharger l'image
    curl -s -H "Authorization: Bearer $OMNI_KEY" \
        "$OMNI_ENDPOINT/api/v1/clusters/$CLUSTER_NAME/image?platform=oracle&arch=arm64" \
        -o "talos-$CLUSTER_NAME.raw.xz" || error_exit "Téléchargement image"

    xz -d "talos-$CLUSTER_NAME.raw.xz" || error_exit "Décompression"
    qemu-img convert -f raw -O qcow2 "talos-$CLUSTER_NAME.raw" "talos-$CLUSTER_NAME.qcow2" || error_exit "Conversion"

    echo -e "${GREEN}✅ Image générée${NC}"

    echo -e "${YELLOW}[3/5] Upload vers OCI...${NC}"
    echo "Upload vers Object Storage..."

    OCI_NAMESPACE=$(oci os ns get --query data --raw-output)
    BUCKET_NAME="talos-images"

    # Créer bucket si nécessaire
    if ! oci os bucket get --bucket-name "$BUCKET_NAME" --namespace-name "$OCI_NAMESPACE" &> /dev/null; then
        oci os bucket create --name "$BUCKET_NAME" --namespace-name "$OCI_NAMESPACE" \
            --compartment-id "$OCI_COMPARTMENT_ID" || error_exit "Création bucket"
    fi

    # Upload
    oci os object put --bucket-name "$BUCKET_NAME" --namespace-name "$OCI_NAMESPACE" \
        --file "talos-$CLUSTER_NAME.qcow2" --name "talos-$CLUSTER_NAME.qcow2" --force || error_exit "Upload"

    echo -e "${GREEN}✅ Upload terminé${NC}"

    echo -e "${YELLOW}[4/5] Création image custom OCI...${NC}"
    echo "Création de l'image (peut prendre 10-15 minutes)..."

    cd /Users/paul/Developer/Perso/homelab

    # Importer l'image
    IMAGE_OCID=$(oci compute image create \
        --compartment-id "$OCI_COMPARTMENT_ID" \
        --namespace-name "$OCI_NAMESPACE" \
        --bucket-name "$BUCKET_NAME" \
        --object-name "talos-$CLUSTER_NAME.qcow2" \
        --display-name "talos-$CLUSTER_NAME" \
        --operating-system "Talos" \
        --operating-system-version "v1.9.0" \
        --query 'data.id' --raw-output) || error_exit "Création image"

    echo "Image OCID: $IMAGE_OCID"

    # Attendre que l'image soit disponible
    echo -e "${YELLOW}[5/5] Attente disponibilité...${NC}"
    echo "Cela peut prendre 10-15 minutes. Patientez..."

    while true; do
        STATUS=$(oci compute image get --image-id "$IMAGE_OCID" --query 'data."lifecycle-state"' --raw-output)
        echo "  Statut: $STATUS"

        if [ "$STATUS" == "AVAILABLE" ]; then
            break
        elif [ "$STATUS" == "FAILED" ]; then
            error_exit "Échec création image"
        fi

        sleep 30
    done

    echo -e "${GREEN}✅ Image disponible${NC}"

    # Mettre à jour Terraform
    echo ""
    echo -e "${YELLOW}Mise à jour Terraform...${NC}"

    cd terraform/oracle-cloud
    if grep -q "^talos_image_id" terraform.tfvars; then
        sed -i.bak "s|^talos_image_id.*|talos_image_id = \"$IMAGE_OCID\"|" terraform.tfvars
    else
        echo "" >> terraform.tfvars
        echo "# Image Talos générée le $(date)" >> terraform.tfvars
        echo "talos_image_id = \"$IMAGE_OCID\"" >> terraform.tfvars
    fi

    echo -e "${YELLOW}Redéploiement VMs avec Talos...${NC}"
    doppler run -- terraform apply -auto-approve -input=false || error_exit "Re-déploiement VMs"

    echo -e "${GREEN}✅ VMs redéployées avec Talos${NC}"
    echo ""
    echo -e "${YELLOW}Attente que Talos démarre (2min)...${NC}"
    sleep 120

    cd ../..
    show_time
}

# ============================================================================
# PHASE 4: Kubernetes Apps
# ============================================================================
phase4_k8s() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  PHASE 4/4: Kubernetes Apps${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""

    echo -e "${YELLOW}[1/4] Récupération kubeconfig...${NC}"

    HUB_IP=$(cd terraform/oracle-cloud && terraform output -raw hub_public_ip)

    # Attendre que le cluster soit prêt
    echo "Attente que le cluster Kubernetes soit prêt..."
    echo "Cela peut prendre 2-3 minutes..."

    for i in {1..10}; do
        if omnictl kubeconfig -c $CLUSTER_NAME > ~/.kube/config 2>/dev/null; then
            if kubectl get nodes &> /dev/null; then
                echo -e "${GREEN}✅ Cluster accessible${NC}"
                break
            fi
        fi
        echo "  Tentative $i/10..."
        sleep 30
    done

    if ! kubectl get nodes &> /dev/null; then
        error_exit "Cluster non accessible"
    fi

    kubectl get nodes

    echo -e "${YELLOW}[2/4] Installation Flux CD...${NC}"
    flux install || error_exit "Installation Flux"
    echo -e "${GREEN}✅ Flux installé${NC}"

    echo -e "${YELLOW}[3/4] Création secret Doppler...${NC}"

    if [ -z "$DOPPLER_TOKEN" ]; then
        echo -e "${YELLOW}DOPPLER_TOKEN non défini${NC}"
        read -s -p "Entrez le token Doppler (infrastructure): " DOPPLER_TOKEN
        echo ""
    fi

    kubectl create secret generic doppler-token-infrastructure \
        --from-literal=dopplerToken="$DOPPLER_TOKEN" \
        -n flux-system || echo "Secret existe déjà"

    echo -e "${GREEN}✅ Secret créé${NC}"

    echo -e "${YELLOW}[4/4] Déploiement applications...${NC}"
    kubectl apply -k kubernetes/clusters/oci-hub || error_exit "Déploiement apps"

    echo -e "${GREEN}✅ Applications déployées${NC}"
    echo ""
    echo "Attente 30s pour le démarrage..."
    sleep 30

    echo ""
    echo "Status des pods:"
    kubectl get pods -n infra || true

    show_time
}

# ============================================================================
# Main
# ============================================================================
main() {
    # Vérifier les arguments
    case "${1:-all}" in
        cloudflare)
            phase1_cloudflare
            ;;
        oci)
            phase2_oci
            ;;
        omni)
            phase3_omni
            ;;
        k8s)
            phase4_k8s
            ;;
        all)
            phase1_cloudflare
            phase2_oci
            phase3_omni
            phase4_k8s
            ;;
        *)
            echo "Usage: $0 [cloudflare|oci|omni|k8s|all]"
            exit 1
            ;;
    esac

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  Déploiement Terminé !${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    show_time
    echo ""

    HUB_IP=$(cd terraform/oracle-cloud && terraform output -raw hub_public_ip 2>/dev/null || echo "N/A")

    echo "Résumé:"
    echo "  Hub IP: $HUB_IP"
    echo "  Cluster: $CLUSTER_NAME"
    echo ""
    echo "URLs:"
    echo "  - Homepage: https://home.smadja.dev"
    echo "  - Omni: http://$HUB_IP:50001"
    echo ""
    echo "Commandes utiles:"
    echo "  kubectl get pods -A"
    echo "  flux get all"
    echo "  omnictl cluster status -c $CLUSTER_NAME"
}

# Exécuter
main "$@"
