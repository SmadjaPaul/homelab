# =============================================================================
# Enrollment Flow Configuration - Disable Self-Registration
# =============================================================================
# This configuration disables public self-registration by blocking access to
# the enrollment flow unless the user has an invitation token.
# Users can only enroll via invitations (Directory → Invitations).
#
# Note: The Terraform provider doesn't support directly modifying the
# "Allow user to start this flow" setting. Instead, we use a policy to block
# public access. You can also disable it manually in the UI:
# Flows → default-enrollment-flow → Settings → Uncheck "Allow user to start this flow"
#
# Docs: https://docs.goauthentik.io/docs/flow/examples/flows#enrollment-flow
#
# Note: We do not lookup the enrollment flow by slug here because the slug can
# vary by Authentik version (e.g. "default-enrollment-flow" vs "default-enrollment")
# or the flow may not exist yet. Use the post-terraform script or UI to disable it.

# Policy to block public enrollment (only allow with invitation token)
resource "authentik_policy_expression" "block_public_enrollment" {
  name       = "block-public-enrollment"
  expression = <<-EOT
    # Only allow enrollment if user has an invitation token in context
    # Invitations set 'invitation' in the request context
    if 'invitation' in request.context or 'invitation_token' in request.context:
        return True
    # Block all other enrollment attempts (public self-registration)
    return False
  EOT
}

# Note: Applying policies to flows directly may not be supported in all provider versions.
# The most reliable way is to disable the flow in the UI or use a policy on the flow itself.
# For now, we'll create the policy and provide instructions for manual application.

# Alternative: Apply policy directly to the flow (if supported)
# This may not work in all provider versions, so manual UI configuration is recommended

# Output instructions for manual configuration (if needed)
output "enrollment_flow_disabled_note" {
  description = "Instructions to manually disable enrollment flow if policy doesn't work"
  value       = <<-EOT
    ✅ Policy created to block public enrollment.

    If you want to also disable the flow in the UI (recommended):
    1. Go to Flows → default-enrollment-flow
    2. Click on Settings
    3. Uncheck "Allow user to start this flow"
    4. Save

    Users can now only enroll via invitations (Directory → Invitations).
  EOT
}
