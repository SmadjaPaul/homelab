# =============================================================================
# Auth0 Terraform Variables
# =============================================================================
# Doppler token is passed via environment variable: DOPPLER_TOKEN
#
# Users are configured below - add more users as needed
# Roles are pre-configured but can be extended in variables.tf
# =============================================================================

# Users to create in Auth0
# Add more users following this pattern:
# username = {
#   email    = "email@example.com"
#   name     = "Full Name"
#   nickname = "nickname"
#   password = "${AUTHENTIK_INITIAL_PASSWORD}"
#   roles    = ["admin", "family", "professional", "media_user"]
# }

users = {
  paul = {
    email    = "paul@smadja.dev"
    name     = "Paul Smadja"
    nickname = "paul"
    password = "" # Managed via Doppler AUTH0_PASSWORDS
    roles    = ["admin"]
  }

  # Example users - uncomment and modify as needed:
  # john = {
  #   email    = "john@smadja.dev"
  #   name     = "John Doe"
  #   nickname = "john"
  #   password = "${AUTHENTIK_INITIAL_PASSWORD}"
  #   roles    = ["family"]
  # }
  # alice = {
  #   email    = "alice@smadja.dev"
  #   name     = "Alice Smith"
  #   nickname = "alice"
  #   password = "${AUTHENTIK_INITIAL_PASSWORD}"
  #   roles    = ["professional"]
  # }
}

# You can also add more roles in variables.tf if needed
