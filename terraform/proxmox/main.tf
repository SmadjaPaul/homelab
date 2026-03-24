# Talos VMs are now provisioned by Omni
# See: https://github.com/siderolabs/omni-infra-provider-proxmox

module "home_ops_node" {
  source = "./modules/omni"

  name = "home-ops-0"

  # Proxmox connection
  proxmox_node = local.secrets.PROXMOX_NODE

  # VM settings
  enable_omni   = true
  vmid          = 101
  cores         = 6
  memory        = 32768
  disk_size     = 100
  storage_pool  = local.secrets.PROXMOX_FAST_STORAGE
  start_on_boot = true

  # Network settings
  network_bridge  = "vmbr0"
  network_vlan_id = 0
  ip_address      = "192.168.68.30"
  gateway         = local.secrets.HOME_NETWORK_GATEWAY
  subnet_mask     = local.secrets.HOME_NETWORK_SUBNET

  # Template (optional)
  template_vm_id = null
}

