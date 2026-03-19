# Spec: Fixes Post-Déploiement — Erreurs Résiduelles

> **Date** : 2026-03-24
> **Contexte** : Cluster OCI opérationnel après migration, mais 6 services présentent des erreurs.

---

## État au 2026-03-24

| Service | Erreur | Priorité |
|---------|--------|----------|
| Homepage | ✅ Fonctionnel | — |
| Navidrome | ✅ Fonctionnel | — |
| Slskd | ✅ Fonctionnel | — |
| Open-WebUI | ❌ 500 Internal Error | P1 |
| Nextcloud | ❌ 524 Timeout | P1 |
| RomM | ✅ Fonctionnel | — |
| Vaultwarden | ✅ Fonctionnel | — |
| Paperless-ngx | ✅ Fonctionnel | — |
| Audiobookshelf | ✅ Fonctionnel | — |
| Immich | ✅ Fonctionnel | — |

---

## Groupe A — Deployments disparus (Homepage, Navidrome, Slskd)

### Symptôme
Erreur **502 Bad Gateway** via Cloudflare. L'outpost Authentik tente de proxifier vers des services qui existent (`ClusterIP` présent) mais dont le pod backend est absent.

### Diagnostic
```bash
kubectl get pods -n homelab   # → No resources found
kubectl get pods -n music     # → seulement audiobookshelf, navidrome et slskd absents
helm list -n homelab          # → homepage deployed (revision 3)
helm list -n music            # → navidrome deployed (revision 5), slskd deployed (revision 3)
helm get manifest navidrome -n music | grep kind:  # → Deployment + Service présents dans manifest
```

**Root cause** : Helm considère les releases comme `deployed` et les Deployments sont dans le manifest, mais les ressources K8s n'existent pas. Les Deployments ont probablement été supprimés lors de purges de namespaces effectuées pendant les sessions de debug (sans supprimer les releases Helm).

### Fix
```bash
export PULUMI_CONFIG_PASSPHRASE=""
export PULUMI_BACKEND_URL="file:///Users/paul/Developer/Perso/homelab/kubernetes-pulumi/.pulumi"
cd kubernetes-pulumi/k8s-apps

# Port-forward Authentik (auto-géré par pulumi up si absent)
kubectl port-forward -n authentik svc/authentik-server 9000:80 &

# Refresh état + redéploiement
uv run pulumi refresh --stack oci --yes
uv run pulumi up --stack oci --yes
```

Pulumi détectera les Deployments manquants et les recréera.

**Vérification** :
```bash
kubectl get pods -n homelab    # → homepage pod Running
kubectl get pods -n music      # → navidrome + slskd pods Running
curl -sI https://home.smadja.dev     # → 200/302
curl -sI https://music.smadja.dev   # → 200/302
curl -sI https://soulseek.smadja.dev # → 200/302
```

---

## Groupe B — Open-WebUI (500 Internal Error)

### Symptôme
Erreur **500** lors de la navigation sur `ai.smadja.dev`. Le pod est Running, les logs montrent des requêtes HTTP 200 sur `/_app/version.json` → l'app démarre mais certaines routes échouent.

### Diagnostic probable
Le pod `open-webui-0` est en `Running` depuis ~1h (redémarré pendant le debug Redis). Une erreur 500 à ce stade peut indiquer :
- **Base de données non migrée** : La DB a été recréée proprement, mais les migrations n'ont peut-être pas toutes tourné.
- **Secret OIDC manquant** : Le `clientSecret` Authentik pour open-webui-oidc n'est peut-être pas encore dans Doppler/K8s.
- **Erreur de session** : WEBUI_SECRET_KEY générique (`change-me-later-please`) — non bloquant mais à changer.

### Fix
```bash
# Vérifier les logs pour identifier la route qui fail
kubectl logs open-webui-0 -n ai --tail=50 2>&1 | grep -i "error\|500\|exception"

# Si erreur DB :
kubectl exec homelab-db-1 -n cnpg-system -- psql -U postgres -d open-webui -c "\dt" | wc -l
# Devrait retourner ~50+ tables si migrations OK

# Si OK, tenter un restart propre :
kubectl rollout restart statefulset/open-webui -n ai
```

**Vérification** : `https://ai.smadja.dev` → page de login Authentik → accès OK.

---

## Groupe C — Nextcloud (524 Timeout)

### Symptôme
Erreur **524** (timeout Cloudflare — le serveur a répondu mais trop lentement). Se produit au premier accès.

### Diagnostic probable
Nextcloud vient d'être redéployé avec `nextcloud:30.0.10-fpm-alpine` + nginx sidecar sur un nouveau PVC `local-path` (20Gi). Au premier démarrage, Nextcloud copie ~15 000 fichiers PHP sur le PVC local → **peut prendre 5-15 min**. Passé ce délai, l'app répond normalement.

Autre cause possible : `startupProbe.failureThreshold: 600` (100 min max) — si le pod est encore en startup, Cloudflare timeout à 100s avant que le pod soit Ready.

