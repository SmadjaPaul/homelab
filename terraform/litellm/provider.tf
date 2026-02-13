# LiteLLM Terraform — root: provider + module credentials
# Backend: backend.tf (OCI). Requires LiteLLM proxy running.
# Secrets: managed in Doppler (project: litellm)

terraform {
  required_version = ">= 1.0"

  required_providers {
    litellm = {
      source  = "ncecere/litellm"
      version = "~> 1.0"
    }
    doppler = {
      source  = "DopplerHQ/doppler"
      version = "1.13.0"
    }
  }
}

# Doppler provider - uses DOPPLER_TOKEN env var
provider "doppler" {}

# Fetch secrets from Doppler
data "doppler_secrets" "litellm" {
  project = "litellm"
  config  = "prd"
}

provider "litellm" {
  # LiteLLM proxy URL from Doppler
  api_base = data.doppler_secrets.litellm.map.LITELLM_URL
  # Master key for proxy admin API from Doppler
  api_key = data.doppler_secrets.litellm.map.LITELLM_MASTER_KEY
}
