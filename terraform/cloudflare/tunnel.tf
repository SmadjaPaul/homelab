# =============================================================================
# Cloudflare Tunnel Configuration
# Secure access to homelab services without exposing ports
# =============================================================================

# Note: Cloudflare Tunnel requires cloudflared to run on your infrastructure
# This creates the tunnel configuration in Cloudflare
# You'll need to install cloudflared on Proxmox or a VM

# Create the tunnel (only when enabled)
resource "cloudflare_tunnel" "homelab" {
  count = var.enable_tunnel ? 1 : 0

  account_id = var.cloudflare_account_id
  name       = "homelab-tunnel"
  secret     = var.tunnel_secret # Base64 encoded secret, generated once
}

# Tunnel configuration - routes traffic to internal services
resource "cloudflare_tunnel_config" "homelab" {
  count = var.enable_tunnel ? 1 : 0

  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.homelab[0].id

  config {
    # Proxmox (internal only via Tunnel)
    ingress_rule {
      hostname = "proxmox.${var.domain}"
      service  = "https://${var.proxmox_local_ip}:8006"
      origin_request {
        no_tls_verify = true # Self-signed cert on Proxmox
      }
    }

    # Grafana
    ingress_rule {
      hostname = "grafana.${var.domain}"
      service  = "http://grafana.monitoring.svc.cluster.local:3000"
    }

    # ArgoCD
    ingress_rule {
      hostname = "argocd.${var.domain}"
      service  = "https://argocd-server.argocd.svc.cluster.local:443"
      origin_request {
        no_tls_verify = true
      }
    }

    # Keycloak (auth)
    ingress_rule {
      hostname = "auth.${var.domain}"
      service  = "http://keycloak.identity.svc.cluster.local:8080"
    }

    # Homepage dashboard
    ingress_rule {
      hostname = "home.${var.domain}"
      service  = "http://homepage.default.svc.cluster.local:3000"
    }

    # Prometheus (internal)
    ingress_rule {
      hostname = "prometheus.${var.domain}"
      service  = "http://prometheus.monitoring.svc.cluster.local:9090"
    }

    # Alertmanager (internal)
    ingress_rule {
      hostname = "alerts.${var.domain}"
      service  = "http://alertmanager.monitoring.svc.cluster.local:9093"
    }

    # Uptime Kuma (status page)
    ingress_rule {
      hostname = "status.${var.domain}"
      service  = "http://uptime-kuma.uptime-kuma.svc.cluster.local:3001"
    }

    # Fider (feedback portal)
    ingress_rule {
      hostname = "feedback.${var.domain}"
      service  = "http://fider.fider.svc.cluster.local:3000"
    }

    # Docusaurus (documentation)
    ingress_rule {
      hostname = "docs.${var.domain}"
      service  = "http://docs.docs.svc.cluster.local:80"
    }

    # Catch-all rule (required)
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# DNS records pointing to the tunnel (only when enabled)
resource "cloudflare_record" "tunnel_cname" {
  for_each = var.enable_tunnel ? var.homelab_services : {}

  zone_id = var.zone_id
  name    = each.value.subdomain
  content = "${cloudflare_tunnel.homelab[0].id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = "${each.value.description} (via Tunnel)"
}

# Access policies for internal services (Zero Trust)
# Requires Cloudflare Access (free for up to 50 users)
resource "cloudflare_access_application" "internal_services" {
  for_each = var.enable_tunnel ? { for k, v in var.homelab_services : k => v if v.internal } : {}

  zone_id          = var.zone_id
  name             = "Homelab - ${each.value.description}"
  domain           = "${each.value.subdomain}.${var.domain}"
  type             = "self_hosted"
  session_duration = "24h"

  # Auto-redirect to login
  auto_redirect_to_identity = true
}

# Access policy - allow only specific emails
resource "cloudflare_access_policy" "internal_allow" {
  for_each = var.enable_tunnel ? { for k, v in var.homelab_services : k => v if v.internal } : {}

  zone_id        = var.zone_id
  application_id = cloudflare_access_application.internal_services[each.key].id
  name           = "Allow homelab admins"
  precedence     = 1
  decision       = "allow"

  include {
    email = var.allowed_emails
  }
}
