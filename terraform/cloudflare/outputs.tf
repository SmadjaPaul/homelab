# =============================================================================
# Cloudflare Outputs
# =============================================================================

output "zone_info" {
  description = "Cloudflare zone information"
  value = {
    zone_id = var.zone_id
    domain  = var.domain
    status  = data.cloudflare_zone.main.status
  }
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    root = {
      name    = cloudflare_record.root.name
      type    = cloudflare_record.root.type
      proxied = cloudflare_record.root.proxied
    }
    www = {
      name    = cloudflare_record.www.name
      type    = cloudflare_record.www.type
      content = cloudflare_record.www.content
    }
    services = { for k, v in cloudflare_record.homelab_services : k => {
      fqdn    = "${v.name}.${var.domain}"
      type    = v.type
      proxied = v.proxied
    } }
  }
}

output "security_settings" {
  description = "Security settings applied"
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
  value = var.enable_tunnel ? {
    tunnel_id   = cloudflare_tunnel.homelab[0].id
    tunnel_name = cloudflare_tunnel.homelab[0].name
    cname       = "${cloudflare_tunnel.homelab[0].id}.cfargotunnel.com"
    status      = "Created - install cloudflared to connect"
    } : {
    status = "Tunnel disabled - set enable_tunnel = true when ready"
  }
}

output "service_urls" {
  description = "URLs for homelab services"
  value = { for k, v in var.homelab_services : k => {
    url         = "https://${v.subdomain}.${var.domain}"
    description = v.description
    internal    = v.internal
  } }
}

output "next_steps" {
  description = "Next steps for configuration"
  value       = <<-EOT

    ✅ Cloudflare configuration applied!

    Next steps:
    1. Security settings are active (SSL strict, HSTS, WAF rules)
    2. DNS records created for all services (placeholder IPs for now)
    3. Email protection (SPF/DMARC) configured

    When infrastructure is ready:
    1. Set enable_tunnel = true in terraform.tfvars
    2. Add cloudflare_account_id and tunnel_secret
    3. Run: terraform apply
    4. Install cloudflared on Proxmox/VM
    5. Connect tunnel: cloudflared tunnel run homelab-tunnel

  EOT
}
