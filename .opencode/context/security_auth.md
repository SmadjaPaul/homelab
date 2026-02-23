<!-- Context: security_auth | Priority: critical | Version: 2.0 | Updated: 2026-02-22 -->

# Security, Access, & Zero Trust

## Architecture
```
Internet → Cloudflare Edge → Cloudflare Tunnel
                    ↓
        Cloudflare Access (Zero Trust)
                    ↓
              Auth0 (Identity Provider)
                    ↓
              Kubernetes Services
```

## Auth0 (Identity Provider)
- Central directory for users and authentication
- Configured via Terraform in `terraform/auth0/`
- Applications registered: cloudflare_access, outline, audiobookshelf
- Organization: homelab (users added via terraform/auth0/modules/users_org)

## Cloudflare Access (Zero Trust Gatekeeper)
- Uses Auth0 as upstream OIDC provider
- **Access Policies**:
  - `ip_bypass`: Allow specific IPs (Terraform CI, local dev)
  - `idp_users`: Allow all Auth0-authenticated users (default policy)
  - `email_fallback`: Allow specific emails (OTP fallback)
- Configured via Terraform in `terraform/cloudflare/modules/access/`

### Access Policy Logic
```hcl
# Pour chaque service:
policies = concat(
  ip_bypass_policy,                                    # Priorité haute
  (role_access[service] OR idp_users_policy),          # Auth requis
  email_fallback_policy                                # Fallback email
)
```

### Current Policy
**Tous les utilisateurs Auth0** ont accès à **toutes les applications**:
- `role_access = {}` (vide = pas de restriction par rôles)
- La politique `idp_users` est appliquée automatiquement

## Services Exposed via Cloudflare Access
| Service | Subdomain | Description |
|---------|-----------|-------------|
| proxmox | proxmox.smadja.dev | Proxmox VE management |
| omni | omni.smadja.dev | Kubernetes cluster management |
| n8n | n8n.smadja.dev | Workflow automation |
| docs | docs.smadja.dev | Documentation |
| lidarr | lidarr.smadja.dev | Music manager |
| seaweedfs | s3.smadja.dev | Object storage |
| outline | outline.smadja.dev | Knowledge base |
| audiobookshelf | audio.smadja.dev | Audiobooks |
| umami | umami.smadja.dev | Analytics |
| vikunja | vikunja.smadja.dev | Task management |
| navidrome | navidrome.smadja.dev | Music server |
| homepage | home.smadja.dev | Homelab Dashboard |

## Network Isolation
- **Cloudflare Tunnels**: No open inbound ports. All traffic routed through cloudflared.
- **TLS**: Valid certificates via cert-manager (Let's Encrypt).
- **Doppler**: Secrets source of truth, synced via External Secrets Operator.
