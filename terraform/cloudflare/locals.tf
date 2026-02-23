# =============================================================================
# Local values — derived from global_config and tunnel module (not from Doppler directly)
# Domain, zone_id, account_id come from module.global_config and are passed to child modules.
# =============================================================================

locals {
  # From global config (Doppler)
  existing_tunnel_id     = module.global_config.existing_tunnel_id
  existing_tunnel_secret = module.global_config.existing_tunnel_secret

  # When regenerating, we pass empty tunnel_id to force update
  tunnel_id_to_pass = var.regenerate_tunnel_credentials ? "" : local.existing_tunnel_id

  # Final tunnel values - used for DNS module
  tunnel_id     = var.enable_tunnel ? coalesce(module.tunnel[0].tunnel_id, local.existing_tunnel_id) : local.existing_tunnel_id
  tunnel_secret = var.enable_tunnel ? module.tunnel[0].tunnel_token : ""
}
