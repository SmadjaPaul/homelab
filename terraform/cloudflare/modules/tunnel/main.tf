# =============================================================================
# Cloudflare Tunnel — resource + ingress config
# =============================================================================

# Generate a new tunnel secret when regenerating
resource "random_password" "tunnel_secret" {
  count   = var.regenerate ? 1 : 0
  length  = 64
  special = false
}

# Tunnel resource - always created when regenerate=true, or when no tunnel_id
# For existing tunnels, import first: terraform import module.tunnel[0].cloudflare_zero_trust_tunnel_cloudflared.homelab[0] account_id/tunnel_id
resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  count         = var.tunnel_id == "" || var.regenerate ? 1 : 0
  account_id    = var.account_id
  name          = "homelab-tunnel"
  tunnel_secret = var.regenerate && length(random_password.tunnel_secret) > 0 ? random_password.tunnel_secret[0].result : var.tunnel_secret
}

# Get the tunnel ID and secret to use
locals {
  actual_tunnel_id     = var.tunnel_id != "" && !var.regenerate ? var.tunnel_id : cloudflare_zero_trust_tunnel_cloudflared.homelab[0].id
  actual_tunnel_name   = "homelab-tunnel"
  actual_tunnel_secret = var.regenerate && length(random_password.tunnel_secret) > 0 ? random_password.tunnel_secret[0].result : var.tunnel_secret
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

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  count      = var.enable_tunnel_config ? 1 : 0
  account_id = var.account_id
  tunnel_id  = local.actual_tunnel_id

  config = {
    ingress = [
      {
        hostname = "home.${var.domain}"
        service  = "http://traefik.traefik.svc.cluster.local:80"
        origin_request = {
          no_tls_verify   = true
          connect_timeout = 30
        }
      },
      {
        hostname = "proxmox.${var.domain}"
        service  = "https://${var.proxmox_local_ip}:8006"
        origin_request = {
          no_tls_verify = true
        }
      },
      # All other services go through Traefik
      {
        service = "http://traefik.traefik.svc.cluster.local:80"
      }
    ]
  }
}
