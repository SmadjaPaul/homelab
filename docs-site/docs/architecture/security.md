---
sidebar_position: 4
---

# Sécurité

## Principes

1. **Zero Trust** : Ne faire confiance à personne par défaut
2. **Defense in Depth** : Plusieurs couches de protection
3. **Least Privilege** : Permissions minimales nécessaires
4. **Encryption Everywhere** : TLS partout, secrets chiffrés

## Couches de sécurité

### 1. Edge (Cloudflare)

| Protection | Description |
|------------|-------------|
| WAF | Web Application Firewall |
| DDoS | Protection contre les attaques DDoS |
| Bot Management | Blocage des bots malveillants |
| SSL/TLS | Chiffrement strict (TLS 1.2+) |
| HSTS | Force HTTPS |

### 2. Accès

| Méthode | Usage |
|---------|-------|
| Cloudflare Access | Services admin (emails autorisés) |
| Twingate | Accès infrastructure |
| Keycloak | SSO pour applications |

### 3. Réseau

| Protection | Outil |
|------------|-------|
| CNI | Cilium |
| Network Policies | Isolation namespaces |
| Service Mesh | mTLS (optionnel) |

### 4. Secrets

| Aspect | Solution |
|--------|----------|
| Chiffrement | SOPS + Age |
| Stockage | Git (chiffré) |
| Injection | External Secrets Operator |

## Gestion des secrets

### SOPS + Age

Tous les secrets sont chiffrés avec SOPS avant d'être committés.

```bash
# Chiffrer un secret
sops -e secrets.yaml > secrets.enc.yaml

# Déchiffrer
sops -d secrets.enc.yaml
```

Configuration dans `.sops.yaml` :

```yaml
creation_rules:
  - path_regex: .*\.yaml$
    age: age1xxxxxxxxx...
```

### Secrets dans Git

| Fichier | Statut |
|---------|--------|
| `*.enc.yaml` | ✅ Chiffré, safe to commit |
| `secrets/*.yaml` | ❌ Ignoré par .gitignore |
| `terraform.tfvars` | ❌ Ignoré par .gitignore |

## CI/CD Security

### GitHub Actions

| Check | Outil |
|-------|-------|
| Secret Detection | Gitleaks |
| SAST | Trivy |
| IaC Security | tfsec |
| K8s Security | Kubescape |
| Dependency Review | GitHub native |

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    hooks:
      - id: gitleaks
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
```

## Authentification

### Keycloak SSO

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   User      │────▶│   Keycloak   │────▶│   Service   │
│             │     │   (OIDC)     │     │             │
└─────────────┘     └──────────────┘     └─────────────┘
```

**Clients OIDC configurés :**

- Grafana
- ArgoCD
- OAuth2 Proxy (services divers)

### Cloudflare Access

Pour les services admin, Cloudflare Access vérifie l'email avant d'autoriser l'accès.

```hcl
resource "cloudflare_access_policy" "internal_allow" {
  include {
    email = ["smadjapaul02@gmail.com"]
  }
}
```

## Audit & Monitoring

### Logs de sécurité

| Source | Destination |
|--------|-------------|
| K8s Audit | Loki |
| Cloudflare | Cloudflare Dashboard |
| ArgoCD | Loki |

### Alertes

| Alerte | Sévérité |
|--------|----------|
| Failed login attempts | Warning |
| Certificate expiring | Warning |
| Service down | Critical |
| Unusual traffic | Warning |
