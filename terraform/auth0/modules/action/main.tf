# =============================================================================
# Auth0 Post-Login Action - Add Roles to JWT for Cloudflare Access RBAC
# =============================================================================
# This action runs after login and adds roles to the JWT token.
# Uses namespaced claims to avoid conflicts with Auth0's restricted claims.
# =============================================================================

terraform {
  required_providers {
    auth0 = {
      source = "auth0/auth0"
    }
  }
}

# Namespace for custom claims (must be a URL you control)
locals {
  claim_namespace = "http://homelab.smadja.dev"
}

resource "auth0_action" "add_roles_to_token" {
  name    = "Add Roles to Token - Homelab"
  runtime = "node22"
  deploy  = true

  code = <<-EOT
    /**
     * Handler that will be called during the execution of a PostLogin flow.
     * Injects roles and metadata so Cloudflare Access can read them via OIDC claims.
     */
    exports.onExecutePostLogin = async (event, api) => {
      const namespace = 'https://homelab.smadja.dev';

      // Add roles from authorization (if available)
      if (event.authorization && event.authorization.roles) {
        api.idToken.setCustomClaim(`$${namespace}/roles`, event.authorization.roles);
        api.idToken.setCustomClaim(`$${namespace}/groups`, event.authorization.roles);
        api.accessToken.setCustomClaim(`$${namespace}/roles`, event.authorization.roles);
      }

      // Add user metadata (helpful for debugging and additional policies)
      const userMetadata = event.user.user_metadata || {};
      if (userMetadata.role) {
        api.idToken.setCustomClaim(`$${namespace}/user_role`, userMetadata.role);
      }

      // Ensure email is verified for Cloudflare Access if needed
      if (!event.user.email_verified) {
        // Optional: you could force verify or block, but Cloudflare usually just needs the claim
      }
    };
  EOT

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }
}

# Bind the action to the post-login trigger
resource "auth0_trigger_actions" "post_login" {
  trigger = "post-login"

  actions {
    id           = auth0_action.add_roles_to_token.id
    display_name = auth0_action.add_roles_to_token.name
  }
}
