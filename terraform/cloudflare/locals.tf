# =============================================================================
# Local values — derived from global_config and tunnel module (not from Doppler directly)
# Domain, zone_id, account_id come from module.global_config and are passed to child modules.
# =============================================================================

locals {
  # From global config (Doppler)
  existing_tunnel_id     = module.global_config.existing_tunnel_id
  existing_tunnel_secret = module.global_config.existing_tunnel_secret

  # Tunnel logic - always manage tunnel when enabled
  manage_tunnel = var.enable_tunnel

  # When regenerating, we pass empty tunnel_id to force update
  tunnel_id_to_pass = var.regenerate_tunnel_credentials ? "" : local.existing_tunnel_id

  # Final tunnel values
  tunnel_id     = local.manage_tunnel ? coalesce(module.tunnel[0].tunnel_id, local.existing_tunnel_id) : ""
  tunnel_secret = local.manage_tunnel ? module.tunnel[0].tunnel_token : ""
}
