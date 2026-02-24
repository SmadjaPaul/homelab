# =============================================================================
# NetBird Outputs
# =============================================================================

output "network_id" {
  description = "NetBird network ID"
  value       = netbird_network.main.id
}

output "setup_keys" {
  description = "Setup keys for connecting peers"
  sensitive   = true
  value = {
    local_cluster = var.enable_local_cluster ? netbird_setup_key.k8s_local[0].key : null
    oci_cluster   = var.enable_oci_cluster ? netbird_setup_key.k8s_oci[0].key : null
    workstation   = var.enable_workstation ? netbird_setup_key.workstation[0].key : null
  }
}

output "group_ids" {
  description = "Group IDs for access policies"
  value = {
    k8s_routers  = var.enable_local_cluster || var.enable_oci_cluster ? netbird_group.k8s_routers[0].id : null
    workstations = var.enable_workstation ? netbird_group.workstations[0].id : null
  }
}

output "route_ids" {
  description = "Network route IDs"
  value = {
    local_cluster_pods     = var.enable_local_cluster && var.local_cluster_pod_cidr != "" ? netbird_route.local_cluster_pods[0].id : null
    local_cluster_services = var.enable_local_cluster && var.local_cluster_service_cidr != "" ? netbird_route.local_cluster_services[0].id : null
    oci_cluster_pods       = var.enable_oci_cluster && var.oci_cluster_pod_cidr != "" ? netbird_route.oci_cluster_pods[0].id : null
    oci_cluster_services   = var.enable_oci_cluster && var.oci_cluster_service_cidr != "" ? netbird_route.oci_cluster_services[0].id : null
  }
}
