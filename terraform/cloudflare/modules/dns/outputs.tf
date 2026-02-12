output "root_record" {
  value = {
    name    = cloudflare_record.root.name
    type    = cloudflare_record.root.type
    proxied = cloudflare_record.root.proxied
  }
}

output "service_records" {
  value = { for k, v in cloudflare_record.homelab_services : k => { name = v.name, type = v.type } }
}

output "tunnel_cname_records" {
  value = { for k, v in cloudflare_record.tunnel_cname : k => { name = v.name, content = v.content } }
}
