#!/bin/bash
# Proxmox — Ajout cache ZFS (L2ARC + SLOG) depuis le NVMe
# À lancer APRÈS avoir créé le pool ZFS (setup-zfs.sh) et réservé des partitions sur le NVMe.
#
# Prérequis :
#   - Pool ZFS existant (ex. tank)
#   - NVMe avec partitions dédiées (ex. une pour L2ARC, une pour SLOG)
#     L’OS peut rester sur une autre partition du même NVMe.
#
# Usage: ./setup-nvme-cache.sh
#
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

[[ "$EUID" -ne 0 ]] && error "Run as root"

echo "=========================================="
echo "   ZFS Cache (L2ARC + SLOG) on NVMe"
echo "=========================================="
echo ""

# Pool existant
read -rp "Nom du pool ZFS (ex. tank) : " POOL_NAME
[[ -z "$POOL_NAME" ]] && error "Pool name required"
zpool list "$POOL_NAME" &>/dev/null || error "Pool $POOL_NAME not found"

# Disques / partitions disponibles
log "Disques et partitions disponibles :"
lsblk -d -o NAME,SIZE,MODEL,FSTYPE,MOUNTPOINT | grep -v "loop\|sr0"
echo ""

# L2ARC (cache lecture) — typiquement 50–100 Go
read -rp "Device ou partition pour L2ARC (ex. /dev/nvme0n1p2) : " L2ARC_DEV
if [[ -n "$L2ARC_DEV" ]]; then
  [[ -b "$L2ARC_DEV" ]] || error "Block device $L2ARC_DEV not found"
  warn "Les données sur $L2ARC_DEV seront utilisées par ZFS (pas effacées mais dédiées)."
  read -rp "Ajouter L2ARC à $POOL_NAME ? (yes/no) : " CONFIRM
  if [[ "$CONFIRM" == "yes" ]]; then
    zpool add -f "$POOL_NAME" cache "$L2ARC_DEV"
    log "L2ARC ajouté : $L2ARC_DEV"
  fi
fi

# SLOG (journal écriture synchrone) — typiquement 10–20 Go, miroir idéal
read -rp "Device ou partition pour SLOG (ex. /dev/nvme0n1p3) : " SLOG_DEV
if [[ -n "$SLOG_DEV" ]]; then
  [[ -b "$SLOG_DEV" ]] || error "Block device $SLOG_DEV not found"
  warn "Les données sur $SLOG_DEV seront effacées et utilisées comme SLOG."
  read -rp "Ajouter SLOG à $POOL_NAME ? (yes/no) : " CONFIRM
  if [[ "$CONFIRM" == "yes" ]]; then
    zpool add -f "$POOL_NAME" log "$SLOG_DEV"
    log "SLOG ajouté : $SLOG_DEV"
  fi
fi

echo ""
log "Cache configuré. Status du pool :"
zpool status "$POOL_NAME"
echo ""
echo "Pour un stockage rapide (apps/jeux) sur le reste du NVMe :"
echo "  1. Créer une partition sur le NVMe (ex. nvme0n1p4)"
echo "  2. zpool create -f -o ashift=12 nvme /dev/nvme0n1p4"
echo "  3. zfs create nvme/vm-disks"
echo "  4. pvesm add zfspool nvme-vm --pool nvme/vm-disks --content images,rootdir --sparse 1"
echo "  Puis dans Terraform : pm_storage_vm = \"nvme-vm\" pour les VMs rapides."
