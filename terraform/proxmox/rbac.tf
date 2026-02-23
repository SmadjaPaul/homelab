resource "proxmox_virtual_environment_role" "omni_provider" {
  role_id = "omni-provider"
  privileges = [
    "VM.Allocate",
    "VM.Config.Disk",
    "VM.Config.CPU",
    "VM.Config.Memory",
    "VM.Config.Network",
    "VM.Config.Options",
    "VM.PowerMgmt",
    "VM.Audit",
    "Datastore.Allocate",
    "Datastore.AllocateSpace",
    "Datastore.Audit",
    "Datastore.AllocateTemplate",
    "Sys.Audit"
  ]
}

resource "proxmox_virtual_environment_user" "omni_provider" {
  user_id = "omni-provider@pve"
  comment = "User for Sidero Omni Infrastructure Provider"
}

resource "proxmox_virtual_environment_acl" "omni_provider" {
  user_id = proxmox_virtual_environment_user.omni_provider.user_id
  role_id = proxmox_virtual_environment_role.omni_provider.role_id
  path    = "/"
}

resource "proxmox_virtual_environment_user_token" "omni_provider_token" {
  user_id    = proxmox_virtual_environment_user.omni_provider.user_id
  token_name = "infra"
}

output "omni_provider_token_id" {
  value     = proxmox_virtual_environment_user_token.omni_provider_token.id
  sensitive = true
}

output "omni_provider_token_secret" {
  value     = proxmox_virtual_environment_user_token.omni_provider_token.value
  sensitive = true
}
