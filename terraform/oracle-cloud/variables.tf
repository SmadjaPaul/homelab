# Variables for Oracle Cloud Infrastructure

variable "region" {
  description = "OCI region"
  type        = string
  default     = "eu-paris-1"
}

variable "compartment_id" {
  description = "OCI compartment OCID"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
  sensitive   = true
}

# Availability domain index (0, 1, 2...) — useful if one AD has no capacity
variable "availability_domain_index" {
  description = "Index of availability domain for management VM (0 = first AD)"
  type        = number
  default     = 0
}

# VCN Configuration
variable "vcn_cidr" {
  description = "CIDR block for VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# Instance Configuration
variable "management_vm" {
  description = "Management VM configuration (Omni, Authentik)"
  type = object({
    name   = string
    ocpus  = number
    memory = number
    disk   = number
  })
  default = {
    name   = "oci-mgmt"
    ocpus  = 1
    memory = 6
    disk   = 50
  }
}

variable "k8s_nodes" {
  description = "Kubernetes nodes configuration"
  type = list(object({
    name   = string
    ocpus  = number
    memory = number
    disk   = number
  }))
  default = [
    {
      name   = "oci-node-1"
      ocpus  = 2
      memory = 12
      disk   = 64
    },
    {
      name   = "oci-node-2"
      ocpus  = 1
      memory = 6
      disk   = 75
    }
  ]
}

# Budget Alert Email
variable "budget_alert_email" {
  description = "Email address for budget alerts"
  type        = string
  sensitive   = true
}

# User OCID (for S3 compatible access keys)
variable "user_ocid" {
  description = "OCI User OCID for creating S3 access keys"
  type        = string
  default     = "" # Optional: set via TF_VAR_user_ocid if needed
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "homelab"
    ManagedBy   = "terraform"
    Environment = "production"
  }
}

# -----------------------------------------------------------------------------
# Vault secrets (OCI Vault — stored in homelab-secrets-vault)
# Local: set via .env (TF_VAR_vault_secret_*) or terraform.tfvars (never commit).
# CI: set vault_secrets_managed_in_ci = true so Terraform keeps existing secrets
#     without overwriting/destroying when vars are null (ignore_changes on content).
# -----------------------------------------------------------------------------

variable "vault_secrets_managed_in_ci" {
  description = "When true (e.g. in CI), keep secret resources but do not overwrite content. Prevents destroy when vars are empty."
  type        = bool
  default     = false
}

variable "vault_secret_cloudflare_api_token" {
  description = "Cloudflare API token (stored in OCI Vault)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vault_secret_tfstate_dev_token" {
  description = "GitHub PAT for TFstate.dev lock (stored in OCI Vault)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vault_secret_omni_db_user" {
  description = "Omni PostgreSQL user (stored in OCI Vault)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vault_secret_omni_db_password" {
  description = "Omni PostgreSQL password (stored in OCI Vault)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vault_secret_omni_db_name" {
  description = "Omni PostgreSQL database name (stored in OCI Vault)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vault_secret_oci_mgmt_ssh_private_key" {
  description = "SSH private key for OCI management VM (same pair as ssh_public_key)"
  type        = string
  default     = ""
  sensitive   = true
}
