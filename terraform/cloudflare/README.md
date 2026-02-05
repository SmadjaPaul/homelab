# Cloudflare Terraform Configuration

Configuration Terraform pour le domaine `smadja.dev` : DNS, Tunnel, WAF, sécurité.

## Authentik API Access (CI/CD)

Pour permettre aux runners GitHub Actions d'accéder à l'API Authentik sans le challenge Cloudflare "Just a moment..." :

### Solution 1 : Règle WAF (recommandé)

Une règle WAF est configurée dans `security.tf` pour autoriser l'accès aux endpoints API d'Authentik :

- **Règle** : `allow_authentik_api` (activée par défaut via `enable_authentik_api_access = true`)
- **Condition** : Requêtes vers `auth.smadja.dev/api/v3/*` ou `/application/o/*` avec header `Authorization`
- **Action** : Skip les règles custom (et exclut de la geo-restriction)

**Limitation** : Cette règle skip uniquement les règles **custom**, pas les managed rulesets (Bot Fight Mode). Si le challenge "Just a moment..." persiste, voir Solution 2.

### Solution 2 : Désactiver Bot Fight Mode pour auth.smadja.dev (si nécessaire)

Si la règle WAF ne suffit pas (le challenge persiste), désactiver temporairement Bot Fight Mode :

1. **Cloudflare Dashboard** → Zone `smadja.dev` → **Security** → **Bots**
2. **Bot Fight Mode** → **Off** (ou créer une exception pour `auth.smadja.dev`)

**Note** : Bot Fight Mode ne peut pas être désactivé via Terraform sur le free tier. Il faut le faire manuellement dans le dashboard.

### Solution 3 : Utiliser AUTHENTIK_TOKEN (fallback)

Si les solutions ci-dessus ne fonctionnent pas, utiliser le secret GitHub `AUTHENTIK_TOKEN` comme fallback. Les workflows Authentik utilisent automatiquement ce token si OAuth2 échoue.

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_authentik_api_access` | Activer la règle WAF pour autoriser l'accès API Authentik | `true` |
| `enable_geo_restriction` | Activer la restriction géographique | `true` |
| `allowed_countries` | Pays autorisés (ISO 3166-1 Alpha 2) | `["FR"]` |

## Déploiement

```bash
cd terraform/cloudflare
terraform init
terraform plan
terraform apply
```

## Vérification

Après déploiement, vérifier dans Cloudflare Dashboard :

1. **Security** → **WAF** → **Custom Rules** : La règle "Homelab - Allow Authentik API (CI/CD)" doit être présente
2. **Security** → **Bots** : Vérifier que Bot Fight Mode n'est pas trop restrictif pour `auth.smadja.dev`

## Troubleshooting

### Le challenge "Just a moment..." persiste

1. Vérifier que la règle WAF est active (Dashboard → Security → WAF)
2. Vérifier que les requêtes incluent le header `Authorization: Bearer <token>`
3. Désactiver temporairement Bot Fight Mode pour `auth.smadja.dev` (Dashboard)
4. Utiliser le fallback `AUTHENTIK_TOKEN` dans les workflows GitHub Actions

### La geo-restriction bloque les runners

La règle `geo_restrict` exclut automatiquement les paths API d'Authentik. Si le problème persiste, vérifier que l'expression de la règle est correcte.
