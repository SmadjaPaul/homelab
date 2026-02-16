# ArgoCD vs Flux CD - Guide Complet

## TL;DR

Dans ce projet, on utilise **Flux CD** (pas ArgoCD) pour déployer les applications Kubernetes. Terraform déploie l'infrastructure (VMs), Flux CD déploie les apps.

```
┌─────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE                           │
├─────────────────────────────────────────────────────────────┤
│ Terraform                                                   │
│ ├── Cloudflare (DNS, Tunnel)                                │
│ └── OCI (VMs, Réseau)                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ (VMs créées)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    KUBERNETES                               │
├─────────────────────────────────────────────────────────────┤
│ Talos Linux (OS)                                            │
│ ├── Omni (gestion)                                          │
│ └── Kubernetes                                              │
│     └── Flux CD (installé manuellement)                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ (GitOps)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    APPLICATIONS                             │
├─────────────────────────────────────────────────────────────┤
│ Flux CD déploie depuis Git:                                 │
│ ├── Authentik                                               │
│ ├── Nextcloud                                               │
│ ├── Cloudflared (dans K8s)                                  │
│ └── ...                                                     │
└─────────────────────────────────────────────────────────────┘
```

## Pourquoi Flux CD et pas ArgoCD ?

### Historique (qjoly/GitOps)

Le projet de référence **qjoly/GitOps** utilise initialement **ArgoCD** comme GitOps operator. Cependant, dans notre architecture actuelle, on utilise **Flux CD** pour plusieurs raisons :

| Aspect | ArgoCD | Flux CD |
|--------|--------|---------|
| **Architecture** | Application avec UI web | Opérateur natif Kubernetes |
| **Interface** | UI web riche | CLI + kubectl |
| **Bootstrapping** | Nécessite installation manuelle | Peut bootstrapper lui-même |
| **Secrets** | Vault, Sealed Secrets | SOPS, External Secrets Operator |
| **Helm** | Bon support | Excellent support |
| **Multi-cluster** | Oui | Oui (plus simple) |

### Notre Choix: Flux CD

**Pourquoi Flux CD dans ce projet :**

1. **Bootstrapping plus simple** : `flux install` et c'est parti
2. **Intégration native** avec External Secrets Operator (Doppler)
3. **Pas de UI** : Moins d'attaque surface, tout se fait via Git
4. **Documentation qjoly** : Montre aussi bien ArgoCD que Flux

## Architecture Détaillée

### Phase 1: Infrastructure (Terraform)

**Qui déploie ?** GitHub Actions (workflow terraform.yaml ou deploy-all.yaml)

**Quoi ?**
```bash
# Cloudflare
dns/
tunnel/
access/       # Authentik OIDC
security/     # WAF, Geo-blocking

# OCI
oci-hub/      # VM avec Omni
3 VMs Talos/  # Kubernetes cluster
```

**Résultat :**
- VMs créées
- DNS configuré
- Tunnel Cloudflare prêt (token généré)
- Mais **pas encore d'applications**

### Phase 2: Bootstrap Kubernetes (Manuel)

**Qui déploie ?** Toi (manuellement via script)

**Pourquoi manuel ?**
- Omni nécessite configuration interactive (créer cluster, générer image)
- Besoin de récupérer kubeconfig
- Secret Doppler à créer

**Étapes :**
```bash
./scripts/bootstrap-phase2.sh
```

**Résultat :**
- Cluster Kubernetes opérationnel
- Flux CD installé
- External Secrets Operator prêt

### Phase 3: Applications (Flux CD)

**Qui déploie ?** Flux CD (automatiquement depuis Git)

**Comment ça marche ?**

```
Git Repository
    │
    │ (Flux surveille)
    ▼
Flux CD (dans K8s)
    │
    ├─ Source: GitRepository
    ├─ Kustomization: apply manifests
    └─ HelmRelease: install charts
    │
    ▼
Kubernetes Cluster
    ├─ Authentik (Helm)
    ├─ Nextcloud (Helm)
    └─ etc.
```

**Configuration :**

Dans `kubernetes/clusters/oci-hub/kustomization.yaml` :
```yaml
resources:
  # Infrastructure
  - ../../apps/infrastructure/external-secrets
  - ../../apps/infrastructure/cloudflare  # Cloudflared + External DNS
  - ../../apps/infrastructure/cert-manager

  # Applications
  - ../../apps/business/authentik
  - ../../apps/productivity/nextcloud
```

**Workflow :**

1. Tu pousses sur Git
2. Flux détecte le changement (polling ou webhook)
3. Flux applie les manifests
4. External Secrets récupère les secrets depuis Doppler
5. Applications déployées !

