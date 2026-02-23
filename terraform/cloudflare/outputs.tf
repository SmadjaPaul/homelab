# =============================================================================
# Cloudflare Outputs (from modules)
# =============================================================================

output "zone_info" {
  description = "Cloudflare zone information"
  sensitive   = true
  value = {
    zone_id = module.global_config.zone_id
    domain  = module.global_config.domain
    status  = data.cloudflare_zone.main.status
  }
}

output "dns_records" {
  description = "DNS records managed by Terraform"
  sensitive   = true
  value = {
    root = module.dns.root_record
    www  = { name = "www", type = "CNAME", content = module.global_config.domain }
    note = "Kubernetes services DNS managed by external-dns in cluster"
  }
}

output "security_settings" {
  description = "Security settings applied (via security module)"
  value = {
    ssl_mode         = "strict"
    min_tls_version  = "1.2"
    always_use_https = true
    hsts_enabled     = true
    waf_rules        = "Configure manually in dashboard (5 free rules)"
  }
}

output "tunnel_info" {
  description = "Cloudflare Tunnel information (when enabled)"
  sensitive   = true
  value = var.enable_tunnel ? {
    tunnel_id   = local.tunnel_id
    tunnel_name = "homelab-tunnel"
    cname       = "${local.tunnel_id}.cfargotunnel.com"
    status      = "Created - install cloudflared to connect"
    } : {
    status = "Tunnel disabled - set enable_tunnel = true when ready"
  }
}

output "tunnel_token" {
  description = "Cloudflare Tunnel token for cloudflared (sensitive)"
  sensitive   = true
  value       = var.enable_tunnel ? local.tunnel_secret : ""
}

output "service_urls" {
  description = "URLs for homelab services"
  sensitive   = true
  value = { for k, v in var.homelab_services : k => {
    url         = "https://${v.subdomain}.${module.global_config.domain}"
    description = v.description
    internal    = v.internal
  } }
}

output "next_steps" {
  description = "Next steps after apply"
  value       = <<-EOT

    ✅ Cloudflare configuration applied!

    Next steps:
    1. Security settings are active (SSL strict, HSTS, WAF rules)
    2. DNS records created for all services

    When infrastructure is ready:
    1. Set enable_tunnel = true in terraform.tfvars
    2. Add cloudflare_account_id and tunnel_secret
    3. Run: terraform apply
    4. Install cloudflared and run: cloudflared tunnel run homelab-tunnel

  EOT
}
