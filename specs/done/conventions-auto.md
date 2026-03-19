# Spec: Convention-over-Configuration pour apps.yaml

## Contexte

`apps.yaml` contient beaucoup de boilerplate redondant : `hostname: {name}.smadja.dev` est répété sur ~90% des apps, `namespace: homelab` sur ~80%, et `dependencies: [external-secrets, cloudflared]` sur 6 apps alors que ces dépendances sont dérivables des autres champs. Les adapters (5 sous-classes) existent pour des différences mineures de format env/db entre charts Helm.

Cette redondance crée du bruit dans le fichier, augmente le risque d'erreur (oubli d'une dépendance, typo dans le hostname), et rend l'ajout d'une nouvelle app plus complexe qu'il ne devrait l'être.

## Objectif

Réduire la surface de configuration de `apps.yaml` de ~40% en dérivant automatiquement les valeurs redondantes, tout en gardant la possibilité d'override explicite.

## Scope

### In scope
- [ ] **Hostname auto-dérivé** : Si `hostname` n'est pas spécifié et que `mode != internal`, dériver `{name}.{domain}` (ou `{hostname_prefix}.{domain}` si un prefix est fourni)
- [ ] **Dependencies auto-injectées** : Dériver des dépendances implicites :
  - `secrets` non vide → dépend de `external-secrets`
  - `hostname` + `mode: protected|public` → dépend de `cloudflared`
  - `database.local: true` → dépend de `cnpg-system`
- [ ] **Chart hints dans AppModel** : Ajouter `env_style: list|map` et `db_env_prefix` optionnel pour remplacer les sous-classes d'adapters
- [ ] **Simplifier les adapters** : Fusionner `PaperlessAdapter`, `VaultwardenAdapter`, `OpenWebUIAdapter` dans `HelmValuesAdapter` en utilisant les chart hints
- [ ] **Garder `AuthentikAdapter`** : Seul cas réellement spécial (structure Helm nested `authentik.postgresql`, `global.env`)

### Out of scope
- Réécriture du loader YAML
- Migration vers un format de config différent (Jsonnet, CUE, etc.)
- Changement du pattern Strategy (on garde les adapters, on en réduit le nombre)

## Contraintes
- Secrets via Doppler uniquement (jamais en dur)
- Définir les apps dans apps.yaml, pas en Python
- Tout passe par Pulumi (pas de kubectl apply direct)
- Rétrocompatible : les apps avec un `hostname` explicite continuent de fonctionner
- Les valeurs auto-dérivées doivent être overridables par un champ explicite

## Critères d'acceptance
- [ ] `uv run pulumi preview --stack oci` passe sans erreur
- [ ] `uv run pytest tests/static/ -v` passe
- [ ] Supprimer le `hostname` d'une app existante → le preview génère le même hostname
- [ ] Supprimer les `dependencies` explicites → le preview déploie dans le même ordre
- [ ] `get_adapter()` ne retourne plus que 2-3 classes (au lieu de 6)
- [ ] Ajouter une nouvelle app simple = ~5 lignes dans apps.yaml (name, port, mode, helm)

## Fichiers concernés
- `kubernetes-pulumi/apps.yaml` — supprimer les champs redondants
- `kubernetes-pulumi/shared/utils/schemas.py` — ajouter `env_style`, `db_env_prefix`, `hostname_prefix` à `AppModel` + `model_validator` pour auto-dérivation
- `kubernetes-pulumi/shared/apps/adapters/__init__.py` — fusionner les adapters, utiliser chart hints
- `kubernetes-pulumi/shared/apps/loader.py` — auto-injecter les dépendances implicites
- `kubernetes-pulumi/tests/static/` — adapter les tests aux nouvelles conventions

## Notes / Références
- Pattern identifié dans `docs/TODO.md` section "apps.yaml — Opportunités DRY"
- Le champ `dependencies` est utilisé par `loader.get_deployment_order()` pour le tri topologique
