#!/bin/bash
# GPU Passthrough Configuration Script for Proxmox VE
# Story: 1.1.3 - Configure GPU Passthrough
# Hardware: AOOSTAR WTR MAX, AMD Ryzen 7 8845HS, NVIDIA GPU
#
# This script completes GPU passthrough setup by:
# 1. Verifying IOMMU is enabled
# 2. Identifying GPU PCI ID
# 3. Blacklisting NVIDIA/nouveau drivers
# 4. Binding GPU to vfio-pci
# 5. Configuring persistent binding at boot
#
# Usage: ./configure-gpu-passthrough.sh
#
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root"
fi

log "Starting GPU passthrough configuration..."

# =============================================================================
# 1. Verify IOMMU is enabled (AC: #1)
# =============================================================================
log "Checking IOMMU status..."

if ! dmesg | grep -q -e "DMAR" -e "IOMMU"; then
    warn "IOMMU not detected in dmesg. Checking kernel parameters..."

    if grep -q "amd_iommu=on\|intel_iommu=on" /proc/cmdline; then
        warn "IOMMU parameter found in cmdline but not active. Reboot may be required."
    else
        error "IOMMU not enabled. Please run post-install.sh first or enable in BIOS and add kernel parameter."
    fi
else
    log "IOMMU is enabled and active"
    dmesg | grep -e "DMAR" -e "IOMMU" | head -5
fi

# =============================================================================
# 2. Identify GPU PCI ID (AC: #2, #3)
# =============================================================================
log "Identifying NVIDIA GPU..."

# Find NVIDIA GPU
GPU_INFO=$(lspci -nn | grep -i "nvidia\|vga.*nvidia" || true)

if [ -z "$GPU_INFO" ]; then
    error "No NVIDIA GPU found. Please verify GPU is installed and detected."
fi

log "Found GPU: $GPU_INFO"

# Extract PCI ID (format: [10de:xxxx])
GPU_PCI_ID=$(echo "$GPU_INFO" | grep -oP '\[10de:\w+\]' | head -1 | tr -d '[]')
GPU_PCI_BDF=$(echo "$GPU_INFO" | awk '{print $1}')

if [ -z "$GPU_PCI_ID" ]; then
    error "Could not extract GPU PCI ID. GPU info: $GPU_INFO"
fi

log "GPU PCI ID: $GPU_PCI_ID"
log "GPU PCI BDF: $GPU_PCI_BDF"

# Check if GPU is already bound to vfio-pci
CURRENT_DRIVER=$(lspci -nnk -s "$GPU_PCI_BDF" | grep -i "kernel driver" | awk '{print $4}' || echo "none")

if [ "$CURRENT_DRIVER" = "vfio-pci" ]; then
    log "GPU is already bound to vfio-pci"
    info "Current driver: $CURRENT_DRIVER"
else
    warn "GPU is currently using driver: ${CURRENT_DRIVER:-none}"
    info "Will bind to vfio-pci after blacklisting host drivers"
fi

# =============================================================================
# 3. Blacklist NVIDIA/nouveau drivers (AC: #3)
# =============================================================================
log "Configuring driver blacklist..."

BLACKLIST_FILE="/etc/modprobe.d/blacklist-nvidia.conf"

cat > "$BLACKLIST_FILE" << EOF
# Blacklist NVIDIA drivers on host to prevent host from using GPU
# Story: 1.1.3 - GPU Passthrough Configuration
# Generated: $(date)

# Blacklist nouveau (open-source NVIDIA driver)
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off

# Blacklist nvidia (proprietary driver)
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm
alias nvidia off
alias nvidia_drm off
alias nvidia_modeset off
alias nvidia_uvm off

# Prevent loading these modules
install nouveau /bin/false
install nvidia /bin/false
install nvidia_drm /bin/false
install nvidia_modeset /bin/false
install nvidia_uvm /bin/false
EOF

log "Blacklist configuration written to $BLACKLIST_FILE"

# Unload drivers if currently loaded
if lsmod | grep -q "^nvidia"; then
    warn "NVIDIA drivers are currently loaded. They will be unloaded on next boot."
    info "To unload now (may affect host display): modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia"
