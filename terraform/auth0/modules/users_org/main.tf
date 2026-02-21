# =============================================================================
# Users Org Module
# =============================================================================
# Creates users and adds them to Auth0 Organization with roles
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
  default = {}
}

variable "org_id" {
  description = "Organization ID"
  type        = string
}

variable "role_ids" {
  description = "Map of role names to IDs"
  type        = map(string)
  default     = {}
}

# Create users
resource "auth0_user" "this" {
  for_each = var.users

  connection_name = "Username-Password-Authentication"
  email           = each.value.email
  email_verified  = true
  password        = each.value.password
  nickname        = each.value.nickname
  name            = each.value.name

  lifecycle {
    create_before_destroy = true
  }
}

# Add users to organization
resource "auth0_organization_member" "this" {
  for_each = var.users

  organization_id = var.org_id
  user_id         = auth0_user.this[each.key].user_id
}

# Assign roles to organization members
resource "auth0_organization_member_roles" "this" {
  for_each = var.users

  organization_id = var.org_id
  user_id         = auth0_user.this[each.key].user_id
  roles           = [for role in each.value.roles : var.role_ids[role] if contains(keys(var.role_ids), role)]
}

output "user_ids" {
  description = "Created user IDs"
  value       = { for k, v in auth0_user.this : k => v.user_id }
}
