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
  count          = (length(try(var.vault_secret_cloudflare_api_token, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-cloudflare-api-token"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_cloudflare_api_token, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# GitHub PAT (TFstate.dev lock) — DEPRECATED: backends now use OCI Object Storage
# Kept for backwards compatibility, can be removed in future
resource "oci_vault_secret" "tfstate_dev_token" {
  count          = (length(try(var.vault_secret_tfstate_dev_token, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-tfstate-dev-token"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_tfstate_dev_token, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# Omni (OCI Management Stack)
resource "oci_vault_secret" "omni_db_user" {
  count          = (length(try(var.vault_secret_omni_db_user, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-omni-db-user"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_omni_db_user, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

resource "oci_vault_secret" "omni_db_password" {
  count          = (length(try(var.vault_secret_omni_db_password, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-omni-db-password"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_omni_db_password, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

resource "oci_vault_secret" "omni_db_name" {
  count          = (length(try(var.vault_secret_omni_db_name, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-omni-db-name"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_omni_db_name, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# SSH private key for OCI management VM (same pair as ssh_public_key)
resource "oci_vault_secret" "oci_mgmt_ssh_private_key" {
  count          = (length(try(var.vault_secret_oci_mgmt_ssh_private_key, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-oci-mgmt-ssh-private-key"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_oci_mgmt_ssh_private_key, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# =============================================================================
# OCI Management Stack secrets (Cloudflare Tunnel + Authentik + PostgreSQL)
# =============================================================================

# Cloudflare Tunnel Token (for cloudflared on OCI VM)
# Only created when content is provided; in CI create via scripts/create-oci-mgmt-secrets.sh
resource "oci_vault_secret" "cloudflare_tunnel_token" {
  count          = length(try(var.vault_secret_cloudflare_tunnel_token, "")) > 0 ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-cloudflare-tunnel-token"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_cloudflare_tunnel_token, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# PostgreSQL password (shared database for Authentik + Omni)
# Only created when content is provided; in CI create via scripts/create-oci-mgmt-secrets.sh
resource "oci_vault_secret" "postgres_password" {
  count          = length(try(var.vault_secret_postgres_password, "")) > 0 ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-postgres-password"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_postgres_password, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# Authentik secret key (for session encryption)
# Only created when content is provided; in CI create via scripts/create-oci-mgmt-secrets.sh
resource "oci_vault_secret" "authentik_secret_key" {
  count          = length(try(var.vault_secret_authentik_secret_key, "")) > 0 ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-authentik-secret-key"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_authentik_secret_key, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# =============================================================================
# Authentik CI/CD OAuth2 secrets (for GitHub Actions workflows)
# =============================================================================

# Authentik API token (bootstrap, for initial OAuth2 provider creation)
# Only created when content is provided; in CI create via scripts/create-oci-mgmt-secrets.sh
resource "oci_vault_secret" "authentik_token" {
  count          = (length(try(var.vault_secret_authentik_token, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-authentik-token"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_authentik_token, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# Authentik OAuth2 client_id (CI automation provider)
# Only created when content is provided; in CI create via scripts/create-oci-mgmt-secrets.sh
# Content is populated after first terraform apply (output from terraform-authentik workflow)
resource "oci_vault_secret" "authentik_oauth2_client_id" {
  count          = (length(try(var.vault_secret_authentik_oauth2_client_id, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-authentik-oauth2-client-id"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_authentik_oauth2_client_id, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# Authentik OAuth2 client_secret (CI automation provider) - DEPRECATED: Use private_key_jwt instead
# Only created when content is provided; in CI create via scripts/create-oci-mgmt-secrets.sh
# Content is populated after first terraform apply (output from terraform-authentik workflow)
# NOTE: This is kept for backward compatibility during migration to private_key_jwt
resource "oci_vault_secret" "authentik_oauth2_client_secret" {
  count          = (length(try(var.vault_secret_authentik_oauth2_client_secret, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-authentik-oauth2-client-secret"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_authentik_oauth2_client_secret, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}

# Authentik Private Key PEM (for private_key_jwt authentication)
# Generated by GitHub Actions workflow and stored in OCI Vault
# Used for signing JWT assertions in client_credentials flow
resource "oci_vault_secret" "authentik_private_key_pem" {
  count          = (length(try(var.vault_secret_authentik_private_key_pem, "")) > 0 || var.vault_secrets_managed_in_ci) ? 1 : 0
  compartment_id = var.compartment_id
  vault_id       = local.vault_id
  key_id         = local.key_id
  secret_name    = "homelab-authentik-private-key-pem"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(try(var.vault_secret_authentik_private_key_pem, "managed-externally"))
  }

  lifecycle {
    ignore_changes = [secret_content]
  }
}
