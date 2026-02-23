terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.73.0"
    }
  }
}

resource "proxmox_virtual_environment_vm" "truenas" {
  description = "TrueNAS Scale - Network Storage"
  node_name   = var.proxmox_node
  vm_id       = var.vmid
  name        = var.name
  tags        = ["storage", "truenas"]
  machine     = "q35"
  bios        = "ovmf"

  startup {
    order      = 2
    up_delay   = 60
    down_delay = 120
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  efi_disk {
    datastore_id = var.fast_storage_pool
    file_format  = "raw"
    type         = "4m"
  }

  disk {
    datastore_id = var.fast_storage_pool
    file_format  = "raw"
    interface    = "scsi0"
    size         = var.boot_disk_size
    cache        = "writeback"
    discard      = "on"
    ssd          = true
  }

  disk {
    datastore_id = var.data_storage_pool
    file_format  = "raw"
    interface    = "scsi1"
    size         = var.data_disk_size
    cache        = "none"
    discard      = "on"
    ssd          = false
  }

  cdrom {
    file_id   = var.truenas_iso_file
    interface = "ide2"
    enabled   = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }
}
