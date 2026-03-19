# SSO Implementation - Transparent Login (Authentik)

This document reviews how to achieve "Transparent SSO" for every application in the homelab, ensuring that any user authenticated via Authentik Proxy (PROTECTED mode) is automatically logged into the underlying app without seeing a second login screen.

---

## 🎯 Implementation Strategy

### 🟢 Category 1: Header-Based Apps (Legacy/Simpler)
*Behavior*: Authentik Proxy sends the user identity via HTTP headers (e.g. `X-Authentik-Username`). The app is configured to "trust" these headers and bypass its own login.

| App | Method | Status | Required Settings | The "Trick" to Bypass Login |
| :--- | :--- | :--- | :--- | :--- |
| **Navidrome** | Header | ✅ SUCCESS | `ND_REVERSEPROXYUSERHEADER=X-Authentik-Username`<br>`ND_REVERSEPROXYWHITELIST=0.0.0.0/0` | Ensure `ND_REVERSEPROXYUSERHEADER` matches the header injected by Authentik. Set whitelist to broad IP range if behind a proxy. |
| **Paperless-ngx** | Header | 🟠 UI Pending | `PAPERLESS_ENABLE_HTTP_REMOTE_USER=true`<br>`PAPERLESS_HTTP_REMOTE_USER_HEADER=HTTP_X_AUTHENTIK_USERNAME` | Use `HTTP_` prefix for Django reasons. Set `PAPERLESS_REMOTE_USER_SET_NAME=true`. |
| **Slskd** | Header | ✅ SUCCESS | `SLSKD_REMOTE_USER_HEADER=HTTP_X_AUTHENTIK_USERNAME` | Standard header injection. |

### 🔵 Category 2: OIDC-Autolink Apps (Modern)
*Behavior*: The app supports OIDC. Since it's behind the Authentik Proxy, the user is already logged into Authentik. We configure the app to automatically trigger/handshake the OIDC flow in the background.

| App | Method | Required Settings | The "Trick" to Bypass Login |
| :--- | :--- | :--- | :--- |
| **Open WebUI** | OIDC | `ENABLE_OAUTH_SIGNUP: "true"`<br>`OAUTH_MERGE_ACCOUNTS_BY_EMAIL: "true"` | Set `WEBUI_AUTH: "true"` but use a specific redirect if possible. Open WebUI usually requires one click on "Login with Authentik", but we can investigate "Force OIDC". |
| **OpenCloud** | OIDC | `PROXY_OIDC_REWRITE_WELLKNOWN: "true"`<br>`OCIS_REVA_SKIP_CHECK: "true"` | Use `PROXY_OIDC_CLIENT_ID` matching Authentik. oCIS can be configured to auto-redirect from `/` to OIDC flow. |
| **Vaultwarden** | OIDC | `SSO_ENABLED: "true"`<br>`SSO_CLIENT_ID: "..."` | Vaultwarden requires one click on "Login with SSO". To make it transparent, we'd need a custom UI but staying in OIDC is safer for bitwarden clients. |
| **Audiobookshelf**| OIDC | Standard OIDC Client | ABS supports auto-creating users from OIDC. |

---

## � TODO List

### [x] Fix SSO for all apps (2026-03-17)
- [x] Open-WebUI: switched to OIDC (was Header), secrets auto-provisioned via Doppler
- [x] OwnCloud (OCIS): fixed OIDC issuer URL → `https://auth.smadja.dev/application/o/owncloud-oidc/`
- [x] Vaultwarden: `allow_external: true` + OIDC secrets provisioned
- [x] Audiobookshelf: `allow_external: true` + OIDC secrets provisioned
- [x] Navidrome: SSO header working
- [x] Paperless-ngx: SSO header working

### [x] Fix Authentik provider API (2026-03-17)
- [x] `get_scope_mapping_output` → `get_property_mapping_provider_scope_output` (pulumi_authentik v2025.8.1)
- [x] `automountServiceAccountToken: true` pour le SA Authentik (Pulumi forçait `false`, empêchant le worker de créer les secrets des outposts)
- [x] Outpost reconciliation: doit utiliser `ProxyKubernetesController.up_with_logs()` (pas le générique)

---

## Audit Review - 2026-03-16

Findings identifiés lors d'un audit global du codebase.

### Securite

