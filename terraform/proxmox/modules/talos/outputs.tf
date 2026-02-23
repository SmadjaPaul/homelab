output "nodes" {
  description = "Talos nodes details"
  value = [
    for i in range(var.node_count) : {
      id     = i
      name   = local.nodes[i].name
      vmid   = local.nodes[i].vmid
      ip     = local.nodes[i].ip
      remote = "talosctl -n ${local.nodes[i].ip}"
    }
  ]
}

output "ips" {
  description = "List of node IPs"
  value       = [for node in local.nodes : node.ip]
}

output "cluster_init_command" {
  description = "Command to initialize cluster"
  value       = "talosctl init --name ${var.cluster_name} --nodes ${join(",", [for node in local.nodes : node.ip])}"
}
