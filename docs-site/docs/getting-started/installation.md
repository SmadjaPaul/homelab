---
sidebar_position: 1
---

# Installation

## Prérequis

### Outils locaux

```bash
# Installer via Homebrew
brew install kubectl helm terraform talosctl argocd k9s kubectx jq yq sops age
brew install oci-cli
```

### Comptes nécessaires

| Service | URL | Usage |
|---------|-----|-------|
| GitHub | github.com | Code source |
| Cloudflare | cloudflare.com | DNS + Tunnel |
| Oracle Cloud | cloud.oracle.com | VMs gratuites |
| Twingate | twingate.com | VPN zero trust |

## Configuration initiale

### 1. Cloner le repository

```bash
git clone git@github.com:SmadjaPaul/homelab.git
cd homelab
```

### 2. Configurer SOPS

```bash
# Générer une clé age
age-keygen -o ~/.config/sops/age/keys.txt

# La clé publique est affichée, la noter
cat ~/.config/sops/age/keys.txt | grep "public key"
```

### 3. Configurer OCI CLI

```bash
# Setup interactif
oci setup config

# Ou copier la config existante
mkdir -p ~/.oci
# Ajouter les fichiers config et clé privée
```

### 4. Installer les pre-commit hooks

```bash
pip install pre-commit
pre-commit install
```

## Déployer l'infrastructure

### Cloudflare

```bash
cd terraform/cloudflare

# Créer terraform.tfvars avec votre token
cp terraform.tfvars.example terraform.tfvars
# Éditer avec vos valeurs

terraform init
terraform plan
terraform apply
```

### Oracle Cloud

```bash
cd terraform/oracle-cloud

# Créer terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Éditer avec vos OCIDs

terraform init
terraform plan
terraform apply
```

## Accéder au cluster

### Via kubectl

```bash
# Télécharger kubeconfig depuis Omni
# ou utiliser talosctl
talosctl kubeconfig -n <node-ip>

# Vérifier
kubectl get nodes
```

### Via ArgoCD

```bash
# Port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Ou via Cloudflare Tunnel
open https://argocd.smadja.dev
```

## Structure du projet

```
homelab/
├── terraform/
│   ├── oracle-cloud/    # Infrastructure OCI
│   └── cloudflare/      # DNS, Tunnel, WAF
├── kubernetes/
│   ├── argocd/          # GitOps
│   ├── infrastructure/  # Infra apps
│   ├── monitoring/      # Observability
│   └── apps/            # User apps
├── scripts/             # Helpers
├── docs-site/docs/      # Documentation (runbooks, architecture, décisions & limites)
├── docs-site/           # Docusaurus (build du site)
└── secrets/             # Encrypted secrets
```

## Workflow quotidien

### Modifier une application

1. Éditer les fichiers dans `kubernetes/apps/<app>/`
2. Commit & push
3. ArgoCD sync automatiquement
4. Vérifier dans l'UI ArgoCD

### Ajouter un secret

1. Créer le fichier YAML
2. Chiffrer avec SOPS : `sops -e secret.yaml > secret.enc.yaml`
3. Supprimer le fichier non chiffré
4. Commit le fichier `.enc.yaml`

### Debug

```bash
# Logs d'un pod
kubectl logs -f deploy/<name> -n <namespace>

# Shell dans un pod
kubectl exec -it deploy/<name> -n <namespace> -- sh

# Events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```
