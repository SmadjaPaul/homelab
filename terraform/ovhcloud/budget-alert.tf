# =============================================================================
# OVHcloud Budget Alert
# Alerte par email dès 1 € de dépense sur le projet Public Cloud
# =============================================================================

resource "ovh_cloud_project_alerting" "budget_1_euro" {
  service_name      = var.ovh_cloud_project_id
  email             = var.budget_alert_email
  monthly_threshold = 1    # 1 euro
  delay             = 3600 # vérification toutes les heures (en secondes)
}
