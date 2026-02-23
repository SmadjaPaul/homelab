# =============================================================================
# Migadu Terraform Configuration
# Email hosting management via Migadu API
# Manages: mailboxes, aliases, identities, rewrites
# =============================================================================

terraform {
  required_version = ">= 1.12"

  required_providers {
    migadu = {
      source  = "metio/migadu"
      version = "~> 2024.6"
    }
    doppler = {
      source  = "DopplerHQ/doppler"
      version = ">= 1.0"
    }
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================

# Doppler secrets for Migadu credentials
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

# Provider doppler - pour stocker les secrets
provider "doppler" {
  doppler_token = var.doppler_token
}

# Migadu credentials - email from variable, API key from Doppler
locals {
  migadu_api_key = data.doppler_secrets.this.map.MIGADU_API_KEY
}

# Provider migadu - email hosting management
provider "migadu" {
  username = var.migadu_email
  token    = local.migadu_api_key
}

# Fetch Migadu credentials from Doppler
data "doppler_secrets" "this" {
  project = var.doppler_project
  config  = var.doppler_environment
}

# =============================================================================
# Configuration Variables
# =============================================================================

variable "migadu_email" {
  type        = string
  default     = "smadja-paul@protonmail.com"
  description = "Migadu account email (for API auth)"
}

variable "domain" {
  type        = string
  default     = "smadja.dev"
  description = "Email domain managed by Migadu"
}

variable "mailboxes" {
  type = list(object({
    local_part      = string
    name            = string
    password        = optional(string, "")
    may_send        = optional(bool, true)
    may_receive     = optional(bool, true)
    may_access_imap = optional(bool, true)
    may_access_pop3 = optional(bool, false)
    is_internal     = optional(bool, false)
  }))
  default     = []
  description = "List of mailboxes to create"
}

variable "aliases" {
  type = list(object({
    local_part  = string
    destination = string
    name        = optional(string, "")
    is_internal = optional(bool, false)
    may_send    = optional(bool, true)
  }))
  default     = []
  description = "List of aliases to create"
}

variable "identities" {
  type = list(object({
    mailbox_local_part = string
    local_part         = string
    name               = string
    password           = optional(string, "")
    may_send           = optional(bool, true)
  }))
  default     = []
  description = "List of identities to create (send from different addresses)"
}
