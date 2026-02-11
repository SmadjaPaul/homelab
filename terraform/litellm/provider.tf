# LiteLLM Terraform — manage credentials, keys, teams via ncecere/litellm
# Requires LiteLLM proxy running (e.g. docker/oci-mgmt). API keys created in a second step with secrets.
# Docs: https://registry.terraform.io/providers/ncecere/litellm/latest/docs

terraform {
  required_version = ">= 1.0"

  required_providers {
    litellm = {
      source  = "ncecere/litellm"
      version = "~> 1.0"
    }
  }

  # Backend: optional. Uncomment and set namespace for OCI, or use local.
  # backend "oci" {
  #   bucket    = "homelab-tfstate"
  #   namespace = "YOUR_TENANCY_NAMESPACE"
  #   key       = "litellm/terraform.tfstate"
  #   region    = "eu-paris-1"
  # }
}

provider "litellm" {
  # LiteLLM proxy URL (internal or public). Set via env LITELLM_URL or variable.
  api_base = var.litellm_url
  # Master key for proxy admin API. Set via env LITELLM_MASTER_KEY or variable.
  api_key = var.litellm_master_key
}
