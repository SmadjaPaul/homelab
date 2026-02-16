# Expression policies pour le contrôle d'accès aux applications

resource "authentik_policy_expression" "admin_only" {
  name       = "admin-group-only"
  expression = <<-EOT
    for group in request.user.ak_groups.all():
        if group.name == 'admin':
            return True
    return False
  EOT
}

resource "authentik_policy_expression" "family_validated_only" {
  name       = "family-validated-only"
  expression = <<-EOT
    for group in request.user.ak_groups.all():
        if group.name == 'family-validated':
            return True
    return False
  EOT
}

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

resource "authentik_policy_expression" "block_public_enrollment" {
  name       = "block-public-enrollment"
  expression = <<-EOT
    if 'invitation' in request.context or 'invitation_token' in request.context:
        return True
    return False
  EOT
}

# Professionnelle : accès réservé au groupe professionnelle (Odoo, etc.)
resource "authentik_policy_expression" "professionnelle_only" {
  name       = "professionnelle-group-only"
  expression = <<-EOT
    for group in request.user.ak_groups.all():
        if group.name == 'professionnelle':
            return True
    return False
  EOT
}
