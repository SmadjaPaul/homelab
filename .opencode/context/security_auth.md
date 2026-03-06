<!-- Context: security_auth | Priority: critical | Version: 1.1 | Updated: 2026-03-06 -->

# Security, Access, & Zero Trust

## Architecture
```
Internet → Cloudflare Edge → Cloudflare Tunnel (cloudflared)
                    ↓
        Authentik Embedded Outpost (port 9000)
                    ↓
   [Session Validation / IDP Redirection]
                    ↓
             backend applications
```

## Authentik (Identity Provider & Proxy)
- **Authentik** is the central directory for users and authentication.
- Configured via Pulumi in `kubernetes-pulumi/shared/apps/common/authentik_registry.py`.
- Features OIDC Auto-Provisioning for apps like Navidrome, Homarr, and Vaultwarden.
- Acts as a Forward Auth Proxy for all internal "protected" apps.

## Cloudflare Tunnels (Zero Trust)
- **Zero Inbound Ports**: The homelab has absolutely no open ports on the router. All traffic is tunneled through `cloudflared`.
- Dynamic DNS routing is orchestrated via `ZeroTrustTunnelCloudflaredConfig` in the Pulumi `k8s-apps` stack.
- Exposed services bypass Cloudflare Access (which is disabled) and are natively protected by Authentik Outposts instead.

## Network Isolation
- **NetworkPolicies**: Restrict pod egress strictly using `NetworkPolicyBuilder`.
- Databases like CloudNativePG are isolated and require strict whitelisted policies by app.
- **Doppler**: Source of truth for secrets, avoiding any plain-text commits. Synchronized via `External Secrets Operator`.
