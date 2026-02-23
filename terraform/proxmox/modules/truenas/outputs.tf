output "vmid" {
  value = var.vmid
}

output "ip_address" {
  value = var.ip_address
}

output "url" {
  value = "http://${var.ip_address}"
}

output "ssh_command" {
  value = "ssh root@${var.ip_address}"
}
