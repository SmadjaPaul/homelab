# Outputs for OKE Infrastructure

output "cluster_id" {
  description = "OKE Cluster ID"
  value       = oci_containerengine_cluster.homelab.id
}

output "cluster_name" {
  description = "OKE Cluster Name"
  value       = oci_containerengine_cluster.homelab.name
}

output "cluster_endpoint" {
  description = "OKE Cluster Endpoint (public if enabled)"
  value       = oci_containerengine_cluster.homelab.endpoint_config[0].is_public_ip_enabled ? oci_containerengine_cluster.homelab.endpoints[0].public_endpoint : oci_containerengine_cluster.homelab.endpoints[0].private_endpoint
}

output "cluster_private_endpoint" {
  description = "OKE Cluster Private Endpoint"
  value       = oci_containerengine_cluster.homelab.endpoints[0].private_endpoint
}

output "cluster_public_endpoint" {
  description = "OKE Cluster Public Endpoint"
  value       = oci_containerengine_cluster.homelab.endpoints[0].public_endpoint
}

output "node_pool_id" {
  description = "Node Pool ID"
  value       = oci_containerengine_node_pool.workers.id
}

output "node_pool_size" {
  description = "Number of nodes in the pool"
  value       = oci_containerengine_node_pool.workers.node_config_details[0].size
}

output "worker_subnet_id" {
  description = "Worker Subnet ID"
  value       = oci_core_subnet.worker_subnet.id
}

output "lb_subnet_id" {
  description = "Load Balancer Subnet ID"
  value       = oci_core_subnet.lb_subnet.id
}

output "vcn_id" {
  description = "VCN ID"
  value       = oci_core_vcn.oke_vcn.id
}

output "vcn_cidr" {
  description = "VCN CIDR Block"
  value       = oci_core_vcn.oke_vcn.cidr_block
}

output "kubeconfig_command" {
  description = "Command to generate kubeconfig"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.homelab.id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0"
}

output "node_ips" {
  description = "Private IPs of worker nodes"
  value       = oci_containerengine_node_pool.workers.nodes[*].private_ip
}
