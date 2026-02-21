# =============================================================================
# Cloudflare DNS Records
# =============================================================================

# Root domain - placeholder (can be disabled if already exists)
resource "cloudflare_dns_record" "root" {
  count = var.create_root_record ? 1 : 0

  zone_id = var.zone_id
  name    = "@"
  content = "192.0.2.1"
  type    = "A"
  proxied = true
  ttl     = 1
  comment = "Root domain - placeholder for Cloudflare Tunnel"


  lifecycle {
    ignore_changes = [content]
  }
}

# WWW redirect to root
resource "cloudflare_dns_record" "www" {
  zone_id = var.zone_id
  name    = "www"
  content = var.domain
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = "WWW redirect to root"

}

# Placeholder A records when tunnel is disabled
resource "cloudflare_dns_record" "homelab_services" {
  for_each = var.enable_tunnel ? {} : var.homelab_services

  zone_id = var.zone_id
  name    = each.value.subdomain
  content = "192.0.2.1"
  type    = "A"
  proxied = true
  ttl     = 1
  comment = each.value.description

}

# CNAMEs to tunnel (when enabled)
resource "cloudflare_dns_record" "tunnel_cname" {
  for_each = var.enable_tunnel ? var.homelab_services : {}

  zone_id = var.zone_id
  name    = each.value.subdomain
  content = "${var.tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = "${each.value.description} (via Tunnel)"

}

# OKE Services DNS is managed by external-dns in Kubernetes
# (via gateway-httproute source + external-dns.alpha.kubernetes.io/target annotation)

# Stream (Comet) - DNS only for direct IP access (no Cloudflare proxy)
resource "cloudflare_dns_record" "stream" {
  count = var.enable_stream_record && var.oci_management_ip != "" ? 1 : 0

  zone_id = var.zone_id
  name    = "stream"
  content = var.oci_management_ip
  type    = "A"
  proxied = false
  ttl     = 300
  comment = "Comet streaming service - direct IP (no proxy)"
}

# SPF
resource "cloudflare_dns_record" "spf" {
  zone_id = var.zone_id
  name    = "@"
  content = "v=spf1 include:spf.migadu.com -all"
  type    = "TXT"
  ttl     = 3600
  comment = "SPF - Migadu email"

}

# DMARC
resource "cloudflare_dns_record" "dmarc" {
  zone_id = var.zone_id
  name    = "_dmarc"
  content = "v=DMARC1; p=quarantine;"
  type    = "TXT"
  ttl     = 3600
  comment = "DMARC - quarantine unaligned messages"

}

# -----------------------------------------------------------------------------
# Migadu Email DNS Records
# -----------------------------------------------------------------------------

# Migadu verification TXT record
resource "cloudflare_dns_record" "migadu_verification" {
  zone_id = var.zone_id
  name    = "@"
  content = "hosted-email-verify=sd1bfbhe"
  type    = "TXT"
  ttl     = 3600
  comment = "Migadu domain verification"

}

# MX records - Required for Migadu domain activation
resource "cloudflare_dns_record" "migadu_mx1" {
  zone_id  = var.zone_id
  name     = "@"
  type     = "MX"
  content  = "aspmx1.migadu.com"
  priority = 10
  ttl      = 3600
  comment  = "Migadu primary MX"

}

resource "cloudflare_dns_record" "migadu_mx2" {
  zone_id  = var.zone_id
  name     = "@"
  type     = "MX"
  content  = "aspmx2.migadu.com"
  priority = 20
  ttl      = 3600
  comment  = "Migadu secondary MX"

}

# DKIM records
resource "cloudflare_dns_record" "migadu_dkim1" {
  zone_id = var.zone_id
  name    = "key1._domainkey"
  content = "key1.${var.domain}._domainkey.migadu.com"
  type    = "CNAME"
  ttl     = 3600
  comment = "Migadu DKIM key 1"

}

resource "cloudflare_dns_record" "migadu_dkim2" {
  zone_id = var.zone_id
  name    = "key2._domainkey"
  content = "key2.${var.domain}._domainkey.migadu.com"
  type    = "CNAME"
  ttl     = 3600
  comment = "Migadu DKIM key 2"

}

resource "cloudflare_dns_record" "migadu_dkim3" {
  zone_id = var.zone_id
  name    = "key3._domainkey"
  content = "key3.${var.domain}._domainkey.migadu.com"
  type    = "CNAME"
  ttl     = 3600
  comment = "Migadu DKIM key 3"

}

# Autoconfig for Thunderbird
resource "cloudflare_dns_record" "migadu_autoconfig" {
  zone_id = var.zone_id
  name    = "autoconfig"
  content = "autoconfig.migadu.com"
  type    = "CNAME"
  ttl     = 3600
  comment = "Thunderbird autoconfig"

}

# SRV records for autodiscover (Outlook)
resource "cloudflare_dns_record" "migadu_srv_autodiscover" {
  zone_id = var.zone_id
  name    = "_autodiscover._tcp"
  type    = "SRV"
  ttl     = 3600
  comment = "Outlook autodiscovery"


  data = {
    priority = 0
    weight   = 1
    port     = 443
    target   = "autodiscover.migadu.com"
  }
}

# SRV records for SMTP submission
resource "cloudflare_dns_record" "migadu_srv_submissions" {
  zone_id = var.zone_id
  name    = "_submissions._tcp"
  type    = "SRV"
  ttl     = 3600
  comment = "SMTP submission (SMTPS)"


  data = {
    priority = 0
    weight   = 1
    port     = 465
    target   = "smtp.migadu.com"
  }
}

# SRV records for IMAP
resource "cloudflare_dns_record" "migadu_srv_imaps" {
  zone_id = var.zone_id
  name    = "_imaps._tcp"
  type    = "SRV"
  ttl     = 3600
  comment = "IMAPS"


  data = {
    priority = 0
    weight   = 1
    port     = 993
    target   = "imap.migadu.com"
  }
}

# SRV records for POP3
resource "cloudflare_dns_record" "migadu_srv_pop3s" {
  zone_id = var.zone_id
  name    = "_pop3s._tcp"
  type    = "SRV"
  ttl     = 3600
  comment = "POP3S"


  data = {
    priority = 0
    weight   = 1
    port     = 995
    target   = "pop.migadu.com"
  }
}
