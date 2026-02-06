# =============================================================================
# SMTP Secrets from OCI Vault
# =============================================================================
# Reads SMTP configuration secrets from OCI Vault to configure Authentik email stage.
# Secrets are created and managed in terraform/oracle-cloud/vault-secrets.tf
#
# Usage:
#   - Set OCI provider credentials (OCI_CLI_* env vars or ~/.oci/config)
#   - Provide oci_compartment_id via variable (from terraform/oracle-cloud outputs)
#   - Secrets are decoded from BASE64 and used in authentik_stage_email
# =============================================================================

# Data source to find secrets by name
data "oci_vault_secrets" "smtp_secrets" {
  count          = var.oci_compartment_id != "" ? 1 : 0
  compartment_id = var.oci_compartment_id

  filter {
    name = "name"
    values = [
      var.oci_smtp_secret_names.host,
      var.oci_smtp_secret_names.port,
      var.oci_smtp_secret_names.username,
      var.oci_smtp_secret_names.password,
      var.oci_smtp_secret_names.from,
    ]
  }
}

# Individual secret bundles (decode BASE64)
locals {
  # Create a map of secret name -> secret OCID
  secret_ocids = var.oci_compartment_id != "" ? {
    for secret in data.oci_vault_secrets.smtp_secrets[0].secrets : secret.name => secret.id
  } : {}

  # Fetch secret bundles and decode
  smtp_host = var.oci_compartment_id != "" && length(local.secret_ocids) > 0 ? try(
    base64decode(
      data.oci_secrets_secretbundle.smtp_host[0].secret_bundle_content[0].content
    ),
    ""
  ) : ""

  smtp_port = var.oci_compartment_id != "" && length(local.secret_ocids) > 0 ? try(
    base64decode(
      data.oci_secrets_secretbundle.smtp_port[0].secret_bundle_content[0].content
    ),
    "587"
  ) : "587"

  smtp_username = var.oci_compartment_id != "" && length(local.secret_ocids) > 0 ? try(
    base64decode(
      data.oci_secrets_secretbundle.smtp_username[0].secret_bundle_content[0].content
    ),
    ""
  ) : ""

  smtp_password = var.oci_compartment_id != "" && length(local.secret_ocids) > 0 ? try(
    base64decode(
      data.oci_secrets_secretbundle.smtp_password[0].secret_bundle_content[0].content
    ),
    ""
  ) : ""

  smtp_from = var.oci_compartment_id != "" && length(local.secret_ocids) > 0 ? try(
    base64decode(
      data.oci_secrets_secretbundle.smtp_from[0].secret_bundle_content[0].content
    ),
    "noreply@smadja.dev"
  ) : "noreply@smadja.dev"
}

# Fetch secret bundles
data "oci_secrets_secretbundle" "smtp_host" {
  count     = var.oci_compartment_id != "" && try(local.secret_ocids[var.oci_smtp_secret_names.host], null) != null ? 1 : 0
  secret_id = local.secret_ocids[var.oci_smtp_secret_names.host]
}

data "oci_secrets_secretbundle" "smtp_port" {
  count     = var.oci_compartment_id != "" && try(local.secret_ocids[var.oci_smtp_secret_names.port], null) != null ? 1 : 0
  secret_id = local.secret_ocids[var.oci_smtp_secret_names.port]
}

data "oci_secrets_secretbundle" "smtp_username" {
  count     = var.oci_compartment_id != "" && try(local.secret_ocids[var.oci_smtp_secret_names.username], null) != null ? 1 : 0
  secret_id = local.secret_ocids[var.oci_smtp_secret_names.username]
}

data "oci_secrets_secretbundle" "smtp_password" {
  count     = var.oci_compartment_id != "" && try(local.secret_ocids[var.oci_smtp_secret_names.password], null) != null ? 1 : 0
  secret_id = local.secret_ocids[var.oci_smtp_secret_names.password]
}

data "oci_secrets_secretbundle" "smtp_from" {
  count     = var.oci_compartment_id != "" && try(local.secret_ocids[var.oci_smtp_secret_names.from], null) != null ? 1 : 0
  secret_id = local.secret_ocids[var.oci_smtp_secret_names.from]
}
