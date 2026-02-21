# =============================================================================
# Users Module
# =============================================================================
# Creates users with roles assigned
# =============================================================================

variable "users" {
  description = "Map of users to create"
  type = map(object({
    email    = string
    name     = string
    nickname = string
    password = string
    roles    = list(string)
  }))
  default = {
    paul = {
      email    = "paul@smadja.dev"
      name     = "Paul Smadja"
      nickname = "paul"
      password = "" # Set via variable
      roles    = ["admin"]
    }
  }
}

variable "role_ids" {
  description = "Map of role names to IDs"
  type        = map(string)
  default     = {}
}

resource "auth0_user" "this" {
  for_each = var.users

  connection_name = "Username-Password-Authentication"
  email           = each.value.email
  password        = each.value.password
  nickname        = each.value.nickname
  name            = each.value.name

  lifecycle {
    # Password changes require user to reset or admin to update
    # This allows Terraform to update password without recreation
    create_before_destroy = true
  }
}

resource "auth0_user_roles" "this" {
  for_each = var.users

  user_id = auth0_user.this[each.key].id
  roles   = [for role in each.value.roles : var.role_ids[role] if contains(keys(var.role_ids), role)]
}

output "users" {
  description = "Created users"
  value       = auth0_user.this
}