## Comparaison Pratique

### Scénario: Déployer une nouvelle app (ex: Wiki)

**Avec ArgoCD (qjoly style) :**
```bash
# 1. Créer Application ArgoCD
kubectl apply -f wiki-application.yaml

# 2. Voir dans UI ArgoCD
# https://argocd.smadja.dev
# Cliquer "Sync"

# 3. Vérifier déploiement
```

**Avec Flux CD (notre projet) :**
```bash
# 1. Créer dossier kubernetes/apps/productivity/wiki/
#    - helmrelease.yaml
#    - ingress.yaml
#    - external-secret.yaml
#    - kustomization.yaml

# 2. Ajouter à kubernetes/clusters/oci-hub/kustomization.yaml
#    - ../../apps/productivity/wiki

# 3. Git commit & push
git add .
git commit -m "Add wiki"
git push

# 4. Flux déploie automatiquement (30-60s)
flux get kustomizations

# 5. Vérifier
kubectl get pods -n productivity
```

### Scénario: Modifier une configuration

**ArgoCD :**
- Modifier dans Git
- ArgoCD détecte drift
- Cliquer "Sync" dans UI (ou auto-sync)

**Flux CD :**
- Modifier dans Git
- Flux détecte et applie automatiquement
- Pas d'UI, tout est dans Git

## Composants Flux CD

### 1. Source Controller

Gère les sources (Git, Helm, S3) :
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: homelab
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/ton-user/homelab
  ref:
    branch: main
```

### 2. Kustomize Controller

Applie les manifests Kustomize :
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: oci-hub
  namespace: flux-system
spec:
  interval: 10m
  path: ./kubernetes/clusters/oci-hub
  prune: true
  sourceRef:
    kind: GitRepository
    name: homelab
```

### 3. Helm Controller

Installe les charts Helm :
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta2
kind: HelmRelease
metadata:
  name: authentik
  namespace: authentik
spec:
  interval: 1h
  chart:
    spec:
      chart: authentik
      sourceRef:
        kind: HelmRepository
        name: authentik
  values:
    # ...
```

## FAQ

### Q: Pourquoi pas les deux ?

**R:** Techniquement possible mais pas recommandé :
- Complexité inutile
- Deux sources de vérité
- Conflits potentiels

### Q: Comment faire du monitoring avec Flux ?

**R:** Flux a des métriques Prometheus, Grafana dashboards disponibles. Plus besoin d'UI web.

```bash
# Voir le status
flux get kustomizations
flux get helmreleases

# Voir les événements
flux events

# Debugging
flux logs
kubectl logs -n flux-system deployment/kustomize-controller
```

### Q: Et si je veux quand même une UI ?

**R:** Options :
1. **Weave GitOps** : UI pour Flux CD
2. **Kubernetes Dashboard** : Dashboard générique K8s
3. **Lens** : IDE pour Kubernetes (desktop app)

### Q: Comment migrer d'ArgoCD à Flux CD ?

**R:** Processus :
1. Installer Flux CD côte à côte
2. Migrer les applications une par une
3. Désinstaller ArgoCD

Exemple dans `docs/MIGRATION.md` (si besoin).

## Résumé des Outils par Phase

| Phase | Outil | Déclencheur | Où |
|-------|-------|-------------|-----|
| **Infrastructure** | Terraform | GitHub Actions (manuel) | OCI, Cloudflare |
| **Bootstrap K8s** | Scripts shell | Manuel | VM Hub |
| **Applications** | Flux CD | Automatique (Git) | Cluster K8s |
| **Secrets** | External Secrets + Doppler | Automatique | Cluster K8s |

## Commandes Essentielles

```bash
# Voir status Flux
flux get all

# Forcer un sync
flux reconcile kustomization oci-hub

# Voir logs
flux logs

# Voir événements
flux events

# Port-forward pour accès local
kubectl port-forward -n authentik svc/authentik-server 9000:80

# Accès via Tailscale (admin)
# Omni: http://10.0.1.2:50001
# kubectl: via kubeconfig
```

## Conclusion

- **Terraform** = Infrastructure (VMs, DNS, réseau)
- **Flux CD** = Applications Kubernetes (GitOps)
- **Pas besoin d'ArgoCD** pour ce projet
- **Tout passe par Git** (sauf bootstrap initial)

Le workflow CI/CD complet :
1. **GitHub Actions** déploie Terraform (Cloudflare + OCI)
2. **Toi** bootstrappes Kubernetes (Omni + Flux)
3. **Flux CD** déploie automatiquement les apps depuis Git
