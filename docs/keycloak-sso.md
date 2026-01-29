# Keycloak SSO Configuration

## Overview

Keycloak provides Single Sign-On (SSO) for all homelab applications using OpenID Connect (OIDC).

```
User → App → Keycloak → Authenticate → Token → App grants access
```

## URLs

| Service | URL |
|---------|-----|
| Keycloak Admin | https://auth.smadja.dev/admin |
| Keycloak Account | https://auth.smadja.dev/realms/homelab/account |

## Initial Setup

### 1. Deploy Keycloak

```bash
# Create secrets first (encrypt with SOPS)
kubectl apply -f kubernetes/apps/keycloak/secrets.enc.yaml

# ArgoCD will deploy Keycloak automatically
```

### 2. Access Admin Console

```bash
# Get initial admin password (if not using secrets)
kubectl get secret keycloak-admin -n identity -o jsonpath='{.data.admin-password}' | base64 -d

# Port-forward if Tunnel not ready
kubectl port-forward svc/keycloak -n identity 8080:80
# Access: http://localhost:8080/admin
```

### 3. Import Realm

1. Go to Keycloak Admin Console
2. Click "Create Realm"
3. Import the realm JSON from `kubernetes/apps/keycloak/realm-homelab.yaml`
4. Update client secrets (generate new ones)

## OIDC Endpoints

For realm `homelab`:

| Endpoint | URL |
|----------|-----|
| Authorization | `https://auth.smadja.dev/realms/homelab/protocol/openid-connect/auth` |
| Token | `https://auth.smadja.dev/realms/homelab/protocol/openid-connect/token` |
| Userinfo | `https://auth.smadja.dev/realms/homelab/protocol/openid-connect/userinfo` |
| JWKS | `https://auth.smadja.dev/realms/homelab/protocol/openid-connect/certs` |
| Discovery | `https://auth.smadja.dev/realms/homelab/.well-known/openid-configuration` |

## Pre-configured Clients

### Grafana

```yaml
# In Grafana values.yaml
grafana.ini:
  auth.generic_oauth:
    enabled: true
    name: Keycloak
    client_id: grafana
    client_secret: ${KEYCLOAK_GRAFANA_SECRET}
    scopes: openid profile email roles
    auth_url: https://auth.smadja.dev/realms/homelab/protocol/openid-connect/auth
    token_url: https://auth.smadja.dev/realms/homelab/protocol/openid-connect/token
    api_url: https://auth.smadja.dev/realms/homelab/protocol/openid-connect/userinfo
    role_attribute_path: contains(roles[*], 'Admin') && 'Admin' || contains(roles[*], 'Editor') && 'Editor' || 'Viewer'
```

### ArgoCD

```yaml
# In ArgoCD ConfigMap
oidc.config: |
  name: Keycloak
  issuer: https://auth.smadja.dev/realms/homelab
  clientID: argocd
  clientSecret: $oidc.keycloak.clientSecret
  requestedScopes: ["openid", "profile", "email", "groups"]
```

### OAuth2 Proxy (generic)

For apps that don't support OIDC natively:

```yaml
# oauth2-proxy config
provider: keycloak-oidc
client_id: oauth2-proxy
client_secret: ${CLIENT_SECRET}
oidc_issuer_url: https://auth.smadja.dev/realms/homelab
redirect_url: https://app.smadja.dev/oauth2/callback
email_domains: ["*"]
allowed_groups: ["admin", "user"]
```

## User Management

### Create User via Admin Console

1. Go to Users → Add User
2. Fill in username, email
3. Go to Credentials → Set Password
4. Go to Role Mappings → Assign roles

### Create User via CLI

```bash
# Using kcadm.sh (inside Keycloak pod)
kubectl exec -it deploy/keycloak -n identity -- \
  /opt/keycloak/bin/kcadm.sh create users \
  -r homelab \
  -s username=newuser \
  -s email=newuser@example.com \
  -s enabled=true
```

## Roles

| Role | Description | Apps |
|------|-------------|------|
| `admin` | Full access to all apps | All |
| `user` | Basic access | Homepage, limited Grafana |

## Security Best Practices

1. **Strong passwords**: Enforce via realm settings
2. **2FA**: Enable TOTP in realm → Authentication
3. **Brute force protection**: Already enabled in realm config
4. **Session limits**: Max 3 concurrent sessions per user

## Backup

Keycloak data is stored in PostgreSQL. Backup the PVC:

```bash
# Backup
kubectl exec -it deploy/keycloak-postgresql -n identity -- \
  pg_dump -U keycloak keycloak > keycloak-backup.sql

# Restore
kubectl exec -i deploy/keycloak-postgresql -n identity -- \
  psql -U keycloak keycloak < keycloak-backup.sql
```
