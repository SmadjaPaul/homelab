---
sidebar_position: 2
---

# Ajouter un service

## Vue d'ensemble

Ajouter un nouveau service implique :

1. Créer l'Application ArgoCD
2. Ajouter au kustomization parent
3. Configurer DNS si nécessaire
4. Commit & push

## Exemple: Déployer WikiJS

### 1. Créer le dossier

```bash
mkdir -p kubernetes/apps/wikijs
```

### 2. Créer l'Application ArgoCD

```yaml
# kubernetes/apps/wikijs/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: wikijs
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://charts.js.wiki
    chart: wiki
    targetRevision: 2.2.0
    helm:
      values: |
        ingress:
          enabled: false

        postgresql:
          enabled: true
          persistence:
            size: 1Gi

        resources:
          requests:
            cpu: 50m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
  destination:
    server: https://kubernetes.default.svc
    namespace: wikijs
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 3. Ajouter au kustomization

```yaml
# kubernetes/apps/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - homepage/application.yaml
  - keycloak/application.yaml
  - uptime-kuma/application.yaml
  - fider/application.yaml
  - wikijs/application.yaml  # Nouveau!
```

### 4. Ajouter DNS (Terraform)

```hcl
# terraform/cloudflare/variables.tf
variable "homelab_services" {
  default = {
    # ... existing services ...

    wikijs = {
      subdomain   = "wiki"
      description = "WikiJS documentation"
      internal    = false
      user_facing = true
    }
  }
}
```

```hcl
# terraform/cloudflare/tunnel.tf
# Ajouter dans ingress_rules
ingress_rule {
  hostname = "wiki.${var.domain}"
  service  = "http://wikijs.wikijs.svc.cluster.local:3000"
}
```

### 5. Commit & Deploy

```bash
git add .
git commit -m "Add WikiJS application"
git push

# ArgoCD sync automatiquement
# Ou forcer:
argocd app sync apps
```

## Service avec manifests custom

Si vous n'utilisez pas un Helm chart :

```yaml
# kubernetes/apps/myapp/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/SmadjaPaul/homelab.git
    targetRevision: main
    path: kubernetes/apps/myapp/manifests  # Dossier local
  # ...
```

Puis créer les manifests :

```
kubernetes/apps/myapp/
├── application.yaml
└── manifests/
    ├── deployment.yaml
    ├── service.yaml
    └── kustomization.yaml
```

## Checklist

- [ ] Application YAML créée
- [ ] Ajouté au kustomization parent
- [ ] DNS configuré (si exposé)
- [ ] Tunnel ingress rule (si via Cloudflare)
- [ ] Secrets chiffrés avec SOPS
- [ ] Resource limits définis
- [ ] Health checks configurés
- [ ] Documentation mise à jour
