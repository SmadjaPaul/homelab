---
sidebar_position: 3
---

# Cloudflare

## Services utilisés

| Service | Usage | Tier |
|---------|-------|------|
| DNS | Gestion des enregistrements | Free |
| SSL/TLS | Certificats | Free |
| WAF | Protection web | Free (basic) |
| Tunnel | Accès sans ports ouverts | Free |
| Access | Zero trust authentication | Free (50 users) |

## Configuration Terraform

### DNS Records

```hcl
# terraform/cloudflare/dns.tf
resource "cloudflare_record" "homelab_services" {
  for_each = var.homelab_services

  zone_id = var.zone_id
  name    = each.value.subdomain
  content = "${cloudflare_tunnel.homelab[0].id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
```

### Security Settings

```hcl
# terraform/cloudflare/security.tf
resource "cloudflare_zone_settings_override" "security" {
  zone_id = var.zone_id

  settings {
    ssl                      = "strict"
    min_tls_version          = "1.2"
    always_use_https         = "on"
    security_header {
      enabled = true
      # HSTS settings...
    }
  }
}
```

## Cloudflare Tunnel

### Fonctionnement

```
Internet → Cloudflare Edge → Tunnel → cloudflared → Service K8s
```

Avantages :
- ✅ Aucun port ouvert sur le routeur
- ✅ DDoS protection gratuite
- ✅ WAF inclus
- ✅ SSL automatique

### Configuration

```yaml
# kubernetes/infrastructure/cloudflared/deployment.yaml
containers:
  - name: cloudflared
    image: cloudflare/cloudflared:latest
    args:
      - tunnel
      - --no-autoupdate
      - run
      - --token
      - $(TUNNEL_TOKEN)
```

### Ingress Rules

```hcl
# terraform/cloudflare/tunnel.tf
ingress_rule {
  hostname = "grafana.smadja.dev"
  service  = "http://grafana.monitoring.svc.cluster.local:3000"
}

ingress_rule {
  hostname = "argocd.smadja.dev"
  service  = "https://argocd-server.argocd.svc.cluster.local:443"
  origin_request {
    no_tls_verify = true
  }
}
```

## Cloudflare Access

### Zero Trust Policies

Services internes protégés par Cloudflare Access :

```hcl
resource "cloudflare_access_application" "internal_services" {
  zone_id = var.zone_id
  name    = "Homelab - Grafana"
  domain  = "grafana.smadja.dev"
}

resource "cloudflare_access_policy" "allow_admin" {
  include {
    email = ["smadjapaul02@gmail.com"]
  }
}
```

### Services protégés

| Service | Protection |
|---------|------------|
| grafana.smadja.dev | Cloudflare Access |
| argocd.smadja.dev | Cloudflare Access |
| prometheus.smadja.dev | Cloudflare Access |
| proxmox.smadja.dev | Cloudflare Access |

## Limites Free Tier

| Feature | Limite |
|---------|--------|
| DNS Records | Illimité |
| Page Rules | 3 |
| WAF Rules | 5 custom |
| Access Users | 50 |
| Tunnels | Illimité |

## API Token

Token avec permissions :

- Zone - DNS - Edit
- Zone - Zone Settings - Edit
- Account - Cloudflare Tunnel - Edit
- Account - Access - Edit

Stocké chiffré dans `secrets/cloudflare.enc.yaml`.
