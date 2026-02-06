# Authentik Terraform configuration
# See: _bmad-output/implementation-artifacts/authentik-terraform-implementation.md
# Auth: set AUTHENTIK_URL and AUTHENTIK_TOKEN (e.g. via .env, not committed)

terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2024.12"
    }
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "authentik" {
  # URL and token from environment: AUTHENTIK_URL, AUTHENTIK_TOKEN
}

provider "oci" {
  # OCI provider configuration from environment variables:
  # - OCI_CLI_TENANCY_OCID
  # - OCI_CLI_USER_OCID
  # - OCI_CLI_FINGERPRINT
  # - OCI_CLI_KEY_FILE
  # - OCI_CLI_REGION
  # Or use ~/.oci/config
}