fi

if lsmod | grep -q "^nouveau"; then
    warn "Nouveau driver is currently loaded. It will be unloaded on next boot."
    info "To unload now (may affect host display): modprobe -r nouveau"
fi

# =============================================================================
# 4. Configure VFIO to bind GPU at boot (AC: #2, #3)
# =============================================================================
log "Configuring VFIO PCI binding..."

# Create VFIO configuration for GPU
VFIO_CONF_FILE="/etc/modprobe.d/vfio.conf"

# Check if vfio.conf already exists and contains GPU binding
if [ -f "$VFIO_CONF_FILE" ] && grep -q "options vfio-pci ids=" "$VFIO_CONF_FILE"; then
    warn "VFIO configuration already contains GPU binding. Updating..."
    # Remove existing ids line and add new one
    sed -i '/options vfio-pci ids=/d' "$VFIO_CONF_FILE"
fi

# Add GPU PCI ID to vfio-pci options
if ! grep -q "options vfio-pci ids=" "$VFIO_CONF_FILE" 2>/dev/null; then
    echo "options vfio-pci ids=$GPU_PCI_ID" >> "$VFIO_CONF_FILE"
    log "Added GPU binding to $VFIO_CONF_FILE"
else
    # Append to existing ids
    EXISTING_IDS=$(grep "options vfio-pci ids=" "$VFIO_CONF_FILE" | cut -d= -f2)
    sed -i "s|options vfio-pci ids=.*|options vfio-pci ids=$EXISTING_IDS,$GPU_PCI_ID|" "$VFIO_CONF_FILE"
    log "Updated GPU binding in $VFIO_CONF_FILE"
fi

# Ensure VFIO modules are loaded at boot (should already be done by post-install.sh)
MODULES_FILE="/etc/modules-load.d/vfio.conf"
if [ ! -f "$MODULES_FILE" ]; then
    cat > "$MODULES_FILE" << EOF
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF
    log "Created VFIO modules file: $MODULES_FILE"
else
    log "VFIO modules file already exists: $MODULES_FILE"
fi

# =============================================================================
# 5. Create initramfs update script (for early binding)
# =============================================================================
log "Configuring initramfs for early GPU binding..."

# Update initramfs to include VFIO modules and blacklist
update-initramfs -u -k all

log "Initramfs updated with VFIO configuration"

# =============================================================================
# 6. Verify configuration files
# =============================================================================
log "Verifying configuration..."

echo ""
info "=== Configuration Summary ==="
echo "GPU PCI ID: $GPU_PCI_ID"
echo "GPU PCI BDF: $GPU_PCI_BDF"
echo ""
echo "Files created/modified:"
echo "  - $BLACKLIST_FILE"
echo "  - $VFIO_CONF_FILE"
echo "  - $MODULES_FILE"
echo ""

# =============================================================================
# 7. Instructions for next steps
# =============================================================================
echo "=========================================="
log "GPU passthrough configuration complete!"
echo "=========================================="
echo ""
warn "REBOOT REQUIRED to apply changes"
echo ""
echo "Next steps after reboot:"
echo "1. Verify IOMMU: dmesg | grep -e DMAR -e IOMMU"
echo "2. Verify GPU binding: lspci -nnk -s $GPU_PCI_BDF | grep -i driver"
echo "   Expected: 'Kernel driver in use: vfio-pci'"
echo "3. In Proxmox UI, add GPU to VM:"
echo "   - Hardware → Add → PCI Device"
echo "   - Select: $GPU_PCI_BDF"
echo "   - Check 'All Functions' if needed"
echo "   - Check 'ROM-Bar' if GPU requires it"
echo "4. Test with a VM (see test instructions below)"
echo ""
echo "To test GPU passthrough:"
echo "  - Create a test VM (e.g., Ubuntu)"
echo "  - Add PCI device: $GPU_PCI_BDF"
echo "  - Boot VM and verify GPU: lspci | grep -i nvidia"
echo ""
