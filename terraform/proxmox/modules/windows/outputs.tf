output "vmid" {
  value = var.vmid
}

output "ip_address" {
  value = var.ip_address
}

output "rdp_address" {
  value = "${var.ip_address}:3389"
}
