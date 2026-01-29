# =============================================================================
# Cloudflare Variables
# =============================================================================

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone permissions"
  type        = string
  sensitive   = true
}

variable "zone_id" {
  description = "Cloudflare Zone ID for smadja.dev"
  type        = string
  default     = "bda8e2196f6b4f1684c6c9c06d996109"
}

variable "domain" {
  description = "Root domain"
  type        = string
  default     = "smadja.dev"
}

# Homelab service subdomains
variable "homelab_services" {
  description = "Homelab services to expose via Cloudflare Tunnel"
  type = map(object({
    subdomain   = string
    description = string
    internal    = bool # true = only via Tunnel, false = public
  }))
  default = {
    # Monitoring
    grafana = {
      subdomain   = "grafana"
      description = "Grafana dashboards"
      internal    = false
    }
    prometheus = {
      subdomain   = "prometheus"
      description = "Prometheus metrics"
      internal    = true
    }
    alertmanager = {
      subdomain   = "alerts"
      description = "Alertmanager"
      internal    = true
    }

    # Infrastructure
    proxmox = {
      subdomain   = "proxmox"
      description = "Proxmox VE management"
      internal    = true
    }
    argocd = {
      subdomain   = "argocd"
      description = "ArgoCD GitOps"
      internal    = false
    }

    # Identity
    keycloak = {
      subdomain   = "auth"
      description = "Keycloak SSO"
      internal    = false
    }

    # Apps
    homepage = {
      subdomain   = "home"
      description = "Homepage dashboard"
      internal    = false
    }
    status = {
      subdomain   = "status"
      description = "Uptime Kuma status page"
      internal    = false
    }
    feedback = {
      subdomain   = "feedback"
      description = "Fider feedback portal"
      internal    = false
    }
  }
}

# Oracle Cloud IPs (will be populated after VMs are created)
variable "oci_management_ip" {
  description = "OCI Management VM public IP"
  type        = string
  default     = "" # Will be set after VM creation
}

variable "oci_node_ips" {
  description = "OCI K8s node public IPs"
  type        = list(string)
  default     = [] # Will be set after VM creation
}

# Proxmox (local network, accessed via Tunnel)
variable "proxmox_local_ip" {
  description = "Proxmox local IP address"
  type        = string
  default     = "192.168.68.51"
}
