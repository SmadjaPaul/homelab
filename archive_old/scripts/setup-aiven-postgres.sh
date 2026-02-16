#!/bin/bash
# Aiven PostgreSQL Setup for Authentik
# Quick setup script for Aiven free tier PostgreSQL

set -e

echo "🐘 Aiven PostgreSQL Setup for Authentik"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Prérequis:${NC}"
echo "1. Créer un compte Aiven: https://console.aiven.io/signup"
echo "2. Vérifier son email"
echo "3. Avoir l'IP publique de ton VM OCI"
echo ""

read -p "As-tu déjà un compte Aiven ? (y/n): " HAS_ACCOUNT

if [[ $HAS_ACCOUNT =~ ^[Nn]$ ]]; then
    echo ""
    echo -e "${YELLOW}Étapes à suivre:${NC}"
    echo "1. Va sur https://console.aiven.io/signup"
    echo "2. Inscris-toi avec GitHub ou email"
    echo "3. Vérifie ton email"
    echo ""
    echo "Une fois connecté, reviens ici et relance le script"
    echo ""
    exit 0
fi

echo ""
echo -e "${BLUE}Configuration manuelle dans Aiven Console:${NC}"
echo "==========================================="
echo ""
echo "1. Créer un service PostgreSQL:"
echo "   - Clique 'Create Service'"
echo "   - Choisis 'PostgreSQL'"
echo "   - Region: 'Google Cloud - europe-west1' (Belgique - proche de Paris)"
echo "   - Plan: 'Hobbyist' (FREE - 1GB)"
echo "   - Service name: 'authentik-db'"
echo ""

echo "2. Attendre que le service soit 'Running' (2-3 minutes)"
echo ""

echo "3. Configurer les restrictions IP (IMPORTANT):"
echo "   - Va dans l'onglet 'Settings' de ton service"
echo "   - Clique 'IP Allowlist'"
echo "   - Ajoute l'IP de ton VM OCI (trouvable dans OCI Console)"
echo "   - Format: xx.xx.xx.xx/32"
echo "   - Supprime '0.0.0.0/0' si présent"
echo ""

echo "4. Récupérer les credentials:"
echo "   - Onglet 'Overview'"
echo "   - Section 'Connection Information'"
echo "   - Copie le 'Service URI'"
echo "   - Format: postgres://avnadmin:PASSWORD@authentik-db-xxx.aivencloud.com:12691/defaultdb?sslmode=require"
echo ""

read -p "Appuie sur Entrée quand tu as le Service URI..."
echo ""

read -p "Colle le Service URI ici: " AIVEN_URI
echo ""

# Extraire les composants de l'URI
if [[ $AIVEN_URI =~ postgres://([^:]+):([^@]+)@([^:]+):([^/]+)/([^?]+) ]]; then
    DB_USER="${BASH_REMATCH[1]}"
    DB_PASSWORD="${BASH_REMATCH[2]}"
    DB_HOST="${BASH_REMATCH[3]}"
    DB_PORT="${BASH_REMATCH[4]}"
    DB_NAME="${BASH_REMATCH[5]}"

    echo -e "${GREEN}✓ URI analysé avec succès${NC}"
    echo ""
    echo "Configuration extraite:"
    echo "  Host: $DB_HOST"
    echo "  Port: $DB_PORT"
    echo "  Database: $DB_NAME"
    echo "  User: $DB_USER"
    echo ""
else
    echo -e "${RED}✗ Format d'URI invalide${NC}"
    echo "Format attendu: postgres://user:password@host:port/db?sslmode=require"
    exit 1
fi

echo ""
echo -e "${BLUE}Configuration Doppler:${NC}"
echo "======================"
echo ""
echo "Ajoute ces secrets dans Doppler (projet 'infrastructure'):"
echo ""
echo -e "${GREEN}AUTHENTIK_POSTGRES_HOST${NC}=$DB_HOST"
echo -e "${GREEN}AUTHENTIK_POSTGRES_PORT${NC}=$DB_PORT"
echo -e "${GREEN}AUTHENTIK_POSTGRES_NAME${NC}=$DB_NAME"
echo -e "${GREEN}AUTHENTIK_POSTGRES_USER${NC}=$DB_USER"
echo -e "${GREEN}AUTHENTIK_POSTGRES_PASSWORD${NC}=$DB_PASSWORD"
echo ""

echo -e "${GREEN}🎉 Configuration Aiven terminée !${NC}"
echo ""
echo "Prochaines étapes:"
echo "1. Ajouter les secrets à Doppler"
echo "2. Générer AUTHENTIK_SECRET_KEY, AUTHENTIK_BOOTSTRAP_PASSWORD, AUTHENTIK_BOOTSTRAP_TOKEN"
echo "3. Déployer: gh workflow run deploy-stack.yml"
