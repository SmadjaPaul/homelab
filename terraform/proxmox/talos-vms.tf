# =============================================================================
# Talos Linux VMs — DEV (single-node) + PROD cluster
# =============================================================================
# Conforme à architecture-proxmox-omni.md ; vérifié vs mitchross/talos-argocd-proxmox.
# UEFI + q35 : recommandé par Sidero pour Talos sur Proxmox.
# Vérification : docs/proxmox-talos-setup-verification.md
# - DEV : 1 nœud (control-plane + worker), 2 vCPU, 4GB RAM, 50GB
# - PROD : 1 control-plane (2 vCPU, 4GB RAM, 50GB) + 1 worker (6 vCPU, 12GB RAM, 200GB)
# Premier boot : attacher l’ISO Talos (tank-iso) en CDROM dans Proxmox, puis talosctl apply-config.
# =============================================================================

# -----------------------------------------------------------------------------
# DEV Cluster — Single node (simulation env de dev)
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "talos_dev" {
  name      = "talos-dev"
  node_name = local.node_name
  vm_id     = var.talos_dev_vm_id
  bios      = "ovmf"
  machine   = "q35"

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = var.pm_storage_vm
    interface    = "scsi0"
    size         = 50
    ssd          = false
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  dynamic "cdrom" {
    for_each = var.talos_iso_file != "" ? [1] : []
    content {
      enabled   = true
      file_id   = "${var.pm_storage_iso}:iso/${var.talos_iso_file}"
      interface = "ide2"
    }
  }

  boot_order = var.talos_iso_file != "" ? ["ide2", "scsi0"] : ["scsi0"]

  tags = ["talos", "kubernetes", "dev"]
}

# -----------------------------------------------------------------------------
# PROD Cluster — Control plane
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "talos_prod_cp" {
  name      = "talos-prod-cp"
  node_name = local.node_name
  vm_id     = var.talos_prod_cp_vm_id
  bios      = "ovmf"
  machine   = "q35"

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = var.pm_storage_vm
    interface    = "scsi0"
    size         = 50
    ssd          = false
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  dynamic "cdrom" {
    for_each = var.talos_iso_file != "" ? [1] : []
    content {
      enabled   = true
      file_id   = "${var.pm_storage_iso}:iso/${var.talos_iso_file}"
      interface = "ide2"
    }
  }

  boot_order = var.talos_iso_file != "" ? ["ide2", "scsi0"] : ["scsi0"]

  tags = ["talos", "kubernetes", "prod", "control-plane"]
}

# -----------------------------------------------------------------------------
# PROD Cluster — Worker
# -----------------------------------------------------------------------------

resource "proxmox_virtual_environment_vm" "talos_prod_worker_1" {
  name      = "talos-prod-worker-1"
  node_name = local.node_name
  vm_id     = var.talos_prod_worker_1_vm_id
  bios      = "ovmf"
  machine   = "q35"

  cpu {
    cores = 6
    type  = "host"
  }

  memory {
    dedicated = 12288 # 12GB
  }

  disk {
    datastore_id = var.pm_storage_vm
    interface    = "scsi0"
    size         = 200
    ssd          = false
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  dynamic "cdrom" {
    for_each = var.talos_iso_file != "" ? [1] : []
    content {
      enabled   = true
      file_id   = "${var.pm_storage_iso}:iso/${var.talos_iso_file}"
      interface = "ide2"
    }
  }

  boot_order = var.talos_iso_file != "" ? ["ide2", "scsi0"] : ["scsi0"]

  tags = ["talos", "kubernetes", "prod", "worker"]
}
