#!/bin/bash
# ZFS Storage Pool Setup for Proxmox (interactif)
# Run this after adding your storage disks
#
# Usage: ./setup-zfs.sh
#
# Recommandation homelab : 2×14 To uniquement en miroir.
#   - Script dédié (non interactif) : ./setup-zfs-14tb-only.sh sda sdb
#   - Voir docs-site/docs/infrastructure/proxmox.md pour le guide complet (SSH puis ZFS).
#
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root"
fi

echo "=========================================="
echo "       ZFS Storage Pool Setup"
echo "=========================================="
echo ""

# =============================================================================
# 1. List available disks
# =============================================================================
log "Available disks:"
echo ""
lsblk -d -o NAME,SIZE,MODEL,SERIAL | grep -v "loop\|sr0"
echo ""

# =============================================================================
# 2. Get disk selection
# =============================================================================
echo "Enter the disks to use for ZFS pool (space-separated, e.g., sda sdb):"
echo "WARNING: All data on these disks will be destroyed!"
read -rp "Disks: " DISK_INPUT

if [ -z "$DISK_INPUT" ]; then
    error "No disks specified"
fi

# Convert to array
IFS=' ' read -ra DISKS <<< "$DISK_INPUT"
DISK_COUNT=${#DISKS[@]}

log "Selected ${DISK_COUNT} disk(s): ${DISKS[*]}"

# Build disk paths
DISK_PATHS=""
for disk in "${DISKS[@]}"; do
    DISK_PATHS+="/dev/${disk} "
done

# =============================================================================
# 3. Choose pool configuration
# =============================================================================
echo ""
echo "Choose ZFS pool configuration:"
echo "1) stripe  - No redundancy (RAID 0) - Maximum space"
echo "2) mirror  - Mirror (RAID 1) - Requires 2+ disks"
echo "3) raidz1  - Single parity (RAID 5) - Requires 3+ disks"
echo "4) raidz2  - Double parity (RAID 6) - Requires 4+ disks"
read -rp "Selection [1-4]: " POOL_TYPE

case $POOL_TYPE in
    1) VDEV_TYPE="" ;;
    2) VDEV_TYPE="mirror" ;;
    3) VDEV_TYPE="raidz1" ;;
    4) VDEV_TYPE="raidz2" ;;
    *) error "Invalid selection" ;;
esac

# =============================================================================
# 4. Pool name
# =============================================================================
read -rp "Pool name [tank]: " POOL_NAME
POOL_NAME=${POOL_NAME:-tank}

# =============================================================================
# 5. Confirm
# =============================================================================
echo ""
echo "=========================================="
echo "Configuration Summary:"
echo "=========================================="
echo "Pool name: ${POOL_NAME}"
echo "Pool type: ${VDEV_TYPE:-stripe}"
echo "Disks: ${DISK_PATHS}"
echo ""
echo "WARNING: This will DESTROY all data on these disks!"
read -rp "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    error "Aborted"
fi

# =============================================================================
# 6. Create ZFS pool
# =============================================================================
log "Creating ZFS pool..."

# shellcheck disable=SC2086
zpool create -f \
    -o ashift=12 \
    -O atime=off \
    -O compression=lz4 \
    -O xattr=sa \
    -O acltype=posixacl \
    -O recordsize=128K \
    ${POOL_NAME} ${VDEV_TYPE} ${DISK_PATHS}

log "ZFS pool created successfully!"

# =============================================================================
# 7. Create datasets
# =============================================================================
log "Creating datasets..."

# VM disks
zfs create -o recordsize=64K "${POOL_NAME}/vm-disks"

# Container storage
zfs create "${POOL_NAME}/containers"

# Backups
zfs create -o compression=zstd "${POOL_NAME}/backups"

# ISO storage
zfs create "${POOL_NAME}/iso"

# Snippets
zfs create "${POOL_NAME}/snippets"

log "Datasets created"

# =============================================================================
# 8. Add to Proxmox
# =============================================================================
log "Adding storage to Proxmox..."

# Add ZFS storage for VMs
pvesm add zfspool "${POOL_NAME}-vm" \
    --pool "${POOL_NAME}/vm-disks" \
    --content images,rootdir \
    --sparse 1

# Add directory storage for ISOs and backups
pvesm add dir "${POOL_NAME}-iso" \
    --path "/${POOL_NAME}/iso" \
    --content iso,vztmpl

pvesm add dir "${POOL_NAME}-backup" \
    --path "/${POOL_NAME}/backups" \
    --content backup

log "Storage added to Proxmox"

# =============================================================================
# 9. Enable ZFS auto-scrub
# =============================================================================
log "Enabling monthly ZFS scrub..."

cat > /etc/cron.monthly/zfs-scrub << EOF
#!/bin/bash
# Monthly ZFS scrub
zpool scrub ${POOL_NAME}
EOF
chmod +x /etc/cron.monthly/zfs-scrub

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=========================================="
log "ZFS setup complete!"
echo "=========================================="
echo ""
zpool status "${POOL_NAME}"
echo ""
zfs list -r "${POOL_NAME}"
echo ""
echo "Storage is now available in Proxmox web UI"
