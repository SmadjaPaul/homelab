terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

variable "name" {
  description = "The name of the VM"
  type        = string
}

resource "proxmox_virtual_environment_vm" "omni" {
  count = var.enable_omni ? 1 : 0

  # VM General Settings
  node_name   = var.proxmox_node
  name        = var.name
  description = "Sidero Omni + Proxmox Infra Provider"
  tags        = ["infrastructure", "kubernetes", "omni", "talos"]
  started     = var.start_on_boot

  agent {
    enabled = false
  }

  # Clone from template if available, otherwise create from scratch
  dynamic "clone" {
    for_each = var.template_vm_id != null ? [1] : []
    content {
      vm_id = var.template_vm_id
    }
  }

  # VM CPU Settings
  cpu {
    cores        = var.cores
    type         = "host"
  }

  # VM Memory Settings
  memory {
    dedicated = var.memory
  }

  # VM Network Settings
  network_device {
    bridge  = var.network_bridge
    vlan_id = var.network_vlan_id
  }

  # VM Disk Settings
  dynamic "disk" {
    for_each = var.template_vm_id == null ? [1] : []
    content {
      datastore_id = var.storage_pool
      size         = var.disk_size
      interface    = "virtio0"
    }
  }

  # Use Q35 machine type
  machine = "q35"

  # OVMF for UEFI boot
  bios = "ovmf"

  vga {
    type = "std"
  }

  # CD-ROM for OS installation
  cdrom {
    enabled   = true
    file_id   = "tank-iso:iso/metal-amd64.iso"
    interface = "ide3"
  }

  boot_order = ["ide3", "virtio0"]

  # Cloud-init configuration (without user_data_file_id for now)
  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip_address}/${var.subnet_mask}"
        gateway = var.gateway
      }
    }
  }

  lifecycle {
    ignore_changes = [
      initialization[0].user_account[0].keys,
      initialization[0].user_account[0].password,
      initialization[0].user_account[0].username,
    ]
  }
}
