output "root_record" {
  value = var.create_root_record ? {
    name    = cloudflare_dns_record.root[0].name
    type    = cloudflare_dns_record.root[0].type
    proxied = cloudflare_dns_record.root[0].proxied
  } : null
}
