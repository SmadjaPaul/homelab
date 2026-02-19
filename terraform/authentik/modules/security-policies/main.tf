# =============================================================================
# Security Policies — Rate limiting and geo restriction
# =============================================================================

# Rate limiting: bloquer après X tentatives échouées
resource "authentik_policy_reputation" "rate_limit_login" {
  count = var.enable_rate_limiting ? 1 : 0

  name              = "rate-limit-login"
  check_ip          = true
  check_username    = true
  threshold         = -5 # Négatif = bloquer après ce score
  execution_logging = true
}

# Policy d'expression pour rate limiting avancé
resource "authentik_policy_expression" "login_rate_limit" {
  count = var.enable_rate_limiting ? 1 : 0

  name       = "login-rate-limit-policy"
  expression = <<-EOT
    # Vérifier les tentatives récentes depuis la même IP
    recent_failed = 0
    for event in ak_logger.get_events(
        action='login_failed',
        client_ip=request.context['client_ip'],
        since='${var.rate_limit_window}'
    ):
        recent_failed += 1

    if recent_failed >= ${var.rate_limit_attempts}:
        ak_logger.info(f"Rate limit exceeded for IP {request.context['client_ip']}")
        return False

    return True
  EOT
}

# Geo-restriction: bloquer les pays non autorisés
resource "authentik_policy_expression" "geo_restriction" {
  count = var.enable_geo_restriction ? 1 : 0

  name       = "geo-restriction-policy"
  expression = <<-EOT
    allowed_countries = [${join(", ", [for c in var.allowed_countries : "'${c}'"])}]

    # Récupérer le pays depuis l'IP (si disponible)
    client_ip = request.context.get('client_ip', '')

    # Note: Nécessite GeoIP configuré dans Authentik
    # Pour l'instant, on laisse passer si on ne peut pas déterminer le pays
    country = request.context.get('geo', {}).get('country', 'unknown')

    if country != 'unknown' and country not in allowed_countries:
        ak_logger.warning(f"Access denied for country: {country}")
        return False

    return True
  EOT
}

# Policy pour détecter les connexions suspectes (heures inhabituelles)
resource "authentik_policy_expression" "suspicious_login_detection" {
  name       = "suspicious-login-detection"
  expression = <<-EOT
    import time

    current_hour = time.localtime().tm_hour

    # Bloquer les connexions entre 2h et 6h du matin sauf pour les admins
    if 2 <= current_hour <= 6:
        # Vérifier si l'utilisateur est admin
        for group in request.user.ak_groups.all():
            if group.name == 'admin':
                return True

        ak_logger.warning(f"Login attempt during restricted hours: {current_hour}:00")
        return False

    return True
  EOT
}

# Policy pour exiger MFA pour les groupes sensibles
resource "authentik_policy_expression" "require_mfa_for_sensitive" {
  name       = "require-mfa-sensitive-groups"
  expression = <<-EOT
    sensitive_groups = ['admin', 'professionnelle']

    # Vérifier si l'utilisateur est dans un groupe sensible
    user_is_sensitive = False
    for group in request.user.ak_groups.all():
        if group.name in sensitive_groups:
            user_is_sensitive = True
            break

    if not user_is_sensitive:
        return True

    # Vérifier si MFA est configuré
    # Note: Cette logique dépend de la configuration MFA dans Authentik
    # Par défaut, on autorise mais on loggue
    if not request.user.attributes.get('mfa_enabled', False):
        ak_logger.info(f"User {request.user.username} in sensitive group without MFA")
        # Vous pouvez changer en False pour bloquer
        return True

    return True
  EOT
}
