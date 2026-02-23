# =============================================================================
# Identities Module — Create identities for mailboxes (send from different addresses)
# =============================================================================
# Identities allow users to send from alternative email addresses
# Docs: https://registry.terraform.io/providers/metio/migadu/latest/docs/resources/identity

variable "domain" {
  type        = string
  description = "Email domain"
}

variable "identities" {
  type = list(object({
    # The mailbox this identity belongs to (local_part)
    mailbox_local_part = string
    # The identity local part (e.g., "info" for info@domain.com)
    local_part = string
    # Display name
    name = string
    # Password for the identity (can be different from mailbox)
    password = optional(string, "")
    # Can send from this identity
    may_send = optional(bool, true)
  }))
  description = "List of identities to create"
  default     = []
}

resource "migadu_identity" "this" {
  for_each = { for id in var.identities : "${id.mailbox_local_part}-${id.local_part}" => id }

  domain_name  = var.domain
  local_part   = each.value.mailbox_local_part
  identity     = each.value.local_part
  name         = each.value.name
  password_use = "none"
}

output "identity_addresses" {
  description = "List of created identity addresses"
  value       = [for id in migadu_identity.this : id.address]
}
