# =============================================================================
# Cloudflare Tunnel — resource + ingress config
# =============================================================================

# Use existing tunnel if tunnel_id is provided, otherwise create new
resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  count      = var.tunnel_id == "" ? 1 : 0
  account_id = var.account_id
  name       = "homelab-tunnel"
  secret     = var.tunnel_secret

  lifecycle {
    ignore_changes = [secret]
  }
}

# Get the tunnel ID to use - either from var.tunnel_id or from the created tunnel
locals {
  actual_tunnel_id   = var.tunnel_id != "" ? var.tunnel_id : cloudflare_zero_trust_tunnel_cloudflared.homelab[0].id
  actual_tunnel_name = var.tunnel_id != "" ? "homelab-tunnel-existing" : cloudflare_zero_trust_tunnel_cloudflared.homelab[0].name
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
  description = "Token for cloudflared to connect"
  value       = var.tunnel_secret
}

output "cname_target" {
  value = "${local.actual_tunnel_id}.cfargotunnel.com"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  count      = var.enable_tunnel_config ? 1 : 0
  account_id = var.account_id
  tunnel_id  = local.actual_tunnel_id

  config {
    # OKE Services via Kubernetes internal DNS
    dynamic "ingress_rule" {
      for_each = var.oke_services
      content {
        hostname = "${ingress_rule.value.hostname}.${var.domain}"
        service  = "https://${ingress_rule.value.service}:${ingress_rule.value.port}"
        origin_request {
          no_tls_verify   = true
          connect_timeout = 30
        }
      }
    }

    # Proxmox (at home)
    ingress_rule {
      hostname = "proxmox.${var.domain}"
      service  = "https://${var.proxmox_local_ip}:8006"
      origin_request {
        no_tls_verify = true
      }
    }

    # Catch-all
    ingress_rule {
      service = "http_status:404"
    }
  }
}
