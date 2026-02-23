# =============================================================================
# Grafana Cloud Terraform Configuration
# =============================================================================
# Manages Grafana Cloud resources: dashboards
# Uses Grafana Cloud free tier
# =============================================================================

# =============================================================================
# Variables
# =============================================================================

# (Moved auth variables to provider.tf)

variable "org_slug" {
  description = "Grafana Cloud organization slug"
  type        = string
  default     = ""
}

variable "stack_slug" {
  description = "Grafana Cloud stack slug"
  type        = string
  default     = ""
}

# =============================================================================
# Grafana Cloud Credentials & Data
# =============================================================================

data "grafana_cloud_stack" "this" {
  provider = grafana.cloud
  slug     = var.stack_slug != "" ? var.stack_slug : var.org_slug
}

resource "grafana_cloud_access_policy" "k8s_monitoring" {
  provider = grafana.cloud
  region   = data.grafana_cloud_stack.this.region_slug
  name     = "k8s-monitoring-${data.grafana_cloud_stack.this.slug}"

  scopes = [
    "metrics:write",
    "logs:write",
    "traces:write",
    "profiles:write"
  ]

  realm {
    type       = "org"
    identifier = data.grafana_cloud_stack.this.org_id
  }
}

resource "grafana_cloud_access_policy_token" "k8s_monitoring" {
  provider         = grafana.cloud
  region           = data.grafana_cloud_stack.this.region_slug
  access_policy_id = grafana_cloud_access_policy.k8s_monitoring.policy_id
  name             = "k8s-monitoring-${data.grafana_cloud_stack.this.slug}-token"
}

resource "random_password" "grafana_admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# =============================================================================
# Doppler Secrets Sync
# =============================================================================

resource "doppler_secret" "grafana_cloud_prom_url" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "GRAFANA_CLOUD_PROM_URL"
  value   = "${data.grafana_cloud_stack.this.prometheus_url}/api/prom/push"
}

resource "doppler_secret" "grafana_cloud_prom_username" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "GRAFANA_CLOUD_PROM_USERNAME"
  value   = data.grafana_cloud_stack.this.prometheus_user_id
}

resource "doppler_secret" "grafana_cloud_loki_url" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "GRAFANA_CLOUD_LOKI_URL"
  value   = "${data.grafana_cloud_stack.this.logs_url}/loki/api/v1/push"
}

resource "doppler_secret" "grafana_cloud_loki_username" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "GRAFANA_CLOUD_LOKI_USERNAME"
  value   = data.grafana_cloud_stack.this.logs_user_id
}

resource "doppler_secret" "grafana_cloud_api_key" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "GRAFANA_CLOUD_API_KEY"
  value   = grafana_cloud_access_policy_token.k8s_monitoring.token
}

resource "doppler_secret" "grafana_admin_user" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "GRAFANA_ADMIN_USER"
  value   = "admin"
}

resource "doppler_secret" "grafana_admin_password" {
  project = var.doppler_project
  config  = var.doppler_environment
  name    = "GRAFANA_ADMIN_PASSWORD"
  value   = random_password.grafana_admin.result
}

# =============================================================================
# Dashboards
# =============================================================================

# =============================================================================
# Dashboards
# =============================================================================

# Kubernetes Cluster Overview
resource "grafana_dashboard" "kubernetes_cluster" {
  config_json = jsonencode({
    title         = "Kubernetes Cluster Overview"
    uid           = "homelab-k8s-cluster"
    tags          = ["kubernetes", "cluster", "monitoring"]
    timezone      = "browser"
    schemaVersion = 16
    version       = 1

    refresh = "30s"

    panels = [
      # CPU Usage
      {
        id      = 1
        title   = "CPU Usage"
        type    = "timeseries"
        gridPos = { x = 0, y = 0, w = 12, h = 8 }
        fieldConfig = {
          defaults = {
            unit = "percent"
            min  = 0
            max  = 100
          }
        }
        options = {
          legend = { displayMode = "table", placement = "bottom" }
        }
        targets = [
          {
            expr  = "sum(rate(container_cpu_usage_seconds_total{job=\"kubelet\"}[5m])) by (node) * 100"
            refId = "A"
          }
        ]
      },
      # Memory Usage
      {
        id      = 2
        title   = "Memory Usage"
        type    = "timeseries"
        gridPos = { x = 12, y = 0, w = 12, h = 8 }
        fieldConfig = {
          defaults = {
            unit = "bytes"
          }
        }
        targets = [
          {
            expr  = "sum(container_memory_working_set_bytes{job=\"kubelet\", container!=\"\"}) by (node)"
            refId = "A"
          }
        ]
      },
      # Pod Status
      {
        id      = 3
        title   = "Pod Status"
        type    = "stat"
        gridPos = { x = 0, y = 8, w = 8, h = 6 }
        options = { colorMode = "background" }
        fieldConfig = {
          defaults = {
            mappings = [
              { type = "value", options = { "1" = { text = "Running", color = "green" } } },
              { type = "value", options = { "0" = { text = "Not Running", color = "red" } } }
            ]
          }
        }
        targets = [
          {
            expr  = "sum(kube_pod_status_phase{phase=\"Running\"})"
            refId = "A"
          }
        ]
      },
      # Network I/O
      {
        id      = 4
        title   = "Network I/O"
        type    = "timeseries"
        gridPos = { x = 8, y = 8, w = 16, h = 8 }
        fieldConfig = {
          defaults = {
            unit = "Bps"
          }
        }
        targets = [
          {
            expr         = "sum(rate(container_network_receive_bytes_total[5m])) by (node)"
            refId        = "A"
            legendFormat = "RX"
          },
          {
            expr         = "-sum(rate(container_network_transmit_bytes_total[5m])) by (node)"
            refId        = "B"
            legendFormat = "TX"
          }
        ]
      }
    ]

    templating = {
      list = [
        {
          name    = "cluster"
          type    = "datasource"
          query   = "prometheus"
          current = { value = "Prometheus", text = "Prometheus" }
        }
      ]
    }

    time       = { from = "now-6h", to = "now" }
    timepicker = { refresh_intervals = ["10s", "30s", "1m", "5m"] }
  })
}