- Secrets hardcodés détectés dans le code (au-delà du LDAP bind password déjà connu). Spec créée : `specs/wip/hardcoded-secrets-cleanup.md`.
- Images Docker non pinnées (tag `:latest`) sur plusieurs apps.
- Security contexts incomplets : `runAsNonRoot` absent sur plusieurs déploiements.
- `node_maintenance.py` utilise `privileged: true` — à redesigner.
- Redis accessible sans authentification (`auth: false`).

### Infrastructure

- Aucune health probe (liveness/readiness) sur les apps critical tier (authentik, vaultwarden).
- Resource limits absentes sur la majorité des apps (seul vaultwarden en a).
- Database backup manquant pour vaultwarden et paperless-ngx (seul authentik a `database_backup`).

### Developer Experience

- Dead code identifié : `mail_dns.py`, `setup_identities`, et d'autres modules non utilisés.
- Adapter pattern over-engineered : 5 sous-classes pour des différences mineures.
- Gaps dans les tests : health probes, resource limits, et backup DB ne sont pas couverts.

### Actions prioritaires

1. 🔴 Nettoyer les secrets hardcodés (spec: `hardcoded-secrets-cleanup.md`)
2. 🟡 Ajouter health probes aux apps critical tier (spec: `health-probes.md`)
3. 🟡 Ajouter resource limits à toutes les apps (spec: `resource-limits.md`)
4. 🟡 Activer l'authentification Redis
5. 🟡 Supprimer le dead code identifié

---

## Refactoring Recommendations - 2026-03-17

### P0 — Automatisation Makefile (éliminer les étapes manuelles)

Actuellement, `make up-apps` ne fait que lancer `pulumi up`. Trois interventions manuelles sont nécessaires à chaque déploiement, ce qui rend le setup trop complexe pour être opéré par un LLM.

| Étape manuelle | Cause | Solution |
|---|---|---|
| `kubectl port-forward svc/authentik-server 9000:80 -n authentik` | `shared/utils/authentik.py:16` hardcode `localhost:9000` | Script wrapper `scripts/ensure_portforward.sh` |
| Outpost reconciliation via worker pod | Le worker ne réconcilie pas automatiquement après recréation | Script `scripts/authentik_post_deploy.sh` qui exec dans le worker |
| JSON patch du Service selector (bug Authentik 2026.2.1) | Selector inclut `app.kubernetes.io/component: server` absent des pods | Même script post-deploy, avec vérification idempotente |

**Cible Makefile :**
```makefile
up-apps: _ensure-portforward _deploy-apps _post-deploy-authentik

_ensure-portforward:
    @scripts/ensure_portforward.sh authentik authentik-server 9000 80

_deploy-apps:
    python3 scripts/stack_manager.py up --stack apps --cluster $(CLUSTER)

_post-deploy-authentik:
    @scripts/authentik_post_deploy.sh
```

**Alternative ambitieuse** : Supprimer le besoin de port-forward en changeant `shared/utils/authentik.py` pour utiliser l'URL interne du cluster (`http://authentik-server.authentik.svc.cluster.local`) si la machine locale a un tunnel vers le cluster.

### P1 — Authentik : Flow UUIDs hardcodés

**Fichier** : `shared/apps/common/authentik_registry.py:40-41`

```python
# Actuel (fragile — change si Authentik est réinstallé)
self.flow_authorization = "306d2f7d-4b4c-4bbe-81bb-dccebe9b3264"
self.flow_invalidation = "ad1278c4-fb2b-4a91-b063-a24aab34f7bb"

# Recommandé (lookup dynamique par slug)
self.flow_authorization = authentik.get_flow_output(
    slug="default-provider-authorization-implicit-consent"
).id
self.flow_invalidation = authentik.get_flow_output(
    slug="default-invalidation-flow"
).id
```

**Effort** : ~15min

### P1 — Authentik : Remplacer subprocess Doppler par Pulumi natif

**Fichier** : `shared/apps/common/authentik_registry.py:59-75`

Le `subprocess.check_output(["doppler", "secrets", "get", "AUTH0_USERS"])` est un hack pour contourner `pulumi.Output`. Remplacer par `doppler.get_secrets_output()` avec `.apply()` pour :
- Éliminer la dépendance sur le CLI Doppler installé localement
- Rester dans le paradigme Pulumi (fonctionne en CI/CD futur)

**Effort** : ~30min

### P2 — Authentik : Group-based access policies

