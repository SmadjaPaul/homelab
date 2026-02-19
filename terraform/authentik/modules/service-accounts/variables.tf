# =============================================================================
# Service Accounts — Machine-to-Machine authentication
# =============================================================================
# Crée des comptes de service pour les connexions automatisées et API.
# Chaque service account est associé à un token d'API stocké dans Doppler.
# =============================================================================

variable "service_accounts" {
  type = list(object({
    name        = string
    description = optional(string, "")
    group_names = optional(list(string), [])
    # Permissions spécifiques
    is_superuser = optional(bool, false)
    # Token settings
    token_expires = optional(string, "") # Format: days=365, hours=24, etc.
    # Path dans Authentik
    path = optional(string, "service-accounts")
  }))
  default = [
    {
      name         = "terraform-ci"
      description  = "Terraform CI/CD service account"
      group_names  = ["admin"]
      is_superuser = true
      path         = "service-accounts"
    },
    {
      name         = "github-actions"
      description  = "GitHub Actions automation"
      group_names  = ["admin"]
      is_superuser = false
      path         = "service-accounts"
    },
    {
      name         = "external-dns"
      description  = "External DNS automation"
      group_names  = []
      is_superuser = false
      path         = "service-accounts"
    }
  ]
  description = "Liste des comptes de service à créer"
}

variable "group_ids_by_name" {
  type        = map(string)
  description = "Map nom de groupe → ID"
}

variable "doppler_project" {
  type        = string
  default     = "infrastructure"
  description = "Projet Doppler pour stocker les tokens"
}

variable "doppler_config" {
  type        = string
  default     = "prd"
  description = "Config Doppler pour stocker les tokens"
}

variable "rotation_trigger" {
  type        = string
  default     = "initial"
  description = "Trigger pour forcer la rotation des tokens"
}
