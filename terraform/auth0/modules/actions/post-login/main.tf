# =============================================================================
# Auth0 Action - Invitation & Role Management
# =============================================================================
# This action:
# 1. Disables self-signup (requires invitation)
# 2. Assigns roles from user_metadata
# 3. Stores user's role in access token for Cloudflare Access
# =============================================================================

exports.onExecutePostLogin = async (event, api) => {
  // Get user metadata
  const userMetadata = event.user.user_metadata || {};

  // Assign role from metadata to token
  if (userMetadata.role) {
    // Add role to ID token for Cloudflare Access
    api.idToken.setCustomClaim('roles', [userMetadata.role]);

    // Add role to access token
    api.accessToken.setCustomClaim('roles', [userMetadata.role]);
  }

  // Store role in app_metadata for persistence
  if (userMetadata.role && !event.user.app_metadata?.role) {
    api.user.setAppMetadata('role', userMetadata.role);
  }
};

exports.onContinuePostLogin = async (event, api) => {
  // This runs after password reset
  // Ensure role is preserved
  const userMetadata = event.user.user_metadata || {};
  const appMetadata = event.user.app_metadata || {};

  if (userMetadata.role && !appMetadata.role) {
    api.user.setAppMetadata('role', userMetadata.role);
  }
};
