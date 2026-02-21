<!-- Context: security_auth | Priority: critical | Version: 1.0 | Updated: 2026-02-21 -->

# Security, Access, & Zero Trust

## The Zero Trust Pipeline
The homelab uses a defense-in-depth approach enforcing strict access controls at the edge before traffic ever hits the internal app.

```
Internet → Cloudflare Edge → Cloudflare Tunnel
                    ↓
        Cloudflare Access (Zero Trust RBAC)
                    ↓
        Authentik (Identity Provider / OAuth)
                    ↓
             Kubernetes Service
```

## Authentik (IDP)
Authentik serves as the central directory and Identity Provider.
- Stores user accounts, groups, and policies.
- Configured via Terraform in `terraform/authentik/`.
- Issues to watch: Ensure OAuth/OIDC providers are correctly applied (Phase 2 bug).

## Cloudflare Access
Acts as the gatekeeper.
- Uses Authentik as its upstream OAuth provider.
- **Access Policies** map Cloudflare rules to Authentik groups (e.g., only "admins" can reach `/admin` routes).
- Configured via Terraform in `terraform/cloudflare/`.

## Network Isolation & TLS
- **Cloudflare Tunnels (cloudflared)**: No open inbound ports on the cluster. All traffic is securely routed from Cloudflare.
- **Strict SSL**: Valid TLS certificates are managed internally by `cert-manager` (Let's Encrypt), ensuring encryption in transit end-to-end.
