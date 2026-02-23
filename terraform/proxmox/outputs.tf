# Omni VM outputs
output "omni_vm" {
  description = "Omni VM details"
  value = {
    vmid = module.omni.omni_vm_id
    ip   = module.omni.omni_ip_address
    ssh  = module.omni.omni_ssh
    mac  = module.omni.omni_mac_address
  }
}

output "omni_url" {
  description = "Omni web interface URL"
  value       = "https://${module.omni.omni_ip_address}"
}

output "omni_ssh" {
  description = "SSH command to connect to Omni VM"
  value       = module.omni.omni_ssh
}
