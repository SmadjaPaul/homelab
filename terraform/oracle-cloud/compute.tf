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
    assign_public_ip = false # Reserved public IP attached separately; do not change or Terraform will try to add an ephemeral IP and conflict with existing
    display_name     = "${var.management_vm.name}-vnic"
    hostname_label   = var.management_vm.name
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(<<-EOF
      #!/bin/bash
      # Update system
      apt-get update && apt-get upgrade -y

      # Install Docker
      curl -fsSL https://get.docker.com | sh
      usermod -aG docker ubuntu

      # Install Docker Compose
      apt-get install -y docker-compose-plugin

      # Create directories for services
      mkdir -p /opt/homelab/{omni,authentik,cloudflared,nginx}
      chown -R ubuntu:ubuntu /opt/homelab

      echo "Management VM setup complete" > /var/log/cloud-init-homelab.log
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

# Kubernetes Nodes
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
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.k8s_nodes[count.index].disk
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    display_name     = "${var.k8s_nodes[count.index].name}-vnic"
    hostname_label   = var.k8s_nodes[count.index].name
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    # Talos Linux will be installed later via ISO
    # For now, Ubuntu is used as a placeholder
  }

  freeform_tags = merge(var.tags, {
    Role = "kubernetes"
    Node = var.k8s_nodes[count.index].name
  })
}
