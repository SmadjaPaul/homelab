# =============================================================================
# NetBird Variables
# =============================================================================

variable "doppler_token" {
  description = "Doppler API token for storing secrets"
  type        = string
  sensitive   = true
}

variable "doppler_project" {
  description = "Doppler project name"
  type        = string
  default     = "infrastructure"
}

variable "doppler_environment" {
  description = "Doppler environment (config)"
  type        = string
  default     = "prd"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "network_name" {
  description = "NetBird network name"
  type        = string
  default     = "homelab"
}

variable "network_description" {
  description = "NetBird network description"
  type        = string
  default     = "Homelab Kubernetes clusters"
}

# =============================================================================
# Cluster Configuration
# =============================================================================

variable "enable_local_cluster" {
  description = "Enable Talos local cluster (Proxmox)"
  type        = bool
  default     = true
}

variable "enable_oci_cluster" {
  description = "Enable OCI OKE cluster"
  type        = bool
  default     = true
}

variable "enable_workstation" {
  description = "Enable workstation setup key"
  type        = bool
  default     = true
}

# Kubernetes pod/service CIDRs (for routes)
variable "local_cluster_pod_cidr" {
  description = "Talos cluster pod CIDR (e.g., 10.42.0.0/16)"
  type        = string
  default     = "10.42.0.0/16"
}

variable "local_cluster_service_cidr" {
  description = "Talos cluster service CIDR (e.g., 10.43.0.0/16)"
  type        = string
  default     = "10.43.0.0/16"
}

variable "oci_cluster_pod_cidr" {
  description = "OKE cluster pod CIDR"
  type        = string
  default     = "10.244.0.0/16"
}

variable "oci_cluster_service_cidr" {
  description = "OKE cluster service CIDR"
  type        = string
  default     = "10.245.0.0/16"
}

# Group IDs for routes (will be created if not provided)
variable "k8s_group_id" {
  description = "Group ID for Kubernetes routers (optional, will be created if null)"
  type        = string
  default     = null
}

# =============================================================================
# Setup Key Configuration
# =============================================================================

variable "setup_key_type" {
  description = "Setup key type: 'reusable' or 'one-off'"
  type        = string
  default     = "reusable"
}

variable "setup_key_usage_limit" {
  description = "Maximum number of times SetupKey can be used (0 for unlimited)"
  type        = number
  default     = 0
}

variable "setup_key_expiry_seconds" {
  description = "Expiry time in seconds (0 is unlimited)"
  type        = number
  default     = 0
}

variable "setup_key_ephemeral" {
  description = "Remove peers after 10 minutes of inactivity (for containers)"
  type        = bool
  default     = false
}
