# =============================================================================
# OVHcloud Object Storage – Limites gratuites (promo 3-AZ)
# Documente les quotas pour rester dans l’offre gratuite et éviter les dépassements
# =============================================================================
# Référence: https://www.ovhcloud.com/fr/public-cloud/prices/
# Promo: 3 premiers Tio/mois offerts (Object Storage 3-AZ) du 01/11/2025 au 31/01/2026.
# Après le 31/01/2026 : la promotion s’arrête ; le stockage n’est plus offert et sera
# facturé aux tarifs standard (par Go). Les 3 To ne restent pas gratuits après expiration.
# Au-delà de 3 Tio pendant la promo : facturation au Go. Alerte budget 1 € + lifecycle 30j.
# =============================================================================

locals {
  # Limites documentées pour l’Object Storage 3-AZ (homelab Velero)
  object_storage_free_limits = {
    storage_tb_per_month = 3            # 3 Tio/mois offerts (promo 3-AZ), partagés entre Velero et archive long terme
    promo_end_date       = "2026-01-31" # Après cette date : facturation aux tarifs standard (plus de 3 To offerts)
    region               = var.s3_region
    note                 = "Au-delà de 3 Tio, facturation au Go. Après 31/01/2026 : tout le stockage facturé au standard. Velero: lifecycle 30j. Archive: pas d'expiration par défaut."
  }
}

output "object_storage_quota_limits" {
  description = "Limites gratuites Object Storage OVH (pour rester sous le seuil payant)"
  value       = local.object_storage_free_limits
}
