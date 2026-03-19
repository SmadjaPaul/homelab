# Spec: Network Policies & Controle d'Acces

## Contexte

Le homelab vise 20 utilisateurs. Toutes les apps sont partagees — c'est voulu, surtout pour les apps media (navidrome, audiobookshelf, slskd) ou partager la bibliotheque evite de dupliquer les fichiers.

L'isolation necessaire n'est pas au niveau des donnees mais au niveau **reseau** (limiter les communications inter-namespaces) et **acces** (controler qui peut acceder a quelle app via Authentik).

## Objectif

Chaque namespace a des NetworkPolicies adaptees, et l'acces aux apps est controle par groupes Authentik declares dans `apps.yaml`.

## Scope

### In scope
- [ ] NetworkPolicies templates (3 profils : `open`, `standard`, `strict`)
- [ ] Nouveau champ `network_policy: open|standard|strict` dans `apps.yaml`
- [ ] Nouveau champ `allowed_groups: [admins, users, friends]` dans `apps.yaml`
- [ ] Generation automatique des NetworkPolicies par namespace
- [ ] Integration `allowed_groups` dans `authentik_registry.py` (policy bindings)

### Out of scope
- Deploy per-user (`multi_tenant: isolated`) — pas pertinent, les apps media sont partagees volontairement
- ResourceQuotas per-user
- Envoy sidecar injection
- Operateur Kubernetes custom

## Design

### NetworkPolicy profiles

```yaml
# Dans apps.yaml, par app
- name: navidrome
  network_policy: standard    # defaut si absent

- name: vaultwarden
  network_policy: strict
```

| Profil | Ingress | Egress |
|---|---|---|
| `open` | Tout autorise | Tout autorise |
| `standard` | Depuis ingress-nginx/cloudflared + meme namespace | DNS + services internes + internet |
| `strict` | Depuis ingress-nginx/cloudflared uniquement | DNS + namespaces declares dans `dependencies` uniquement |

Default : `standard` (retro-compatible, securise sans casser).

### Controle d'acces par groupe

```yaml
# Dans apps.yaml
- name: navidrome
  allowed_groups: [users, friends]    # tous les groupes -> tout le monde

- name: paperless-ngx
  allowed_groups: [admins]            # restreint aux admins

- name: open-webui
  allowed_groups: [admins, users]     # pas les friends
```

Les groupes referencent `identities.groups` dans `apps.yaml`. Si `allowed_groups` est absent, l'app est accessible a tous les users authentifies (comportement actuel).

Dans `authentik_registry.py`, pour chaque app avec `allowed_groups`, on cree un `PolicyBinding` Authentik qui lie l'Application au groupe. Les users hors groupe voient une page 403.

### Implementation

**NetworkPolicies** (~50 LOC) :

1. `shared/apps/common/kubernetes_registry.py` : nouvelle methode `_create_network_policy(app, profile)`
2. Genere un `NetworkPolicy` K8s par app en fonction du profil
3. Appelee dans le flow existant de `register_app()`

**Allowed Groups** (~30 LOC) :

1. `shared/apps/common/authentik_registry.py` : dans la boucle de `configure_authentik_layer()`
2. Si `app.allowed_groups` est defini, creer un `PolicyBindingGroup` par groupe
3. Lier au `Application` Authentik de l'app

## Contraintes
- Secrets via Doppler uniquement
- Tout passe par Pulumi
- apps.yaml = source de verite
- Retro-compatible : sans `network_policy` ni `allowed_groups`, comportement actuel preserve

## Criteres d'acceptance
- [ ] `network_policy: strict` genere une NetworkPolicy deny-all + whitelist
- [ ] `network_policy: standard` autorise ingress depuis cloudflared + meme namespace
- [ ] `allowed_groups: [admins]` cree un PolicyBinding Authentik
- [ ] Apps sans `allowed_groups` restent accessibles a tous
- [ ] `uv run pulumi preview --stack oci` passe sans erreur
- [ ] `uv run pytest tests/static/ -v` passe
- [ ] Test statique : chaque `allowed_groups` reference un groupe existant dans `identities.groups`
- [ ] Test dynamique : `curl` depuis un namespace `strict` vers un non-autorise est bloque

## Fichiers concernes
- `kubernetes-pulumi/apps.yaml` — nouveaux champs `network_policy`, `allowed_groups`
- `kubernetes-pulumi/shared/utils/schemas.py` — nouveaux champs dans `AppModel`
- `kubernetes-pulumi/shared/apps/common/kubernetes_registry.py` — generation NetworkPolicies
- `kubernetes-pulumi/shared/apps/common/authentik_registry.py` — PolicyBindings par groupe
- `kubernetes-pulumi/tests/static/test_network_policies.py` — tests
- `kubernetes-pulumi/tests/static/test_allowed_groups.py` — tests

## Notes / References
- Inspire des 14 templates NetworkPolicy d'Olares (`framework/app-service/pkg/security/templates.go`)
- Notre approche est plus simple : 3 profils couvrent 100% des cas
- ~0 overhead : les NetworkPolicies sont des objets K8s legers, pas de pods supplementaires
