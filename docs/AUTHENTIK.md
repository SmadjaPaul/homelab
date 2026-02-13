# Authentik + Cloudflare Access Architecture

This document describes the authentication architecture using **Authentik** as the Identity Provider (IdP) and **Cloudflare Access** as the authentication proxy.

## Architecture Overview

```
User Request
    ↓
Cloudflare Access (Zero Trust)
    ↓ [Redirects to IdP if not authenticated]
Authentik (OIDC Provider)
    ↓ [Returns JWT token]
Cloudflare Access [Validates token]
    ↓
Cloudflare Tunnel
    ↓
Traefik (Reverse Proxy)
    ↓
Service (Protected)
```

## Why This Architecture?

**Authentik** provides:
- Full OIDC/OAuth2 provider capabilities
- Service accounts (M2M tokens) for machine authentication
- RBAC with groups and policies
- Web UI for user management
- LDAP support
- SAML support

**Cloudflare Access** provides:
- Global edge network (fast authentication worldwide)
- Additional security layer before reaching your infrastructure
- Bot protection
- Geo-blocking
- No open ports required

## Flow Explained

1. **User visits service** (e.g., `https://prometheus.smadja.dev`)
2. **Cloudflare Access intercepts** the request
3. **If not authenticated**: Redirects to Authentik login
4. **User authenticates** with Authentik (credentials, 2FA, etc.)
5. **Authentik redirects** back to Cloudflare with JWT token
6. **Cloudflare validates** the token and creates session
7. **Request forwarded** through Tunnel → Traefik → Service
8. **Subsequent requests**: Use Cloudflare session (no redirect)

## Components

### 1. Authentik (Identity Provider)

**URL**: https://auth.smadja.dev

**Services**:
- `authentik-server` - Main application (port 9000)
- `authentik-worker` - Background tasks
- `authentik-postgres` - Database
- `authentik-redis` - Cache/Sessions

**Features**:
- User management with web UI
- Group-based access control
- OAuth2/OIDC provider for Cloudflare Access
- Service accounts for machine-to-machine auth
- MFA (TOTP, WebAuthn)

### 2. Cloudflare Access (Auth Proxy)

**Configuration**: Managed via Terraform (`terraform/cloudflare/modules/access/`)

**IdP Integration**:
- Type: OIDC
- Authorization URL: `https://auth.smadja.dev/application/o/authorize/`
- Token URL: `https://auth.smadja.dev/application/o/token/`
- Certs URL: `https://auth.smadja.dev/application/o/jwks/`
- Client ID: `cloudflare-access-smadja`

**Access Policies**:
- Internal services: Require Authentik authentication
- Public services: No authentication required

### 3. Services

**Protected Services** (require auth):
- Prometheus (`prometheus.smadja.dev`)
- Traefik Dashboard (`traefik.smadja.dev`)
- Blocky DNS (`dns.smadja.dev`)
- Gitea (`git.smadja.dev`) - planned
- Vaultwarden (`vault.smadja.dev`) - planned

**Public Services** (no auth required):
- Authentik itself (`auth.smadja.dev`)
- Homepage (`smadja.dev`)
- Status page (`status.smadja.dev`)

## RBAC Configuration

### Groups in Authentik

- **admins**: Full access to all services
- **users**: Access to user-facing services
- **family**: Family members access
- **service-accounts**: For machine authentication

### Policies in Cloudflare Access

1. **authentik_everyone**: Any authenticated Authentik user
2. **internal_allow**: Fallback with specific emails

## Service Accounts (Machine Authentication)

For CI/CD, APIs, and automation:

```bash
# Create service account in Authentik UI
# 1. Directory → Users → Create
# 2. Set username: terraform-ci
# 3. Set type: Service account
# 4. Generate token

# Use token in API calls
curl -H "Authorization: Bearer <token>" \
  https://api.smadja.dev/endpoint
```

## Setup Instructions

### 1. Initial Authentik Setup

```bash
# Access Authentik first time
https://auth.smadja.dev/if/flow/initial-setup/

# Set admin password
# Configure initial settings
```

### 2. Configure Cloudflare Access IdP

Terraform already configured this. Verify in Cloudflare Dashboard:
- Zero Trust → Settings → Authentication → Identity Providers
- Should see "Authentik" configured

### 3. Add Users

Via Authentik UI:
1. Directory → Users → Create
2. Set username, email, name
3. Add to groups
4. Set password or send enrollment email

### 4. Configure Access Applications

```bash
# Run terraform to create Access apps
cd terraform/cloudflare
terraform apply
```

## Doppler Secrets Required

Add to Doppler (infrastructure project):

```bash
# Authentik Docker
doppler secrets set AUTHENTIK_SECRET_KEY "$(openssl rand -base64 60)" -p infrastructure
doppler secrets set AUTHENTIK_POSTGRES_PASSWORD "$(openssl rand -base64 32)" -p infrastructure
doppler secrets set AUTHENTIK_BOOTSTRAP_PASSWORD "your-admin-password" -p infrastructure
doppler secrets set AUTHENTIK_BOOTSTRAP_TOKEN "$(openssl rand -hex 32)" -p infrastructure

# Authentik Terraform (authentik project)
doppler secrets set AUTHENTIK_TOKEN "your-api-token" -p authentik
```

## Troubleshooting

### Can't Access Services

1. Check Cloudflare Access logs:
   - Zero Trust → Logs → Access

2. Check Authentik logs:
   ```bash
   docker logs oci-core-authentik-server-1
   ```

3. Verify IdP configuration:
   - Authentik → Applications → Providers
   - Should see "Cloudflare Access" provider

### OIDC Errors

Check these URLs are accessible:
- `https://auth.smadja.dev/application/o/authorize/`
- `https://auth.smadja.dev/application/o/token/`
- `https://auth.smadja.dev/application/o/jwks/`

### Session Issues

Clear browser cookies for:
- `smadja.dev`
- `cloudflareaccess.com`

## Migration from Authelia

If you were using Authelia before:

1. **Export users** from Authelia (if file-based)
2. **Import users** into Authentik via UI or API
3. **Recreate groups** in Authentik
4. **Update Cloudflare Access** IdP (already done)
5. **Remove Authelia** containers

## Security Considerations

1. **Authentik admin**: Use strong password + 2FA
2. **Service accounts**: Rotate tokens regularly
3. **Cloudflare**: Enable geo-restriction if needed
4. **Backups**: Backup Authentik database regularly

## References

- [Authentik Documentation](https://docs.goauthentik.io/)
- [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/applications/)
- [OIDC with Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/generic-oidc/)
