output "tunnel_id" {
  description = "Cloudflare Tunnel ID (for DNS CNAME target)"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

output "tunnel_name" {
  value = cloudflare_zero_trust_tunnel_cloudflared.homelab.name
}

output "tunnel_token" {
  sensitive   = true
  description = "Token for cloudflared to connect"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.tunnel_token
}

output "cname_target" {
  value = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
}
