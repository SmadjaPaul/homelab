# =============================================================================
# Configuration Maps
# =============================================================================

locals {
  groups = {
    admins = {
      name = "Admins"
    }
    media = {
      name = "Media Users"
    }
  }

  users = {
    paul = {
      username = "paul"
      name     = "Paul Smadja"
      email    = "paul@smadja.dev"
      groups   = ["Admins", "Media Users"]
    }
  }
}
