# =============================================================================
# Policies for Application Access Control
# =============================================================================
# The goauthentik/authentik provider does not expose "policy_group_membership"
# as a resource; we use expression policies to enforce group membership.
# Ref: https://registry.terraform.io/providers/goauthentik/authentik/latest/docs

# Policy: Only admin group can access admin applications (e.g. Omni)
resource "authentik_policy_expression" "admin_only" {
  name       = "admin-group-only"
  expression = <<-EOT
    for group in request.user.ak_groups.all():
        if group.name == 'admin':
            return True
    return False
  EOT
}

# Policy: Only validated family members can access family applications
resource "authentik_policy_expression" "family_validated_only" {
  name       = "family-validated-only"
  expression = <<-EOT
    for group in request.user.ak_groups.all():
        if group.name == 'family-validated':
            return True
    return False
  EOT
}

# Expression policy: Require both admin group AND family-validated group
resource "authentik_policy_expression" "admin_and_validated" {
  name       = "admin-and-validated"
  expression = <<-EOT
    has_admin = False
    has_validated = False
    for group in request.user.ak_groups.all():
        if group.name == 'admin':
            has_admin = True
        if group.name == 'family-validated':
            has_validated = True
    return has_admin and has_validated
  EOT
}
