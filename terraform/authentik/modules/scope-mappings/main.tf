# =============================================================================
# Scope Mappings — OIDC claims pour Cloudflare Access et autres providers
# =============================================================================

# Scope mapping standard pour openid
resource "authentik_property_mapping_provider_scope" "openid" {
  name       = "openid-scope"
  scope_name = "openid"
  expression = <<-EOT
    return {
        "sub": request.user.pk,
    }
  EOT
}

# Scope mapping pour email
resource "authentik_property_mapping_provider_scope" "email" {
  name       = "email-scope"
  scope_name = "email"
  expression = <<-EOT
    return {
        "email": request.user.email,
        "email_verified": True,
    }
  EOT
}

# Scope mapping pour profile
resource "authentik_property_mapping_provider_scope" "profile" {
  name       = "profile-scope"
  scope_name = "profile"
  expression = <<-EOT
    return {
        "name": request.user.name,
        "preferred_username": request.user.username,
        "nickname": request.user.username,
    }
  EOT
}

# Scope mapping CRITIQUE pour Cloudflare Access: les groupes
resource "authentik_property_mapping_provider_scope" "groups" {
  count = var.create_cloudflare_access_mappings ? 1 : 0

  name       = "groups-scope"
  scope_name = "groups"
  expression = <<-EOT
    # Récupérer tous les groupes de l'utilisateur
    groups = []
    for group in request.user.ak_groups.all():
        groups.append(group.name)

    return {
        "groups": groups,
    }
  EOT
}

# Scope mapping personnalisé pour Cloudflare Access avec attributs supplémentaires
resource "authentik_property_mapping_provider_scope" "cloudflare_access" {
  count = var.create_cloudflare_access_mappings ? 1 : 0

  name       = "cloudflare-access-scope"
  scope_name = "cf_access"
  expression = <<-EOT
    # Format compatible Cloudflare Access
    groups = []
    for group in request.user.ak_groups.all():
        groups.append(group.name)

    # Attributs personnalisés
    custom_claims = ${jsonencode(var.additional_claims)}

    return {
        "sub": str(request.user.pk),
        "email": request.user.email or request.user.username + "@smadja.dev",
        "name": request.user.name,
        "groups": groups,
        "custom_claims": custom_claims,
    }
  EOT
}

# Data source pour récupérer les mappings par défaut d'Authentik
data "authentik_property_mapping_provider_scope" "openid_default" {
  managed = "goauthentik.io/providers/oauth2/scope-openid"
}

data "authentik_property_mapping_provider_scope" "email_default" {
  managed = "goauthentik.io/providers/oauth2/scope-email"
}

data "authentik_property_mapping_provider_scope" "profile_default" {
  managed = "goauthentik.io/providers/oauth2/scope-profile"
}
