# =============================================================================
# Roles Module
# =============================================================================
# Creates extensible roles for homelab users
# =============================================================================

variable "roles" {
  description = "Map of roles to create"
  type = map(object({
    description = string
  }))
  default = {
    admin = {
      description = "Full administrative access to all resources"
    }
    family = {
      description = "Family member - limited access"
    }
    professional = {
      description = "Professional user - moderate access"
    }
    media_user = {
      description = "Media user - access to media services only"
    }
  }
}

resource "auth0_role" "this" {
  for_each = var.roles

  name        = each.key
  description = each.value.description
}

output "roles" {
  description = "Created roles"
  value       = auth0_role.this
}

output "role_ids" {
  description = "Map of role names to IDs"
  value       = { for k, v in auth0_role.this : k => v.id }
}
