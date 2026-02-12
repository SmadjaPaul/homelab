#!/usr/bin/env bash
# Reset Authentik admin password
# Usage: ./scripts/reset-authentik-password.sh [email] [new_password] [vm_ip]
#
# VM IP (la CI utilise un state distant, pas le state local) :
#   - Variable d'environnement : OCI_MGMT_VM_IP=1.2.3.4
#   - Ou 3e argument : $0 email password 1.2.3.4
#   - Ou Terraform output si state local (terraform/oracle-cloud) contient la VM
#   - Sinon le script demandera l'IP.
#
# This script connects to the OCI management VM and resets the Authentik user password
# via the Authentik shell command.

set -e

EMAIL="${1:-smadja-paul@protonmail.com}"
NEW_PASSWORD="${2:-}"
VM_IP="${3:-}"

if [[ -z "$NEW_PASSWORD" ]]; then
  echo "Usage: $0 [email] [new_password] [vm_ip]"
  echo ""
  echo "Example:"
  echo "  $0 smadja-paul@protonmail.com 'MyNewPassword123!'"
  echo "  OCI_MGMT_VM_IP=1.2.3.4 $0 smadja-paul@protonmail.com 'MyNewPassword123!'"
  echo ""
  echo "⚠️  If no password is provided, a random one will be generated."
  read -p "Generate random password? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
  NEW_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-24)
  echo "Generated password: $NEW_PASSWORD"
fi

# VM IP: env > 3rd arg > Terraform (local state) > prompt
if [[ -z "$VM_IP" && -n "${OCI_MGMT_VM_IP:-}" ]]; then
  VM_IP="$OCI_MGMT_VM_IP"
fi

if [[ -z "$VM_IP" ]] && command -v terraform &> /dev/null && command -v jq &> /dev/null; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  TERRAFORM_DIR="$PROJECT_ROOT/terraform/oracle-cloud"
  if [[ -d "$TERRAFORM_DIR" ]]; then
    VM_IP=$(cd "$TERRAFORM_DIR" && terraform output -json 2>/dev/null | jq -r '.management_vm.value.public_ip // .management_vm.public_ip // empty' 2>/dev/null || echo "")
  fi
fi

if [[ -z "$VM_IP" ]]; then
  read -rp "Enter OCI management VM IP: " VM_IP
fi

echo "Connecting to VM: $VM_IP"
echo "Resetting password for: $EMAIL"

# SSH options: timeout pour ne pas rester bloqué, BatchMode pour éviter prompt mot de passe
# Clé : utiliser OCI_MGMT_SSH_KEY ou ~/.ssh/oci-homelab (même clé que la CI / Terraform)
SSH_OPTS=(-o ConnectTimeout=20 -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
[[ -n "${OCI_MGMT_SSH_KEY:-}" ]] && SSH_OPTS+=(-i "$OCI_MGMT_SSH_KEY")
# Fallback key used by CI/docs
[[ -z "${OCI_MGMT_SSH_KEY:-}" && -f "$HOME/.ssh/oci-homelab" ]] && SSH_OPTS+=(-i "$HOME/.ssh/oci-homelab")

echo "Testing SSH connectivity..."
if ! ssh "${SSH_OPTS[@]}" ubuntu@"$VM_IP" "echo OK" 2>/dev/null; then
  echo ""
  echo "Error: Cannot reach the VM via SSH (timeout 20s)."
  echo "  - Check that the VM IP is correct and the instance is running (OCI console)."
  echo "  - SSH key: set OCI_MGMT_SSH_KEY or use ~/.ssh/oci-homelab (private key of the key pair used in Terraform)."
  echo "  - If the VM is only reachable from a VPN or specific network, connect first then run this script."
  exit 1
fi

# SSH to VM and reset password via Authentik shell (pass args so remote receives them)
ssh "${SSH_OPTS[@]}" ubuntu@"$VM_IP" bash -s "$EMAIL" "$NEW_PASSWORD" <<'EOF'
set -e
EMAIL=$1
NEW_PASSWORD=$2
cd ~/homelab/oci-mgmt 2>/dev/null || cd /opt/oci-mgmt 2>/dev/null || cd ~/oci-mgmt

# Check if containers are running
if ! docker compose ps 2>/dev/null | grep -q authentik-server; then
  echo "Error: Authentik containers are not running"
  exit 1
fi

# Reset password using Authentik shell
echo "Resetting password for user: $EMAIL"
docker compose exec -T authentik-server ak reset_password --email "$EMAIL" --password "$NEW_PASSWORD" || {
  echo "Error: Failed to reset password. Trying alternative method..."

  # Alternative: Create/update user via shell if reset fails
  echo "Creating/updating admin user via shell..."
  docker compose exec -T authentik-server ak shell -c "
from authentik.core.models import User
from authentik.core.models import Group
user, created = User.objects.get_or_create(
    email='$EMAIL',
    defaults={'username': '$EMAIL', 'name': '$EMAIL'}
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
}

echo ""
echo "✅ Password reset complete!"
echo "Email: $EMAIL"
echo "New password: $NEW_PASSWORD"
echo ""
echo "⚠️  IMPORTANT: Save this password securely!"
EOF

echo ""
echo "✅ Password reset script completed!"
echo "Try logging in at: https://auth.smadja.dev"
echo ""
echo "Pour Terraform/CI: crée un token dans Authentik → Directory → Tokens & App passwords"
echo "→ Create token → copie la valeur → GitHub Secrets AUTHENTIK_TOKEN"
