#!/bin/bash
# Proxmox VE Post-Installation Script
# Run this after installing Proxmox and adding disks
#
# Usage: ./post-install.sh
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

log "Starting Proxmox VE post-installation..."

# =============================================================================
# 1. Disable Enterprise Repository (for non-subscribers)
# =============================================================================
log "Configuring repositories..."

# Disable enterprise repo
if [ -f /etc/apt/sources.list.d/pve-enterprise.list ]; then
    sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
    log "Disabled enterprise repository"
fi

# Add no-subscription repository
if ! grep -q "pve-no-subscription" /etc/apt/sources.list; then
    echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >> /etc/apt/sources.list
    log "Added no-subscription repository"
fi

# =============================================================================
# 2. Update System
# =============================================================================
log "Updating system..."
apt-get update
apt-get dist-upgrade -y

# =============================================================================
# 3. Install Useful Packages
# =============================================================================
log "Installing additional packages..."
apt-get install -y \
    vim \
    htop \
    iotop \
    tmux \
    curl \
    wget \
    git \
    lm-sensors \
    smartmontools \
    nvme-cli \
    hdparm \
    iperf3

# =============================================================================
# 4. Configure SSH
# =============================================================================
log "Configuring SSH..."

# Disable root password login (use keys)
sed -i 's/#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl restart sshd

log "SSH configured (key-based auth only)"

# =============================================================================
# 5. Enable IOMMU (for PCI passthrough)
# =============================================================================
log "Checking IOMMU..."

if ! grep -q "iommu=on" /etc/default/grub; then
    # Detect CPU vendor
    if grep -q "Intel" /proc/cpuinfo; then
        IOMMU_PARAM="intel_iommu=on"
    else
        IOMMU_PARAM="amd_iommu=on"
    fi

    sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet ${IOMMU_PARAM} iommu=pt\"/" /etc/default/grub
    update-grub
    log "IOMMU enabled (reboot required)"
else
    log "IOMMU already configured"
fi

# =============================================================================
# 6. Load VFIO modules
# =============================================================================
log "Configuring VFIO modules..."

cat > /etc/modules-load.d/vfio.conf << EOF
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF

log "VFIO modules configured"

# =============================================================================
# 7. Disable Subscription Nag
# =============================================================================
log "Disabling subscription nag..."

# Create script to remove nag
cat > /usr/local/bin/disable-pve-nag.sh << 'SCRIPT'
#!/bin/bash
# Remove subscription nag from Proxmox VE
sed -Ezi.bak "s/(Ext\.Msg\.show\(\{[^}]+get498teletext\s+title: gettext\('No valid subscription).teletext+teletext(\}\);)/void({ title: '', msg: '' });\n\t\t\1\2/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy.service
SCRIPT

chmod +x /usr/local/bin/disable-pve-nag.sh
# Run it
/usr/local/bin/disable-pve-nag.sh 2>/dev/null || warn "Could not disable nag (may already be disabled)"

# =============================================================================
# 8. Configure Sensors
# =============================================================================
log "Detecting sensors..."
sensors-detect --auto || true

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=========================================="
log "Post-installation complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Reboot to apply IOMMU changes: reboot"
echo "2. Configure ZFS storage (see setup-zfs.sh)"
echo "3. Configure network bridges"
echo "4. Install Talos Linux VMs"
echo ""
