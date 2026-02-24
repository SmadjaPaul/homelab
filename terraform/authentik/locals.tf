# =============================================================================
# Configuration Maps
# =============================================================================

locals {
  groups = {
    admins = {
      name = "Admins"
    }
    media_users = {
      name = "Media Users"
    }
  }

  users = {
    paul = {
      username = "paul"
      name     = "Paul Smadja"
      email    = "paul@smadja.dev"
      is_admin = true
      groups   = ["Admins", "Media Users"]
    }
  }
}
