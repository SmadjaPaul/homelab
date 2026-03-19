# SSO Implementation - Homelab (Automated v2)

## Description
L'authentification est désormais **entièrement automatisée** via le système de **SSO Presets**. Il n'est plus nécessaire de configurer manuellement les variables d'environnement pour la plupart des applications.

## Configuration dans `apps.yaml`
Il suffit de renseigner le champ `sso` (dans le bloc `auth`) avec l'un des presets supportés :
- `authentik-oidc` : Pour les applications supportant nativement OpenID Connect (Vaultwarden, Immich, ROMM, Nextcloud).
- `authentik-header` : Pour les applications lisant les headers injectés par le proxy (Navidrome, Paperless-ngx, Open WebUI).

```yaml
- name: my-app
  auth:
    sso: authentik-oidc  # Déclenche l'injection automatique
```

## Architecture Globale

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AUTHENTIK (IdP + Proxy)                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │
│  │  Proxy Outpost  │  │   LDAP Outpost  │  │      OIDC Providers        │ │
│  │   (port 9000)   │  │    (port 3389)  │  │  (per-app OAuth2/OIDC)    │ │
│  └────────┬────────┘  └────────┬────────┘  └──────────────┬────────────┘ │
│           │                     │                           │               │
│           │    ┌────────────────┴───────────────────────┐               │
│           │    │                                                           │
│           ▼    ▼                                                           │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    Authentik Server                                   │  │
│  │  • User Directory (users + groups)                                   │  │
│  │  • OIDC Authorization Flows                                          │  │
│  │  • Password Recovery Flow                                            │  │
│  │  • LDAP Backend (synced to internal directory)                       │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│─────────────────────────────────────────────────────────────────────────────┘
```

## Couche 1: Le Proxy (Authentik Outpost)

Toutes les apps en `mode: protected` (ou `exposure: protected`) passent par le proxy Authentik. L'injecteur d'adaptateur configure automatiquement l'Outpost et l'Ingress.

Le proxy injecte les headers suivants vers le backend (Preset `authentik-header`):
- `HTTP_X_AUTHENTIK_USERNAME` - Nom d'utilisateur
- `HTTP_X_AUTHENTIK_EMAIL` - Email
- `HTTP_X_AUTHENTIK_NAME` - Nom complet
- `HTTP_X_FORWARDED_USER` - Username


**Note:** Open-WebUI est en `mode: protected` (proxy Authentik) + OIDC. L'utilisateur est redirigé automatiquement via le proxy avant d'arriver sur l'app.

**Source:** [Open-WebUI OIDC](https://docs.openwebui.com/tutorials/integrations/auth-identity/okta-oidc-sso)

---

### ✅ Paperless-ngx - GAP OK

**Méthode:** Header
**Auto-création:** ✅ OUI

```yaml
PAPERLESS_ENABLE_HTTP_REMOTE_USER: "true"
PAPERLESS_HTTP_REMOTE_USER_HEADER: "HTTP_X_AUTHENTIK_USERNAME"
PAPERLESS_HTTP_REMOTE_USER_AUTH_ALLOW_SIGNUPS: "true"  # ← CRÉE LES USERS
```

**Source:** [Paperless-ngx OIDC Integration](https://kabason.net/home-lab/application/paperlessintegration)

---

### ❌ SLSKD - GAP INCOMPATIBLE

**Méthode:** Header
**Auto-création:** ❌ **NON SUPPORTÉ**

**Problème identifié:**
- SLSKD n'a **PAS de support pour l'authentification par headers**
- Il n'a pas de variable d'environnement pour lire `HTTP_X_AUTHENTIK_USERNAME`
- Il ne supporte pas OIDC/OAuth2
- Il n'a pas de mécanisme de création automatique d'utilisateurs

**Source:** [slskd GitHub](https://github.com/slskd/slskd) - Documentation configuration

**Options pour SLSKD:**

| Option | Description | Auto-création user | Sécurité | Recommandation |
|--------|-------------|-------------------|----------|-----------------|
| **A. Public** | Pas d'auth du tout | N/A | 🔴 Risqué | ❌ Non recommandé |
| **B. Compte partagé** | Un seul compte pour tous | ❌ Non | 🟡 Moyen | ⚠️ Option simple |
| **C. Basic Auth via proxy** | Auth basic dans le proxy | ❌ Non | 🟡 Moyen | ⚠️ Alternative |
| **D. IP Allowlist** | Par IP/source | N/A | 🟢 Bon | ✅ **Recommandé** |

**Recommandation: Option D - IP Allowlist**
- Ajouter une règle NetworkPolicy pour autoriser seulement le traffic depuis le tunnel Cloudflare
- SLSKD n'est accessible qu'à travers le tunnel déjà protégé
- Usage: "Service pour demander d'ajouter des morceaux" = pas de données sensibles

**Config recommandée:**
```yaml
mode: public  # Plus de protection au niveau proxy
# OU
# Ajouter NetworkPolicy pour IPs autorisées
```

---

### ✅ Homepage - GAP OK

**Méthode:** Proxy Only (pas d'auth dans l'app)
**Auto-création:** N/A - Pas nécessaire

Homepage n'a pas de système d'authentification. L'accès est contrôlé uniquement par le proxy Authentik.

---

# Recommandations de Refactoring

## Actions requise pour avoir SSO + auto-création universelle

| Priorité | App | Action | Impact |
|----------|-----|--------|--------|
| 🔴 Haute | **SLSKD** | Passer en `mode: public` + NetworkPolicy | Moyen |
| 🟡 Moyenne | **Open-WebUI** | Ajouter config OIDC complète | Faible |

## Configuration cible pour chaque application

### 1. Navidrome (OK)
```yaml
mode: protected
auth: true
provisioning:
  method: header
