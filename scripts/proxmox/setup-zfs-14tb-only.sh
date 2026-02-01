#!/bin/bash
# ZFS Storage Pool — Miroir 2×14 To uniquement (non interactif)
#
# Usage: ./setup-zfs-14tb-only.sh <disk1> <disk2> [pool_name]
#   disk1, disk2 : noms des disques (ex. sda sdb) — sans /dev/
#   pool_name    : nom du pool (défaut: tank)
#
# Exemple: CONFIRM=yes ./setup-zfs-14tb-only.sh sda sdb
#          CONFIRM=yes ./setup-zfs-14tb-only.sh sda sdb tank
#
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

[[ "$EUID" -ne 0 ]] && error "Please run as root"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <disk1> <disk2> [pool_name]"
  echo "  disk1, disk2 : e.g. sda sdb (the two 14 TB disks)"
  echo "  pool_name    : default tank"
  echo "Example: CONFIRM=yes $0 sda sdb"
  exit 1
fi

DISK1="$1"
DISK2="$2"
POOL_NAME="${3:-tank}"

for d in "$DISK1" "$DISK2"; do
  [[ -b "/dev/$d" ]] || error "Block device /dev/$d not found"
done

echo "=========================================="
echo "   ZFS Pool — Mirror 2×14 TB only"
echo "=========================================="
echo ""
log "Disks: /dev/$DISK1 /dev/$DISK2"
log "Pool:  $POOL_NAME (mirror)"
echo ""

if [[ "${CONFIRM}" != "yes" ]]; then
  echo "WARNING: All data on /dev/$DISK1 and /dev/$DISK2 will be DESTROYED!"
  read -rp "Type 'yes' to continue: " c
  [[ "$c" == "yes" ]] || error "Aborted"
fi

# Create mirror pool
log "Creating ZFS pool (mirror)..."
zpool create -f \
  -o ashift=12 \
  -O atime=off \
  -O compression=lz4 \
  -O xattr=sa \
  -O acltype=posixacl \
  -O recordsize=128K \
  "${POOL_NAME}" mirror "/dev/${DISK1}" "/dev/${DISK2}"

log "Creating datasets..."
zfs create -o recordsize=64K "${POOL_NAME}/vm-disks"
zfs create "${POOL_NAME}/containers"
zfs create -o compression=zstd "${POOL_NAME}/backups"
zfs create "${POOL_NAME}/iso"
zfs create "${POOL_NAME}/snippets"

log "Adding storage to Proxmox..."
pvesm add zfspool "${POOL_NAME}-vm" \
  --pool "${POOL_NAME}/vm-disks" \
  --content images,rootdir \
  --sparse 1

pvesm add dir "${POOL_NAME}-iso" \
  --path "/${POOL_NAME}/iso" \
  --content iso,vztmpl

pvesm add dir "${POOL_NAME}-backup" \
  --path "/${POOL_NAME}/backups" \
  --content backup

log "Enabling monthly ZFS scrub..."
cat > /etc/cron.monthly/zfs-scrub << EOF
#!/bin/bash
zpool scrub ${POOL_NAME}
EOF
chmod +x /etc/cron.monthly/zfs-scrub

echo ""
echo "=========================================="
log "ZFS setup complete (2×14 TB mirror)"
echo "=========================================="
echo ""
zpool status "${POOL_NAME}"
echo ""
zfs list -r "${POOL_NAME}"
