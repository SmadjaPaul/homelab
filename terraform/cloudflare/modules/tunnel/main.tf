# =============================================================================
# Cloudflare Tunnel — resource + ingress config
#
# IMPORTANT: When using an existing tunnel (tunnel_id is provided), we still
# create the Terraform resource but with lifecycle ignore_changes to prevent
# Terraform from trying to modify or destroy it.
# =============================================================================

# Generate a new tunnel secret when regenerating
resource "random_password" "tunnel_secret" {
  count   = var.regenerate ? 1 : 0
  length  = 64
  special = false
}

# Tunnel resource - always created to maintain state, but managed externally
# When tunnel_id is provided, use that tunnel; otherwise create new
resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  count         = 1
  account_id    = var.account_id
  name          = "homelab-tunnel"
  tunnel_secret = var.tunnel_id != "" ? var.tunnel_secret : (var.regenerate && length(random_password.tunnel_secret) > 0 ? random_password.tunnel_secret[0].result : var.tunnel_secret)

  # Don't let Terraform destroy or modify existing tunnels
  lifecycle {
    ignore_changes = [tunnel_secret, name]
  }
}

# Get the tunnel ID and secret to use
locals {
  actual_tunnel_id     = var.tunnel_id != "" ? var.tunnel_id : cloudflare_zero_trust_tunnel_cloudflared.homelab[0].id
  actual_tunnel_name   = "homelab-tunnel"
  actual_tunnel_secret = var.tunnel_secret
}

output "tunnel_id" {
  description = "Cloudflare Tunnel ID (for DNS CNAME target)"
  value       = local.actual_tunnel_id
}

output "tunnel_name" {
  value = local.actual_tunnel_name
}

output "tunnel_token" {
  sensitive   = true
  description = "Secret for cloudflared to connect"
  value       = local.actual_tunnel_secret
}

output "cname_target" {
  value = "${local.actual_tunnel_id}.cfargotunnel.com"
}

# NOTE: Tunnel ingress config (cloudflare_zero_trust_tunnel_cloudflared_config)
# has been migrated to Pulumi (k8s-apps stack) where it is generated dynamically
# from apps.yaml. This keeps apps.yaml as the single source of truth for routing.
#
# CRITICAL: Before applying this Terraform change, you MUST run:
# terraform state rm 'module.tunnel[0].cloudflare_zero_trust_tunnel_cloudflared_config.homelab[0]'
# to prevent Terraform from destroying the config that Pulumi is taking over.
