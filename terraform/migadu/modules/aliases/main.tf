# =============================================================================
# Aliases Module — Create and manage Migadu aliases
# =============================================================================

variable "domain" {
  type        = string
  description = "Email domain"
}

variable "aliases" {
  type = list(object({
    local_part  = string
    destination = string
    name        = optional(string, "")
    is_internal = optional(bool, false)
    may_send    = optional(bool, true)
  }))
  description = "List of aliases to create"
  default     = []
}

resource "migadu_alias" "this" {
  for_each = { for a in var.aliases : a.local_part => a }

  domain_name  = var.domain
  local_part   = each.value.local_part
  destinations = [each.value.destination]
}

output "alias_addresses" {
  description = "List of created alias addresses"
  value       = [for a in migadu_alias.this : a.address]
}

output "alias_ids" {
  description = "List of created alias IDs"
  value       = [for a in migadu_alias.this : a.id]
}
