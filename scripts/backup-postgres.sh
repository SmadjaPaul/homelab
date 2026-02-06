#!/usr/bin/env bash
# Backup PostgreSQL databases to OCI Object Storage
# Usage: ./scripts/backup-postgres.sh [VM_IP]
#
# This script:
# 1. Connects to the OCI management VM
# 2. Creates a backup of all PostgreSQL databases
# 3. Uploads the backup to OCI Object Storage
# 4. Keeps the last 7 daily backups

set -e

VM_IP="${1:-}"
BACKUP_BUCKET="${BACKUP_BUCKET:-homelab-backups}"
BACKUP_PREFIX="${BACKUP_PREFIX:-postgres}"

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

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="postgres_backup_${BACKUP_DATE}.sql.gz"
BACKUP_PATH="/tmp/${BACKUP_FILE}"

echo "📦 Starting PostgreSQL backup..."
echo "VM IP: $VM_IP"
echo "Backup file: $BACKUP_FILE"

# Step 1: Create backup on VM
echo ""
echo "1️⃣ Creating backup on VM..."
ssh ubuntu@"$VM_IP" bash <<'EOF'
set -e
cd ~/homelab/oci-mgmt

# Check if PostgreSQL container is running
if ! docker compose ps | grep -q postgres; then
  echo "Error: PostgreSQL container is not running"
  exit 1
fi

# Create backup
echo "Dumping all databases..."
docker compose exec -T postgres pg_dumpall -U homelab | gzip > "$BACKUP_PATH"

# Verify backup
if [[ ! -f "$BACKUP_PATH" ]] || [[ ! -s "$BACKUP_PATH" ]]; then
  echo "Error: Backup file is empty or missing"
  exit 1
fi

BACKUP_SIZE=\$(du -h "$BACKUP_PATH" | cut -f1)
echo "✅ Backup created: $BACKUP_FILE (\$BACKUP_SIZE)"
EOF

# Step 2: Download backup locally
echo ""
echo "2️⃣ Downloading backup..."
scp ubuntu@"$VM_IP:$BACKUP_PATH" "/tmp/$BACKUP_FILE"

# Step 3: Upload to OCI Object Storage
echo ""
echo "3️⃣ Uploading to OCI Object Storage..."

# Check if OCI CLI is configured
if ! command -v oci &> /dev/null; then
  echo "Error: OCI CLI not found. Install it or configure it first."
  exit 1
fi

# Get namespace from Terraform or config
NAMESPACE="${OCI_OBJECT_STORAGE_NAMESPACE:-}"
if [[ -z "$NAMESPACE" ]]; then
  if command -v terraform &> /dev/null; then
    cd terraform/oracle-cloud
    NAMESPACE=$(terraform output -json 2>/dev/null | jq -r '.object_storage_namespace.value // empty' || echo "")
    cd - > /dev/null
  fi
fi

if [[ -z "$NAMESPACE" ]]; then
  echo "Error: OCI Object Storage namespace not found"
  echo "Set OCI_OBJECT_STORAGE_NAMESPACE environment variable or configure Terraform outputs"
  exit 1
fi

# Get compartment ID
COMPARTMENT_ID="${OCI_COMPARTMENT_ID:-}"
if [[ -z "$COMPARTMENT_ID" ]]; then
  if command -v terraform &> /dev/null; then
    cd terraform/oracle-cloud
    COMPARTMENT_ID=$(terraform output -json 2>/dev/null | jq -r '.compartment_id.value // empty' || echo "")
    cd - > /dev/null
  fi
fi

if [[ -z "$COMPARTMENT_ID" ]]; then
  echo "Error: OCI Compartment ID not found"
  exit 1
fi

# Create bucket if it doesn't exist
echo "Checking if bucket exists..."
if ! oci os bucket get --bucket-name "$BACKUP_BUCKET" --namespace "$NAMESPACE" &>/dev/null; then
  echo "Creating bucket: $BACKUP_BUCKET"
  oci os bucket create \
    --compartment-id "$COMPARTMENT_ID" \
    --name "$BACKUP_BUCKET" \
    --namespace "$NAMESPACE" \
    --public-access-type "NoPublicAccess" \
    --storage-tier "Standard"
fi

# Upload backup
echo "Uploading backup to OCI Object Storage..."
oci os object put \
  --bucket-name "$BACKUP_BUCKET" \
  --namespace "$NAMESPACE" \
  --name "${BACKUP_PREFIX}/${BACKUP_FILE}" \
  --file "/tmp/$BACKUP_FILE" \
  --content-type "application/gzip"

echo "✅ Backup uploaded: ${BACKUP_PREFIX}/${BACKUP_FILE}"

# Step 4: Cleanup old backups (keep last 7 days)
echo ""
echo "4️⃣ Cleaning up old backups (keeping last 7 days)..."
oci os object list \
  --bucket-name "$BACKUP_BUCKET" \
  --namespace "$NAMESPACE" \
  --prefix "${BACKUP_PREFIX}/" \
  --query "data[?contains(name, 'postgres_backup_')].name" \
  --raw-output | jq -r '.[]' | sort -r | tail -n +8 | while read -r old_backup; do
  echo "Deleting old backup: $old_backup"
  oci os object delete \
    --bucket-name "$BACKUP_BUCKET" \
    --namespace "$NAMESPACE" \
    --object-name "$old_backup" \
    --force
done

# Cleanup local and remote temp files
echo ""
echo "5️⃣ Cleaning up temporary files..."
rm -f "/tmp/$BACKUP_FILE"
ssh ubuntu@"$VM_IP" "rm -f \$BACKUP_PATH"

echo ""
echo "✅ Backup completed successfully!"
echo ""
echo "Backup location: oci://$BACKUP_BUCKET/${BACKUP_PREFIX}/${BACKUP_FILE}"
echo ""
echo "To restore:"
echo "  ./scripts/restore-postgres.sh $BACKUP_FILE"
