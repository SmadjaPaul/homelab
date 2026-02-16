# =============================================================================
# Users — Optional: manage Authentik users and group membership in Terraform
# =============================================================================
# Inspiré de K-FOSS (Users/) et goauthentik/terraform-provider-authentik examples.
# Si la liste est vide, aucun utilisateur n'est créé. Préférer les invitations
# (Directory → Invitations) pour l'onboarding ; ce module sert pour des comptes
# déclaratifs (service accounts, premiers admins, etc.).
# =============================================================================

variable "users" {
  type = list(object({
    username    = string
    name        = string
    email       = optional(string, "")
    group_names = list(string)
    is_active   = optional(bool, true)
    path        = optional(string, "")
    password    = optional(string, "") # bcrypt hash or plaintext
  }))
  default     = []
  description = "Liste d'utilisateurs à créer. group_names doit correspondre aux clés de group_ids_by_name."
}

variable "group_ids_by_name" {
  type        = map(string)
  description = "Map nom de groupe → ID (ex: output group_ids_by_name du module groups)"
}
