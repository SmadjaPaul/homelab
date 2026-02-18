# =============================================================================
# Aiven Main Configuration
# =============================================================================

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

# =============================================================================
# Dragonfly (optional)
# =============================================================================

resource "aiven_dragonfly" "dragonfly" {
  count = var.create_dragonfly ? 1 : 0

  project      = var.project_name
  cloud_name   = var.cloud_name
  plan         = "startup-4"
  service_name = "${var.service_name_prefix}-dragonfly"
}

# =============================================================================
# Kafka (optional)
# =============================================================================

resource "aiven_kafka" "kafka" {
  count = var.create_kafka ? 1 : 0

  project      = var.project_name
  cloud_name   = var.cloud_name
  plan         = "startup-2"
  service_name = "${var.service_name_prefix}-kafka"
}

# =============================================================================
# Redis (optional)
# =============================================================================

resource "aiven_redis" "redis" {
  count = var.create_redis ? 1 : 0

  project      = var.project_name
  cloud_name   = var.cloud_name
  plan         = "startup-4"
  service_name = "${var.service_name_prefix}-redis"
}

# =============================================================================
# Outputs
# =============================================================================

output "project_name" {
  description = "Aiven project name"
  value       = var.project_name
}

output "dragonfly_info" {
  description = "Dragonfly service information"
  value = var.create_dragonfly ? {
    service_name = aiven_dragonfly.dragonfly[0].service_name
    service_uri  = aiven_dragonfly.dragonfly[0].service_uri
    state        = aiven_dragonfly.dragonfly[0].state
  } : null
}

output "kafka_info" {
  description = "Kafka service information"
  value = var.create_kafka ? {
    service_name = aiven_kafka.kafka[0].service_name
    service_uri  = aiven_kafka.kafka[0].service_uri
    state        = aiven_kafka.kafka[0].state
  } : null
}

output "redis_info" {
  description = "Redis service information"
  value = var.create_redis ? {
    service_name = aiven_redis.redis[0].service_name
    service_uri  = aiven_redis.redis[0].service_uri
    state        = aiven_redis.redis[0].state
  } : null
}

output "next_steps" {
  description = "Next steps after apply"
  value       = <<-EOT

    ✅ Aiven services configured!

    To create services, set the appropriate flags in terraform.tfvars:
    - create_dragonfly = true
    - create_kafka = true
    - create_redis = true

    Then run: terraform apply

    Note: Service URIs are sensitive - use terraform output -sensitive to view them.

  EOT
}
