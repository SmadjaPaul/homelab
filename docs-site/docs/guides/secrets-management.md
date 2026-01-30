---
sidebar_position: 3
---

# Gestion des secrets

## SOPS + Age

### Fonctionnement

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   secret    │────▶│    SOPS     │────▶│ secret.enc  │
│   .yaml     │     │  (chiffre)  │     │   .yaml     │
└─────────────┘     └─────────────┘     └─────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │  Age key    │
                    │ (privée)    │
                    └─────────────┘
```

### Configuration

```yaml
# .sops.yaml
creation_rules:
  - path_regex: kubernetes/.*\.yaml$
    encrypted_regex: "^(data|stringData)$"
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

  - path_regex: secrets/.*\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Générer une clé

```bash
# Créer le dossier
mkdir -p ~/.config/sops/age

# Générer la clé
age-keygen -o ~/.config/sops/age/keys.txt

# Afficher la clé publique
age-keygen -y ~/.config/sops/age/keys.txt
```

### Chiffrer un fichier

```bash
# Créer le secret en clair
cat > secrets/my-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
stringData:
  password: super-secret-password
EOF

# Chiffrer
sops -e secrets/my-secret.yaml > secrets/my-secret.enc.yaml

# Supprimer le fichier en clair
rm secrets/my-secret.yaml
```

### Déchiffrer

```bash
# Afficher en clair
sops -d secrets/my-secret.enc.yaml

# Éditer en place
sops secrets/my-secret.enc.yaml
```

### Fichier chiffré exemple

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
stringData:
  password: ENC[AES256_GCM,data:xxxxxxxxxxxxxxxx,iv:...,tag:...,type:str]
sops:
  age:
    - recipient: age1xxxxxx
      enc: |
        -----BEGIN AGE ENCRYPTED FILE-----
        ...
        -----END AGE ENCRYPTED FILE-----
  lastmodified: "2026-01-29T00:00:00Z"
  version: 3.8.1
```

## Dans Kubernetes

### Option 1: ksops (ArgoCD)

Utiliser ksops pour déchiffrer automatiquement dans ArgoCD.

```yaml
# kustomization.yaml
generators:
  - secrets-generator.yaml

# secrets-generator.yaml
apiVersion: viaduct.ai/v1
kind: ksops
metadata:
  name: secrets
files:
  - secrets.enc.yaml
```

### Option 2: External Secrets Operator

Synchroniser depuis un secret store externe.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cloudflare-api
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault
    kind: ClusterSecretStore
  target:
    name: cloudflare-credentials
  data:
    - secretKey: api-token
      remoteRef:
        key: cloudflare
        property: token
```

## Best Practices

### À faire

- ✅ Toujours chiffrer avant de commit
- ✅ Vérifier avec `git diff` avant push
- ✅ Backup de la clé Age
- ✅ Rotation régulière des secrets

### À éviter

- ❌ Committer des secrets en clair
- ❌ Partager la clé privée
- ❌ Stocker la clé dans le repo
- ❌ Utiliser des mots de passe faibles

## Vérification

### Pre-commit hook

Le hook `gitleaks` vérifie automatiquement :

```bash
# Test manuel
gitleaks detect --source .

# Dans pre-commit
pre-commit run gitleaks
```

### CI/CD

GitHub Actions vérifie aussi :

```yaml
# .github/workflows/security.yml
jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: gitleaks/gitleaks-action@v2
```
