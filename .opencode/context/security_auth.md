<!-- Context: security_auth | Priority: critical | Version: 2.0 | Updated: 2026-03-13 -->

# Security, Access, & Zero Trust

## Architecture (Zero Trust)

```
Internet → Cloudflare DNS → Cloudflare Tunnel (cloudflared)
                                         ↓
                              Authentik Embedded Outpost
                                         ↓
                           [Session Validation / IDP Redirect]
                                         ↓
                              Protected Apps or Direct (public)
```

- **Zero Open Ports**: No inbound ports on router. All traffic through Cloudflare Tunnel.
- **external-dns**: Auto-creates DNS CNAMEs from Authentik Ingress.

## Authentik (IdP & SSO)

- Central user directory and authentication.
- **Proxy Mode**: Forward Auth for apps without native auth.
- **OIDC/OAuth2**: Auto-provisioning for modern apps (Vaultwarden, Navidrome, Nextcloud).
- **Embedded Outpost**: Runs in K8s (ak-outpost-* pods, port 9000).

## Protected vs Public Apps

| Mode | Traffic Flow |
|------|--------------|
| **protected** | User → Cloudflare Tunnel → Authentik Outpost → App |
| **public** | User → Cloudflare Tunnel → Direct to K8s Service |

## Network Isolation

- **NetworkPolicies**: Restrict pod egress via `NetworkPolicyBuilder`.
- **Database Isolation**: CloudNativePG requires strict whitelisted policies.
- **Doppler**: Single source of truth for secrets.

## Services with Auth

| Service | Auth Method | URL |
|---------|------------|-----|
| **Authentik** | Native | auth.smadja.dev |
| **Vaultwarden** | OIDC Auto-Provision | vault.smadja.dev |
| **Navidrome** | OIDC Auto-Provision | music.smadja.dev |
| **Homepage** | Protected Proxy | home.smadja.dev |
| **Nextcloud** | OIDC Auto-Provision | cloud.smadja.dev |
| **Open-WebUI** | OIDC Auto-Provision | ai.smadja.dev |

## Debugging Access Issues

Check logs in these namespaces:
- `cloudflared` - Tunnel connectivity
- `authentik` - Outpost, authentication
- `external-dns` - DNS records
