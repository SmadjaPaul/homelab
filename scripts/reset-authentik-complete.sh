#!/usr/bin/env bash
# Reset complet d'Authentik - Réinitialise tous les accès et crée un nouvel admin
# Usage: ./scripts/reset-authentik-complete.sh [email] [password]
#
# Options:
#   1. Reset le mot de passe d'un utilisateur existant
#   2. Créer un nouvel utilisateur admin
#   3. Réinitialiser complètement Authentik (supprime toutes les données)

set -euo pipefail

EMAIL="${1:-smadja-paul@protonmail.com}"
NEW_PASSWORD="${2:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Reset Complet Authentik ===${NC}\n"

# Get VM IP from Terraform, OCI CLI, or prompt
VM_IP=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/oracle-cloud"

# Try Terraform first
if command -v terraform &> /dev/null && command -v jq &> /dev/null; then
  if [[ -d "$TERRAFORM_DIR" ]]; then
    cd "$TERRAFORM_DIR" 2>/dev/null || true
    # Try different output formats
    VM_IP=$(terraform output -json management_vm 2>/dev/null | jq -r '.public_ip // empty' 2>/dev/null || echo "")
    if [[ -z "$VM_IP" || "$VM_IP" == "null" ]]; then
      # Try alternative format
      VM_IP=$(terraform output -json 2>/dev/null | jq -r '.management_vm.value.public_ip // .management_vm.public_ip // empty' 2>/dev/null || echo "")
    fi
    cd - > /dev/null 2>&1 || true
  fi
fi

# Try OCI CLI if Terraform didn't work
if [[ -z "$VM_IP" || "$VM_IP" == "null" ]]; then
  if command -v oci &> /dev/null && command -v jq &> /dev/null; then
    echo -e "${BLUE}Tentative de récupération de l'IP via OCI CLI...${NC}"
    # Get compartment ID from Terraform or env
    COMPARTMENT_ID="${OCI_CLI_TENANCY_OCID:-}"
    if [[ -z "$COMPARTMENT_ID" ]] && [[ -d "$TERRAFORM_DIR" ]]; then
      cd "$TERRAFORM_DIR" 2>/dev/null || true
      COMPARTMENT_ID=$(terraform output -raw compartment_id 2>/dev/null || echo "")
      cd - > /dev/null 2>&1 || true
    fi

    if [[ -n "$COMPARTMENT_ID" ]]; then
      INSTANCE_ID=$(oci compute instance list \
        --compartment-id "$COMPARTMENT_ID" \
        --display-name "oci-mgmt" \
        --query 'data[0].id' \
        --raw-output 2>/dev/null || echo "")

      if [[ -n "$INSTANCE_ID" && "$INSTANCE_ID" != "null" ]]; then
        VM_IP=$(oci compute instance list-vnics \
          --instance-id "$INSTANCE_ID" \
          --query 'data[0]."public-ip"' \
          --raw-output 2>/dev/null || echo "")
      fi
    fi
  fi
fi

# Prompt user if still no IP found
if [[ -z "$VM_IP" || "$VM_IP" == "null" ]]; then
  echo -e "${YELLOW}⚠️  Impossible de récupérer automatiquement l'IP de la VM.${NC}"
  echo -e "${YELLOW}Tu peux la trouver via:${NC}"
  echo -e "${BLUE}  1. Console OCI → Compute → Instances → oci-mgmt → Public IP${NC}"
  echo -e "${BLUE}  2. Ou via OCI CLI: oci compute instance list-vnics --instance-id <instance-id>${NC}"
  echo ""
  read -rp "Entrez l'IP de la VM OCI management: " VM_IP
fi

if [[ -z "$VM_IP" ]]; then
  echo -e "${RED}❌ Erreur: IP de la VM requise${NC}"
  exit 1
fi

# Find SSH key (prioritize oci_mgmt.pem as it's the one from OCI Vault)
SSH_KEY=""
SSH_KEY_PATHS=(
  "$HOME/.ssh/oci_mgmt.pem"
  "$HOME/.ssh/oci-homelab"
  "$HOME/.ssh/oci_mgmt_key"
  "$HOME/.ssh/id_ed25519"
  "$HOME/.ssh/id_rsa"
)

