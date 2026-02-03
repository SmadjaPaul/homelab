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

# Geo-restriction: allow traffic only from these countries (ISO 3166-1 Alpha 2)
# Empty list = no geo restriction (worldwide)
variable "allowed_countries" {
  description = "Allow access only from these country codes (e.g. [\"FR\"] for France only). Empty = no restriction."
  type        = list(string)
  default     = ["FR"]
}

variable "enable_geo_restriction" {
  description = "Enable WAF rule to block traffic from countries not in allowed_countries"
  type        = bool
  default     = true
}

# Homelab service subdomains
variable "homelab_services" {
  description = "Homelab services to expose via Cloudflare Tunnel"
  type = map(object({
    subdomain   = string
    description = string
    internal    = bool # true = requires Cloudflare Access, false = public
    user_facing = bool # true = visible to users, false = admin only
  }))
  default = {
    # ===========================================
    # USER-FACING SERVICES (visible to users)
    # ===========================================
    homepage = {
      subdomain   = "home"
      description = "Homepage dashboard"
      internal    = false
      user_facing = true
    }
    authentik = {
      subdomain   = "auth"
      description = "Authentik SSO"
      internal    = false
      user_facing = true
    }
    status = {
      subdomain   = "status"
      description = "Uptime Kuma status page"
      internal    = false
      user_facing = true
    }
    feedback = {
      subdomain   = "feedback"
      description = "Fider feedback portal"
      internal    = false
      user_facing = true
    }
    docs = {
      subdomain   = "docs"
      description = "Docusaurus documentation"
      internal    = false
      user_facing = true
    }

    # ===========================================
    # TECHNICAL SERVICES (admin only)
    # ===========================================
    grafana = {
      subdomain   = "grafana"
      description = "Grafana dashboards"
      internal    = true
      user_facing = false
    }
    prometheus = {
      subdomain   = "prometheus"
      description = "Prometheus metrics"
      internal    = true
      user_facing = false
    }
    alertmanager = {
      subdomain   = "alerts"
      description = "Alertmanager"
      internal    = true
      user_facing = false
    }
    proxmox = {
      subdomain   = "proxmox"
      description = "Proxmox VE management"
      internal    = true
      user_facing = false
    }
    argocd = {
      subdomain   = "argocd"
      description = "ArgoCD GitOps"
      internal    = true
      user_facing = false
    }
    omni = {
      subdomain   = "omni"
      description = "Omni Talos management"
      internal    = true
      user_facing = false
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
