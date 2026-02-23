# Guide de Déploiement

Ce guide détaille les étapes pour initialiser et maintenir votre infrastructure souveraine.

## 🚀 Architecture Actuelle

```
GitHub (Flux) → Cluster OCI (OKE) → Cloudflare Tunnel → Utilisateurs
      ↑                              ↓
   Doppler (Secrets)         Auth0 (Auth)
```

## 🔄 Workflow de Déploiement

### 1. Modifier les manifests

Les manifests Kubernetes sont dans `kubernetes/apps/`:
- Chaque application a son propre répertoire sous `kubernetes/apps/{category}/{app}/`
- Déployé via **Flux CD** (GitOps)

### 2. Pousser sur Git

```bash
git add .
git commit -m "feat: add lidarr"
git push
```

### 3. Flux applique automatiquement

- Flux détecte les changements
- Applique les manifests sur le cluster OCI
- Vérifiable avec: `kubectl get kustomizations -A`

---

## 🛠️ Commandes Utiles

### Vérifier le statut du cluster
```bash
# Toutes les Kustomizations
kubectl get kustomizations -A

# Helm releases
kubectl get helmreleases -A

# Pods
kubectl get pods -A
```

### Debug
```bash
# Logs Flux
kubectl logs -n flux-system -l app=source-controller

# Logs Helm
kubectl logs -n flux-system -l app=helm-controller

# Événements
kubectl get events -A --sort-by='.lastTimestamp'
```

### Forcer une reconciliation
```bash
# Forcer Flux à resynchroniser
flux reconcile source git homelab -n flux-system

# Forcer une HelmRelease
kubectl annotate helmrelease <name> -n <ns> fluxcd.io/force-apply=true --overwrite
```

---

## 📦 Ajouter une Application

### 1. Créer la structure

```bash
mkdir -p kubernetes/apps/<category>/<app>/base
```

### 2. Fichiers nécessaires

- `namespace.yaml` - Namespace Kubernetes
- `helmrelease.yaml` - Déploiement Helm
- `kustomization.yaml` - Kustomize config
- `ingress.yaml` (optionnel) - Exposition externe
- `external-secret.yaml` (optionnel) - Secrets Doppler

### 3. Ajouter au parent

Modifier `kubernetes/apps/<category>/kustomization.yaml`:
```yaml
resources:
  - <app>/base
```

### 4. Pousser

```bash
git add kubernetes/apps/<category>/
git commit -m "feat: add <app>"
git push
```

---

## 🔐 Gestion des Secrets

### Via Doppler

1. Ajouter le secret dans Doppler (projet: infrastructure, config: prd)
2. Créer un ExternalSecret dans Kubernetes:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: my-secret
  namespace: my-app
spec:
  secretStoreRef:
    name: doppler
    kind: ClusterSecretStore
  target:
    name: my-secret
    creationPolicy: Owner
  dataFrom:
  - extract:
      key: MY_SECRET
```

---

## 🔧 Terraform (Infrastructure)

### Cloudflare (DNS, Access, Tunnel)

```bash
cd terraform/cloudflare
terraform plan
terraform apply
```

### OCI (OKE, Object Storage)

```bash
cd terraform/oracle-cloud
terraform plan
terraform apply
```

---

## 🆘 Troubleshooting

### Pod crashloop
```bash
kubectl describe pod <pod-name> -n <ns>
kubectl logs <pod-name> -n <ns>
```

### Helm release failed
```bash
kubectl describe helmrelease <name> -n <ns>
```

### ImagePullBackOff
- Vérifier le registry
- Vérifier les credentials (imagePullSecrets)

---

## 📖 Documentation

- **ROADMAP.md** - État d'avancement du projet
- **SERVICE-CATALOG.md** - Liste des services déployés
- **ARCHITECTURE.md** - Vue d'ensemble technique
- **CLAUDE.md** - Instructions pour l'agent IA