for key_path in "${SSH_KEY_PATHS[@]}"; do
  if [[ -f "$key_path" ]]; then
    SSH_KEY="$key_path"
    chmod 600 "$SSH_KEY" 2>/dev/null || true
    break
  fi
done

# Try to get SSH key from OCI Vault if not found locally
if [[ -z "$SSH_KEY" ]] && command -v oci &> /dev/null && command -v jq &> /dev/null; then
  echo -e "${BLUE}Tentative de récupération de la clé SSH depuis OCI Vault...${NC}"
  COMPARTMENT_ID="${OCI_CLI_TENANCY_OCID:-}"
  if [[ -z "$COMPARTMENT_ID" ]] && [[ -d "$TERRAFORM_DIR" ]]; then
    cd "$TERRAFORM_DIR" 2>/dev/null || true
    COMPARTMENT_ID=$(terraform output -raw compartment_id 2>/dev/null || echo "")
    cd - > /dev/null 2>&1 || true
  fi

  if [[ -n "$COMPARTMENT_ID" ]]; then
    SECRET_OCID=$(oci vault secret list \
      --compartment-id "$COMPARTMENT_ID" \
      --name "homelab-oci-mgmt-ssh-private-key" \
      --lifecycle-state ACTIVE \
      --query 'data[0].id' \
      --raw-output 2>/dev/null || echo "")

    if [[ -n "$SECRET_OCID" && "$SECRET_OCID" != "null" ]]; then
      TEMP_KEY=$(mktemp)
      oci secrets secret-bundle get \
        --secret-id "$SECRET_OCID" \
        --stage CURRENT \
        --query 'data."secret-bundle-content".content' \
        --raw-output 2>/dev/null | \
        base64 -d > "$TEMP_KEY" 2>/dev/null || true

      if [[ -s "$TEMP_KEY" ]]; then
        chmod 600 "$TEMP_KEY"
        SSH_KEY="$TEMP_KEY"
        echo -e "${GREEN}✅ Clé SSH récupérée depuis OCI Vault${NC}"
      else
        rm -f "$TEMP_KEY"
      fi
    fi
  fi
fi

# Prompt for SSH key if still not found
if [[ -z "$SSH_KEY" ]]; then
  echo -e "${YELLOW}⚠️  Clé SSH non trouvée.${NC}"
  echo -e "${YELLOW}Emplacements vérifiés:${NC}"
  for key_path in "${SSH_KEY_PATHS[@]}"; do
    echo -e "${BLUE}  - $key_path${NC}"
  done
  echo ""
  echo -e "${YELLOW}Tu peux aussi récupérer la clé depuis OCI Vault:${NC}"
  echo -e "${BLUE}  oci secrets secret-bundle get --secret-id <ocid> --query 'data.\"secret-bundle-content\".content' --raw-output | base64 -d > ~/.ssh/oci_mgmt.pem${NC}"
  echo ""
  read -rp "Chemin vers la clé SSH privée (ou laisse vide pour utiliser ~/.ssh/id_rsa): " SSH_KEY_INPUT

  if [[ -n "$SSH_KEY_INPUT" ]]; then
    SSH_KEY="$SSH_KEY_INPUT"
  else
    SSH_KEY="$HOME/.ssh/id_rsa"
  fi

  if [[ ! -f "$SSH_KEY" ]]; then
    echo -e "${RED}❌ Erreur: Clé SSH non trouvée: $SSH_KEY${NC}"
    echo -e "${YELLOW}Tu peux récupérer la clé depuis OCI Vault ou la créer manuellement.${NC}"
    exit 1
  fi

  chmod 600 "$SSH_KEY" 2>/dev/null || true
fi

