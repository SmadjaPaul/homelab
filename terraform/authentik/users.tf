# =============================================================================
# Authentik Users
# =============================================================================

resource "authentik_user" "paul" {
  username = "paul"
  name     = "Paul Smadja"
  email    = "paul@smadja.dev"
  groups   = [authentik_group.admins.id, authentik_group.media.id]
}

# Example of how to add more users
# resource "authentik_user" "family_member" {
#   username = "family"
#   name     = "Family Member"
#   email    = "family@smadja.dev"
#   groups   = [authentik_group.media.id]
# }