# Auto-création: ND_REVERSEPROXYAUTOCREATE: "true"
```

### 2. Vaultwarden (OK)
```yaml
mode: protected
auth: true
provisioning:
  method: oidc
# Auto-création: native OIDC
```

### 3. Audiobookshelf (OK)
```yaml
mode: protected
auth: true
provisioning:
  method: oidc
# Auto-création: native OIDC
```

### 4. OwnCloud (OK)
```yaml
mode: protected
auth: true
provisioning:
  method: oidc
# Auto-création: PROXY_AUTOPROVISION_ACCOUNTS
```

### 5. Open-WebUI (À modifier)
```yaml
mode: protected
auth: true
provisioning:
  method: oidc  # ← CHANGER de "header" vers "oidc"
# Auto-création: ENABLE_OAUTH_SIGNUP
```

### 6. Paperless-ngx (OK)
```yaml
mode: protected
auth: true
provisioning:
  method: header
# Auto-création: PAPERLESS_HTTP_REMOTE_USER_AUTH_ALLOW_SIGNUPS
```

### 7. SLSKD (À modifier)
```yaml
# OPTION RECOMMANDÉE:
mode: public  # ← Le proxy Cloudflare suffit
auth: false  # ← Pas d'auth dans l'app
# IP allowlist via NetworkPolicy
```

### 8. Homepage (OK)
```yaml
mode: protected
auth: false  # ← Pas d'auth dans l'app
# Proxy Authentik suffit
```

---

## Résumé final

| App | Methode SSO | Auto-création | Status |
|-----|-------------|---------------|--------|
| **Navidrome** | Header | ✅ | ✅ OK |
| **Vaultwarden** | OIDC | ✅ | ✅ OK |
| **Audiobookshelf** | OIDC | ✅ | ✅ OK |
| **OwnCloud** | OIDC | ✅ | ✅ OK |
| **Open-WebUI** | OIDC | ✅ | ✅ OK |
| **Paperless-ngx** | Header | ✅ | ✅ OK |
| **SLSKD** | ❌ | ❌ | ❌ Incompatible |
| **Homepage** | N/A | N/A | ✅ OK |

---

## Sources

- [Navidrome Externalized Authentication](https://www.navidrome.org/docs/usage/integration/authentication/)
- [Vaultwarden SSO Wiki](https://github.com/dani-garcia/vaultwarden/wiki/Enabling-SSO-support-using-OpenId-Connect)
- [Authentik Integration - Audiobookshelf](https://integrations.goauthentik.io/media/audiobookshelf/)
- [OwnCloud Proxy Documentation](https://owncloud.dev/services/proxy/)
- [Open-WebUI OIDC](https://docs.openwebui.com/tutorials/integrations/auth-identity/okta-oidc-sso)
- [Paperless-ngx OIDC Integration](https://kabason.net/home-lab/application/paperlessintegration)
- [slskd Configuration](https://github.com/slskd/slskd/blob/master/docs/config.md)
