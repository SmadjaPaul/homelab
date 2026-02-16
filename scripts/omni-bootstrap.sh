#!/bin/bash
#
# Omni Bootstrap Automatisé
# Automatise la création du cluster, génération d'image, et import OCI
# Usage: ./scripts/omni-bootstrap.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
OMNI_ENDPOINT="${OMNI_ENDPOINT:-}"
OMNI_KEY="${OMNI_KEY:-}"  # Clé API Omni (générée dans UI)
CLUSTER_NAME="oci-hub"
TALOS_VERSION="v1.9.0"
K8S_VERSION="1.31.0"
OCI_REGION="eu-paris-1"
OCI_COMPARTMENT_ID="${OCI_COMPARTMENT_ID:-}"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Omni Bootstrap Automatisé${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Vérifier prérequis
check_prereqs() {
    echo -e "${YELLOW}[Check] Vérification des prérequis...${NC}"

    for cmd in omnictl oci talosctl jq curl; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}❌ $cmd n'est pas installé${NC}"
            exit 1
        fi
    done

    if [ -z "$OMNI_ENDPOINT" ]; then
        echo -e "${RED}❌ OMNI_ENDPOINT non défini${NC}"
        echo "Exportez: export OMNI_ENDPOINT=https://votre-omni:50001"
        exit 1
    fi

    if [ -z "$OMNI_KEY" ]; then
        echo -e "${RED}❌ OMNI_KEY non défini${NC}"
        echo "Générez une clé dans Omni UI → Settings → Keys"
        exit 1
    fi

    echo -e "${GREEN}✅ Prérequis OK${NC}"
}

# Étape 1: Créer le cluster dans Omni
create_cluster() {
    echo ""
    echo -e "${BLUE}[1/6] Création du cluster dans Omni...${NC}"

    # Vérifier si le cluster existe déjà
    if omnictl cluster get "$CLUSTER_NAME" &> /dev/null; then
        echo -e "${YELLOW}⚠️  Cluster $CLUSTER_NAME existe déjà${NC}"
        return 0
    fi

    # Créer le cluster via omnictl
    omnictl cluster create \
        --name "$CLUSTER_NAME" \
        --kubernetes-version "$K8S_VERSION" \
        --talos-version "$TALOS_VERSION" \
        --control-plane-count 1 \
        --worker-count 2

    echo -e "${GREEN}✅ Cluster $CLUSTER_NAME créé${NC}"
}

# Étape 2: Générer l'image Talos
generate_image() {
    echo ""
    echo -e "${BLUE}[2/6] Génération de l'image Talos...${NC}"

    mkdir -p /tmp/talos-images
    cd /tmp/talos-images

    # Télécharger l'image via l'API Omni
    # Omni génère une image préconfigurée pour le cluster
    echo "Téléchargement de l'image Oracle Cloud..."

    # Utiliser l'API Omni pour générer et télécharger l'image
    curl -s -H "Authorization: Bearer $OMNI_KEY" \
        "$OMNI_ENDPOINT/api/v1/clusters/$CLUSTER_NAME/image?platform=oracle&arch=arm64" \
        -o "talos-$CLUSTER_NAME-oracle-arm64.raw.xz"

    if [ ! -f "talos-$CLUSTER_NAME-oracle-arm64.raw.xz" ]; then
        echo -e "${RED}❌ Échec du téléchargement de l'image${NC}"
        exit 1
    fi

    # Décompresser
    echo "Décompression..."
    xz -d "talos-$CLUSTER_NAME-oracle-arm64.raw.xz"

    # Convertir en qcow2
    echo "Conversion en QCOW2..."
    qemu-img convert -f raw -O qcow2 \
        "talos-$CLUSTER_NAME-oracle-arm64.raw" \
        "talos-$CLUSTER_NAME-oracle-arm64.qcow2"

    # Créer le fichier de métadonnées OCI
    cat > image_metadata.json << EOF
{
    "version": 2,
    "externalLaunchOptions": {
        "firmware": "UEFI_64",
        "networkType": "PARAVIRTUALIZED",
        "bootVolumeType": "PARAVIRTUALIZED",
        "remoteDataVolumeType": "PARAVIRTUALIZED",
        "localDataVolumeType": "PARAVIRTUALIZED",
        "launchOptionsSource": "PARAVIRTUALIZED",
        "pvAttachmentVersion": 2,
        "pvEncryptionInTransitEnabled": true,
        "consistentVolumeNamingEnabled": true
    },
    "imageCapabilityData": null,
    "imageCapsFormatVersion": null,
    "operatingSystem": "Talos",
    "operatingSystemVersion": "$TALOS_VERSION",
    "additionalMetadata": {
        "shapeCompatibilities": [
            {
                "internalShapeName": "VM.Standard.A1.Flex",
                "ocpuConstraints": null,
                "memoryConstraints": null
            }
        ]
    }
}
EOF

    # Créer le bundle OCI
    tar czf "talos-$CLUSTER_NAME.oci" \
        "talos-$CLUSTER_NAME-oracle-arm64.qcow2" \
        image_metadata.json

    echo -e "${GREEN}✅ Image générée: /tmp/talos-images/talos-$CLUSTER_NAME.oci${NC}"

    cd - > /dev/null
}

