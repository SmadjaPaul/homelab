# =============================================================================
# Aiven Variables
# =============================================================================

variable "aiven_token" {
  description = "Aiven API token"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Aiven project name"
  type        = string
  default     = "homelab-smadja"
}

variable "cloud_name" {
  description = "Cloud provider region"
  type        = string
  default     = "google-europe-west1"
}

variable "service_name_prefix" {
  description = "Prefix for service names"
  type        = string
  default     = "homelab"
}

# =============================================================================
# Service Creation Flags
# =============================================================================

variable "create_dragonfly" {
  description = "Whether to create Dragonfly service"
  type        = bool
  default     = false
}

variable "create_kafka" {
  description = "Whether to create Kafka service"
  type        = bool
  default     = false
}

variable "create_redis" {
  description = "Whether to create Redis service"
  type        = bool
  default     = false
}
