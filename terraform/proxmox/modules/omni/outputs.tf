# Omni module outputs
output "omni_vm_id" {
  description = "Omni VM ID"
  value       = proxmox_virtual_environment_vm.omni[0].vm_id
}

output "omni_ip_address" {
  description = "Omni VM IP address"
  value       = var.ip_address
}

output "omni_mac_address" {
  description = "Omni VM MAC address"
  value       = try(proxmox_virtual_environment_vm.omni[0].mac_addresses[0], "")
}

output "omni_ssh" {
  description = "SSH command to connect to Omni VM"
  value       = "ssh root@${var.ip_address}"
}

output "omni_url" {
  description = "Omni web interface URL"
  value       = "https://${var.ip_address}"
}
