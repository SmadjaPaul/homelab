# Compute Instances for Oracle Cloud

# Management VM (Omni, Authentik, Cloudflare Tunnel)
resource "oci_core_instance" "management" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index % length(data.oci_identity_availability_domains.ads.availability_domains)].name
  display_name        = var.management_vm.name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.management_vm.ocpus
    memory_in_gbs = var.management_vm.memory
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.management_vm.disk
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true # Use ephemeral public IP for SSH access
    display_name     = "${var.management_vm.name}-vnic"
    hostname_label   = var.management_vm.name
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(<<-EOF
      #!/bin/bash
      set -e
      exec > >(tee /var/log/cloud-init-homelab.log) 2>&1
      echo "=== Starting Homelab VM Setup ==="

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
      apt-get install -y fail2ban ufw unattended-upgrades

      # Configure fail2ban for SSH protection
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

      # Configure UFW (SSH always; 80/443 only if allow_public_http_https)
      echo "[3/7] Configuring firewall (UFW)..."
      ufw default deny incoming
      ufw default allow outgoing
      ufw allow ssh
      ${var.allow_public_http_https ? "ufw allow 80/tcp\n      ufw allow 443/tcp" : ""}
      # Allow internal VCN traffic
      ufw allow from 10.0.0.0/16
      echo "y" | ufw enable

      # Configure automatic security updates
      echo "[4/7] Enabling automatic security updates..."
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
      echo "[5/7] Hardening SSH configuration..."
      sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
      sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
      sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
      sed -i 's/#MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
      systemctl reload sshd

      # ==========================================================================
      # DOCKER INSTALLATION
      # ==========================================================================
      echo "[6/7] Installing Docker..."
      curl -fsSL https://get.docker.com | sh
      usermod -aG docker ubuntu

      # Install Docker Compose
      apt-get install -y docker-compose-plugin

      # ==========================================================================
      # APPLICATION SETUP
      # ==========================================================================
      echo "[7/7] Creating application directories..."
      mkdir -p /opt/homelab/{omni,authentik,cloudflared,nginx}
      mkdir -p /home/ubuntu/homelab
      chown -R ubuntu:ubuntu /opt/homelab /home/ubuntu/homelab

      echo "=== Homelab VM Setup Complete ==="
      echo "Security features enabled:"
      echo "  - fail2ban (SSH brute-force protection)"
      echo "  - UFW firewall (22 + optional 80/443 per allow_public_http_https)"
      echo "  - Automatic security updates"
      echo "  - SSH hardening (key-only, no root)"
    EOF
    )
  }

  freeform_tags = merge(var.tags, {
    Role = "management"
  })
}

# Management VM public IP (from VNIC; instance has no direct public_ip attribute)
data "oci_core_vnic_attachments" "management" {
  compartment_id = var.compartment_id
  instance_id    = oci_core_instance.management.id
}

data "oci_core_vnic" "management" {
  vnic_id = data.oci_core_vnic_attachments.management.vnic_attachments[0].vnic_id
}

# Kubernetes Nodes — Talos Linux from first boot when talos_image_id is set
# Approach: use the image generated by Omni (pre-configured with credentials). See README and
# https://blog.zwindler.fr/2025/01/04/sideros-omni-talos-oracle-cloud/
# Private IPs: 10.0.1.10 (control plane), 10.0.1.11, ... (workers)
locals {
  k8s_node_private_ips = [for i in range(length(var.k8s_nodes)) : "10.0.1.${10 + i}"]
}

resource "oci_core_instance" "k8s_node" {
  count = length(var.k8s_nodes)

  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[count.index % length(data.oci_identity_availability_domains.ads.availability_domains)].name
  display_name        = var.k8s_nodes[count.index].name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.k8s_nodes[count.index].ocpus
    memory_in_gbs = var.k8s_nodes[count.index].memory
  }

  source_details {
    source_type             = "image"
    source_id               = var.talos_image_id != "" ? var.talos_image_id : data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.k8s_nodes[count.index].disk
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    private_ip       = local.k8s_node_private_ips[count.index]
    display_name     = "${var.k8s_nodes[count.index].name}-vnic"
    hostname_label   = var.k8s_nodes[count.index].name
  }

  # Talos image from Omni is pre-configured (no user_data). Ubuntu fallback uses SSH key.
  metadata = var.talos_image_id != "" ? {} : {
    ssh_authorized_keys = var.ssh_public_key
  }

  freeform_tags = merge(var.tags, {
    Role = "kubernetes"
    Node = var.k8s_nodes[count.index].name
  })
}

# K8s node VNICs (for public IP in outputs; instance has no direct public_ip attribute)
data "oci_core_vnic_attachments" "k8s_node" {
  count          = length(oci_core_instance.k8s_node)
  compartment_id = var.compartment_id
  instance_id    = oci_core_instance.k8s_node[count.index].id
}

data "oci_core_vnic" "k8s_node" {
  count   = length(oci_core_instance.k8s_node)
  vnic_id = data.oci_core_vnic_attachments.k8s_node[count.index].vnic_attachments[0].vnic_id
}