Actuellement, toutes les apps sont accessibles à tous les utilisateurs authentifiés. Authentik permet de restreindre par groupe via `PolicyBinding`.

**Proposition** : Ajouter un champ optionnel `allowed_groups` dans `apps.yaml` :
```yaml
- name: vaultwarden
  allowed_groups: ["admins"]
```

Puis dans `authentik_registry.py`, créer un `PolicyBindingGroup` + `PolicyBinding` liant le groupe à l'`Application`. (~15 lignes de code)

**Effort** : ~1h

### P2 — Authentik : Supprimer le hack Vaultwarden dans le DNS helper

**Fichier** : `shared/apps/common/authentik_registry.py:448-449`

```python
# Hack actuel
if "vault." in str(host):
    target_svc = "vaultwarden"
    target_port = 8080
```

Remplacer par un champ optionnel `ingress_backend` dans le schéma `AppModel` pour les apps public qui ont besoin d'un routage DNS spécial.

**Effort** : ~30min

### P3 — Standardiser OIDC naming conventions

Les `client_secret_key` dans Doppler varient entre apps (`VAULTWARDEN_SSO_CLIENT_SECRET` vs `OPEN_WEBUI_OIDC_CLIENT_SECRET`). Le code a déjà un fallback correct (`{APP_NAME}_OIDC_CLIENT_SECRET` ligne 308), mais certaines apps override avec des noms incohérents.

Harmoniser les noms dans `apps.yaml` pour utiliser la convention `{APP_NAME}_OIDC_CLIENT_SECRET` partout.

**Effort** : ~20min

### P3 — Authentik : MFA stages

Aucun stage MFA (TOTP, WebAuthn) n'est provisionné via Pulumi. Le flow d'auth utilise `default-provider-authorization-implicit-consent` (pas de MFA).

Ajouter un `AuthenticatorTOTPStage` ou `AuthenticatorWebAuthnStage` au flow d'authentification. Authentik supporte le MFA conditionnel (par groupe, par app). Faible priorité pour un homelab.

**Effort** : ~2h

### Fonctionnalités Authentik non utilisées (pour info)

| Fonctionnalité | Status | Recommandation |
|---|---|---|
| **Blueprints** (config-as-code YAML) | Non utilisé | Ne pas migrer — Pulumi est plus puissant et déjà en place |
| **Groups & Policies** | Sous-utilisé | Voir P2 ci-dessus |
| **MFA stages** | Non configuré | Voir P3 ci-dessus |
| **Token rotation** | Non implémenté | Faible priorité pour un homelab |
| **Enrollment flows** (self-service signup) | Non utilisé | Inutile — provisioning centralisé via Doppler suffit |

### Dead code identifié (à supprimer)

| Module | Fonction/Classe | LOC |
|---|---|---|
| `shared/utils/cluster.py` | `is_local_cluster()`, `create_provider_from_kubeconfig()`, `is_audit_mode()` | ~40 |
| `shared/utils/versions.py` | `HelmRepos`, `StorageClasses` | ~45 |
| `shared/apps/impl/authentik.py` | `create_app()` + wrappers redondants | ~20 |
| `shared/apps/impl/external_secrets.py` | `create_app()` | ~5 |
| `shared/apps/impl/cloudflared.py` | `create_app()` | ~5 |

### apps.yaml — Opportunités DRY

| Pattern dupliqué | Occurrences | Solution |
|---|---|---|
| `replicas: 1` | Toutes les apps | Défaut implicite dans le schéma |
| `hostname: {name}.smadja.dev` | ~90% des apps | Convention dérivable de `name` + `domain` |
| `namespace: homelab` | ~80% des apps | Défaut implicite |
| Probe definitions identiques | 3 apps | Template de probes par type d'app |
| `dependencies: [external-secrets, cloudflared]` | 6 apps | Injection automatique basée sur `secrets` et `mode` |

### Adapter pattern — Simplification

5 sous-classes (`VaultwardenAdapter`, `PaperlessAdapter`, `AppTemplateAdapter`, `OpenWebUIAdapter`, `AuthentikAdapter`) pour des différences mineures. La majorité ne fait que réarranger des clés YAML.

**Recommandation** : Remplacer par un système de `value_transforms` déclaratif dans `apps.yaml` (mapping de clés), ne garder qu'un adapter générique + Authentik (seul cas réellement spécial).
