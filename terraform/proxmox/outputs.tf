# Home Ops Node outputs
output "home_ops_vm" {
  description = "Home Ops VM details"
  value = {
    vmid = module.home_ops_node.omni_vm_id
    ip   = module.home_ops_node.omni_ip_address
    mac  = module.home_ops_node.omni_mac_address
  }
}
