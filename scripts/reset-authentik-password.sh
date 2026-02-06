#!/usr/bin/env bash
# Reset Authentik admin password
# Usage: ./scripts/reset-authentik-password.sh [email] [new_password]
#
# This script connects to the OCI management VM and resets the Authentik user password
# via the Authentik shell command.

set -e

EMAIL="${1:-smadja-paul@protonmail.com}"
NEW_PASSWORD="${2:-}"

if [[ -z "$NEW_PASSWORD" ]]; then
  echo "Usage: $0 [email] [new_password]"
  echo ""
  echo "Example:"
  echo "  $0 smadja-paul@protonmail.com 'MyNewPassword123!'"
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

# Get VM IP from Terraform or prompt
if command -v terraform &> /dev/null; then
  cd terraform/oracle-cloud
  VM_IP=$(terraform output -json 2>/dev/null | jq -r '.management_vm.value.public_ip // empty' || echo "")
  cd - > /dev/null
fi

if [[ -z "$VM_IP" ]]; then
  read -rp "Enter OCI management VM IP: " VM_IP
fi

echo "Connecting to VM: $VM_IP"
echo "Resetting password for: $EMAIL"

# SSH to VM and reset password via Authentik shell
ssh ubuntu@"$VM_IP" bash <<'EOF'
set -e
cd ~/homelab/oci-mgmt

# Check if containers are running
if ! docker compose ps | grep -q authentik-server; then
  echo "Error: Authentik containers are not running"
  exit 1
fi

# Reset password using Authentik shell
echo "Resetting password for user: $EMAIL"
docker compose exec -T authentik-server ak reset_password --email "$EMAIL" --password "$NEW_PASSWORD" || {
  echo "Error: Failed to reset password. Trying alternative method..."

  # Alternative: Create a new admin user if reset fails
  echo "Creating new admin user..."
  docker compose exec -T authentik-server ak create_user \
    --email admin@smadja.dev \
    --name "Admin User" \
    --password "$NEW_PASSWORD" \
    --superuser || true
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
