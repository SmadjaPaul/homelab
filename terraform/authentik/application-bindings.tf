# =============================================================================
# Application Bindings - Link Groups and Policies to Applications
# =============================================================================
# These bindings control who can access which applications.
# Note: Group access is typically managed via Policy Bindings with
# Group Membership policies, or manually in the UI.

# Bind admin-only policy to Omni application
# This ensures only users in the "admin" group can access Omni
resource "authentik_policy_binding" "omni_admin_policy" {
  target  = authentik_application.omni.uuid
  policy  = authentik_policy_expression.admin_only.id
  order   = 0
  negate  = false
  enabled = true
  timeout = 30
}

# Output instructions for manual group binding (if needed)
# Some versions of the Terraform provider may not support direct group-to-application binding
# In that case, bind groups manually in the UI:
# Applications → Omni → Policy / Group / User Bindings → Add group "admin"
output "omni_group_binding_note" {
  description = "Instructions to bind admin group to Omni if not done automatically"
  value       = <<-EOT
    ✅ Admin-only policy bound to Omni application.

    To also bind the admin group directly (recommended):
    1. Go to Applications → Omni
    2. Click on "Policy / Group / User Bindings"
    3. Click "Create"
    4. Select Group: "admin"
    5. Order: 0
    6. Save

    This ensures users in the admin group can access Omni.
  EOT
}
