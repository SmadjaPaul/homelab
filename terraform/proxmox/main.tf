# Talos VMs are now provisioned by Omni
# See: https://github.com/siderolabs/omni-infra-provider-proxmox

module "omni" {
  source = "./modules/omni"

  # Proxmox connection
  proxmox_node = local.secrets.PROXMOX_NODE

  # VM settings
  enable_omni   = local.secrets.ENABLE_OMNI == "true"
  vmid          = tonumber(local.secrets.OMNI_VMID)
  cores         = tonumber(local.secrets.OMNI_CORES)
  memory        = tonumber(local.secrets.OMNI_MEMORY)
  disk_size     = tonumber(local.secrets.OMNI_DISK)
  storage_pool  = local.secrets.PROXMOX_FAST_STORAGE
  start_on_boot = true

  # Network settings
  network_bridge  = "vmbr0"
  network_vlan_id = 0
  ip_address      = local.secrets.OMNI_IP
  gateway         = local.secrets.HOME_NETWORK_GATEWAY
  subnet_mask     = local.secrets.HOME_NETWORK_SUBNET

  # Template (optional - set to a VM ID to clone from template)
  # Leave null to create VM from scratch
  template_vm_id = null
}
