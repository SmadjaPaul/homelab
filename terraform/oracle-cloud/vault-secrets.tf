# -----------------------------------------------------------------------------
# OCI Vault Secrets — CI secrets stored in OCI (Cloudflare, Omni, SSH, etc.)
# Local: values from TF_VAR_vault_secret_* (e.g. .env). Empty = secret not created.
# CI: set TF_VAR_vault_secrets_managed_in_ci=true so resources are kept and
#     content is not overwritten/destroyed when vars are null (ignore_changes).
# https://docs.oracle.com/en-us/iaas/Content/KeyManagement/Concepts/keyoverview.htm
# -----------------------------------------------------------------------------

locals {
  vault_id = oci_kms_vault.homelab_secrets.id
  key_id   = oci_kms_key.homelab_secrets_key.id
}

# Cloudflare
resource "oci_vault_secret" "cloudflare_api_token" {
  count          = (length(coalesce(var.vault_secret_cloudflare_api_token, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-cloudflare-api-token"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(coalesce(var.vault_secret_cloudflare_api_token, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# GitHub PAT (TFstate.dev lock) — DEPRECATED: backends now use OCI Object Storage
# Kept for backwards compatibility, can be removed in future
resource "oci_vault_secret" "tfstate_dev_token" {
  count          = (length(coalesce(var.vault_secret_tfstate_dev_token, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-tfstate-dev-token"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(coalesce(var.vault_secret_tfstate_dev_token, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# Omni (OCI Management Stack)
resource "oci_vault_secret" "omni_db_user" {
  count          = (length(coalesce(var.vault_secret_omni_db_user, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-omni-db-user"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(coalesce(var.vault_secret_omni_db_user, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

resource "oci_vault_secret" "omni_db_password" {
  count          = (length(coalesce(var.vault_secret_omni_db_password, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-omni-db-password"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(coalesce(var.vault_secret_omni_db_password, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

resource "oci_vault_secret" "omni_db_name" {
  count          = (length(coalesce(var.vault_secret_omni_db_name, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-omni-db-name"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(coalesce(var.vault_secret_omni_db_name, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# SSH private key for OCI management VM (same pair as ssh_public_key)
resource "oci_vault_secret" "oci_mgmt_ssh_private_key" {
  count          = (length(coalesce(var.vault_secret_oci_mgmt_ssh_private_key, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-oci-mgmt-ssh-private-key"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(coalesce(var.vault_secret_oci_mgmt_ssh_private_key, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}
