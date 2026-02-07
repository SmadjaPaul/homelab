# =============================================================================
# Link Recovery Flow to Default Authentication Flow
# =============================================================================
# This configuration creates a new identification stage with recovery flow linked.
# After applying this Terraform configuration, run the script to update the binding:
#
#   ./scripts/link-recovery-flow.sh <AUTHENTIK_URL> <AUTHENTIK_TOKEN>
#
# The recovery flow will appear as "Forgot username or password?" link on the login page.
# =============================================================================

# Get the default authentication flow
data "authentik_flow" "default_authentication" {
  slug = "default-authentication-flow"
}

# Create a new identification stage with recovery flow linked
# This will replace the default identification stage in the authentication flow
resource "authentik_stage_identification" "default_auth_with_recovery" {
  depends_on = [authentik_flow.recovery]

  name          = "default-authentication-identification-with-recovery"
  user_fields   = ["email", "username"]
  recovery_flow = authentik_flow.recovery.uuid
}

# Output the stage ID for use with the linking script
output "identification_stage_id" {
  description = "ID of the identification stage with recovery flow (for linking script)"
  value       = authentik_stage_identification.default_auth_with_recovery.id
}

output "recovery_flow_slug" {
  description = "Slug of the recovery flow"
  value       = authentik_flow.recovery.slug
}

output "next_steps" {
  description = "Instructions to complete the recovery flow linking"
  value       = <<-EOT
    ✅ Identification stage with recovery flow created!

    Next step: Link it to the default authentication flow by running:

      ./scripts/link-recovery-flow.sh ${var.authentik_url != "" ? var.authentik_url : "https://auth.smadja.dev"} <AUTHENTIK_TOKEN>

    Or manually in the UI:
    1. Go to Flows → default-authentication-flow
    2. Click on the Identification stage
    3. Set "Recovery flow" to "default-recovery-flow"
    4. Save

    After linking, the "Forgot username or password?" link will appear on the login page.
  EOT
}
