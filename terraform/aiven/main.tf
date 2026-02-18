terraform {
  required_version = ">= 1.0"

  required_providers {
    aiven = {
      source = "aiven/aiven"
    }
  }
}

provider "aiven" {
  api_token = var.aiven_token
}

variable "aiven_token" {
  description = "Aiven API token"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Aiven project name"
  type        = string
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

# =============================================================================
# Dragonfly (only if create_dragonfly = true)
# =============================================================================

resource "aiven_dragonfly" "dragonfly" {
  count = var.create_dragonfly ? 1 : 0

  project      = var.project_name
  cloud_name   = var.cloud_name
  plan         = "startup-4"
  service_name = "${var.service_name_prefix}-dragonfly"
}

output "dragonfly_service_name" {
  description = "Dragonfly service name"
  value       = var.create_dragonfly ? aiven_dragonfly.dragonfly[0].service_name : null
}

output "dragonfly_service_uri" {
  description = "Dragonfly service URI (sensitive)"
  sensitive   = true
  value       = var.create_dragonfly ? aiven_dragonfly.dragonfly[0].service_uri : null
}

# =============================================================================
# Kafka (only if create_kafka = true)
# =============================================================================

resource "aiven_kafka" "kafka" {
  count = var.create_kafka ? 1 : 0

  project      = var.project_name
  cloud_name   = var.cloud_name
  plan         = "startup-2"
  service_name = "${var.service_name_prefix}-kafka"
}

output "kafka_service_name" {
  description = "Kafka service name"
  value       = var.create_kafka ? aiven_kafka.kafka[0].service_name : null
}

output "kafka_service_uri" {
  description = "Kafka service URI (sensitive)"
  sensitive   = true
  value       = var.create_kafka ? aiven_kafka.kafka[0].service_uri : null
}

# =============================================================================
# Redis (only if create_redis = true)
# =============================================================================

resource "aiven_redis" "redis" {
  count = var.create_redis ? 1 : 0

  project      = var.project_name
  cloud_name   = var.cloud_name
  plan         = "startup-4"
  service_name = "${var.service_name_prefix}-redis"
}

output "redis_service_name" {
  description = "Redis service name"
  value       = var.create_redis ? aiven_redis.redis[0].service_name : null
}

output "redis_service_uri" {
  description = "Redis service URI (sensitive)"
  sensitive   = true
  value       = var.create_redis ? aiven_redis.redis[0].service_uri : null
}

# =============================================================================
# Outputs
# =============================================================================

output "project_name" {
  description = "Aiven project name"
  value       = var.project_name
}
