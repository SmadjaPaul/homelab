# Terraform Apply depuis Kubernetes (derrière Cloudflare Tunnel)

Ce document explique comment exécuter Terraform sur l'infrastructure Authentik alors que celle-ci est déployée sur Kubernetes et exposée via Cloudflare Tunnel.

## Le Défi

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   Terraform     │         │  Cloudflare      │         │   Kubernetes    │
│   (CI/CD ou     │ ──────► │  Tunnel          │ ──────► │   (Authentik)   │
│   local)        │         │  (auth.smadja.dev)         │                 │
└─────────────────┘         └──────────────────┘         └─────────────────┘
       │                                                            │
       │                     Problème:                              │
       │   Comment Terraform atteint l'API Authentik                │
       │   quand elle est derrière Cloudflare Tunnel ?              │
       │                                                            │
       └────────────────────────────────────────────────────────────┘
```

## Solutions

### Solution 1: Tunnel Cloudflare déjà configuré (Recommandé pour la prod)

Si votre tunnel Cloudflare est déjà configuré et fonctionnel:

```bash
# Terraform utilise directement l'URL publique
export AUTHENTIK_URL="https://auth.smadja.dev"
export AUTHENTIK_TOKEN="$(doppler secrets get AUTHENTIK_TOKEN --plain)"

cd terraform/authentik
terraform apply
```

**Avantages:**
- ✅ Simple et direct
- ✅ Fonctionne depuis n'importe où (CI/CD GitHub Actions)
- ✅ Sécurisé par Cloudflare Access (quand activé)

**Inconvénients:**
- ❌ Nécessite que le tunnel soit fonctionnel
- ❌ Dépend de Cloudflare

### Solution 2: Port-Forward Kubernetes (Développement/Debug)

Pour le développement ou quand le tunnel n'est pas accessible:

```bash
# 1. Port-forward depuis votre machine locale vers le pod Authentik
kubectl -n authentik port-forward svc/authentik-server 9000:80

# 2. Utiliser localhost dans Terraform
export AUTHENTIK_URL="http://localhost:9000"
export AUTHENTIK_TOKEN="$(kubectl -n authentik get secret authentik-bootstrap-token -o jsonpath='{.data.token}' | base64 -d)"

# 3. Terraform apply
cd terraform/authentik
terraform apply
```

**Avantages:**
- ✅ Ne dépend pas de Cloudflare
- ✅ Accès direct, plus rapide
- ✅ Fonctionne même si le tunnel est down

**Inconvénients:**
- ❌ Nécessite accès au cluster Kubernetes
- ❌ Ne fonctionne pas en CI/CD (GitHub Actions)
- ❌ Bootstrap token nécessaire (temporaire)

### Solution 3: VPN/Overlay Network (Option avancée)

Si vous avez un VPN ou un réseau overlay (Tailscale, Netbird, etc.):

```bash
# Connecter au VPN
sudo tailscale up

# Utiliser l'IP interne du service
export AUTHENTIK_URL="http://authentik-server.authentik.svc.cluster.local:80"

# Ou via l'IP Tailscale
export AUTHENTIK_URL="http://100.x.x.x:9000"
```

### Solution 4: Job Kubernetes (CI/CD interne)

Créer un Job Kubernetes qui exécute Terraform depuis l'intérieur du cluster:

```yaml
# kubernetes/jobs/terraform-authentik.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: terraform-authentik
  namespace: authentik
spec:
  template:
    spec:
      serviceAccountName: terraform-runner
      containers:
      - name: terraform
        image: hashicorp/terraform:1.12
        command:
        - /bin/sh
        - -c
        - |
          # Cloner le repo
          apk add --no-cache git
          git clone https://github.com/votre-user/homelab.git /tmp/homelab
          cd /tmp/homelab/terraform/authentik

          # Configurer les secrets depuis Doppler
          export TF_VAR_doppler_token="$(cat /secrets/doppler-token)"

          # Terraform
          terraform init
          terraform apply -auto-approve
        env:
        - name: DOPPLER_TOKEN
          valueFrom:
            secretKeyRef:
              name: doppler-token
              key: token
        volumeMounts:
        - name: secrets
          mountPath: /secrets
      restartPolicy: Never
      volumes:
      - name: secrets
        secret:
          secretName: terraform-secrets
