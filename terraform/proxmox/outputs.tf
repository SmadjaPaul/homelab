# =============================================================================
# Proxmox Outputs
# =============================================================================

output "nodes" {
  description = "Proxmox cluster nodes (test connection)"
  value       = data.proxmox_virtual_environment_nodes.nodes
}

output "node_names" {
  description = "List of Proxmox node names"
  value       = data.proxmox_virtual_environment_nodes.nodes.names
}

# -----------------------------------------------------------------------------
# Talos VMs
# -----------------------------------------------------------------------------

output "talos_dev_vm_id" {
  description = "Proxmox VM ID for talos-dev (DEV cluster single-node)"
  value       = proxmox_virtual_environment_vm.talos_dev.vm_id
}

output "talos_prod_cp_vm_id" {
  description = "Proxmox VM ID for talos-prod-cp (PROD control plane)"
  value       = proxmox_virtual_environment_vm.talos_prod_cp.vm_id
}

output "talos_prod_worker_1_vm_id" {
  description = "Proxmox VM ID for talos-prod-worker-1 (PROD worker)"
  value       = proxmox_virtual_environment_vm.talos_prod_worker_1.vm_id
}

output "talos_vm_names" {
  description = "Talos VM names (for talosctl / Omni)"
  value = {
    dev = proxmox_virtual_environment_vm.talos_dev.name
    prod = {
      control_plane = proxmox_virtual_environment_vm.talos_prod_cp.name
      worker_1      = proxmox_virtual_environment_vm.talos_prod_worker_1.name
    }
  }
}
