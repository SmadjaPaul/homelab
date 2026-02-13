# =============================================================================
# Cloudflare DNS Records
# =============================================================================

# Root domain - placeholder (can be disabled if already exists)
resource "cloudflare_record" "root" {
  count = var.create_root_record ? 1 : 0

  zone_id         = var.zone_id
  name            = "@"
  content         = "192.0.2.1"
  type            = "A"
  proxied         = true
  ttl             = 1
  comment         = "Root domain - placeholder for Cloudflare Tunnel"
  allow_overwrite = true

  lifecycle {
    ignore_changes = [content]
  }
}

# WWW redirect to root
resource "cloudflare_record" "www" {
  zone_id         = var.zone_id
  name            = "www"
  content         = var.domain
  type            = "CNAME"
  proxied         = true
  ttl             = 1
  comment         = "WWW redirect to root"
  allow_overwrite = true
}

# Placeholder A records when tunnel is disabled
resource "cloudflare_record" "homelab_services" {
  for_each = var.enable_tunnel ? {} : var.homelab_services

  zone_id         = var.zone_id
  name            = each.value.subdomain
  content         = "192.0.2.1"
  type            = "A"
  proxied         = true
  ttl             = 1
  comment         = each.value.description
  allow_overwrite = true
}

# OCI Management VM
resource "cloudflare_record" "oci_mgmt" {
  count = var.oci_management_ip != "" ? 1 : 0

  zone_id = var.zone_id
  name    = "oci-mgmt"
  content = var.oci_management_ip
  type    = "A"
  proxied = false
  ttl     = 300
  comment = "OCI Management VM - direct access"
}

# OCI K8s nodes
resource "cloudflare_record" "oci_nodes" {
  count = length(var.oci_node_ips)

  zone_id = var.zone_id
  name    = "oci-node-${count.index + 1}"
  content = var.oci_node_ips[count.index]
  type    = "A"
  proxied = false
  ttl     = 300
  comment = "OCI K8s Node ${count.index + 1}"
}

# CNAMEs to tunnel (when enabled). for_each keys must be known at plan time, so we use
# only var.enable_tunnel; content uses tunnel_id (may be known after apply).
resource "cloudflare_record" "tunnel_cname" {
  for_each = var.enable_tunnel ? var.homelab_services : {}

  zone_id         = var.zone_id
  name            = each.value.subdomain
  content         = "${var.tunnel_id}.cfargotunnel.com"
  type            = "CNAME"
  proxied         = true
  ttl             = 1
  comment         = "${each.value.description} (via Tunnel)"
  allow_overwrite = true
}

# SPF
resource "cloudflare_record" "spf" {
  zone_id         = var.zone_id
  name            = "@"
  content         = "v=spf1 -all"
  type            = "TXT"
  ttl             = 3600
  comment         = "SPF - no email sending allowed"
  allow_overwrite = true
}

# DMARC
resource "cloudflare_record" "dmarc" {
  zone_id         = var.zone_id
  name            = "_dmarc"
  content         = "v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s;"
  type            = "TXT"
  ttl             = 3600
  comment         = "DMARC - reject all unauthorized email"
  allow_overwrite = true
}
