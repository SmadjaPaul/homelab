# Terraform — LiteLLM

Gestion des clés API et des paramètres LiteLLM via le [provider ncecere/litellm](https://registry.terraform.io/providers/ncecere/litellm/latest/docs).

## Prérequis

- Le proxy LiteLLM doit être démarré (ex. `docker compose up -d` dans `docker/oci-mgmt`).
- Une clé master définie dans `.env` : `LITELLM_MASTER_KEY`.

## Usage

```bash
cd terraform/litellm

# Option 1 : variables en env
export LITELLM_URL="https://llm.smadja.dev"
export LITELLM_MASTER_KEY="sk-..."

# Option 2 : tfvars (ne pas committer les clés)
echo 'litellm_url = "https://llm.smadja.dev"' > terraform.tfvars
# LITELLM_MASTER_KEY via env ou TF_VAR_litellm_master_key

terraform init
terraform plan
```

## Création des clés plus tard

Quand les secrets (Synthetic, etc.) sont prêts, ajouter des ressources `litellm_credential` dans `credentials.tf` et alimenter les valeurs depuis un secret manager (OCI Vault, etc.). Voir la doc du provider pour le schéma exact de la ressource `credential`.
