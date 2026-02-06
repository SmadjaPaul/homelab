#!/bin/bash
# Script helper pour configurer Resend SMTP dans OCI Vault via Terraform
# Usage: ./scripts/setup-resend-smtp.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/oracle-cloud"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Configuration Resend SMTP pour Authentik ===${NC}\n"

# Check if we're in the right directory
if [[ ! -d "$TERRAFORM_DIR" ]]; then
    echo -e "${RED}❌ Erreur: Répertoire terraform/oracle-cloud introuvable${NC}"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Check if terraform is initialized
if [[ ! -d ".terraform" ]]; then
    echo -e "${YELLOW}⚠️  Terraform n'est pas initialisé. Initialisation...${NC}"
    terraform init
fi

# Prompt for Resend API key
echo -e "${YELLOW}Entrez votre API key Resend (commence par 're_'):${NC}"
read -rs RESEND_API_KEY
echo ""

if [[ ! "$RESEND_API_KEY" =~ ^re_ ]]; then
    echo -e "${RED}❌ Erreur: L'API key Resend doit commencer par 're_'${NC}"
    exit 1
fi

# Prompt for from address
echo -e "${YELLOW}Entrez l'adresse email FROM (ex: noreply@smadja.dev):${NC}"
read -r SMTP_FROM

if [[ -z "$SMTP_FROM" ]]; then
    echo -e "${YELLOW}⚠️  Utilisation de l'adresse par défaut: onboarding@resend.dev${NC}"
    SMTP_FROM="onboarding@resend.dev"
fi

# Set environment variables
export TF_VAR_vault_secret_authentik_smtp_host="smtp.resend.com"
export TF_VAR_vault_secret_authentik_smtp_port="587"
export TF_VAR_vault_secret_authentik_smtp_username="resend"
export TF_VAR_vault_secret_authentik_smtp_password="$RESEND_API_KEY"
export TF_VAR_vault_secret_authentik_smtp_from="$SMTP_FROM"

echo -e "\n${BLUE}Configuration:${NC}"
echo "  Host: smtp.resend.com"
echo "  Port: 587"
echo "  Username: resend"
echo "  From: $SMTP_FROM"
echo ""

# Show plan
echo -e "${BLUE}Plan Terraform:${NC}"
terraform plan -out=tfplan

echo -e "\n${YELLOW}Voulez-vous appliquer ces changements? (y/N):${NC}"
read -r CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "\n${GREEN}Application des changements...${NC}"
    terraform apply tfplan
    rm -f tfplan

    echo -e "\n${GREEN}✅ Secrets Resend créés dans OCI Vault!${NC}"
    echo -e "\n${BLUE}Prochaines étapes:${NC}"
    echo "  1. Configure le module Authentik:"
    echo "     cd terraform/authentik"
    echo "     COMPARTMENT_ID=\$(cd ../oracle-cloud && terraform output -raw compartment_id)"
    echo "     terraform apply -var=\"oci_compartment_id=\$COMPARTMENT_ID\""
    echo ""
    echo "  2. Teste l'envoi d'email:"
    echo "     docker compose exec authentik-server ak test_email ton-email@example.com -S default-recovery-email"
else
    echo -e "\n${YELLOW}Annulé. Aucun changement appliqué.${NC}"
    rm -f tfplan
fi
