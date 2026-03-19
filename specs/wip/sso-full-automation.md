# Spec: SSO Full Automation — Éliminer toute config manuelle

## Contexte

Le système SSO actuel (`sso_presets.py` + `authentik_registry.py`) accomplit ~80% du travail : il crée les providers OIDC/Proxy dans Authentik et pousse les secrets dans Doppler. Mais le "dernier kilomètre" est cassé :

1. **3 apps en `UI_ONLY_OIDC`** (Nextcloud, Immich, Audiobookshelf) nécessitent une config manuelle dans leur UI admin — config jamais faite, donc SSO inopérant
2. **Callback paths hardcodés** dans un dict Python (`authentik_registry.py:116-130`) — RomM v4.7.0 a changé son path, cassant le SSO silencieusement
3. **Presets incomplets** — Navidrome manque `ND_REVERSEPROXYAUTOCREATE=true`, empêchant l'auto-création d'utilisateurs
4. **Open WebUI** avait des noms de variables incorrects (`OIDC_*` au lieu de `OAUTH_*`), partiellement corrigé
5. **Aucune validation post-deploy** — pas de test qui vérifie que le callback OIDC répond

État actuel par app :
| App | Status SSO | Problème |
|-----|-----------|----------|
| Nextcloud | ❌ | Plugin `user_oidc` non configuré (UI_ONLY) |
| Immich | ⚠️ User manuel | OIDC non configuré dans l'admin UI (UI_ONLY) |
| Audiobookshelf | ⚠️ User manuel | OIDC non configuré dans l'admin UI (UI_ONLY) |
| RomM | ❌ 404 callback | Path configuré `/api/oauth2/openid/callback`, réel `/api/oauth/openid` |
| Navidrome | ❌ | `ND_REVERSEPROXYAUTOCREATE=true` manquant |
| Open WebUI | ❌ CrashLoop | Bug peewee migration (hors scope SSO) |
| Vaultwarden | ✅ | — |
| Paperless-ngx | ✅ | — |

