# Matrice RBAC (Role-Based Access Control)

Ce document définit la matrice des accès pour l'Identity Provider Authentik et son intégration avec Cloudflare Access.

## Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                      CLOUDFLARE ACCESS                          │
│                         (Free Tier)                             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  IdP: Authentik OIDC                                    │   │
│  │  - Authentification via auth.smadja.dev                 │   │
│  │  - 50 utilisateurs max (Free)                           │   │
│  │  - RBAC via groupes Authentik                           │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AUTHENTIK                                  │
│                    (Open Source)                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Groups     │  │   Policies   │  │  Scope Mappings      │  │
│  │   (RBAC)     │  │  (Access)    │  │  (OIDC Claims)       │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Groupes et Rôles

### Groupes Définis dans Terraform

| Groupe | Description | Accès | Superuser |
|--------|-------------|-------|-----------|
| `admin` | Administrateurs système | **Full access** à toutes les applications | Non (principe du moindre privilège) |
| `family-validated` | Famille validée manuellement | Apps famille: Nextcloud, Vaultwarden, etc. | Non |
| `professionnelle` | Utilisateurs professionnels | Apps métier: Odoo, outils pro | Non |
| `service-accounts` | Comptes de service M2M | Accès API uniquement | Selon configuration |

### Utilisateurs Définis dans le Code

Les utilisateurs suivants sont définis dans `terraform/authentik/variables.tf` pour ne jamais être perdus:

```hcl
authentik_users = [
  {
    username    = "smadja-paul"
    name        = "Paul"
    email       = "smadja-paul@protonmail.com"
    group_names = ["admin", "family-validated"]
    is_active   = true
    password    = "$2y$05$..."  # Hash bcrypt
  }
]
```

## Matrice d'Accès aux Applications

### Applications Authentik (Proxy/OIDC)

| Application | Groupe Requis | Policy | Description |
|-------------|---------------|--------|-------------|
| **Omni** | `admin` | `admin-group-only` | Management Kubernetes |
| **LiteLLM** | `admin` | `admin-group-only` | Interface LLM |
| **OpenClaw** | `admin` | `admin-group-only` | Automation |
| **Odoo** | `professionnelle` | `professionnelle-group-only` | ERP métier |
| **Nextcloud** | `family-validated` | `family-validated-only` | Stockage famille |
| **Vaultwarden** | `family-validated` | `family-validated-only` | Password manager |

### Cloudflare Access Applications (Future)

| Application | URL | Groupe Authentik | Policy Cloudflare |
|-------------|-----|------------------|-------------------|
| **Homepage** | `home.smadja.dev` | `admin`, `family-validated` | Allow: groups contains valid groups |
| **Authentik UI** | `auth.smadja.dev` | Tous | Allow: authenticated users |
| **Internal Tools** | `*.smadja.dev` | `admin` | Allow: email ends with @smadja.dev |

## Policies de Sécurité

### Expression Policies (Authentik)

```hcl
# Admin uniquement
admin-group-only: |
  for group in request.user.ak_groups.all():
      if group.name == 'admin':
          return True
  return False

# Famille validée uniquement
family-validated-only: |
  for group in request.user.ak_groups.all():
      if group.name == 'family-validated':
          return True
  return False

# Admin ET validée (double vérification)
admin-and-validated: |
  has_admin = False
  has_validated = False
  for group in request.user.ak_groups.all():
      if group.name == 'admin':
          has_admin = True
      if group.name == 'family-validated':
          has_validated = True
  return has_admin and has_validated
```

### Security Policies (Terraform)

| Policy | Type | Description | Activation |
|--------|------|-------------|------------|
| `rate-limit-login` | Reputation | Blocage après 5 tentatives en 5 min | ✅ Par défaut |
| `login-rate-limit-policy` | Expression | Rate limiting avancé par IP | ✅ Par défaut |
| `geo-restriction-policy` | Expression | Restriction par pays (FR, BE, CH, LU) | ❌ Désactivé |
| `suspicious-login-detection` | Expression | Détection connexions 2h-6h | ✅ Par défaut |
| `require-mfa-sensitive-groups` | Expression | MFA requis pour admin/pro | ✅ Par défaut |

