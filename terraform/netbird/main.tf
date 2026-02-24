# =============================================================================
# NetBird Terraform — root module
# VPN mesh pour accès cluster + interconnect cluster-to-cluster
# Secrets sourced from Doppler (NETBIRD_API_KEY)
# =============================================================================

terraform {
  required_version = ">= 1.12"

  required_providers {
    netbird = {
      source  = "netbirdio/netbird"
      version = "~> 0.0"
    }
    doppler = {
      source  = "DopplerHQ/doppler"
      version = ">= 1.0"
    }
  }
}

provider "doppler" {
  doppler_token = var.doppler_token
}

# Centralised config: Doppler secrets exposed as outputs for all modules
module "global_config" {
  source = "./modules/global_config"

  doppler_project     = var.doppler_project
  doppler_environment = var.doppler_environment
}

provider "netbird" {
  token = module.global_config.netbird_api_key
}

# =============================================================================
# Network — the NetBird network (account-level container)
# =============================================================================
resource "netbird_network" "main" {
  name        = var.network_name
  description = var.network_description
}

# =============================================================================
# Groups — pour organiser les peers et les access policies
# =============================================================================
resource "netbird_group" "k8s_routers" {
  count = var.enable_local_cluster || var.enable_oci_cluster ? 1 : 0

  name = "Kubernetes Routers"
}

resource "netbird_group" "workstations" {
  count = var.enable_workstation ? 1 : 0

  name = "Workstations"
}

# =============================================================================
# Setup Keys — pour connecter les peers (machines/containers)
# =============================================================================
resource "netbird_setup_key" "k8s_local" {
  count = var.enable_local_cluster ? 1 : 0

  name                   = "Kubernetes Local Cluster"
  type                   = var.setup_key_type
  expiry_seconds         = var.setup_key_expiry_seconds
  usage_limit            = var.setup_key_usage_limit
  ephemeral              = var.setup_key_ephemeral
  allow_extra_dns_labels = false
  auto_groups            = [netbird_group.k8s_routers[0].id]
  revoked                = false
}

resource "netbird_setup_key" "k8s_oci" {
  count = var.enable_oci_cluster ? 1 : 0

  name                   = "Kubernetes OCI Cluster"
  type                   = var.setup_key_type
  expiry_seconds         = var.setup_key_expiry_seconds
  usage_limit            = var.setup_key_usage_limit
  ephemeral              = var.setup_key_ephemeral
  allow_extra_dns_labels = false
  auto_groups            = [netbird_group.k8s_routers[0].id]
  revoked                = false
}

resource "netbird_setup_key" "workstation" {
  count = var.enable_workstation ? 1 : 0

  name                   = "Workstation"
  type                   = var.setup_key_type
  expiry_seconds         = var.setup_key_expiry_seconds
  usage_limit            = var.setup_key_usage_limit
  ephemeral              = false
  allow_extra_dns_labels = false
  auto_groups            = [netbird_group.workstations[0].id]
  revoked                = false
}

# =============================================================================
# Network Routes — Remote Network Access
# =============================================================================
resource "netbird_route" "local_cluster_pods" {
  count = var.enable_local_cluster && var.local_cluster_pod_cidr != "" ? 1 : 0

  network_id = netbird_network.main.id
  groups     = [netbird_group.k8s_routers[0].id]
  network    = var.local_cluster_pod_cidr
  enabled    = true
}

resource "netbird_route" "local_cluster_services" {
  count = var.enable_local_cluster && var.local_cluster_service_cidr != "" ? 1 : 0

  network_id = netbird_network.main.id
  groups     = [netbird_group.k8s_routers[0].id]
  network    = var.local_cluster_service_cidr
  enabled    = true
}

resource "netbird_route" "oci_cluster_pods" {
  count = var.enable_oci_cluster && var.oci_cluster_pod_cidr != "" ? 1 : 0

  network_id = netbird_network.main.id
  groups     = [netbird_group.k8s_routers[0].id]
  network    = var.oci_cluster_pod_cidr
  enabled    = true
}

resource "netbird_route" "oci_cluster_services" {
  count = var.enable_oci_cluster && var.oci_cluster_service_cidr != "" ? 1 : 0

  network_id = netbird_network.main.id
  groups     = [netbird_group.k8s_routers[0].id]
  network    = var.oci_cluster_service_cidr
  enabled    = true
}

# =============================================================================
# Access Policies — contrôler les accès entre groups
# =============================================================================

# Workstations peuvent accéder aux clusters K8s
resource "netbird_policy" "workstation_to_k8s" {
  count = var.enable_workstation && (var.enable_local_cluster || var.enable_oci_cluster) ? 1 : 0

  name    = "Workstation to Kubernetes"
  enabled = true

  rule {
    name          = "Allow workstation to k8s"
    action        = "accept"
    bidirectional = true
    enabled       = true
    protocol      = "all"
    sources       = [netbird_group.workstations[0].id]
    destinations  = [netbird_group.k8s_routers[0].id]
  }
}

# =============================================================================
# Doppler Secrets Sync — partager les setup keys
# =============================================================================

resource "doppler_secret" "netbird_setup_key_local" {
  count   = var.enable_local_cluster ? 1 : 0
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "NETBIRD_SETUP_KEY_LOCAL"
  value   = netbird_setup_key.k8s_local[0].key
}

resource "doppler_secret" "netbird_setup_key_oci" {
  count   = var.enable_oci_cluster ? 1 : 0
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "NETBIRD_SETUP_KEY_OCI"
  value   = netbird_setup_key.k8s_oci[0].key
}

resource "doppler_secret" "netbird_setup_key_workstation" {
  count   = var.enable_workstation ? 1 : 0
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "NETBIRD_SETUP_KEY_WORKSTATION"
  value   = netbird_setup_key.workstation[0].key
}

# Network ID for reference
resource "doppler_secret" "netbird_network_id" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "NETBIRD_NETWORK_ID"
  value   = netbird_network.main.id
}
