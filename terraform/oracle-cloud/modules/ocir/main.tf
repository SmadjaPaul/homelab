# =============================================================================
# OCIR - Oracle Cloud Infrastructure Registry
# Container image repositories for homelab apps
# =============================================================================

terraform {
  required_providers {
    oci = {
      source = "oracle/oci"
    }
    doppler = {
      source = "DopplerHQ/doppler"
    }
  }
}

# Get tenancy name
data "oci_identity_tenancy" "this" {
  tenancy_id = var.compartment_id
}

# Docker config JSON for Kubernetes
locals {
  # OCIR username format: <tenancy_name>/<username>
  ocir_username = "${data.oci_identity_tenancy.this.name}/${var.oci_user_name}"
  ocir_email    = "homelab@smadja.dev"

  # Build docker config JSON
  docker_config_json = jsonencode({
    auths = {
      "${var.region}.ocir.io" = {
        username = local.ocir_username
        password = oci_identity_auth_token.ocir.token
        email    = local.ocir_email
      }
    }
  })
}

# =============================================================================
# Create OCIR Repositories
# =============================================================================

# Media apps repositories
resource "oci_artifacts_container_repository" "lidarr" {
  compartment_id = var.compartment_id
  display_name   = "lidarr"
}

resource "oci_artifacts_container_repository" "navidrome" {
  compartment_id = var.compartment_id
  display_name   = "navidrome"
}

resource "oci_artifacts_container_repository" "audiobookshelf" {
  compartment_id = var.compartment_id
  display_name   = "audiobookshelf"
}

# =============================================================================
# Auth Token for Container Registry
# =============================================================================

# Generate Auth Token for OCIR access
resource "oci_identity_auth_token" "ocir" {
  description = "Homelab OCIR access token"
  user_id     = var.oci_user_ocid

  lifecycle {
    # Recreate token if it gets rotated
    create_before_destroy = true
  }
}

# =============================================================================
# Sync Registry Credentials to Doppler
# =============================================================================

# Sync to Doppler (as base64 for Kubernetes secret)
resource "doppler_secret" "ocir_docker_config" {
  project = "infrastructure"
  config  = "prd"
  name    = "OCIR_DOCKER_CONFIG"
  value   = base64encode(local.docker_config_json)
}

resource "doppler_secret" "ocir_username" {
  project = "infrastructure"
  config  = "prd"
  name    = "OCIR_USERNAME"
  value   = local.ocir_username
}

resource "doppler_secret" "ocir_password" {
  project = "infrastructure"
  config  = "prd"
  name    = "OCIR_PASSWORD"
  value   = oci_identity_auth_token.ocir.token
}

resource "doppler_secret" "ocir_region" {
  project = "infrastructure"
  config  = "prd"
  name    = "OCIR_REGION"
  value   = var.region
}

# =============================================================================
# Outputs
# =============================================================================

output "lidarr_repository_url" {
  value = "${var.region}.ocir.io/${oci_artifacts_container_repository.lidarr.display_name}"
}

output "navidrome_repository_url" {
  value = "${var.region}.ocir.io/${oci_artifacts_container_repository.navidrome.display_name}"
}

output "audiobookshelf_repository_url" {
  value = "${var.region}.ocir.io/${oci_artifacts_container_repository.audiobookshelf.display_name}"
}