## Scope Mappings (OIDC)

Pour l'intégration Cloudflare Access, les scope mappings suivants sont créés:

| Scope | Description | Utilisé par |
|-------|-------------|-------------|
| `openid` | Identifiant unique | Tous les providers OIDC |
| `email` | Adresse email vérifiée | Cloudflare Access, SSO |
| `profile` | Nom, username | Cloudflare Access, SSO |
| `groups` | **Liste des groupes** | Cloudflare Access RBAC |
| `cf_access` | Claims personnalisés Cloudflare | Cloudflare Access spécifique |

**Important**: Le scope `groups` est **CRITIQUE** pour le RBAC dans Cloudflare Access car il permet de transmettre les groupes Authentik dans le JWT.

## Service Accounts (M2M)

### Comptes de Service Définis

| Compte | Description | Groupes | Utilisation |
|--------|-------------|---------|-------------|
| `terraform-ci` | Terraform CI/CD | `admin` | GitHub Actions |
| `github-actions` | Automatisation GitHub | `admin` | Workflows CI/CD |
| `external-dns` | Synchronisation DNS | - | Kubernetes ExternalDNS |

### Secrets Doppler Automatiques

Chaque service account crée automatiquement un secret dans Doppler:

```
AUTHENTIK_TOKEN_TERRAFORM_CI=<token>
AUTHENTIK_TOKEN_GITHUB_ACTIONS=<token>
AUTHENTIK_TOKEN_EXTERNAL_DNS=<token>
```

## Rotation des Secrets

### Rotation de Mots de Passe

```bash
# Déclencher une rotation
cd terraform/authentik
terraform apply -var="password_rotation_trigger=v2"

# Ou forcer une rotation complète
terraform apply -var="force_password_rotation=true"
```

### Rotation de Tokens

Les tokens des service accounts sont automatiquement rotatés quand `rotation_trigger` change.

## Intégration Cloudflare Access (Préparation)

### Configuration Future

Quand vous serez prêt à activer Cloudflare Access:

1. **Créer l'application OIDC** dans Authentik (déjà fait dans `modules/apps`)
2. **Configurer l'IdP** dans Cloudflare Zero Trust:
   - Type: OpenID Connect
   - Client ID: depuis Authentik
   - Callback URL: `https://smadja.cloudflareaccess.com/cdn-cgi/access/callback`
   - Scopes: `openid`, `email`, `profile`, `groups`

3. **Créer les applications** dans Cloudflare Access avec policies basées sur les groupes

### Exemple de Policy Cloudflare (Future)

```hcl
resource "cloudflare_access_policy" "admin_only" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_access_application.protected_app.id
  name           = "Admin Only"
  decision       = "allow"

  include {
    # Utilisateurs authentifiés via Authentik
    login_method = [cloudflare_access_identity_provider.authentik.id]
  }

  require {
    # Email spécifique
    email = ["smadja-paul@protonmail.com"]

    # OU groupe (quand groups scope est activé)
    # groups = ["admin"]
  }
}
```

## Commandes Utiles

### Vérifier les Groupes d'un Utilisateur

```bash
# Via API Authentik
curl -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  https://auth.smadja.dev/api/v3/core/users/
```

### Tester une Policy

```bash
# Dans l'interface Authentik
# Applications → Policies → [Policy] → Test
```

### Lister les Service Accounts

```bash
kubectl -n authentik exec -it deployment/authentik-server -- \
  ak user list --path service-accounts
```

## Références

- [Documentation Authentik Terraform](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
- [Intégration Cloudflare Access](https://docs.goauthentik.io/integrations/services/cloudflare-access/)
- [Cloudflare Access Generic OIDC](https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/generic-oidc/)
- [Guide Authentik + Cloudflare Tunnel](https://github.com/eclecticbouquet/authentikate-your-cloudflared)
