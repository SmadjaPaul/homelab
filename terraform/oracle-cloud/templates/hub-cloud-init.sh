#!/bin/bash
# Cloud-init pour VM Hub (oci-hub)
# Services: Omni + Tailscale + Comet
# NOTE: Cloudflared (tunnel) tourne dans le cluster K8s (GitOps)

set -e
exec > >(tee /var/log/cloud-init-oci-hub.log) 2>&1
echo "=== Starting OCI Hub Setup ==="

# ==========================================================================
# SYSTEM UPDATES
# ==========================================================================
echo "[1/7] Updating system..."
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get upgrade -y

# ==========================================================================
# SECURITY HARDENING
# ==========================================================================
echo "[2/7] Installing security tools..."
apt-get install -y fail2ban ufw unattended-upgrades curl gnupg

# Configure fail2ban
cat > /etc/fail2ban/jail.local << 'FAIL2BAN'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
FAIL2BAN

systemctl enable fail2ban
systemctl restart fail2ban

# Configure UFW - Seulement SSH (le reste via Tailscale)
# Cloudflared tourne dans K8s, pas besoin d'ouvrir de ports ici
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow from 10.0.0.0/16  # Internal VCN
echo "y" | ufw enable

# Automatic security updates
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'AUTOUPDATE'
Unattended-Upgrade::Allowed-Origins {
    "$${distro_id}:$${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
AUTOUPDATE

systemctl enable unattended-upgrades

# SSH hardening
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
systemctl reload sshd

# ==========================================================================
# TAILSCALE INSTALL
# ==========================================================================
echo "[3/7] Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# Connect to Tailscale (subnet router mode)
if [ -n "${tailscale_auth_key}" ]; then
    tailscale up --authkey="${tailscale_auth_key}" --advertise-routes=10.0.0.0/16 --accept-dns=false
    echo "Tailscale connected successfully"
else
    echo "WARNING: No Tailscale auth key provided. Manual connection required."
    echo "Run: tailscale up --advertise-routes=10.0.0.0/16"
fi

# ==========================================================================
# DOCKER INSTALLATION
# ==========================================================================
echo "[4/7] Installing Docker..."
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu
apt-get install -y docker-compose-plugin

# ==========================================================================
# OMNI INSTALL
# ==========================================================================
echo "[5/7] Setting up Omni..."
mkdir -p /opt/omni/data
mkdir -p /opt/omni/etcd

# Create Omni compose file
cat > /opt/omni/docker-compose.yaml << 'OMNI_COMPOSE'
services:
  omni:
    image: ghcr.io/siderolabs/omni:latest
    container_name: omni
    restart: always
    ports:
      - "50000:50000"
      - "50001:50001"
    volumes:
      - ./data:/data
      - ./etcd:/.etcd
    environment:
      - OMNI_ETCD_DATA_DIR=/.etcd
    command: >
      --data-dir=/data
      --advertise-addr=PUBLIC_IP:50000
      --bind-addr=0.0.0.0:50000
      --http-bind-addr=0.0.0.0:50001
      --private-key-source=file:///data/omni.asc
      --public-key-source=file:///data/omni.asc
      --machine-api-bind-addr=0.0.0.0:50002
      --etcd-embed=true
      --etcd-endpoints=http://127.0.0.1:2379
OMNI_COMPOSE

# Replace PUBLIC_IP with actual IP
PUBLIC_IP=$(curl -s ifconfig.me)
sed -i "s/PUBLIC_IP/$PUBLIC_IP/g" /opt/omni/docker-compose.yaml

chown -R ubuntu:ubuntu /opt/omni

# ==========================================================================
# COMET INSTALL (Streaming)
# ==========================================================================
%{ if comet_enabled }
echo "[6/7] Setting up Comet..."
mkdir -p /opt/comet/data

cat > /opt/comet/docker-compose.yaml << 'COMET_COMPOSE'
services:
  comet:
    image: ghcr.io/g0ldyy/comet:latest
    container_name: comet
    restart: always
    ports:
      - "8080:8080"
    volumes:
      - ./data:/data
    environment:
      - DATABASE_PATH=/data/comet.db
      - LOG_LEVEL=info
      - PORT=8080
COMET_COMPOSE

chown -R ubuntu:ubuntu /opt/comet
%{ else }
echo "[6/7] Comet disabled"
%{ endif }

# ==========================================================================
# START SERVICES
# ==========================================================================
echo "[7/7] Starting services..."
cd /opt/omni && docker compose up -d

%{ if comet_enabled }
cd /opt/comet && docker compose up -d
%{ endif }

# ==========================================================================
# SETUP DIRECTORIES
# ==========================================================================
mkdir -p /opt/homelab/{scripts,backup}
mkdir -p /home/ubuntu/homelab
chown -R ubuntu:ubuntu /opt/homelab /home/ubuntu/homelab

echo "=== OCI Hub Setup Complete ==="
echo "Services installed on VM Hub:"
echo "  - fail2ban (security)"
echo "  - UFW firewall"
echo "  - Tailscale (VPN mesh - admin only)"
echo "  - Docker"
echo "  - Omni (K8s management)"
%{ if comet_enabled }
echo "  - Comet (streaming - direct)"
%{ endif }
echo ""
echo "Services in K8s cluster (GitOps):"
echo "  - Cloudflare Tunnel (public services)"
echo "  - Traefik (ingress)"
echo "  - All apps (Nextcloud, Matrix, etc.)"
echo ""
echo "Access:"
echo "  Tailscale: sudo tailscale status"
echo "  Omni: https://$PUBLIC_IP:50001 (via Tailscale)"
%{ if comet_enabled }
echo "  Comet: http://$PUBLIC_IP:8080 (direct + Cloudflare Access)"
%{ endif }
echo "  K8s Dashboard: http://localhost:8080 (kubectl port-forward)"
