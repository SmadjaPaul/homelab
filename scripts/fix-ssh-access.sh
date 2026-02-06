#!/usr/bin/env bash
# Fix SSH access to OCI management VM
# This script helps diagnose and fix SSH connection issues
#
# Usage: ./scripts/fix-ssh-access.sh

set -e

echo "🔍 Diagnosing SSH access to OCI management VM..."
echo ""

# Get VM IP from Terraform
VM_IP=""
if command -v terraform &> /dev/null; then
  cd terraform/oracle-cloud
  VM_IP=$(terraform output -json 2>/dev/null | jq -r '.management_vm.value.public_ip // empty' || echo "")
  cd - > /dev/null
fi

if [[ -z "$VM_IP" ]]; then
  echo "❌ Could not get VM IP from Terraform"
  echo ""
  echo "Please provide the VM IP manually:"
  read -rp "VM IP: " VM_IP
fi

echo "VM IP: $VM_IP"
echo ""

# Check current IP
echo "1️⃣ Checking your current public IP..."
CURRENT_IP=$(curl -s https://api.ipify.org || echo "unknown")
echo "Your current IP: $CURRENT_IP"
echo ""

# Check SSH connectivity
echo "2️⃣ Testing SSH connectivity..."
if timeout 5 bash -c "echo > /dev/tcp/$VM_IP/22" 2>/dev/null; then
  echo "✅ Port 22 is open"
else
  echo "❌ Port 22 is not accessible (firewall/security list issue)"
  echo ""
  echo "Possible causes:"
  echo "  - Your IP ($CURRENT_IP) is not in admin_allowed_cidrs"
  echo "  - allow_ssh_from_anywhere is false"
  echo "  - Security list not attached to subnet"
  echo ""
fi

# Check Terraform variables
echo ""
echo "3️⃣ Checking Terraform configuration..."
cd terraform/oracle-cloud

if terraform output -json &>/dev/null; then
  ALLOW_ANYWHERE=$(terraform output -json 2>/dev/null | jq -r '.allow_ssh_from_anywhere.value // "false"' || echo "false")
  ADMIN_CIDRS=$(terraform output -json 2>/dev/null | jq -r '.admin_allowed_cidrs.value // []' || echo "[]")

  echo "allow_ssh_from_anywhere: $ALLOW_ANYWHERE"
  echo "admin_allowed_cidrs: $ADMIN_CIDRS"

  if [[ "$ALLOW_ANYWHERE" == "true" ]]; then
    echo "✅ SSH is allowed from anywhere (temporary setting)"
  else
    echo "⚠️  SSH is restricted to specific IPs"

    # Check if current IP is in the list
    IP_IN_LIST=false
    if echo "$ADMIN_CIDRS" | grep -q "$CURRENT_IP"; then
      IP_IN_LIST=true
    fi

    if [[ "$IP_IN_LIST" == "true" ]]; then
      echo "✅ Your IP ($CURRENT_IP) is in admin_allowed_cidrs"
    else
      echo "❌ Your IP ($CURRENT_IP) is NOT in admin_allowed_cidrs"
      echo ""
      echo "🔧 Solution: Add your IP to admin_allowed_cidrs"
      echo ""
      echo "Option 1: Update terraform.tfvars"
      echo "  admin_allowed_cidrs = [\"$CURRENT_IP/32\"]"
      echo ""
      echo "Option 2: Temporarily allow SSH from anywhere"
      echo "  allow_ssh_from_anywhere = true"
      echo ""
      echo "Then run: terraform apply"
    fi
  fi
else
  echo "⚠️  Could not read Terraform outputs"
fi

cd - > /dev/null

# Check SSH key
echo ""
echo "4️⃣ Checking SSH key..."
SSH_KEY="${HOME}/.ssh/oci_mgmt.pem"
if [[ -f "$SSH_KEY" ]]; then
  echo "✅ SSH key found: $SSH_KEY"
  chmod 600 "$SSH_KEY" 2>/dev/null || true
else
  echo "⚠️  SSH key not found: $SSH_KEY"
  echo ""
  echo "The script expects the key at: $SSH_KEY"
  echo "Or use: ssh -i <path-to-key> ubuntu@$VM_IP"
fi

# Try SSH connection
echo ""
echo "5️⃣ Attempting SSH connection..."
if [[ -f "$SSH_KEY" ]]; then
  if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$SSH_KEY" ubuntu@"$VM_IP" "echo 'SSH connection successful'" 2>&1; then
    echo "✅ SSH connection successful!"
  else
    SSH_ERROR=$?
    echo "❌ SSH connection failed (exit code: $SSH_ERROR)"
    echo ""
    echo "Common issues:"
    echo "  1. Firewall blocking (check above)"
    echo "  2. Wrong SSH key"
    echo "  3. VM not running"
    echo "  4. fail2ban blocking your IP"
    echo ""
    echo "Try manually:"
    echo "  ssh -i $SSH_KEY ubuntu@$VM_IP"
  fi
else
  echo "⚠️  Skipping SSH test (key not found)"
fi

echo ""
echo "📋 Summary:"
echo "  VM IP: $VM_IP"
echo "  Your IP: $CURRENT_IP"
echo "  SSH Key: ${SSH_KEY:-not found}"
echo ""
echo "Next steps:"
echo "  1. If your IP is not in admin_allowed_cidrs, add it to terraform.tfvars"
echo "  2. Run: cd terraform/oracle-cloud && terraform apply"
echo "  3. Wait 1-2 minutes for security list to update"
echo "  4. Try SSH again"
