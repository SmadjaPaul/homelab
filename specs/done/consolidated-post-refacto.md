# Spec: Finalisation du Déploiement Post-Refactorisation

> **Consolide** : `refacto_architecture.md`, `post-migration-fix.md`, `unified-storage.md`, `deployment-reliability.md`, `authentik-sso-review.md`
>
> **Objectif** : Rendre le cluster OCI pleinement fonctionnel après la migration Pydantic + app-template v3
>
> **Statut** : ✅ **TERMINÉ** — 2026-03-24

---

## Résultat final

Tous les 15 services sont opérationnels sur le cluster OCI (ARM64 Ampere A1) :

| Service | URL | État |
|---------|-----|------|
| Authentik | auth.smadja.dev | ✅ Running |
| Homepage | home.smadja.dev | ✅ Running |
| Vaultwarden | vault.smadja.dev | ✅ Running |
| Nextcloud | cloud.smadja.dev | ✅ Running |
| Paperless-ngx | paperless.smadja.dev | ✅ Running |
| Open-WebUI | ai.smadja.dev | ✅ Running (+ Ollama + Pipelines) |
| Immich | photos.smadja.dev | ✅ Running (server + machine-learning) |
| RomM | romm.smadja.dev | ✅ Running |
| Navidrome | music.smadja.dev | ✅ Running |
| Audiobookshelf | audiobooks.smadja.dev | ✅ Running |
| Slskd | soulseek.smadja.dev | ✅ Running |
| Cloudflared | — | ✅ Running |
| Monitoring | — | ✅ Running |

---

## Phase 0 — Correctifs Urgents ✅ TERMINÉE

### 0.1 Immich — Service orphelin ✅
Suppression du svc orphelin + recréation via Pulumi avec port correct (2283).

### 0.2 Immich — DB Password Drift ✅
Resynchronisation manuelle + migration chart 0.8.1 → 0.10.3 (résout le bug immutable selector).

### 0.3 Open-WebUI — Redis ARM64 + peewee migration ✅
- Image tag supprimé (utilise appVersion chart 0.8.10)
- Redis bitnami subchart (AMD64) désactivé → Redis centralisé `redis.storage.svc.cluster.local`
- Config via `websocket.url` + `websocket.redis.enabled: false` (valeurs natives du chart)
- SSO migré `authentik-header` → `authentik-oidc`

### 0.4 Nextcloud — Init PHP sur SMB ✅
- Image `nextcloud:30.0.10-fpm-alpine` (tag explicite, évite concaténation flavor)
- nginx sidecar : `docker.io/library/nginx:alpine` (FQN — cluster en short name enforcing)
- `/var/www/html` → local-path 20Gi (rapide pour init PHP)
- `/var/www/html/data` → SMB `nextcloud-data` via `nextcloudData.existingClaim`

---

## Phase 1 — Connectivité ✅ TERMINÉE

- Tunnel Cloudflare opérationnel pour tous les services
- Port-forward Authentik automatisé dans `__main__.py` via `subprocess.Popen` + `atexit`
- DNS auto-géré par external-dns

---

## Phase 2 — SSO ✅ TERMINÉE

- `sso_presets.py` : `UI_ONLY_OIDC`, `APP_OIDC_OVERRIDES`, `APP_HEADER_OVERRIDES` propres
- Authentik : 9 proxy providers + OIDC pour Immich, Nextcloud, Open-WebUI, RomM, Vaultwarden
- Dead code nettoyé (owncloud, presets morts, adapter open-webui)

**Configuration UI restante (one-time, à faire manuellement) :**

| App | Quoi configurer |
|-----|----------------|
| **Audiobookshelf** | Settings → Auth → OpenID Connect : Issuer=`https://auth.smadja.dev/application/o/audiobookshelf-oidc/`, Client ID=`audiobookshelf-oidc`, Secret=Doppler `AUDIOBOOKSHELF_OIDC_CLIENT_SECRET` |
| **Immich** | Admin → Settings → OAuth : Issuer=`https://auth.smadja.dev/application/o/immich-oidc/`, Client ID=`immich-oidc`, Secret=Doppler `IMMICH_OIDC_CLIENT_SECRET` |
| **Nextcloud** | `php occ user_oidc:provider authentik --clientid=nextcloud-oidc --clientsecret=<SECRET> --discoveryuri=https://auth.smadja.dev/application/o/nextcloud-oidc/.well-known/openid-configuration` |

---

## Fixes ARM64 appliqués (spécifiques OCI Ampere A1)

Règles établies pour éviter les régressions :

1. **Images bitnami** → toujours AMD64. Désactiver les subcharts Redis/PostgreSQL bitnami, utiliser le Redis centralisé `redis.storage.svc.cluster.local:6379`.
2. **Short name mode enforcing** → toujours utiliser des noms d'images fully-qualified (`docker.io/library/nginx:alpine`, pas `nginx:alpine`).
3. **Extensions PostgreSQL** (Immich v2+) → créer `vector`, `earthdistance`, `cube` en superuser avant le premier démarrage.

---

## Incidents PVC survenus pendant le déploiement

Plusieurs PVCs ont été accidentellement supprimées lors de purges de namespaces répétées. Résolution :
- `reclaimPolicy: Retain` sur tous les PVs SMB → données NAS préservées
- Procédure de rescue : `kubectl patch pv <name> --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'` puis recréation manuelle du PVC avec `volumeName`
- `nextcloud-data` et `immich-library` : gérés hors Pulumi (PVCs manuels qui référencent les PVs existants)
- StorageClass par défaut : `local-path` marqué `is-default-class=true` (résout les PVCs sans storageClass)

---

## Phases futures (hors scope — cluster stable)

Ces améliorations ont été spécifiées mais ne font pas partie des critères d'acceptance :

- **Phase 3** : Preflight Validator, fix structurel DB provisioning (hash password dans nom Job), rotation credentials, Deployment Summary Script, Smoke Tests
- **Phase 4** : External Storage Nextcloud (hub unifié musique/photos/documents via montages SMB)
- **Phase 5** : Protocoles typés (`TunnelRoutable`, `AuthConfigurable`) pour prévenir les régressions `hostname=None`

---

## Critères d'acceptance validés

- [x] `pulumi up --stack oci` réussit sans erreurs
- [x] 15 applications déployées (`pulumi stack output deployed_apps`)
- [x] Tous les pods Running ou Completed
- [x] Tunnel Cloudflare actif (routing via `*.smadja.dev`)
- [x] Authentik SSO opérationnel (outpost + providers)
- [x] Port-forward Authentik automatisé (plus d'étape manuelle)
