---
sidebar_position: 3
---

# Identity & Access

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Utilisateur                            │
│                           │                                 │
│            ┌──────────────┼──────────────┐                 │
│            │              │              │                 │
│            ▼              ▼              ▼                 │
│     ┌──────────┐   ┌──────────┐   ┌──────────┐           │
│     │Cloudflare│   │ Keycloak │   │ Twingate │           │
│     │ Access   │   │   SSO    │   │   VPN    │           │
│     └──────────┘   └──────────┘   └──────────┘           │
│            │              │              │                 │
│            ▼              ▼              ▼                 │
│     ┌──────────┐   ┌──────────┐   ┌──────────┐           │
│     │  Admin   │   │   Apps   │   │  Infra   │           │
│     │ Services │   │  (OIDC)  │   │ (private)│           │
│     └──────────┘   └──────────┘   └──────────┘           │
└─────────────────────────────────────────────────────────────┘
```

## Keycloak

### Accès

- URL: https://auth.smadja.dev
- Admin console: https://auth.smadja.dev/admin

### Realm: homelab

| Configuration | Valeur |
|---------------|--------|
| Realm | homelab |
| Login theme | keycloak |
| Email verification | Désactivé |

### Utilisateurs

| User | Rôles | Usage |
|------|-------|-------|
| admin | admin, user | Administration |
| maureen | user | Utilisatrice |
| family | user | Famille |

### Clients OIDC

| Client | Type | Redirect URIs |
|--------|------|---------------|
| grafana | confidential | https://grafana.smadja.dev/* |
| argocd | confidential | https://argocd.smadja.dev/* |
| oauth2-proxy | confidential | https://*.smadja.dev/* |

### Configuration OAuth2

```yaml
# Exemple pour Grafana
auth.generic_oauth:
  enabled: true
  name: Keycloak
  client_id: grafana
  client_secret: ${KEYCLOAK_CLIENT_SECRET}
  scopes: openid email profile
  auth_url: https://auth.smadja.dev/realms/homelab/protocol/openid-connect/auth
  token_url: https://auth.smadja.dev/realms/homelab/protocol/openid-connect/token
  api_url: https://auth.smadja.dev/realms/homelab/protocol/openid-connect/userinfo
```

## Cloudflare Access

### Fonctionnement

1. User accède à grafana.smadja.dev
2. Cloudflare intercepte la requête
3. Redirection vers login Cloudflare
4. Vérification email autorisé
5. Accès autorisé → forward au service

### Services protégés

| Service | Policy |
|---------|--------|
| grafana.smadja.dev | Email in allowlist |
| argocd.smadja.dev | Email in allowlist |
| prometheus.smadja.dev | Email in allowlist |
| alerts.smadja.dev | Email in allowlist |

### Configuration Terraform

```hcl
resource "cloudflare_access_application" "grafana" {
  zone_id = var.zone_id
  name    = "Grafana"
  domain  = "grafana.smadja.dev"
}

resource "cloudflare_access_policy" "allow_admin" {
  application_id = cloudflare_access_application.grafana.id
  name           = "Allow Admin"
  decision       = "allow"
  include {
    email = ["smadjapaul02@gmail.com"]
  }
}
```

## Twingate

### Fonctionnement

VPN zero-trust pour accès aux ressources internes.

1. Client Twingate sur device
2. Connexion au réseau Twingate
3. Connector dans K8s route le trafic
4. Accès aux ressources définies

### Ressources configurées

| Resource | Address | Ports |
|----------|---------|-------|
| Proxmox | 192.168.68.51 | 8006 |
| K8s Services | *.svc.cluster.local | All |
| Home Network | 192.168.68.0/24 | All |

### Setup

1. Créer compte sur twingate.com
2. Déployer le connector (voir `kubernetes/infrastructure/twingate/`)
3. Définir les ressources
4. Installer le client sur les devices

## Matrice des accès

| Service | Public | CF Access | Keycloak | Twingate |
|---------|--------|-----------|----------|----------|
| Homepage | ✅ | | | |
| Status | ✅ | | | |
| Feedback | ✅ | | | |
| Auth | ✅ | | | |
| Grafana | | ✅ | ✅ | |
| ArgoCD | | ✅ | ✅ | |
| Prometheus | | ✅ | | |
| Proxmox | | | | ✅ |
