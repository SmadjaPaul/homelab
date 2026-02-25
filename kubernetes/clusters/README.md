# Kubernetes Clusters

Ce repertoire contient la configuration Flux pour les differents clusters.

## Structure

```
clusters/
├── local/                 # Cluster Talos (Proxmox) - ETEINT
│   ├── bootstrap.yaml    # A appliquer manuellement pour bootstrap Flux
│   └── clusters/local/   # Configuration Flux reconciliee
│       ├── flux-system/
│       │   └── kustomization.yaml
│       ├── sources.yaml  # HelmRepositories
│       └── apps.yaml    # Applications
│
└── oci/                  # Cluster OCI (Oracle Cloud) - ACTIF
    ├── bootstrap.yaml
    └── clusters/oci/
        ├── flux-system/
        │   └── kustomization.yaml
        ├── sources.yaml
        └── apps.yaml
```

## Cluster OCI (Actif)

Le cluster OCI est actuellement le seul cluster actif.

### Configuration

- **Path:** `clusters/oci/`
- **Bootstrap:** `clusters/oci/bootstrap.yaml`
- **Apps:** `clusters/oci/clusters/oci/apps.yaml`

## Cluster Local (Eteint)

Le cluster local (Talos sur Proxmox) est actuellement eteint.

### Configuration

- **Path:** `clusters/local/`
- **Bootstrap:** `clusters/local/bootstrap.yaml`

Pour le reactiver:
1. Allumer les VMs Talos
2. Executer le bootstrap Flux
3. Ajouter les applications souhaitees

## Bootstrap d'un nouveau cluster

### 1. Installer Flux CLI

```bash
brew install fluxcd/tap/flux
```

### 2. Verifier le cluster

```bash
flux check --pre
```

### 3. Bootstrap Flux

```bash
flux bootstrap github \
  --owner=SmadjaPaul \
  --repository=homelab \
  --path=clusters/oci \
  --token-auth \
  --components=source-controller,kustomize-controller,helm-controller,notification-controller
```

### 4. Appliquer le bootstrap

```bash
kubectl apply -f clusters/oci/bootstrap.yaml
```

## Ajouter une nouvelle application

1. Creer l'app dans `kubernetes/apps/<categorie>/<app>/`
2. Ajouter la reference dans `clusters/oci/clusters/oci/apps.yaml`

## Best Practices

- Toujours utiliser `prune: true` pour le menage
- Toujours utiliser `wait: true` pour attendre le deploiement
- Definir des `dependsOn` si necessaire
- Utiliser des versions fixes pour la production
- Activer `driftDetection` pour detecter les modifications manuelles
- Intervalle de 10-15min pour les Kustomizations
- Intervalle de 1h pour les HelmRepositories

---

## Future: Multi-Tenant avec KubVirt

Cette section documente comment ajouter un tenant de development avec KubVirt.

### Concept

Un tenant est un environnement separe (namespace ou cluster virtuel) pour tester des modifications avant production.

```
homelab/
├── clusters/
│   ├── oci/           # Production
│   └── local/         # Development (future)
│
└── tenants/
    └── dev/           # Tenant de developpement
        ├── kustomization.yaml
        └── apps/
            ├── test-app-1/
            └── test-app-2/
```

### Implementation

Le tenant dev sera deploye sur le cluster `local` (quand il sera actif) via une Kustomization separee:

```yaml
# tenants/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
metadata:
  name: dev-tenant
spec:
  interval: 5m
  path: ./tenants/dev/apps
  prune: true
  wait: true
  sourceRef:
    kind: GitRepository
    name: homelab
  # Limiter aux namespaces dev-*
  patches:
    - patch: |
        - op: replace
          path: /spec/targetNamespace
          value: dev-test
      target:
        kind: HelmRelease
```

### Ressources necessaires

1. **KubVirt:** Machine virtuelle Kubernetes
2. **Storage:** PVC pour les tests
3. **Network:** Isolation du tenant

### Etapes pour mettre en place

1. **Phase 1:** Allumer le cluster local
2. **Phase 2:** Installer KubVirt sur le cluster local
3. **Phase 3:** Creer le repertoire `tenants/dev/`
4. **Phase 4:** Ajouter le tenant dans `clusters/local/kustomization.yaml`

### Reference

- [flux2-multi-tenancy](https://github.com/fluxcd/flux2-multi-tenancy)
- [KubVirt Documentation](https://kubevirt.io/)
- [Virtual Machines sur Kubernetes](https://kubevirt.io/user-guide/)

### Tests recommandes avant production

1. **Test de charge:**Verifier que l'app tient la charge
2. **Test de mise a jour:**Verifier le upgrade/downgrade
3. **Test de rollback:**Verifier le retour en arriere
4. **Test de persistence:**Verifier les donnees

### Promotion vers Production

```
Dev (local/KubVirt) -> Staging (OCI) -> Production (OCI)
```

Ou directement:
```
Dev (local) -> Production (OCI)
```

Pour une promotion automatique, voir [GitHub Actions Promotion](./flux-use-cases-gh-actions-helm-promotion.md)
