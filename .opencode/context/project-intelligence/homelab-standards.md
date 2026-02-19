<!-- Context: project-intelligence/homelab-standards | Priority: high | Version: 4.0 | Updated: 2026-02-19 -->

# Homelab Coding Standards

> Coding standards and patterns for Kubernetes/Flux/Kustomize configuration.

## Kubernetes Standards

### File Organization
- One app per directory under `kubernetes/apps/{category}/{app}/`
- Base config in `base/` subdirectory
- Use `kustomization.yaml` for each layer
- Group by category: automation, infra, public

### Naming Conventions
- Files: kebab-case (`my-resource.yaml`)
- Namespaces: lowercase (`my-app`)
- Labels: kebab-case (`app.kubernetes.io/name`)

### Labels Required
```yaml
labels:
  app.kubernetes.io/name: ${app}
  app.kubernetes.io/instance: ${instance}
  app.kubernetes.io/part-of: ${category}
```

## Kustomize Standards

### Structure
```
{app}/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── helmrelease.yaml
│   └── helmrepository.yaml
└── {env}/                  # Optional overlays
    └── kustomization.yaml
```

### Overlay Pattern
```yaml
# {env}/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

patches:
  - path: values-patch.yaml
```

## Helm Standards

### Values Hierarchy
1. `values.yaml` - defaults in HelmRelease
2. `values-{env}.yaml` - environment overrides
3. Use Flux's `valuesFrom` for external values

### HelmRelease Best Practices
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: my-app
spec:
  chart:
    spec:
      chart: my-chart
      version: "1.0.0"
      sourceRef:
        kind: HelmRepository
        name: my-repo
```

## Secrets with Doppler

### External Secrets
Secrets are stored in Doppler and synced via External Secrets Operator (managed by Flux):

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
spec:
  secretStoreRef:
    name: doppler
    kind: ClusterSecretStore
  target:
    name: my-app-secrets
  data:
    - secretKey: API_KEY
      remoteRef:
        key: my-app
        property: API_KEY
```

### Secrets NEVER Committed
- Never commit secrets to git
- Use `.gitignore` for `secrets.yaml`, `*.tfvars`
- All secrets in Doppler

## Terraform vs Flux

### Terraform (Cloud Infrastructure Only)
- OCI resources (compute, network, OKE)
- Cloudflare configuration
- Authentik deployment (Helm chart via Terraform)

### Flux (All Kubernetes Resources)
- Namespaces
- HelmReleases
- Kustomizations
- ExternalSecrets
- ClusterSecretStore
- RBAC (ServiceAccounts, Roles, RoleBindings)

## Cloudflare + Authentik

### Cloudflare Access
Authentik as OAuth provider for Cloudflare Access:

```yaml
# Authentik OAuth configuration for Cloudflare Access
AUTH_URL: "https://authentik.example.com/application/o/authorize/"
TOKEN_URL: "https://authentik.example.com/application/o/token/"
```

### Authentik Application
- Configure each app in Authentik
- Create corresponding Access Policy in Cloudflare
- Map Authentik groups to RBAC policies

## YAML Standards

### Indentation
- Use 2 spaces (Kubernetes standard)
- No tabs

### Multi-document
```yaml
---
apiVersion: v1
kind: ConfigMap
---
apiVersion: v1
kind: Secret
```

## Validation

- Run `kubectl kustomize` to validate Kustomize
- Use `flux check` for Flux validation
- Test Helm templates: `helm template .`
- Run `terraform validate` for Terraform

## Git Commit Messages

```
feat(apps): add new application to automation
fix(infra): correct traefik routing
chore(cicd): update GitHub Actions workflow
chore(secrets): add new external secret
```
