terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.73.0"
    }
  }
}

resource "proxmox_virtual_environment_vm" "windows" {
  count = var.gpu_pci != null ? 1 : 0

  description = "Windows 11 - Desktop/Dev"
  node_name   = var.proxmox_node
  vm_id       = var.vmid
  name        = var.name
  tags        = ["desktop", "windows"]
  machine     = "q35"
  bios        = "ovmf"

  startup {
    order      = 99
    up_delay   = 30
    down_delay = 30
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  efi_disk {
    datastore_id = var.storage_pool
    file_format  = "raw"
    type         = "4m"
  }

  disk {
    datastore_id = var.storage_pool
    file_format  = "raw"
    interface    = "scsi0"
    size         = var.disk_size
    cache        = "writeback"
    discard      = "on"
    ssd          = true
  }

  cdrom {
    file_id = var.windows_iso_file
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "win11"
  }

  vga {
    type = "qxl"
  }

  dynamic "hostpci" {
    for_each = var.gpu_pci != null ? [var.gpu_pci] : []
    content {
      device = "hostpci0"
      id     = hostpci.value
      pcie   = true
      xvga   = true
    }
  }
}
