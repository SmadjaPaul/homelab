# Compute Module - Management VM

# Data: Ubuntu Image
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Management VM
resource "oci_core_instance" "management" {
  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = var.vm_name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.vm_ocpus
    memory_in_gbs = var.vm_memory
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.vm_disk
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.assign_public_ip
    display_name     = "${var.vm_name}-vnic"
    hostname_label   = var.vm_name
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(<<-EOF
      #!/bin/bash
      set -e
      echo "=== Starting Homelab VM Setup ==="
      
      # System updates
      export DEBIAN_FRONTEND=noninteractive
      apt-get update && apt-get upgrade -y
      
      # Install base packages
      apt-get install -y curl wget git docker.io
      
      echo "=== VM Setup Complete ==="
      EOF
    )
  }

  freeform_tags = var.tags
}

# Data: Availability Domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# =============================================================================
# Outputs
# =============================================================================

output "management_vm_id" {
  value = oci_core_instance.management.id
}

output "management_vm_ip" {
  value = oci_core_instance.management.public_ip
}

output "management_vm_private_ip" {
  value = oci_core_instance.management.private_ip
}