Inspiration : [Olares/beclab](https://github.com/beclab/Olares) automatise l'injection OIDC à l'install via un platform controller + Helm template variables. On adapte ce pattern à notre stack Pulumi + Authentik.

## Objectif

Toute app déclarant `sso: authentik-oidc` ou `sso: authentik-header` dans `apps.yaml` a un SSO fonctionnel après `pulumi up`, sans aucune intervention manuelle.

## Scope

### In scope

#### Phase 1 — Fixes immédiats (presets + callback paths)
- [ ] Ajouter champ optionnel `oidc_callback` dans `AppModel` (schema)
- [ ] Migrer les callback paths du dict hardcodé vers `apps.yaml` (source de vérité)
- [ ] Fallback : si `oidc_callback` absent, utiliser le dict de conventions existant (rétrocompatible)
- [ ] Fix RomM : callback → `/api/oauth/openid`
- [ ] Fix Navidrome : ajouter `ND_REVERSEPROXYAUTOCREATE: "true"` au preset header
- [ ] Fix Navidrome : ajouter `ND_EXTAUTH_URL` avec l'URL interne du proxy Authentik si nécessaire

#### Phase 2 — Éliminer `UI_ONLY_OIDC` (post-deploy Jobs)
- [ ] Créer un mécanisme de "post-deploy hook" dans `kubernetes_registry.py` : un Job K8s exécuté après le Helm release
- [ ] Nextcloud : Job post-deploy → `php occ app:install user_oidc && php occ user_oidc:provider authentik --clientid=... --clientsecret=... --discoveryuri=...`
- [ ] Immich : Job post-deploy → appel API Admin (`/api/system-config` PUT avec OAuth settings)
- [ ] Audiobookshelf : Job post-deploy → appel API Admin (si supporté) OU documentation comme exception
- [ ] Supprimer le set `UI_ONLY_OIDC` de `sso_presets.py` une fois les Jobs en place
- [ ] Les Jobs doivent être idempotents (re-run safe)

#### Phase 3 — Validation post-deploy (smoke tests SSO)
- [ ] Test smoke : pour chaque app avec `sso: authentik-oidc`, vérifier que le callback endpoint ne retourne pas 404
- [ ] Test smoke : pour chaque app avec `sso: authentik-header`, vérifier que le proxy injecte bien les headers
- [ ] Test statique : valider que chaque app avec `sso` a un `oidc_callback` ou une convention connue

### Out of scope
- Migration vers Authelia (on reste sur Authentik)
- SCIM provisioning
- LDAP binding côté apps
- Refonte du modèle double-layer (protected + OIDC) — améliorable mais pas bloquant
- Fix du bug peewee Open WebUI (bug upstream, pas SSO)
- Forward Auth mode (amélioration future)

## Contraintes
- Secrets via Doppler uniquement (jamais en dur)
- Définir les apps dans apps.yaml, pas en Python
- Tout passe par Pulumi (pas de kubectl apply direct)
- Les Jobs post-deploy doivent utiliser les secrets existants (Doppler → ExternalSecrets → K8s Secret)
- Les Jobs doivent être idempotents — `pulumi up` repeated ne doit pas casser la config
- Le mécanisme de post-deploy doit être générique (réutilisable pour d'autres apps futures)
- Les callback paths dans `apps.yaml` priment toujours sur les conventions

## Design

### Schema — nouveau champ `oidc_callback`

```yaml
# apps.yaml
- name: romm
  sso: authentik-oidc
  auth:
    oidc_callback: /api/oauth/openid
```

Dans `schemas.py`, ajouter `oidc_callback: Optional[str]` à `AuthConfig`. Le champ est lu par `authentik_registry.py:_get_redirect_uris()` en priorité sur le dict de conventions.

### Post-deploy Jobs — pattern générique

Nouveau champ `post_deploy` dans `AppModel` :

```yaml
- name: nextcloud
  sso: authentik-oidc
  post_deploy:
    container: nextcloud  # container cible dans le pod
    commands:
      - "php occ app:install user_oidc || true"
      - "php occ user_oidc:provider authentik --clientid=${OIDC_CLIENT_ID} --clientsecret=${OIDC_CLIENT_SECRET} --discoveryuri=https://auth.smadja.dev/application/o/nextcloud-oidc/.well-known/openid-configuration"
```

Implémenté via un `kubernetes.batch.v1.Job` Pulumi :
- `depends_on` le Helm Release de l'app
- Monte les mêmes secrets que le pod de l'app
- Utilise l'image du pod comme base
- Idempotent par design (commandes avec `|| true`, `--update-if-exists`, etc.)

Alternative pour Immich/Audiobookshelf qui n'ont pas de CLI : un Job avec `curl` / `wget` contre l'API admin interne.

### Résolution du callback — ordre de priorité

```
1. apps.yaml → auth.oidc_callback           (explicite, priorité max)
2. apps.yaml → auth.provisioning.redirect_uris  (override custom)
3. sso_presets.py → convention dict            (fallback)
4. défaut → /oauth2/callback                  (catch-all)
```

## Plan d'implémentation

### Phase 1 — Fixes immédiats (~1h)
1. `schemas.py` : ajouter `oidc_callback: Optional[str]` à `AuthConfig`
2. `apps.yaml` : ajouter `oidc_callback` pour RomM, et les autres apps OIDC connues
3. `authentik_registry.py:_get_redirect_uris()` : lire `app.auth.oidc_callback` en priorité
4. `sso_presets.py` : ajouter `ND_REVERSEPROXYAUTOCREATE: "true"` au preset Navidrome
5. Tests statiques : adapter `test_sso_presets.py`

### Phase 2 — Post-deploy Jobs (~3-4h)
1. `schemas.py` : ajouter `PostDeployConfig` (container, commands, env_from_secrets)
2. `kubernetes_registry.py` : créer le Job post-deploy si `app.post_deploy` défini
3. `apps.yaml` : définir les post_deploy pour Nextcloud, Immich, Audiobookshelf
4. Tester sur le cluster : `pulumi up` → vérifier que les Jobs créent la config OIDC
5. `sso_presets.py` : supprimer `UI_ONLY_OIDC`

### Phase 3 — Smoke tests (~1h)
1. `tests/smoke/test_sso_callbacks.py` : hit callback endpoints, assert != 404
2. `tests/static/test_sso_completeness.py` : valider que chaque app SSO a un callback défini
3. Intégrer dans le workflow de test existant

## Critères d'acceptance
- [ ] `uv run pulumi preview --stack oci` passe sans erreur
- [ ] `uv run pytest tests/static/ -v` passe
- [ ] RomM : cliquer "Se connecter avec Authentik" → redirige vers Authentik → retour sur RomM → user créé
- [ ] Navidrome : accéder à `music.smadja.dev` → proxy Authentik → arrivée dans Navidrome avec user `paul` auto-créé
- [ ] Nextcloud : accéder à `cloud.smadja.dev` → proxy Authentik → bouton "Se connecter avec Authentik" → user `paul@smadja.dev` auto-créé
- [ ] Immich : accéder à `photos.smadja.dev` → proxy Authentik → bouton OAuth → user `paul@smadja.dev` auto-créé
- [ ] Audiobookshelf : accéder à `audiobooks.smadja.dev` → proxy Authentik → bouton OpenID → user auto-créé
- [ ] Aucun champ `UI_ONLY_OIDC` ne subsiste dans le code
- [ ] Smoke test SSO passe pour toutes les apps avec `sso:` défini

## Fichiers concernés

### Modifiés
- `kubernetes-pulumi/shared/utils/schemas.py` — `AuthConfig.oidc_callback`, `PostDeployConfig`
- `kubernetes-pulumi/shared/apps/sso_presets.py` — fix Navidrome, supprimer `UI_ONLY_OIDC`
- `kubernetes-pulumi/shared/apps/common/authentik_registry.py` — lire `oidc_callback` en priorité
- `kubernetes-pulumi/shared/apps/common/kubernetes_registry.py` — créer Jobs post-deploy
- `kubernetes-pulumi/apps.yaml` — `oidc_callback` + `post_deploy` pour les apps concernées
- `kubernetes-pulumi/tests/static/test_sso_presets.py` — adapter tests

### Créés
- `kubernetes-pulumi/tests/smoke/test_sso_callbacks.py` — smoke tests SSO
- `kubernetes-pulumi/tests/static/test_sso_completeness.py` — validation statique

## Risques
- **Immich/Audiobookshelf API** : l'API admin n'est peut-être pas stable ou documentée → fallback : documenter comme exception manuelle
- **Job idempotence** : les commandes `occ` doivent supporter le re-run → tester avec `--update-if-exists` ou équivalent
- **Timing** : le Job post-deploy doit attendre que le pod soit Ready → utiliser `depends_on` + `initContainers` avec wait
- **Nextcloud init lent** : le premier boot peut prendre 5-10 min (migration PHP) → le Job doit avoir un `backoffLimit` + `activeDeadlineSeconds` généreux

## Notes / Références
- [Olares auth architecture](https://github.com/beclab/Olares) — inspiration pour le pattern "injection OIDC à l'install"
- [Nextcloud user_oidc CLI](https://github.com/nextcloud/user_oidc#occ-commands) — `occ user_oidc:provider`
- [Immich OAuth API](https://immich.app/docs/administration/oauth) — config via Admin UI ou API
- [Audiobookshelf OpenID](https://www.audiobookshelf.org/guides/openid/) — config via Admin UI
- [Navidrome Reverse Proxy Auth](https://www.navidrome.org/docs/usage/security/#reverse-proxy-authentication) — `ND_REVERSEPROXYAUTOCREATE`
- Spec précédente : `specs/done/sso-presets.md`
- Spec précédente : `specs/done/consolidated-post-refacto.md`
