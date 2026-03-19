# Spec: SSO Presets System

## Contexte

Configurer le SSO pour une nouvelle app nécessite aujourd'hui ~30 lignes de YAML dans `apps.yaml` (provisioning config, extra_env OIDC, redirect URIs, client_id, etc.) plus la connaissance des particularités de chaque app (format des env vars, URL du provider OIDC, callback path). Le code dans `authentik_registry.py` gère déjà la création du provider OIDC et l'injection du client_secret dans Doppler, mais le câblage côté app (env vars, Helm values) est entièrement manuel.

Les configs SSO sont documentées dans `docs/TODO.md` mais pas codifiées — il faut les redécouvrir à chaque fois.

## Objectif

Pouvoir ajouter une app avec SSO complet (OIDC ou Header) en une seule ligne : `sso: oidc` ou `sso: header` dans `apps.yaml`.

## Scope

### In scope
- [ ] Créer `shared/apps/sso_presets.py` : dictionnaire de configs SSO connues par app (env vars, redirect URIs, callback paths, scopes)
- [ ] Ajouter un champ `sso: oidc|header|none` dans `AppModel` (optionnel, dérive `provisioning` + `extra_env`)
- [ ] Presets pour les apps existantes : Open-WebUI, OwnCloud, Vaultwarden, Audiobookshelf, Navidrome, Paperless-ngx, Slskd
- [ ] Auto-injection des env vars OIDC standard (issuer URL, client_id, scopes) dérivées du domaine et du nom de l'app
- [ ] Fallback : si `provisioning` est défini explicitement, il prime sur le preset
- [ ] Supporter les deux modes : `header` (X-Authentik-Username) et `oidc` (full OIDC flow)

### Out of scope
- SCIM provisioning (Authentik → App push)
- LDAP binding pour les apps (le LDAP Outpost existe mais le câblage côté app est trop varié)
- Apps non encore déployées
- Changement du flow Authentik lui-même

## Contraintes
- Secrets via Doppler uniquement (jamais en dur)
- Définir les apps dans apps.yaml, pas en Python
- Tout passe par Pulumi (pas de kubectl apply direct)
- Le preset ne doit PAS écraser des valeurs Helm définies explicitement par l'utilisateur
- L'URL de l'issuer OIDC doit être dérivée dynamiquement : `https://auth.{domain}/application/o/{app-name}-oidc/`

## Critères d'acceptance
- [ ] `uv run pulumi preview --stack oci` passe sans erreur
- [ ] `uv run pytest tests/static/ -v` passe
- [ ] Remplacer la config SSO complète d'Open-WebUI par `sso: oidc` → le preview génère les mêmes resources
- [ ] Ajouter une nouvelle app OIDC-compatible = `name` + `helm` + `sso: oidc` (5 lignes max)
- [ ] Le preset injecte automatiquement : `OAUTH_CLIENT_ID`, `OPENID_PROVIDER_URL`, `OAUTH_CLIENT_SECRET` (via secret ref)
- [ ] Les apps `sso: header` injectent automatiquement les bonnes env vars (`ND_REVERSEPROXYUSERHEADER`, etc.)
- [ ] Un test unitaire valide que chaque preset connu produit les bonnes env vars

## Fichiers concernés
- `kubernetes-pulumi/shared/apps/sso_presets.py` — nouveau fichier : registre des presets SSO
- `kubernetes-pulumi/shared/utils/schemas.py` — ajouter `sso: Optional[SSOMode]` à `AppModel`
- `kubernetes-pulumi/shared/apps/adapters/__init__.py` — appeler le preset dans `apply_provisioning_config()`
- `kubernetes-pulumi/apps.yaml` — simplifier les configs SSO existantes
- `kubernetes-pulumi/tests/static/test_sso_presets.py` — nouveau : tests unitaires des presets

## Notes / Références
- Configs SSO documentées dans `docs/TODO.md` section "Implementation Strategy"
- Redirect URIs connues déjà dans `authentik_registry.py:116-130` (`_get_redirect_uris`)
- Le `client_secret` est déjà auto-poussé dans Doppler par `authentik_registry.py:326-340`
