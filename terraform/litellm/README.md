# Terraform — LiteLLM

Gestion des clés API LiteLLM via le [provider ncecere/litellm](https://registry.terraform.io/providers/ncecere/litellm/latest/docs). Le proxy LiteLLM doit être démarré (ex. dans `docker/oci-mgmt`).

## Structure

- **Root** : provider, variables, appel du module `credentials`.
- **`modules/credentials`** : clés API (ex. OpenClaw). Ajouter d’autres ressources `litellm_key` ou `litellm_credential` ici si besoin.
- **Backend** : `backend.tf` (OCI, même bucket que cloudflare/authentik). Remplacer `YOUR_TENANCY_NAMESPACE` en local ; en CI, ajouter une étape d’injection du namespace si tu exécutes ce stack en pipeline.

## Prérequis

- Proxy LiteLLM démarré (ex. `docker compose up -d` dans `docker/oci-mgmt`).
- Clé master dans l’env : `LITELLM_MASTER_KEY`.

## Usage

```bash
cd terraform/litellm

# Option 1 : variables en env
export LITELLM_URL="https://llm.smadja.dev"
export LITELLM_MASTER_KEY="sk-..."

# Option 2 : tfvars (ne pas committer les clés)
echo 'litellm_url = "https://llm.smadja.dev"' > terraform.tfvars
# LITELLM_MASTER_KEY via env ou TF_VAR_litellm_master_key

# Backend OCI : remplacer YOUR_TENANCY_NAMESPACE dans backend.tf puis :
terraform init -reconfigure
terraform plan
terraform apply
```

## Création de clés supplémentaires

Pour d’autres clés (Synthetic, etc.) : ajouter des ressources `litellm_key` ou `litellm_credential` dans `modules/credentials/main.tf` et les variables/outputs associés. Alimenter les secrets depuis OCI Vault ou env selon ton setup.