### Fix
```bash
# Vérifier l'état du pod
kubectl get pods -n productivity
kubectl logs -f $(kubectl get pod -n productivity -l app.kubernetes.io/name=nextcloud -o name) -c nextcloud 2>&1 | tail -20

# Si "Initializing nextcloud..." → attendre (peut prendre 10-15 min)
# Si pod Ready → l'erreur 524 est liée au temps de réponse PHP-FPM
```

Si le timeout persiste une fois le pod Ready, augmenter le timeout Cloudflare dans le tunnel config (ou vérifier que le nginx sidecar forward bien vers FPM).

**Vérification** : `https://cloud.smadja.dev` → page login Nextcloud.

---

## Groupe D — RomM (login impossible)

### Symptôme
Impossible de se connecter ou de reset le mot de passe sur `romm.smadja.dev`.

### Diagnostic probable
Deux causes possibles :
1. **Admin password non initialisé** : La DB a été recréée par l'autre LLM (fix migration `romfilecategory`). Le compte admin initial peut avoir un mot de passe inconnu.
2. **OIDC non configuré** : Le secret `ROMM_OIDC_CLIENT_SECRET` dans Doppler est peut-être absent ou vide, bloquant le login SSO.

### Fix
```bash
# Option 1 : Reset du mot de passe admin via CLI RomM
kubectl exec -it $(kubectl get pod -n gaming -l app.kubernetes.io/name=romm -o name) -- \
  python3 manage.py reset_admin_password

# Option 2 : Vérifier le secret OIDC
kubectl get secret romm-secrets -n gaming -o jsonpath='{.data.ROMM_OIDC_CLIENT_SECRET}' | base64 -d

# Option 3 : Accéder directement à la DB pour reset
kubectl exec homelab-db-1 -n cnpg-system -- psql -U postgres -d romm \
  -c "UPDATE users SET password=crypt('newpassword', gen_salt('bf')) WHERE username='admin';"
```

Vérifier également que `OIDC_ENABLED=true` est bien injecté dans les env vars du pod :
```bash
kubectl exec $(kubectl get pod -n gaming -l app.kubernetes.io/name=romm -o name) -- env | grep OIDC
```

---

## Groupe E — Vaultwarden (login impossible + pas de SSO)

### Symptôme
Impossible de se connecter à `vault.smadja.dev`. Pas de SSO fonctionnel.

### Contexte
Vaultwarden est en mode `public` (accès direct, sans outpost Authentik). Le SSO pour Vaultwarden utilise OIDC côté app (pas de proxy Authentik). La configuration OIDC doit être faite dans le **panneau admin Vaultwarden**.

### Diagnostic probable
- Le pod est Running.
- Le mot de passe admin Vaultwarden est dans Doppler (`VAULTWARDEN_ADMIN_TOKEN`).
- Le client OIDC (`vaultwarden-oidc`) est provisionné dans Authentik.
- **Mais** : la configuration SSO dans Vaultwarden n'a pas été faite (UI-only).

### Fix

**1. Accéder au panel admin** : `https://vault.smadja.dev/admin`
- Token admin = valeur de `VAULTWARDEN_ADMIN_TOKEN` dans Doppler

**2. Configurer SSO dans l'admin** :
```
General Settings → SSO enabled: ON
OpenID Connect configuration:
  Authority: https://auth.smadja.dev/application/o/vaultwarden-oidc/
  Client ID: vaultwarden-oidc
  Client Secret: <valeur de VAULTWARDEN_OIDC_CLIENT_SECRET dans Doppler>
```

**3. Vérifier les env vars déjà injectées** (le preset injecte déjà `SSO_ENABLED`, `SSO_AUTHORITY`, `SSO_SCOPES`) :
```bash
kubectl exec $(kubectl get pod -n vaultwarden -l app.kubernetes.io/name=vaultwarden -o name) -- env | grep SSO
```

Si `SSO_ENABLED=true` et `SSO_AUTHORITY` sont présents → la config est injectée, il manque juste `SSO_CLIENT_SECRET` (qui ne peut pas être injecté automatiquement car c'est généré par Authentik).

---

## Ordre d'exécution recommandé

1. **`pulumi up`** → recrée Homepage, Navidrome, Slskd (Groupe A) — débloque immédiatement 3 services
2. **Attendre** que Nextcloud finisse son init PHP (Groupe C) — passif, 10-15 min
3. **Vaultwarden admin panel** (Groupe E) — 5 min, débloque vault + SSO
4. **RomM reset password** (Groupe D) — 5 min
5. **Open-WebUI logs** → diagnostiquer la 500 (Groupe B)

---

## Critères de validation

- [ ] `https://home.smadja.dev` → 200
- [ ] `https://music.smadja.dev` → 200
- [ ] `https://soulseek.smadja.dev` → 200
- [ ] `https://ai.smadja.dev` → login Authentik → dashboard
- [ ] `https://cloud.smadja.dev` → page Nextcloud
- [ ] `https://romm.smadja.dev` → login OK
- [ ] `https://vault.smadja.dev` → login SSO OK
