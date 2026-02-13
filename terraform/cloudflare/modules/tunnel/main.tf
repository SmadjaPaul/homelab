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
    # Avoid replacement after import: secret is not returned by API,
    # so Terraform would otherwise plan destroy+create.
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
    # Homepage
    ingress_rule {
      hostname = "smadja.dev"
      service  = "http://traefik:80"
    }
    ingress_rule {
      hostname = "www.smadja.dev"
      service  = "http://traefik:80"
    }

    # Authentik
    ingress_rule {
      hostname = "auth.smadja.dev"
      service  = "http://traefik:80"
    }

    # DNS Blocky
    ingress_rule {
      hostname = "dns.smadja.dev"
      service  = "http://traefik:80"
    }

    # Gitea
    ingress_rule {
      hostname = "git.smadja.dev"
      service  = "http://traefik:80"
    }

    # Vaultwarden
    ingress_rule {
      hostname = "vault.smadja.dev"
      service  = "http://traefik:80"
    }

    # File Browser
    ingress_rule {
      hostname = "files.smadja.dev"
      service  = "http://traefik:80"
    }

    # Uptime Kuma
    ingress_rule {
      hostname = "status.smadja.dev"
      service  = "http://traefik:80"
    }

    # Prometheus
    ingress_rule {
      hostname = "prometheus.smadja.dev"
      service  = "http://traefik:80"
    }

    # Traefik Dashboard
    ingress_rule {
      hostname = "traefik.smadja.dev"
      service  = "http://traefik:80"
    }

    # Proxmox (at home)
    ingress_rule {
      hostname = "proxmox.smadja.dev"
      service  = "https://192.168.68.51:8006"
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
