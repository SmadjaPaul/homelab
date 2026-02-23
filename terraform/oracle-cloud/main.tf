# =============================================================================
# Oracle Cloud Infrastructure - OKE (Free Tier)
# Simple Kubernetes cluster without management VM
# =============================================================================

terraform {
  # Backend "oci" natif (sans hashicorp/oci) à partir de Terraform 1.12
  required_version = ">= 1.12"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0, < 7.0"
    }
    doppler = {
      source  = "DopplerHQ/doppler"
      version = ">= 1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

# Doppler provider - uses DOPPLER_TOKEN env var or explicit token
provider "doppler" {
  doppler_token = var.doppler_token
}

# Fetch secrets from Doppler (optional - fallback to env vars)
# Only query Doppler if a token is available
data "doppler_secrets" "this" {
  count = var.doppler_token != "" ? 1 : 0

  project = "infrastructure"
  config  = "prd"
}

# Locals pour gérer les secrets avec fallback sur les variables d'environnement
# Note: Les noms correspondent à ceux dans votre Doppler
# Fallback hierarchy: TF_VAR_* > Doppler > OCI_* env vars
locals {
  # Récupérer les valeurs depuis Doppler (si disponible)
  doppler_secrets     = length(data.doppler_secrets.this) > 0 ? data.doppler_secrets.this[0].map : {}
  doppler_tenancy     = lookup(local.doppler_secrets, "OCI_CLI_TENANCY", "")
  doppler_user        = lookup(local.doppler_secrets, "OCI_CLI_USER", "")
  doppler_fingerprint = lookup(local.doppler_secrets, "OCI_CLI_FINGERPRINT", "")
  doppler_key         = lookup(local.doppler_secrets, "OCI_CLI_KEY_CONTENT", "")

  # Utiliser coalesce pour le fallback: var > doppler > "" (OCI provider utilisera les env vars)
  oci_tenancy_ocid = coalesce(
    var.tenancy_ocid != "" ? var.tenancy_ocid : null,
    local.doppler_tenancy != "" ? local.doppler_tenancy : null,
    ""
  )
  oci_user_ocid = coalesce(
    var.user_ocid != "" ? var.user_ocid : null,
    local.doppler_user != "" ? local.doppler_user : null,
    ""
  )
  oci_fingerprint = coalesce(
    var.oci_fingerprint != "" ? var.oci_fingerprint : null,
    local.doppler_fingerprint != "" ? local.doppler_fingerprint : null,
    ""
  )
  oci_private_key = coalesce(
    var.oci_private_key != "" ? var.oci_private_key : null,
    local.doppler_key != "" ? local.doppler_key : null,
    ""
  )
}

# Validation pour s'assurer que les credentials sont présents (via vars, Doppler, ou env)
resource "null_resource" "validate_credentials" {
  lifecycle {
    precondition {
      condition     = length(local.oci_tenancy_ocid) > 0 || length(coalesce(var.tenancy_ocid, "")) > 0
      error_message = "OCI_TENANCY_OCID is required. Set it via: 1) Doppler (OCI_CLI_TENANCY), 2) terraform.tfvars, or 3) OCI_CLI_TENANCY env var"
    }
    precondition {
      condition     = length(local.oci_user_ocid) > 0 || length(coalesce(var.user_ocid, "")) > 0
      error_message = "OCI_USER_OCID is required. Set it via: 1) Doppler (OCI_CLI_USER), 2) terraform.tfvars, or 3) OCI_CLI_USER env var"
    }
    precondition {
      condition     = length(local.oci_fingerprint) > 0 || length(coalesce(var.oci_fingerprint, "")) > 0
      error_message = "OCI_FINGERPRINT is required. Set it via: 1) Doppler (OCI_CLI_FINGERPRINT), 2) terraform.tfvars, or 3) OCI_CLI_FINGERPRINT env var"
    }
    precondition {
      condition     = length(local.oci_private_key) > 0 || length(coalesce(var.oci_private_key, "")) > 0
      error_message = "OCI_PRIVATE_KEY is required. Set it via: 1) Doppler (OCI_CLI_KEY_CONTENT), 2) terraform.tfvars, or 3) OCI_CLI_KEY_CONTENT env var"
    }
  }
}

provider "oci" {
  region = var.region
  # Si les valeurs locales sont vides, le provider OCI utilisera automatiquement
  # les variables d'environnement: OCI_CLI_TENANCY, OCI_CLI_USER, OCI_CLI_FINGERPRINT, OCI_CLI_KEY_CONTENT
  tenancy_ocid = local.oci_tenancy_ocid != "" ? local.oci_tenancy_ocid : null
  user_ocid    = local.oci_user_ocid != "" ? local.oci_user_ocid : null
  fingerprint  = local.oci_fingerprint != "" ? local.oci_fingerprint : null
  private_key  = local.oci_private_key != "" ? local.oci_private_key : null
}

# =============================================================================
# Network Module
# =============================================================================

module "network" {
  source = "./modules/network"

  compartment_id      = var.compartment_id
  vcn_name            = "homelab"
  vcn_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"

  tags = {
    Environment = "homelab"
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# OKE Module (Kubernetes Cluster - Free Tier)
# =============================================================================

module "oke" {
  source = "./modules/oke"

  compartment_id     = var.compartment_id
  cluster_name       = "homelab-k8s"
  vcn_id             = module.network.vcn_id
  lb_subnet_id       = module.network.public_subnet_id
  worker_subnet_id   = module.network.private_subnet_id
  kubernetes_version = var.kubernetes_version
  region             = var.region
  node_ocpus         = 2
  node_memory        = 12
  node_count         = 2
  ssh_public_key     = var.ssh_public_key

  tags = {
    Environment = "homelab"
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Monitoring & Logging Module (Free Tier)
# =============================================================================

module "monitoring" {
  source = "./modules/monitoring"

  compartment_id = var.compartment_id
  prefix         = "homelab"

  tags = {
    Environment = "homelab"
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# S3 Credentials & Secret Management (Always Free)
# =============================================================================

# Generate S3-compatible Customer Secret Key for the current OCI user
resource "oci_identity_customer_secret_key" "s3_key" {
  display_name = "homelab-s3-key"
  user_id      = local.oci_user_ocid
}

# Sync S3 credentials to Doppler
resource "doppler_secret" "s3_access_key" {
  project = "infrastructure"
  config  = "prd"
  name    = "OCI_S3_ACCESS_KEY"
  value   = oci_identity_customer_secret_key.s3_key.id
}

resource "doppler_secret" "s3_secret_key" {
  project = "infrastructure"
  config  = "prd"
  name    = "OCI_S3_SECRET_KEY"
  value   = oci_identity_customer_secret_key.s3_key.key
}

resource "doppler_secret" "s3_endpoint_url" {
  project = "infrastructure"
  config  = "prd"
  name    = "OCI_S3_ENDPOINT_URL"
  value   = "https://${data.oci_objectstorage_namespace.this.namespace}.compat.objectstorage.${var.region}.oraclecloud.com"
}

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.compartment_id
}

# Get user name for OCIR
data "oci_identity_user" "this" {
  user_id = local.oci_user_ocid
}

# =============================================================================
# OCIR - Container Registry
# =============================================================================

module "ocir" {
  source = "./modules/ocir"

  providers = {
    oci     = oci
    doppler = doppler
  }

  compartment_id = var.compartment_id
  region         = var.region
  oci_user_ocid  = local.oci_user_ocid
  oci_user_name  = data.oci_identity_user.this.name
}


# =============================================================================
# Outputs
# =============================================================================

output "vcn_id" {
  value = module.network.vcn_id
}

output "public_subnet_id" {
  value = module.network.public_subnet_id
}

output "private_subnet_id" {
  value = module.network.private_subnet_id
}

output "cluster_id" {
  value = module.oke.cluster_id
}

output "cluster_ocid" {
  value = module.oke.cluster_ocid
}

output "cluster_endpoint" {
  value = module.oke.cluster_endpoint
}

output "kubeconfig_command" {
  value = module.oke.kubeconfig_command
}

output "log_group_id" {
  value = module.monitoring.log_group_id
}
