---
sidebar_position: 2
---

# Configuration

## Variables d'environnement

### SOPS (Secrets)

```bash
# Générer une clé age
age-keygen -o ~/.config/sops/age/keys.txt

# Exporter la variable
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

### OCI CLI

```bash
# Setup interactif
oci setup config
```

Configuration dans `~/.oci/config` :

```ini
[DEFAULT]
user=ocid1.user.oc1..xxxxx
fingerprint=xx:xx:xx:xx
tenancy=ocid1.tenancy.oc1..xxxxx
region=eu-paris-1
key_file=~/.oci/oci_api_key.pem
```

## Fichiers de configuration

### terraform.tfvars

Créer les fichiers de variables pour chaque provider :

```bash
# Oracle Cloud
cp terraform/oracle-cloud/terraform.tfvars.example terraform/oracle-cloud/terraform.tfvars
# Éditer avec vos OCIDs

# Cloudflare
cp terraform/cloudflare/terraform.tfvars.example terraform/cloudflare/terraform.tfvars
# Éditer avec votre API token
```

### .sops.yaml

Configurer SOPS pour chiffrer les secrets :

```yaml
creation_rules:
  - path_regex: kubernetes/.*\.yaml$
    encrypted_regex: "^(data|stringData)$"
    age: age1xxxxxxxxx  # Votre clé publique

  - path_regex: secrets/.*\.yaml$
    age: age1xxxxxxxxx
```

## Pre-commit hooks

```bash
# Installer pre-commit
pip install pre-commit

# Activer les hooks
pre-commit install

# Tester
pre-commit run --all-files
```

## Kubectl context

```bash
# Télécharger kubeconfig depuis Omni
# ou via talosctl
talosctl kubeconfig -n <node-ip>

# Vérifier
kubectl config get-contexts
kubectl config use-context homelab
```