```

**Avantages:**
- ✅ Fonctionne depuis l'intérieur du cluster
- ✅ Pas besoin de Cloudflare
- ✅ Idéal pour GitOps avec Flux/ArgoCD

**Inconvénients:**
- ❌ Complexité accrue
- ❌ Maintenance d'un job Kubernetes

## Configuration GitHub Actions (Recommandé)

La meilleure approche pour la CI/CD est d'utiliser **Solution 1** (Cloudflare Tunnel public) car c'est la plus simple et la plus fiable.

### Workflow GitHub Actions

```yaml
# .github/workflows/terraform-authentik.yml
name: Authentik Terraform

on:
  push:
    branches: [main]
    paths:
      - 'terraform/authentik/**'
  workflow_dispatch:

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: "1.12.0"

    - name: Terraform Init
      working-directory: terraform/authentik
      run: terraform init
      env:
        TF_VAR_doppler_token: ${{ secrets.DOPPLER_SERVICE_TOKEN }}

    - name: Terraform Plan
      working-directory: terraform/authentik
      run: terraform plan
      env:
        TF_VAR_doppler_token: ${{ secrets.DOPPLER_SERVICE_TOKEN }}

    - name: Terraform Apply
      if: github.ref == 'refs/heads/main'
      working-directory: terraform/authentik
      run: terraform apply -auto-approve
      env:
        TF_VAR_doppler_token: ${{ secrets.DOPPLER_SERVICE_TOKEN }}
```

### Configuration Doppler

Assurez-vous que Doppler contient:

```
# Project: homelab, Config: prd
AUTHENTIK_URL=https://auth.smadja.dev
AUTHENTIK_TOKEN=<token-permanent-terraform>
```

## Rotation de Mots de Passe depuis CI/CD

### Déclencher une rotation via GitHub Actions

```yaml
# .github/workflows/rotate-authentik-passwords.yml
name: Rotate Authentik Passwords

on:
  workflow_dispatch:
    inputs:
      rotation_version:
        description: 'Version de rotation (ex: v2, v3)'
        required: true
        default: 'v2'

jobs:
  rotate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3

    - name: Rotate Passwords
      working-directory: terraform/authentik
      run: |
        terraform init
        terraform apply -auto-approve \
          -var="password_rotation_trigger=${{ github.event.inputs.rotation_version }}" \
          -var="force_password_rotation=true"
      env:
        TF_VAR_doppler_token: ${{ secrets.DOPPLER_SERVICE_TOKEN }}
```

## Troubleshooting

### Erreur: "Failed to fetch user/group information"

**Cause**: Cloudflare Access est activé et bloque l'API

**Solution**:
```bash
# Désactiver temporairement Cloudflare Access pour l'API
# Ou utiliser le port-forward (Solution 2)
kubectl -n authentik port-forward svc/authentik-server 9000:80
export AUTHENTIK_URL="http://localhost:9000"
```

### Erreur: "Connection refused" ou timeout

**Cause**: Le tunnel Cloudflare n'est pas fonctionnel

**Vérification**:
```bash
# Vérifier le statut du tunnel
curl -s https://auth.smadja.dev/-/health/ready/

# Si KO, vérifier les pods
kubectl -n cloudflared get pods
kubectl -n authentik get pods
```

### Erreur: "401 Unauthorized"

**Cause**: Token invalide ou expiré

**Solution**:
```bash
# Récupérer un nouveau bootstrap token
kubectl -n authentik get secret authentik-bootstrap-token \
  -o jsonpath='{.data.token}' | base64 -d

# Ou utiliser le token Terraform CI depuis Doppler
doppler secrets get AUTHENTIK_TOKEN_TERRAFORM_CI --plain
```

## Bonnes Pratiques

1. **Utilisez toujours les variables d'environnement** pour les tokens, jamais en dur dans le code
2. **Stockez les secrets dans Doppler** pour une gestion centralisée
3. **Utilisez des tokens de service** (service accounts) plutôt que des tokens utilisateurs
4. **Activez le state locking** avec le backend OCI pour éviter les conflits
5. **Planifiez régulièrement** la rotation des mots de passe (ex: tous les 90 jours)

## Résumé des Commandes

```bash
# === Développement local (port-forward) ===
kubectl -n authentik port-forward svc/authentik-server 9000:80
export AUTHENTIK_URL="http://localhost:9000"
export AUTHENTIK_TOKEN="<bootstrap-token>"
cd terraform/authentik && terraform apply

# === Production (via Cloudflare Tunnel) ===
export AUTHENTIK_URL="https://auth.smadja.dev"
export AUTHENTIK_TOKEN="$(doppler secrets get AUTHENTIK_TOKEN --plain)"
cd terraform/authentik && terraform apply

# === Rotation de mots de passe ===
terraform apply -var="password_rotation_trigger=v2"

# === Force rotation ===
terraform apply -var="force_password_rotation=true"
```
