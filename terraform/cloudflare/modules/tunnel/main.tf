# =============================================================================
# Cloudflare Tunnel — resource + ingress config
# =============================================================================

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id = var.account_id
  name       = "homelab-tunnel"
  secret     = var.tunnel_secret

  lifecycle {
    # Avoid replacement after import: secret is not returned by API,
    # so Terraform would otherwise plan destroy+create.
    ignore_changes = [secret]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  count      = var.enable_tunnel_config ? 1 : 0
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id

  config {
    ingress_rule {
      hostname = "proxmox.${var.domain}"
      service  = "https://${var.proxmox_local_ip}:8006"
      origin_request {
        no_tls_verify = true
      }
    }
    ingress_rule {
      hostname = "grafana.${var.domain}"
      service  = "http://grafana.monitoring.svc.cluster.local:3000"
    }
    ingress_rule {
      hostname = "argocd.${var.domain}"
      service  = "https://argocd-server.argocd.svc.cluster.local:443"
      origin_request {
        no_tls_verify = true
      }
    }
    ingress_rule {
      hostname = "auth.${var.domain}"
      service  = "http://localhost:8080"
    }
    ingress_rule {
      hostname = "omni.${var.domain}"
      service  = "http://localhost:8080"
    }
    ingress_rule {
      hostname = "llm.${var.domain}"
      service  = "http://localhost:8080"
    }
    ingress_rule {
      hostname = "openclaw.${var.domain}"
      service  = "http://localhost:8080"
    }
    ingress_rule {
      hostname = "home.${var.domain}"
      service  = "http://homepage.default.svc.cluster.local:3000"
    }
    ingress_rule {
      hostname = "prometheus.${var.domain}"
      service  = "http://prometheus.monitoring.svc.cluster.local:9090"
    }
    ingress_rule {
      hostname = "alerts.${var.domain}"
      service  = "http://alertmanager.monitoring.svc.cluster.local:9093"
    }
    ingress_rule {
      hostname = "status.${var.domain}"
      service  = "http://uptime-kuma.uptime-kuma.svc.cluster.local:3001"
    }
    ingress_rule {
      hostname = "feedback.${var.domain}"
      service  = "http://fider.fider.svc.cluster.local:3000"
    }
    ingress_rule {
      hostname = "docs.${var.domain}"
      service  = "http://docs.docs.svc.cluster.local:80"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}
