output "root_record" {
  value = var.create_root_record ? {
    name    = cloudflare_record.root[0].name
    type    = cloudflare_record.root[0].type
    proxied = cloudflare_record.root[0].proxied
  } : null
}

output "service_records" {
  value = { for k, v in cloudflare_record.homelab_services : k => { name = v.name, type = v.type } }
}

output "tunnel_cname_records" {
  value = { for k, v in cloudflare_record.tunnel_cname : k => { name = v.name, content = v.content } }
}
