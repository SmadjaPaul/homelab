# =============================================================================
# Migadu — Root module (Email hosting management)
# =============================================================================
# Manages:
# - Mailboxes: email accounts
# - Aliases: email forwarding/alternative addresses
# - Identities: send from different addresses
# - Password rotation via password_rotation_trigger variable
# =============================================================================

# -----------------------------------------------------------------------------
# Password Rotation Trigger
# -----------------------------------------------------------------------------
resource "null_resource" "password_rotation_trigger" {
  triggers = {
    trigger = var.password_rotation_trigger
  }
}

# -----------------------------------------------------------------------------
# Random Password Generator for Mailboxes
# -----------------------------------------------------------------------------
resource "random_password" "noreply_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}?@"

  lifecycle {
    replace_triggered_by = [null_resource.password_rotation_trigger]
  }
}

resource "random_password" "paul_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}?@"

  lifecycle {
    replace_triggered_by = [null_resource.password_rotation_trigger]
  }
}

# -----------------------------------------------------------------------------
# Mailboxes (passwords managed by random_password above)
# -----------------------------------------------------------------------------
module "mailboxes" {
  source = "./modules/mailboxes"

  domain    = var.domain
  mailboxes = var.mailboxes
  passwords = {
    "noreply" = random_password.noreply_password.result
    "paul"    = random_password.paul_password.result
  }
}

# -----------------------------------------------------------------------------
# Aliases (disabled - complex configuration)
# -----------------------------------------------------------------------------
# module "aliases" {
#   source = "./modules/aliases"
#
#   domain  = var.domain
#   aliases = var.aliases
# }

# -----------------------------------------------------------------------------
# Identities (disabled - complex configuration)
# -----------------------------------------------------------------------------
# module "identities" {
#   source = "./modules/identities"
#
#   domain     = var.domain
#   identities = var.identities
# }

# -----------------------------------------------------------------------------
# Store SMTP credentials in Doppler for authentik
# -----------------------------------------------------------------------------
# Migadu provides SMTP credentials that can be used by authentik
resource "doppler_secret" "smtp_host" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "AUTHENTIK_SMTP_HOST"
  value   = "mail.${var.domain}"
}

resource "doppler_secret" "smtp_port" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "AUTHENTIK_SMTP_PORT"
  value   = "587"
}

resource "doppler_secret" "smtp_username" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "AUTHENTIK_SMTP_USERNAME"
  value   = local.smtp_username
}

resource "doppler_secret" "smtp_password" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "AUTHENTIK_SMTP_PASSWORD"
  value   = random_password.noreply_password.result

  lifecycle {
    replace_triggered_by = [null_resource.password_rotation_trigger]
  }
}

resource "doppler_secret" "smtp_from" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "AUTHENTIK_SMTP_FROM"
  value   = "noreply@${var.domain}"
}

locals {
  smtp_username = var.smtp_mailbox != "" ? "${var.smtp_mailbox}@${var.domain}" : ""
}

# SMTP mailbox for sending emails
variable "smtp_mailbox" {
  type        = string
  default     = "noreply"
  description = "Mailbox local part to use for SMTP (authentik sending)"
}

# Password rotation trigger - change to regenerate passwords
variable "password_rotation_trigger" {
  type        = string
  default     = "initial"
  description = "Change this value to trigger password rotation (e.g., 'v1', 'v2')"
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "mailboxes_created" {
  description = "Mailboxes created"
  value       = module.mailboxes.mailbox_addresses
}

# output "aliases_created" {
#   description = "Aliases created"
#   value       = module.aliases.alias_addresses
# }

# output "identities_created" {
#   description = "Identities created"
#   value       = module.identities.identity_addresses
# }

output "smtp_config" {
  description = "SMTP configuration for authentik"
  value = {
    host     = "mail.${var.domain}"
    port     = "587"
    username = local.smtp_username
    from     = "noreply@${var.domain}"
  }
  sensitive = true
}
