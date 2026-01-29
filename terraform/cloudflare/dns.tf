# =============================================================================
# Cloudflare DNS Records
# =============================================================================

# Root domain - placeholder for now
# Will point to Cloudflare Tunnel or load balancer
resource "cloudflare_record" "root" {
  zone_id = var.zone_id
  name    = "@"
  content = "192.0.2.1"  # Placeholder - will be replaced by Tunnel
  type    = "A"
  proxied = true
  ttl     = 1  # Auto when proxied
  comment = "Root domain - placeholder for Cloudflare Tunnel"

  lifecycle {
    ignore_changes = [content]  # Will be managed by Tunnel later
  }
}

# WWW redirect to root
resource "cloudflare_record" "www" {
  zone_id = var.zone_id
  name    = "www"
  content = var.domain
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = "WWW redirect to root"
}

# =============================================================================
# Homelab Service DNS Records (via Tunnel)
# These will be CNAMEs pointing to the Tunnel
# =============================================================================

# Placeholder records for services - will point to Tunnel later
resource "cloudflare_record" "homelab_services" {
  for_each = var.homelab_services

  zone_id = var.zone_id
  name    = each.value.subdomain
  content = "192.0.2.1"  # Placeholder - will be Tunnel UUID
  type    = "A"
  proxied = true
  ttl     = 1
  comment = each.value.description

  lifecycle {
    ignore_changes = [content, type]  # Will be managed by Tunnel later
  }
}

# =============================================================================
# Oracle Cloud DNS Records (when VMs are available)
# =============================================================================

# Management VM (direct access for SSH, etc.)
resource "cloudflare_record" "oci_mgmt" {
  count = var.oci_management_ip != "" ? 1 : 0

  zone_id = var.zone_id
  name    = "oci-mgmt"
  content = var.oci_management_ip
  type    = "A"
  proxied = false  # Direct access for SSH
  ttl     = 300
  comment = "OCI Management VM - direct access"
}

# K8s nodes (direct access)
resource "cloudflare_record" "oci_nodes" {
  count = length(var.oci_node_ips)

  zone_id = var.zone_id
  name    = "oci-node-${count.index + 1}"
  content = var.oci_node_ips[count.index]
  type    = "A"
  proxied = false  # Direct access for K8s API
  ttl     = 300
  comment = "OCI K8s Node ${count.index + 1}"
}

# =============================================================================
# Email DNS Records (for future use)
# =============================================================================

# MX records placeholder (uncomment when setting up email)
# resource "cloudflare_record" "mx_primary" {
#   zone_id  = var.zone_id
#   name     = "@"
#   content  = "mail.smadja.dev"
#   type     = "MX"
#   priority = 10
#   ttl      = 3600
#   comment  = "Primary MX record"
# }

# SPF record (prevents email spoofing)
resource "cloudflare_record" "spf" {
  zone_id = var.zone_id
  name    = "@"
  content = "v=spf1 -all"  # No email sent from this domain (for now)
  type    = "TXT"
  ttl     = 3600
  comment = "SPF - no email sending allowed"
}

# DMARC record (email authentication)
resource "cloudflare_record" "dmarc" {
  zone_id = var.zone_id
  name    = "_dmarc"
  content = "v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s;"
  type    = "TXT"
  ttl     = 3600
  comment = "DMARC - reject all unauthorized email"
}