# Store temp key path for cleanup
TEMP_SSH_KEY=""
if [[ "$SSH_KEY" == /tmp/* ]]; then
  TEMP_SSH_KEY="$SSH_KEY"
fi

# Test SSH connection with the found key
if [[ -n "$SSH_KEY" && -n "$VM_IP" ]]; then
  echo -e "${BLUE}Test de la connexion SSH avec: $SSH_KEY${NC}"
  if ! ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes ubuntu@"$VM_IP" "echo 'SSH OK'" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  La clé $SSH_KEY ne fonctionne pas.${NC}"
    echo -e "${YELLOW}Tentative de récupération depuis OCI Vault...${NC}"

    # Try to get SSH key from OCI Vault
    if command -v oci &> /dev/null && command -v jq &> /dev/null; then
      COMPARTMENT_ID="${OCI_CLI_TENANCY_OCID:-}"
      if [[ -z "$COMPARTMENT_ID" ]] && [[ -d "$TERRAFORM_DIR" ]]; then
        cd "$TERRAFORM_DIR" 2>/dev/null || true
        COMPARTMENT_ID=$(terraform output -raw compartment_id 2>/dev/null || echo "")
        cd - > /dev/null 2>&1 || true
      fi

      if [[ -n "$COMPARTMENT_ID" ]]; then
        SECRET_OCID=$(oci vault secret list \
          --compartment-id "$COMPARTMENT_ID" \
          --name "homelab-oci-mgmt-ssh-private-key" \
          --lifecycle-state ACTIVE \
          --query 'data[0].id' \
          --raw-output 2>/dev/null || echo "")

        if [[ -n "$SECRET_OCID" && "$SECRET_OCID" != "null" ]]; then
          TEMP_KEY=$(mktemp)
          oci secrets secret-bundle get \
            --secret-id "$SECRET_OCID" \
            --stage CURRENT \
            --query 'data."secret-bundle-content".content' \
            --raw-output 2>/dev/null | \
            base64 -d > "$TEMP_KEY" 2>/dev/null || true

          if [[ -s "$TEMP_KEY" ]]; then
            chmod 600 "$TEMP_KEY"
            if ssh -i "$TEMP_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes ubuntu@"$VM_IP" "echo 'SSH OK'" >/dev/null 2>&1; then
              SSH_KEY="$TEMP_KEY"
              TEMP_SSH_KEY="$TEMP_KEY"
              echo -e "${GREEN}✅ Clé SSH récupérée depuis OCI Vault et testée${NC}"
            else
              rm -f "$TEMP_KEY"
            fi
          else
            rm -f "$TEMP_KEY"
          fi
        fi
      fi
    fi

    # If still not working, prompt user
    if ! ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes ubuntu@"$VM_IP" "echo 'SSH OK'" >/dev/null 2>&1; then
      echo -e "${RED}❌ La clé SSH ne fonctionne toujours pas.${NC}"
      echo -e "${YELLOW}Vérifie que la clé correspond à la VM ou fournis le bon chemin.${NC}"
      read -rp "Chemin vers la clé SSH privée: " SSH_KEY_INPUT
      if [[ -n "$SSH_KEY_INPUT" && -f "$SSH_KEY_INPUT" ]]; then
        SSH_KEY="$SSH_KEY_INPUT"
        chmod 600 "$SSH_KEY" 2>/dev/null || true
      else
        echo -e "${RED}❌ Clé SSH invalide${NC}"
        exit 1
      fi
    fi
  else
    echo -e "${GREEN}✅ Connexion SSH OK${NC}"
  fi
fi

echo -e "${BLUE}VM IP: $VM_IP${NC}"
echo -e "${BLUE}Email: $EMAIL${NC}"
echo -e "${BLUE}SSH Key: $SSH_KEY${NC}"
echo ""

# Menu
echo -e "${YELLOW}Choisis une option:${NC}"
echo "1) Reset le mot de passe d'un utilisateur existant"
echo "2) Créer un nouvel utilisateur admin"
echo "3) Réinitialiser complètement Authentik (⚠️  SUPPRIME TOUTES LES DONNÉES)"
echo ""
read -rp "Choix (1-3): " CHOICE

case "$CHOICE" in
  1)
    echo -e "\n${BLUE}=== Option 1: Reset mot de passe utilisateur ===${NC}"

    if [[ -z "$NEW_PASSWORD" ]]; then
      echo -e "${YELLOW}Générer un mot de passe aléatoire? (y/n):${NC}"
      read -rp "" GENERATE
      if [[ "$GENERATE" =~ ^[Yy]$ ]]; then
        NEW_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
        echo -e "${GREEN}Mot de passe généré: $NEW_PASSWORD${NC}"
      else
        read -rsp "Entrez le nouveau mot de passe: " NEW_PASSWORD
        echo ""
      fi
    fi

    echo -e "\n${BLUE}Reset du mot de passe pour: $EMAIL${NC}"

    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$VM_IP" bash -s "$EMAIL" "$NEW_PASSWORD" <<'EOF'
EMAIL=$1
NEW_PASSWORD=$2
set -e
cd ~/homelab/oci-mgmt || cd /opt/oci-mgmt || cd ~/oci-mgmt

# Check if containers are running
if ! docker compose ps 2>/dev/null | grep -q authentik-server; then
  echo "❌ Authentik n'est pas démarré. Démarrage..."
  docker compose up -d authentik-server authentik-worker
  echo "⏳ Attente du démarrage d'Authentik..."
  sleep 10
fi

# Reset password or create user if doesn't exist
docker compose exec -T authentik-server ak reset_password --email "$EMAIL" --password "$NEW_PASSWORD" 2>/dev/null || \
docker compose exec -T authentik-server ak shell -c "
from authentik.core.models import User
from authentik.core.models import Group
user, created = User.objects.get_or_create(
    email='$EMAIL',
    defaults={
        'username': '$EMAIL',
        'name': '$EMAIL',
    }
)
user.set_password('$NEW_PASSWORD')
user.is_superuser = True
user.is_active = True
user.save()
try:
    admin_group = Group.objects.get(name='authentik Admins')
    user.ak_groups.add(admin_group)
except Group.DoesNotExist:
    pass
print('✅ User created/updated:', user.email)
" || true

echo "✅ Mot de passe reset pour $EMAIL"
EOF

    echo -e "\n${GREEN}✅ Mot de passe reset avec succès!${NC}"
    echo -e "${GREEN}Nouveau mot de passe: $NEW_PASSWORD${NC}"
    ;;

  2)
    echo -e "\n${BLUE}=== Option 2: Créer un nouvel utilisateur admin ===${NC}"

    if [[ -z "$NEW_PASSWORD" ]]; then
      NEW_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
      echo -e "${GREEN}Mot de passe généré: $NEW_PASSWORD${NC}"
    fi

    echo -e "\n${BLUE}Création d'un nouvel utilisateur admin: $EMAIL${NC}"

    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$VM_IP" bash -s "$EMAIL" "$NEW_PASSWORD" <<'EOF'
EMAIL=$1
NEW_PASSWORD=$2
set -e
cd ~/homelab/oci-mgmt || cd /opt/oci-mgmt || cd ~/oci-mgmt

# Check if containers are running
if ! docker compose ps 2>/dev/null | grep -q authentik-server; then
  echo "❌ Authentik n'est pas démarré. Démarrage..."
  docker compose up -d authentik-server authentik-worker
  echo "⏳ Attente du démarrage d'Authentik..."
  sleep 10
fi

# Create new admin user
docker compose exec -T authentik-server ak shell -c "
from authentik.core.models import User
from authentik.core.models import Group
user, created = User.objects.get_or_create(
    email='$EMAIL',
    defaults={
        'username': '$EMAIL',
        'name': '$EMAIL',
    }
)
user.set_password('$NEW_PASSWORD')
user.is_superuser = True
user.is_active = True
user.save()
try:
    admin_group = Group.objects.get(name='authentik Admins')
    user.ak_groups.add(admin_group)
except Group.DoesNotExist:
    pass
if created:
    print('✅ User created:', user.email)
else:
    print('✅ User updated:', user.email)
"

echo "✅ Utilisateur admin créé: $EMAIL"
EOF

    echo -e "\n${GREEN}✅ Nouvel utilisateur admin créé!${NC}"
    echo -e "${GREEN}Email: $EMAIL${NC}"
    echo -e "${GREEN}Mot de passe: $NEW_PASSWORD${NC}"
    ;;

  3)
    echo -e "\n${RED}⚠️  ATTENTION: Cette option va SUPPRIMER TOUTES LES DONNÉES Authentik!${NC}"
    echo -e "${RED}Cela inclut:${NC}"
    echo -e "${RED}  - Tous les utilisateurs${NC}"
    echo -e "${RED}  - Toutes les applications${NC}"
    echo -e "${RED}  - Toutes les configurations${NC}"
    echo ""
    read -rp "Es-tu sûr de vouloir continuer? (tape 'RESET' en majuscules): " CONFIRM

    if [[ "$CONFIRM" != "RESET" ]]; then
      echo -e "${YELLOW}Annulé.${NC}"
      exit 0
    fi

    if [[ -z "$NEW_PASSWORD" ]]; then
      NEW_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
      echo -e "${GREEN}Mot de passe pour le nouvel admin: $NEW_PASSWORD${NC}"
    fi

    echo -e "\n${BLUE}=== Option 3: Réinitialisation complète d'Authentik ===${NC}"
    echo -e "${YELLOW}Arrêt d'Authentik...${NC}"

    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$VM_IP" bash -s "$EMAIL" "$NEW_PASSWORD" <<'EOF'
EMAIL=$1
NEW_PASSWORD=$2
set -e
cd ~/homelab/oci-mgmt || cd /opt/oci-mgmt || cd ~/oci-mgmt

# Stop Authentik
echo "Arrêt d'Authentik..."
docker compose stop authentik-server authentik-worker || true

# Backup database (just in case)
echo "Sauvegarde de la base de données..."
docker compose exec -T postgres pg_dump -U authentik authentik > /tmp/authentik_backup_$(date +%Y%m%d_%H%M%S).sql 2>/dev/null || true

# Remove Authentik database
echo "Suppression de la base de données Authentik..."
docker compose exec -T postgres psql -U authentik -d postgres <<SQL
DROP DATABASE IF EXISTS authentik;
CREATE DATABASE authentik;
SQL

# Restart Authentik (will recreate database)
echo "Redémarrage d'Authentik..."
docker compose up -d authentik-server authentik-worker

echo "⏳ Attente du démarrage d'Authentik (30 secondes)..."
sleep 30

# Create new admin user
echo "Création du nouvel utilisateur admin..."
docker compose exec -T authentik-server ak create_user \
  --email "$EMAIL" \
  --username "$EMAIL" \
  --name "$EMAIL" \
  --password "$NEW_PASSWORD" \
  --is-superuser

echo "✅ Authentik réinitialisé avec succès!"
EOF

    echo -e "\n${GREEN}✅ Authentik complètement réinitialisé!${NC}"
    echo -e "${GREEN}Nouvel utilisateur admin:${NC}"
    echo -e "${GREEN}  Email: $EMAIL${NC}"
    echo -e "${GREEN}  Mot de passe: $NEW_PASSWORD${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Note: Tu devras reconfigurer:${NC}"
    echo -e "${YELLOW}  - Les applications (Omni, etc.)${NC}"
    echo -e "${YELLOW}  - Les groupes${NC}"
    echo -e "${YELLOW}  - Les flows (recovery flow, etc.)${NC}"
    echo -e "${YELLOW}  - Les providers${NC}"
    ;;

  *)
    echo -e "${RED}❌ Choix invalide${NC}"
    exit 1
    ;;
esac

# Cleanup temp SSH key if used
if [[ -n "$TEMP_SSH_KEY" && -f "$TEMP_SSH_KEY" ]]; then
  rm -f "$TEMP_SSH_KEY"
fi

echo ""
echo -e "${GREEN}✅ Opération terminée!${NC}"
echo -e "${BLUE}Tu peux maintenant te connecter sur: https://auth.smadja.dev${NC}"