# Kubernetes Pods Overview
resource "grafana_dashboard" "kubernetes_pods" {
  config_json = jsonencode({
    title         = "Kubernetes Pods"
    uid           = "homelab-k8s-pods"
    tags          = ["kubernetes", "pods"]
    timezone      = "browser"
    schemaVersion = 16
    version       = 1

    refresh = "30s"

    panels = [
      {
        id      = 1
        title   = "Pod CPU Usage"
        type    = "timeseries"
        gridPos = { x = 0, y = 0, w = 12, h = 8 }
        fieldConfig = {
          defaults = {
            unit = "percent"
            min  = 0
          }
        }
        targets = [
          {
            expr  = "sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace, pod) * 100"
            refId = "A"
          }
        ]
      },
      {
        id      = 2
        title   = "Pod Memory Usage"
        type    = "timeseries"
        gridPos = { x = 12, y = 0, w = 12, h = 8 }
        fieldConfig = {
          defaults = {
            unit = "bytes"
          }
        }
        targets = [
          {
            expr  = "sum(container_memory_working_set_bytes) by (namespace, pod)"
            refId = "A"
          }
        ]
      },
      {
        id      = 3
        title   = "Pod Status"
        type    = "table"
        gridPos = { x = 0, y = 8, w = 24, h = 8 }
        targets = [
          {
            expr   = "kube_pod_status_phase"
            format = "table"
            refId  = "A"
          }
        ]
      }
    ]

    templating = {
      list = [
        {
          name    = "namespace"
          type    = "query"
          query   = "label_values(kube_pod_info, namespace)"
          refresh = 1
          current = { value = "infra", text = "infra" }
        }
      ]
    }
  })
}

# Kubernetes Namespaces
resource "grafana_dashboard" "kubernetes_namespaces" {
  config_json = jsonencode({
    title         = "Kubernetes Namespaces"
    uid           = "homelab-k8s-namespaces"
    tags          = ["kubernetes", "namespaces"]
    timezone      = "browser"
    schemaVersion = 16
    version       = 1

    panels = [
      {
        id      = 1
        title   = "CPU by Namespace"
        type    = "bargauge"
        gridPos = { x = 0, y = 0, w = 12, h = 8 }
        fieldConfig = {
          defaults = {
            unit = "percent"
            min  = 0
          }
        }
        targets = [
          {
            expr  = "sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace) * 100"
            refId = "A"
          }
        ]
      },
      {
        id      = 2
        title   = "Memory by Namespace"
        type    = "bargauge"
        gridPos = { x = 12, y = 0, w = 12, h = 8 }
        fieldConfig = {
          defaults = {
            unit = "bytes"
          }
        }
        targets = [
          {
            expr  = "sum(container_memory_working_set_bytes) by (namespace)"
            refId = "A"
          }
        ]
      }
    ]
  })
}

# =============================================================================
# Outputs
# =============================================================================

output "grafana_url" {
  description = "Grafana Cloud URL"
  value       = "https://${var.org_slug}.grafana.net"
}

output "dashboards" {
  description = "Created dashboard UIDs"
  value = {
    kubernetes_cluster    = grafana_dashboard.kubernetes_cluster.uid
    kubernetes_pods       = grafana_dashboard.kubernetes_pods.uid
    kubernetes_namespaces = grafana_dashboard.kubernetes_namespaces.uid
  }
}
