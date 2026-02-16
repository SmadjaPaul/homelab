# =============================================================================
# RBAC Groups — admin, family-validated
# =============================================================================
# Aligné sur docs-site/docs/advanced/planning-conclusions.md et inspiré de
# ghndrx/authentik-terraform (rbac-groups) et K-FOSS (Groups/).
# Matrice d'accès : voir docs/RBAC.md (ou output rbac_matrix_note).
# =============================================================================

# Admin : accès aux apps d'administration (Omni, LiteLLM, OpenClaw, etc.)
# Non exposées aux utilisateurs famille ; réservé au groupe admin.
resource "authentik_group" "admin" {
  name         = "admin"
  is_superuser = false
  attributes = jsonencode({
    description = "Administrators: access to Omni, LiteLLM, OpenClaw, Cloudflare Access IdP"
    role        = "admin"
  })
}

# Family-validated : utilisateurs validés manuellement pour les apps famille
# (Nextcloud, Vaultwarden, etc.). Utilisé aussi dans admin_and_validated pour
# les apps exigeant admin + validated.
resource "authentik_group" "family_validated" {
  name         = "family-validated"
  is_superuser = false
  attributes = jsonencode({
    description = "Manually validated family users: access to family apps (Nextcloud, etc.)"
    role        = "family-validated"
  })
}

# Professionnelle : utilisateurs pro, accès aux services métier (Odoo, etc.)
# Distinct de family-validated. Voir docs/authentik-rbac-spec.md.
resource "authentik_group" "professionnelle" {
  name         = "professionnelle"
  is_superuser = false
  attributes = jsonencode({
    description = "Professional users: access to Odoo and other business apps"
    role        = "professionnelle"
  })
}
