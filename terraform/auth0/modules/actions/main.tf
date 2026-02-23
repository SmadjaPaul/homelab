# =============================================================================
# Actions Module - Placeholder
# =============================================================================
# Note: Auth0 Actions require specific Terraform provider configuration
# The post-login action should be configured manually in Auth0 Dashboard:
# 1. Go to Actions > Library > + Build Custom
# 2. Create "Add Role to Token" action
# 3. Add the code below
# 4. Drag to Post Login flow
# =============================================================================

# Code to use in Auth0 Dashboard Action:
variable "action_code" {
  description = "Action code for post-login"
  type        = string
  default     = <<-EOT
    exports.onExecutePostLogin = async (event, api) => {
      const appMetadata = event.user.app_metadata || {};
      const userMetadata = event.user.user_metadata || {};
      const role = appMetadata.role || userMetadata.role;

      if (role) {
        api.idToken.setCustomClaim('roles', [role]);
        api.accessToken.setCustomClaim('roles', [role]);
      }
    };
  EOT
}
