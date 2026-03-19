# Spec: Provider Abstraction (`requires:` dans apps.yaml)

## Contexte

Aujourd'hui, chaque app dans `apps.yaml` doit explicitement configurer ses secrets, database et storage avec du boilerplate repetitif. Par exemple, une app qui a besoin de PostgreSQL doit declarer `database: { local: true, size: 5Gi }` + les secrets associes. Une app qui utilise Redis doit hardcoder `REDIS_URL` dans ses `extra_env`.

Olares resout ce probleme avec un pattern "Provider" : chaque app declare ses besoins (`requires: [postgresql, redis]`) et le systeme injecte automatiquement les secrets et configs.

Avec 20 utilisateurs vises, le nombre d'apps va croitre et ce boilerplate deviendra un vrai frein.

## Objectif

Une app peut declarer `requires: [postgresql, redis, s3]` dans `apps.yaml` et le code Pulumi provisionne automatiquement les ressources + injecte les secrets, sans configuration manuelle par app.

## Scope

### In scope
- [ ] Nouveau champ `requires: []` dans le schema `apps.yaml` / `AppModel`
- [ ] Provider `postgresql` : cree DB + user dans le cluster CNPG partage, injecte secret `{app}-db-app` (host, username, password, dbname)
- [ ] Provider `redis` : injecte `REDIS_URL` pointant vers le Redis partage
- [ ] Provider `s3:{bucket-name}` : reference un bucket existant dans `buckets:`, injecte les credentials S3
- [ ] Retro-compatibilite : `database:` et `secrets:` existants continuent de fonctionner
- [ ] Migration progressive : les apps existantes peuvent migrer une par une

### Out of scope
- Providers custom (MongoDB, Elasticsearch, etc.) — on n'en a pas besoin
- Provisioning de nouvelles instances Redis/PostgreSQL dedie par app
- UI ou CLI pour gerer les providers

## Design

### Schema `apps.yaml`

```yaml
# Avant (verbose)
- name: paperless-ngx
  database:
    local: true
    size: 5Gi
    storage_class: oci-bv
  secrets:
    - name: paperless-db-creds
      keys:
        DB_HOST: PAPERLESS_DB_HOST
  extra_env:
    REDIS_URL: "redis://redis-master.storage.svc.cluster.local:6379/2"

# Apres (declaratif)
- name: paperless-ngx
  requires:
    - postgresql          # auto: DB + secret {app}-db-app
    - redis               # auto: injecte REDIS_URL (slot auto-attribue)
```

### Mapping Provider -> Actions

| Provider | Ressources creees | Secret injecte | Env vars injectees |
|---|---|---|---|
| `postgresql` | DB + user dans `homelab-db` | `{app}-db-app` (host, user, pass, dbname) | — |
| `redis` | Rien (Redis partage) | — | `REDIS_URL=redis://redis-master.storage:6379/{slot}` |
| `s3:{name}` | Rien (bucket dans `buckets:`) | `{app}-s3-creds` (endpoint, access_key, secret_key, bucket) | — |

### Slot Redis auto-attribue

Chaque app utilisant Redis recoit un slot (DB number) unique, attribue par ordre alphabetique des noms d'app. Stocke dans un dict dans `kubernetes_registry.py`. Evite les collisions sans config manuelle.

### Implementation

1. **`shared/utils/schemas.py`** : Ajouter `requires: Optional[List[str]]` a `AppModel`
2. **`shared/apps/common/provider_registry.py`** (nouveau) : Classe `ProviderRegistry` qui :
   - Parse les `requires` de chaque app
   - Delegue a `KubernetesRegistry` (postgresql), injecte env (redis), reference buckets (s3)
3. **`shared/apps/common/registry.py`** : Appeler `ProviderRegistry` dans le flow de registration
4. **`shared/apps/common/kubernetes_registry.py`** : Extraire la logique DB existante en methode reutilisable

### Migration

Les champs `database:` et `secrets:` restent fonctionnels. `requires: [postgresql]` est un sucre syntaxique qui genere les memes ressources. A terme, on migre toutes les apps et on deprecie les anciens champs.

## Contraintes
- Secrets via Doppler uniquement (jamais en dur)
- Definir les apps dans apps.yaml, pas en Python
- Tout passe par Pulumi (pas de kubectl apply direct)
- Retro-compatible : les apps existantes ne cassent pas

## Criteres d'acceptance
- [ ] `requires: [postgresql]` produit les memes ressources que `database: { local: true }`
- [ ] `requires: [redis]` injecte `REDIS_URL` avec un slot unique par app
- [ ] `requires: [s3:velero-backups]` injecte les credentials du bucket
- [ ] Les apps existantes avec `database:` / `secrets:` fonctionnent toujours
- [ ] `uv run pulumi preview --stack oci` passe sans erreur
- [ ] `uv run pytest tests/static/ -v` passe
- [ ] Un test statique verifie que chaque provider dans `requires` est valide

## Fichiers concernes
- `kubernetes-pulumi/apps.yaml` — ajouter `requires:` aux apps
- `kubernetes-pulumi/shared/utils/schemas.py` — nouveau champ `requires`
- `kubernetes-pulumi/shared/apps/common/provider_registry.py` — nouveau fichier
- `kubernetes-pulumi/shared/apps/common/registry.py` — integration
- `kubernetes-pulumi/shared/apps/common/kubernetes_registry.py` — refactor DB provisioning
- `kubernetes-pulumi/tests/static/test_provider_registry.py` — tests

## Notes / References
- Inspire du pattern `Middleware` d'Olares (`framework/app-service/pkg/tapr/middleware_types.go`)
- Leur `ProviderHelper.ToPermissionCfg()` fait exactement ce mapping provider -> config
