# =============================================================================
# Provider Configuration
# =============================================================================

terraform {
  required_version = ">= 1.12"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 2.0"
    }
    doppler = {
      source  = "DopplerHQ/doppler"
      version = ">= 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# --- Grafana Provider ---
variable "grafana_token" {
  description = "Grafana Cloud API token (Cloud Access Policy Token with 'stack-admin' or 'org-admin' to provision dashboards)"
  type        = string
  sensitive   = true
}

variable "grafana_url" {
  description = "Grafana Cloud URL"
  type        = string
  default     = "https://smadja.grafana.net"
}

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_token
}

provider "grafana" {
  alias                     = "cloud"
  cloud_access_policy_token = var.grafana_token
}

# --- Doppler Provider ---
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

provider "doppler" {
  doppler_token = var.doppler_token
}

# --- Random Provider ---
provider "random" {}
