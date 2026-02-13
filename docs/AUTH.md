# Authentication Setup with Authelia

This homelab uses **Authelia** for authentication and RBAC (Role-Based Access Control).

## Overview

- **Auth URL**: https://auth.smadja.dev
- **Type**: Self-hosted with file-based user database
- **RBAC**: Yes, via groups (admins, users)
- **2FA**: TOTP (Time-based One-Time Password) support

## Access Control Rules

| Service | Domain | Required Group |
|---------|--------|----------------|
| Traefik Dashboard | traefik.smadja.dev | admins |
| Prometheus | prometheus.smadja.dev | admins |
| Blocky DNS | dns.smadja.dev | admins |
| Git | git.smadja.dev | any user |
| Vaultwarden | vault.smadja.dev | any user |
| File Browser | files.smadja.dev | any user |
| Status Page | status.smadja.dev | any user |

## Setup Instructions

### 1. Generate Admin Password

```bash
# Generate password hash for admin user
./scripts/generate-authelia-password.sh "YourSecurePassword123!"
```

### 2. Update Doppler Secrets

Add these secrets to Doppler (infrastructure project):

```bash
# Required secrets
doppler secrets set AUTHELIA_JWT_SECRET "$(openssl rand -hex 32)" -p infrastructure
doppler secrets set AUTHELIA_SESSION_SECRET "$(openssl rand -hex 32)" -p infrastructure
doppler secrets set AUTHELIA_STORAGE_ENCRYPTION_KEY "$(openssl rand -hex 32)" -p infrastructure
```

### 3. Update User Database

Edit `docker/oci-core/config/authelia/users_database.yml`:

```yaml
users:
  admin:
    displayname: "Your Name"
    password: "$argon2id$v=19$m=65536,t=3,p=4$..."  # Paste hash here
    email: your@email.com
    groups:
      - admins
      - users
```

### 4. Deploy

```bash
# Via GitHub Actions
gh workflow run deploy-stack.yml

# Or manually on the VM
cd /opt/oci-core
docker compose --profile core up -d
```

### 5. First Login

1. Visit https://auth.smadja.dev
2. Login with your credentials
3. Setup 2FA using your authenticator app
4. Access protected services

## Adding More Users

1. Generate password hash: `./scripts/generate-authelia-password.sh "password"`
2. Edit `config/authelia/users_database.yml`
3. Add new user entry
4. Restart authelia container

## RBAC Configuration

Access rules are defined in `config/authelia/configuration.yml`:

```yaml
access_control:
  default_policy: deny
  rules:
    - domain: admin-service.smadja.dev
      policy: one_factor
      subject:
        - "group:admins"

    - domain: user-service.smadja.dev
      policy: one_factor
```

## Troubleshooting

**Container keeps restarting:**
```bash
docker logs oci-core-authelia-1
```

**Can't login:**
- Check password hash is correct
- Verify users_database.yml syntax
- Check authelia logs

**Services show 401 Unauthorized:**
- Verify traefik middleware is configured
- Check authelia is running: `docker ps | grep authelia`

## Comparison with Cloudflare Access

This setup replaces Cloudflare Access with a self-hosted solution:

| Feature | Cloudflare Access | Authelia |
|---------|------------------|----------|
| Hosted | Cloud-hosted | Self-hosted |
| Cost | Free tier limited | Free (open source) |
| RBAC | Yes | Yes |
| 2FA | Yes | Yes (TOTP) |
| Session control | Limited | Full control |
| Dependency | Internet + Cloudflare | Local network |

Authelia provides better privacy and full control over your authentication data.
