#!/usr/bin/env bash
# Restore PostgreSQL databases from OCI Object Storage backup
# Usage: ./scripts/restore-postgres.sh [backup_file] [VM_IP]
#
# This script:
# 1. Downloads the backup from OCI Object Storage
# 2. Restores it to PostgreSQL on the VM
# 3. Restarts Authentik services

set -e

BACKUP_FILE="${1:-}"
VM_IP="${2:-}"
BACKUP_BUCKET="${BACKUP_BUCKET:-homelab-backups}"
BACKUP_PREFIX="${BACKUP_PREFIX:-postgres}"

if [[ -z "$BACKUP_FILE" ]]; then
  echo "Usage: $0 [backup_file] [VM_IP]"
  echo ""
  echo "Example:"
  echo "  $0 postgres_backup_20240206_120000.sql.gz"
  echo ""
  echo "Available backups:"

  # List available backups
  NAMESPACE="${OCI_OBJECT_STORAGE_NAMESPACE:-}"
  if [[ -z "$NAMESPACE" ]] && command -v terraform &> /dev/null; then
    cd terraform/oracle-cloud
    NAMESPACE=$(terraform output -json 2>/dev/null | jq -r '.object_storage_namespace.value // empty' || echo "")
    cd - > /dev/null
  fi

  if [[ -n "$NAMESPACE" ]]; then
    oci os object list \
      --bucket-name "$BACKUP_BUCKET" \
      --namespace "$NAMESPACE" \
      --prefix "${BACKUP_PREFIX}/" \
      --query "data[?contains(name, 'postgres_backup_')].name" \
      --raw-output | jq -r '.[]' | sort -r | head -10
  fi

  exit 1
fi

# Get VM IP from Terraform if not provided
if [[ -z "$VM_IP" ]]; then
  if command -v terraform &> /dev/null; then
    cd terraform/oracle-cloud
    VM_IP=$(terraform output -json 2>/dev/null | jq -r '.management_vm.value.public_ip // empty' || echo "")
    cd - > /dev/null
  fi

  if [[ -z "$VM_IP" ]]; then
    read -rp "Enter OCI management VM IP: " VM_IP
  fi
fi

# Get namespace
NAMESPACE="${OCI_OBJECT_STORAGE_NAMESPACE:-}"
if [[ -z "$NAMESPACE" ]] && command -v terraform &> /dev/null; then
  cd terraform/oracle-cloud
  NAMESPACE=$(terraform output -json 2>/dev/null | jq -r '.object_storage_namespace.value // empty' || echo "")
  cd - > /dev/null
fi

if [[ -z "$NAMESPACE" ]]; then
  echo "Error: OCI Object Storage namespace not found"
  exit 1
fi

BACKUP_PATH="/tmp/$BACKUP_FILE"

echo "🔄 Starting PostgreSQL restore..."
echo "Backup file: $BACKUP_FILE"
echo "VM IP: $VM_IP"
echo ""

# Confirm restore
read -p "⚠️  This will REPLACE all current PostgreSQL data. Continue? (yes/no) " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  echo "Restore cancelled."
  exit 1
fi

# Step 1: Download backup from OCI Object Storage
echo ""
echo "1️⃣ Downloading backup from OCI Object Storage..."
oci os object get \
  --bucket-name "$BACKUP_BUCKET" \
  --namespace "$NAMESPACE" \
  --object-name "${BACKUP_PREFIX}/${BACKUP_FILE}" \
  --file "$BACKUP_PATH"

if [[ ! -f "$BACKUP_PATH" ]] || [[ ! -s "$BACKUP_PATH" ]]; then
  echo "Error: Backup file is empty or missing"
  exit 1
fi

BACKUP_SIZE=$(du -h "$BACKUP_PATH" | cut -f1)
echo "✅ Backup downloaded: $BACKUP_SIZE"

# Step 2: Upload to VM
echo ""
echo "2️⃣ Uploading backup to VM..."
scp "$BACKUP_PATH" ubuntu@"$VM_IP:$BACKUP_PATH"

# Step 3: Restore on VM
echo ""
echo "3️⃣ Restoring PostgreSQL databases..."
ssh ubuntu@"$VM_IP" bash <<'EOF'
set -e
cd ~/homelab/oci-mgmt

# Check if PostgreSQL container is running
if ! docker compose ps | grep -q postgres; then
  echo "Error: PostgreSQL container is not running"
  exit 1
fi

# Stop Authentik services (they depend on PostgreSQL)
echo "Stopping Authentik services..."
docker compose stop authentik-server authentik-worker authentik-outpost-proxy omni || true

# Restore database
echo "Restoring databases from backup..."
gunzip -c "$BACKUP_PATH" | docker compose exec -T postgres psql -U homelab -d postgres

# Restart services
echo "Restarting services..."
docker compose up -d

# Cleanup
rm -f "$BACKUP_PATH"

echo "✅ Restore completed!"
EOF

# Cleanup local file
rm -f "$BACKUP_PATH"

echo ""
echo "✅ Restore completed successfully!"
echo ""
echo "Services are restarting. Wait a few minutes, then check:"
echo "  - https://auth.smadja.dev"
echo "  - https://omni.smadja.dev"
