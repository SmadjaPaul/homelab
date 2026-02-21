# =============================================================================
# Mailboxes Module — Create and manage Migadu mailboxes
# =============================================================================

variable "domain" {
  type        = string
  description = "Email domain"
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
  description = "List of mailboxes to create"
  default     = []
}

variable "passwords" {
  type        = map(string)
  description = "Map of passwords by local_part (from random_password)"
  default     = {}
}

resource "migadu_mailbox" "this" {
  for_each = { for mb in var.mailboxes : mb.local_part => mb }

  domain_name     = var.domain
  local_part      = each.value.local_part
  name            = each.value.name
  may_send        = each.value.may_send
  may_receive     = each.value.may_receive
  may_access_imap = each.value.may_access_imap
  may_access_pop3 = each.value.may_access_pop3
  is_internal     = each.value.is_internal

  # Use password from passwords map if available, otherwise from variable (invitation)
  password = try(var.passwords[each.value.local_part], null) != "" ? try(var.passwords[each.value.local_part], null) : (each.value.password != "" ? each.value.password : null)
}

output "mailbox_addresses" {
  description = "List of created mailbox addresses"
  value       = [for mb in migadu_mailbox.this : mb.address]
}

output "mailbox_ids" {
  description = "List of created mailbox IDs"
  value       = [for mb in migadu_mailbox.this : mb.id]
}
