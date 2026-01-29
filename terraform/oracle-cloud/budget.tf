# =============================================================================
# Oracle Cloud Budget and Billing Alerts
# Ensures you're notified before any unexpected charges
# =============================================================================

# Budget for the entire tenancy
resource "oci_budget_budget" "homelab" {
  compartment_id = var.compartment_id
  amount         = 1 # 1 EUR budget
  reset_period   = "MONTHLY"
  display_name   = "homelab-free-tier-budget"
  description    = "Budget to monitor homelab spending and ensure we stay within free tier"

  # Target the root compartment (entire tenancy)
  target_type = "COMPARTMENT"
  targets     = [var.compartment_id]

  freeform_tags = var.tags
}

# Alert at 50% (0.50 EUR) - Early warning
resource "oci_budget_alert_rule" "warning_50_percent" {
  budget_id      = oci_budget_budget.homelab.id
  display_name   = "50-percent-warning"
  type           = "ACTUAL"
  threshold      = 50
  threshold_type = "PERCENTAGE"

  recipients = var.budget_alert_email
  message    = "⚠️ HOMELAB ALERT: You've reached 50% of your 1 EUR budget (0.50 EUR spent). Check your Oracle Cloud usage!"

  freeform_tags = var.tags
}

# Alert at 80% (0.80 EUR) - Getting close
resource "oci_budget_alert_rule" "warning_80_percent" {
  budget_id      = oci_budget_budget.homelab.id
  display_name   = "80-percent-warning"
  type           = "ACTUAL"
  threshold      = 80
  threshold_type = "PERCENTAGE"

  recipients = var.budget_alert_email
  message    = "🚨 HOMELAB ALERT: You've reached 80% of your 1 EUR budget (0.80 EUR spent). Review resources immediately!"

  freeform_tags = var.tags
}

# Alert at 100% (1 EUR) - Budget reached
resource "oci_budget_alert_rule" "critical_100_percent" {
  budget_id      = oci_budget_budget.homelab.id
  display_name   = "100-percent-critical"
  type           = "ACTUAL"
  threshold      = 100
  threshold_type = "PERCENTAGE"

  recipients = var.budget_alert_email
  message    = "🔴 CRITICAL: Homelab has reached 1 EUR budget! You may be exceeding free tier limits. Check Oracle Cloud Console NOW!"

  freeform_tags = var.tags
}

# Forecast alert - warns if projected to exceed budget
resource "oci_budget_alert_rule" "forecast_warning" {
  budget_id      = oci_budget_budget.homelab.id
  display_name   = "forecast-exceed-warning"
  type           = "FORECAST"
  threshold      = 100
  threshold_type = "PERCENTAGE"

  recipients = var.budget_alert_email
  message    = "📊 FORECAST ALERT: Based on current usage, your homelab is projected to exceed the 1 EUR budget this month!"

  freeform_tags = var.tags
}
