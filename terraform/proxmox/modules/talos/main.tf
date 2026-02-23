terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.73.0"
    }
  }
}

locals {
  nodes = [for i in range(var.node_count) : {
    id   = i
    vmid = var.vmid_start + i
    ip   = join(".", [split(".", var.base_ip)[0], split(".", var.base_ip)[1], split(".", var.base_ip)[2], tonumber(split(".", var.base_ip)[3]) + i])
    name = "${var.cluster_name}-${format("%02d", i + 1)}"
  }]
}

# Create Talos VMs with ISO boot
resource "proxmox_virtual_environment_vm" "talos" {
  count = var.node_count

  name        = local.nodes[count.index].name
  node_name   = var.proxmox_node
  vm_id       = local.nodes[count.index].vmid
  description = "Talos Linux - Node ${count.index + 1}"
  tags        = ["talos", "kubernetes"]

  on_boot = true

  cpu {
    cores = var.cpus
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.storage_pool
    size         = var.disk_size
    interface    = "virtio0"
  }

  network_device {
    bridge   = "vmbr0"
    firewall = false
    model    = "e1000"
  }

  # Boot from ISO for installation
  cdrom {
    file_id = "tank-iso:iso/metal-amd64.iso"
  }

  machine = "q35"

  bios = "ovmf"

  tablet_device = false
}
