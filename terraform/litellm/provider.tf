# LiteLLM Terraform — root: provider + module credentials
# Backend: backend.tf (OCI). Requires LiteLLM proxy running (e.g. docker/oci-mgmt).

terraform {
  required_version = ">= 1.0"

  required_providers {
    litellm = {
      source  = "ncecere/litellm"
      version = "~> 1.0"
    }
  }
}

provider "litellm" {
  # LiteLLM proxy URL (internal or public). Set via env LITELLM_URL or variable.
  api_base = var.litellm_url
  # Master key for proxy admin API. Set via env LITELLM_MASTER_KEY or variable.
  api_key = var.litellm_master_key
}
