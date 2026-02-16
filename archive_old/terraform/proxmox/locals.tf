# =============================================================================
# Proxmox Locals
# =============================================================================

locals {
  # Nœud cible : variable ou premier nœud du cluster
  node_name = coalesce(var.pm_node_name, try(data.proxmox_virtual_environment_nodes.nodes.names[0], "pve"))
}
