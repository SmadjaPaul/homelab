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

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  count      = var.enable_tunnel_config ? 1 : 0
  account_id = var.account_id
  tunnel_id  = local.actual_tunnel_id

  config = {
    ingress = [
      # Route through Envoy Gateway Internal (behind Cloudflare Tunnel)
      # Envoy Gateway internal LB: 141.253.110.118
      {
        hostname = "home.${var.domain}"
        service  = "http://envoy-gateway.envoy-gateway.svc.cluster.local:80"
        origin_request = {
          no_tls_verify   = true
          connect_timeout = 30
        }
      },
      {
        hostname = "auth.${var.domain}"
        service  = "http://envoy-gateway.envoy-gateway.svc.cluster.local:80"
        origin_request = {
          no_tls_verify   = true
          connect_timeout = 30
        }
      },
      {
        hostname = "login.${var.domain}"
        service  = "http://envoy-gateway.envoy-gateway.svc.cluster.local:80"
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
      # Default catch-all (fallback to internal gateway)
      {
        service = "http://envoy-gateway.envoy-gateway.svc.cluster.local:80"
      }
    ]
  }
}