# Étape 3: Upload vers OCI
upload_to_oci() {
    echo ""
    echo -e "${BLUE}[3/6] Upload vers OCI Object Storage...${NC}"

    BUCKET_NAME="talos-images"
    IMAGE_FILE="/tmp/talos-images/talos-$CLUSTER_NAME.oci"

    # Créer le bucket s'il n'existe pas
    if ! oci os bucket get --bucket-name "$BUCKET_NAME" --namespace-name "$(oci os ns get --query data --raw-output)" &> /dev/null; then
        echo "Création du bucket $BUCKET_NAME..."
        oci os bucket create \
            --name "$BUCKET_NAME" \
            --namespace-name "$(oci os ns get --query data --raw-output)" \
            --compartment-id "$OCI_COMPARTMENT_ID"
    fi

    # Upload
    echo "Upload de l'image (peut prendre quelques minutes)..."
    oci os object put \
        --bucket-name "$BUCKET_NAME" \
        --namespace-name "$(oci os ns get --query data --raw-output)" \
        --file "$IMAGE_FILE" \
        --name "talos-$CLUSTER_NAME.oci" \
        --force

    echo -e "${GREEN}✅ Image uploadée dans le bucket${NC}"
}

# Étape 4: Créer l'image custom dans OCI
create_custom_image() {
    echo ""
    echo -e "${BLUE}[4/6] Création de l'image custom OCI...${NC}"

    NAMESPACE=$(oci os ns get --query data --raw-output)

    # Créer l'image custom
    echo "Création de l'image (peut prendre 10-15 minutes)..."
    IMAGE_OCID=$(oci compute image create \
        --compartment-id "$OCI_COMPARTMENT_ID" \
        --namespace-name "$NAMESPACE" \
        --bucket-name "talos-images" \
        --object-name "talos-$CLUSTER_NAME.oci" \
        --display-name "talos-$CLUSTER_NAME" \
        --operating-system "Talos" \
        --operating-system-version "$TALOS_VERSION" \
        --query 'data.id' \
        --raw-output)

    echo -e "${GREEN}✅ Image custom créée${NC}"
    echo "OCID: $IMAGE_OCID"

    # Sauvegarder pour Terraform
    echo "$IMAGE_OCID" > /tmp/talos-image-ocid.txt
    echo ""
    echo -e "${YELLOW}📝 OCID sauvegardé dans /tmp/talos-image-ocid.txt${NC}"
}

# Étape 5: Attendre que l'image soit disponible
wait_for_image() {
    echo ""
    echo -e "${BLUE}[5/6] Attente de la disponibilité de l'image...${NC}"

    IMAGE_OCID=$(cat /tmp/talos-image-ocid.txt)

    echo "Cela peut prendre 10-15 minutes..."
    while true; do
        STATUS=$(oci compute image get \
            --image-id "$IMAGE_OCID" \
            --query 'data."lifecycle-state"' \
            --raw-output)

        echo "Statut: $STATUS"

        if [ "$STATUS" == "AVAILABLE" ]; then
            echo -e "${GREEN}✅ Image disponible !${NC}"
            break
        elif [ "$STATUS" == "FAILED" ]; then
            echo -e "${RED}❌ Échec de la création de l'image${NC}"
            exit 1
        fi

        echo "Attente de 30s..."
        sleep 30
    done
}

# Étape 6: Mettre à jour Terraform
update_terraform() {
    echo ""
    echo -e "${BLUE}[6/6] Mise à jour de Terraform...${NC}"

    IMAGE_OCID=$(cat /tmp/talos-image-ocid.txt)
    TFVARS_FILE="terraform/oracle-cloud/terraform.tfvars"

    # Sauvegarder l'ancien
    cp "$TFVARS_FILE" "$TFVARS_FILE.bak"

    # Mettre à jour ou ajouter talos_image_id
    if grep -q "^talos_image_id" "$TFVARS_FILE"; then
        sed -i.bak "s|^talos_image_id.*|talos_image_id = \"$IMAGE_OCID\"|" "$TFVARS_FILE"
    else
        echo "" >> "$TFVARS_FILE"
        echo "# Image Talos générée par Omni le $(date)" >> "$TFVARS_FILE"
        echo "talos_image_id = \"$IMAGE_OCID\"" >> "$TFVARS_FILE"
    fi

    echo -e "${GREEN}✅ Terraform mis à jour${NC}"
    echo ""
    echo -e "${YELLOW}📋 Prochaines étapes:${NC}"
    echo "1. cd terraform/oracle-cloud"
    echo "2. terraform plan (vérifier)"
    echo "3. terraform apply (déployer les VMs avec Talos)"
    echo "4. Récupérer kubeconfig: omnictl kubeconfig -c $CLUSTER_NAME"
    echo "5. kubectl apply -k kubernetes/clusters/oci-hub"
}

# Main
main() {
    check_prereqs
    create_cluster
    generate_image
    upload_to_oci
    create_custom_image
    wait_for_image
    update_terraform

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  Omni Bootstrap Terminé !${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo "Résumé:"
    echo "  - Cluster Omni: $CLUSTER_NAME"
    echo "  - Image Talos: $(cat /tmp/talos-image-ocid.txt)"
    echo "  - Terraform: mis à jour"
    echo ""
    echo "Prochaine étape: terraform apply"
}

# Exécuter si appelé directement
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
