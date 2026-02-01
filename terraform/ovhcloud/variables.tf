# =============================================================================
# OVHcloud Variables
# =============================================================================

variable "ovh_endpoint" {
  description = "OVH API endpoint (ovh-eu, ovh-ca, ovh-us)"
  type        = string
  default     = "ovh-eu"
}

variable "ovh_application_key" {
  description = "OVH Application Key"
  type        = string
  sensitive   = true
}

variable "ovh_application_secret" {
  description = "OVH Application Secret"
  type        = string
  sensitive   = true
}

variable "ovh_consumer_key" {
  description = "OVH Consumer Key"
  type        = string
  sensitive   = true
}

variable "ovh_cloud_project_id" {
  description = "OVH Public Cloud project ID (service_name)"
  type        = string
}

variable "s3_region" {
  description = "Object Storage S3 region (e.g. gra, sbg, bhs). Use a 3-AZ region for the 3 To free promo."
  type        = string
  default     = "gra"
}

variable "velero_bucket_name" {
  description = "Name of the S3 bucket for Velero backups (short-term, lifecycle 30j)"
  type        = string
  default     = "homelab-velero-backups"
}

# Bucket archive long terme (données utilisateur ZFS/Nextcloud « à ne pas perdre »)
variable "long_term_bucket_name" {
  description = "Name of the S3 bucket for long-term user data archive (ZFS, Nextcloud tagged data)"
  type        = string
  default     = "homelab-user-data-archive"
}

variable "long_term_expiration_days" {
  description = "Optional expiration in days for long-term bucket (null = no expiration, data kept indefinitely). Set e.g. 2555 for ~7 years."
  type        = number
  default     = null
}

variable "object_storage_user_description" {
  description = "Description for the Object Storage user"
  type        = string
  default     = "homelab-velero-s3"
}

# Budget alert (1 euro threshold)
variable "budget_alert_email" {
  description = "Email address to receive budget alerts when project spending reaches 1 euro"
  type        = string
}

# S3 credentials for the AWS provider (bucket creation).
# Leave empty on first run; after creating user+credential with -target, get from output and re-apply.
variable "ovh_s3_access_key" {
  description = "OVH S3 access key (from ovh_cloud_project_user_s3_credential). Set after first apply."
  type        = string
  default     = null
  sensitive   = true
}

variable "ovh_s3_secret_key" {
  description = "OVH S3 secret key (from ovh_cloud_project_user_s3_credential). Set after first apply."
  type        = string
  default     = null
  sensitive   = true
}
