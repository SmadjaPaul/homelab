# -----------------------------------------------------------------------------
# OCI Vault (KMS) + Master Key for Secrets — Free Tier friendly
# - OCI Secret Management is free (no charge for secrets).
# - Key Management: virtual vaults with software keys are free; HSM keys incur a fee.
# - vault_type = "DEFAULT" = virtual vault with software-backed keys (free tier).
# - Limits: 5,000 secrets per tenancy, 30 active versions per secret, 64 KB max per secret.
# https://docs.oracle.com/en-us/iaas/Content/KeyManagement/Concepts/keyoverview.htm
# -----------------------------------------------------------------------------

resource "oci_kms_vault" "homelab_secrets" {
  compartment_id = var.compartment_id
  display_name   = "homelab-secrets-vault"
  vault_type     = "DEFAULT" # Virtual vault + software keys (free); do not use HSM
}

resource "oci_kms_key" "homelab_secrets_key" {
  compartment_id      = var.compartment_id
  display_name        = "homelab-secrets-master-key"
  management_endpoint = oci_kms_vault.homelab_secrets.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32 # bytes (256 bits AES, software key, free tier)
  }
}
