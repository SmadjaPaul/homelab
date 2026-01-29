# Cloudflare Free Tier - What's Included

## Fully Free Features (No Limits)

| Feature | Description | Limit |
|---------|-------------|-------|
| **DNS** | Authoritative DNS hosting | Unlimited records |
| **CDN** | Global content delivery | Unlimited bandwidth |
| **SSL/TLS** | Universal SSL certificates | Unlimited |
| **DDoS Protection** | Layer 3/4/7 protection | Unlimited |
| **Cloudflare Tunnel** | Secure tunnels to origin | Unlimited tunnels |
| **Bot Fight Mode** | Basic bot protection | Enabled |
| **HSTS** | HTTP Strict Transport Security | Enabled |

## Free with Limits

| Feature | Free Limit | Notes |
|---------|------------|-------|
| **WAF Custom Rules** | 5 rules | Enough for homelab |
| **Page Rules** | 3 rules | Use Transform Rules instead |
| **Cloudflare Access** | 50 users | More than enough |
| **Rate Limiting** | 1 rule | Basic protection |
| **Transform Rules** | 10 rules | URL rewrites, headers |

## Paid Features (DO NOT ENABLE)

| Feature | Cost | Why to Avoid |
|---------|------|--------------|
| Argo Smart Routing | $5/month + usage | Not needed for homelab |
| Load Balancing | $5/month | Use K8s internal LB |
| Advanced Certificate Manager | $10/month | Universal SSL is enough |
| Cloudflare Stream | $5/month | Not needed |
| Workers (beyond free) | $5/month | Stay within free tier |
| R2 Storage (beyond free) | Usage-based | Use OCI Object Storage |

## How to Stay Free

1. **Never enable paid add-ons** in the Cloudflare dashboard
2. **Don't upgrade** to Pro/Business/Enterprise plans
3. **Stay within WAF rule limits** (5 custom rules max)
4. **Use Cloudflare Tunnel** instead of exposing public IPs
5. **Cloudflare Access** is free for up to 50 users

## No Budget Alerts Needed

Unlike Oracle Cloud, Cloudflare's free tier is truly free:
- No credit card required for free features
- No accidental charges from usage spikes
- Paid features require explicit opt-in

## Monitoring Usage

Check your usage in the Cloudflare dashboard:
- **Analytics** → Traffic, requests, bandwidth
- **Security** → WAF events, bot traffic
- **DNS** → Query volume

## Terraform Safety

Our Terraform configuration only uses free features:
- ✅ DNS records
- ✅ Zone settings (SSL, security headers)
- ✅ WAF custom rules (within 5 rule limit)
- ✅ Cloudflare Tunnel (when enabled)
- ✅ Cloudflare Access (for internal services)

No paid resources are provisioned.
