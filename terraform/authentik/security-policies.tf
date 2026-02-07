# =============================================================================
# Security Policies — Password strength, brute-force (reputation)
# =============================================================================
# Inspired by ghndrx/authentik-terraform. These policies improve security
# for recovery (password reset) and login (rate limiting by IP/username).
# MFA (TOTP/WebAuthn) is configured manually or via flow stages; see docs.

# -----------------------------------------------------------------------------
# Password policy — enforced on recovery (password reset) and enrollment
# -----------------------------------------------------------------------------
resource "authentik_policy_password" "strong" {
  name          = "strong-password"
  length_min    = 12
  error_message = "Le mot de passe doit contenir au moins 12 caractères, une majuscule, une minuscule, un chiffre et un symbole, et ne pas figurer dans des fuites connues."

  amount_uppercase = 1
  amount_lowercase = 1
  amount_digits    = 1
  amount_symbols   = 1
  symbol_charset   = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"

  check_static_rules      = true # No username/simple variants
  check_have_i_been_pwned = true # Reject breached passwords (HIBP)
  hibp_allowed_count      = 0
  check_zxcvbn            = true # Strength score
  zxcvbn_score_threshold  = 3    # 0–4; 3 = strong

  execution_logging = false
}

# Bind password policy to recovery flow — when user sets new password on reset
resource "authentik_policy_binding" "recovery_password_policy" {
  target  = authentik_flow_stage_binding.recovery_prompt_password.id
  policy  = authentik_policy_password.strong.id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

# -----------------------------------------------------------------------------
# Reputation policy — brute-force protection on login
# -----------------------------------------------------------------------------
# Score starts at 0; each failed attempt decreases it. Below threshold = deny.
# Bind to default authentication flow so every login attempt is evaluated.
resource "authentik_policy_reputation" "login" {
  name              = "login-reputation"
  check_ip          = true
  check_username    = true
  threshold         = -5 # Block after 5 failed attempts (per IP or per username)
  execution_logging = true
}

# Use default authentication flow from login-flow-recovery-link.tf
resource "authentik_policy_binding" "login_reputation" {
  target  = data.authentik_flow.default_authentication.id
  policy  = authentik_policy_reputation.login.id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}
