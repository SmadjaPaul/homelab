# RBAC Authentik — Groupes et accès aux applications

Ce document décrit le modèle **RBAC** (Role-Based Access Control) utilisé dans le Terraform Authentik du homelab, aligné sur [planning-conclusions](../../../docs-site/docs/advanced/planning-conclusions.md) et inspiré de [ghndrx/authentik-terraform](https://github.com/ghndrx/authentik-terraform) et [K-FOSS/auth.kristinejones.dev-TF](https://github.com/K-FOSS/auth.kristinejones.dev-TF).

## Groupes

| Groupe              | Rôle / usage |
|---------------------|--------------|
| **admin**           | Administrateurs : accès aux apps d’admin (Omni, LiteLLM, OpenClaw, etc.). Non exposé aux utilisateurs famille. |
| **family-validated**| Utilisateurs famille validés manuellement : accès aux apps famille (Nextcloud, Vaultwarden, etc.). |
| **professionnelle** | Utilisateurs pro : accès aux services métier (Odoo, etc.). Distinct de family-validated. |

Les groupes sont définis dans `modules/groups` avec des attributs optionnels (description, role) pour la traçabilité.

## Policies d’expression

| Policy                   | Rôle |
|--------------------------|------|
| **admin_only**           | Accès réservé aux utilisateurs du groupe `admin`. |
| **family_validated_only**| Accès réservé au groupe `family-validated`. |
| **admin_and_validated** | Accès si l’utilisateur est à la fois dans `admin` et `family-validated`. |
| **block_public_enrollment** | Bloque l'enrollment sans token d'invitation. |
| **professionnelle_only** | Accès réservé au groupe `professionnelle` (Odoo, etc.). |

Définies dans `modules/policies`. Spécification détaillée : [authentik-rbac-spec](../../../docs/authentik-rbac-spec.md).

## Matrice d’accès (applications)

| Application           | Groupes / policies liés |
|-----------------------|-------------------------|
| **Omni**              | admin (policy binding + group) |
| **LiteLLM**           | admin |
| **OpenClaw** (proxy)  | admin |
| **OpenClaw (OIDC)**   | admin |
| **Odoo**              | professionnelle_only |
| **Cloudflare Access (IdP)** | Tous (ou admin_only si restreint) ; les apps côté Cloudflare peuvent filtrer par groupe. |
| **Apps famille** (futur) | family_validated_only ou admin_and_validated selon le cas. |

Les bindings sont dans `modules/bindings`.

## Utilisateurs dans Terraform (optionnel)

Le module **Users** (`modules/users`) permet de créer des utilisateurs et de les assigner à des groupes via la variable `authentik_users` :

```hcl
authentik_users = [
  {
    username    = "admin1"
    name        = "Admin One"
    email       = "admin@example.com"
    group_names = ["admin"]
    is_active   = true
  }
]
```

- **Recommandation** : utiliser les **invitations** (Directory → Invitations) pour l’onboarding normal ; le module Users sert aux comptes déclaratifs (premiers admins, service accounts, etc.).
- Les mots de passe ne sont pas gérés dans Terraform ; utiliser invitation ou recovery après création.

## Références

- [Authentik — Groups](https://docs.goauthentik.io/users-sources/groups/)
- [Terraform provider authentik](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
- [ghndrx/authentik-terraform — RBAC](https://github.com/ghndrx/authentik-terraform#rbac-groups-rbac-groupstf)
