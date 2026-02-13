# Homelab URLs & Services

## Infrastructure

| Service | URL | Status | Auth |
|---------|-----|--------|------|
| **Root Domain** | https://smadja.dev | ✅ Active | Public |
| **Traefik Dashboard** | https://traefik.smadja.dev | ✅ Active | Public |
| **Prometheus** | https://prometheus.smadja.dev | ✅ Active | Cloudflare Access |

## Core Services

| Service | URL | Status | Description |
|---------|-----|--------|-------------|
| **Blocky DNS** | https://dns.smadja.dev | ✅ Active | DNS ad-blocker (port 5053) |
| **Blocky Admin** | http://158.178.210.98:4000 | ✅ Active | Direct access to DNS admin |

## AI Services (Disabled - ARM64)

| Service | URL | Status | Reason |
|---------|-----|--------|--------|
| **LiteLLM** | https://llm.smadja.dev | ❌ Disabled | ARM64 incompatibility |
| **OpenClaw** | https://openclaw.smadja.dev | ❌ Disabled | ARM64 incompatibility |

## Monitoring

| Service | URL | Status | Notes |
|---------|-----|--------|-------|
| **Grafana Cloud** | https://smadja.grafana.net | 🔧 Setup Required | Configure with GRAFANA_CLOUD_* secrets |
| **Prometheus (Local)** | https://prometheus.smadja.dev | ✅ Active | Scrapes local metrics |

## Protected Services (Cloudflare Access)

These require authentication via Cloudflare Access:

- https://prometheus.smadja.dev
- https://grafana.smadja.dev (if enabled)
- https://llm.smadja.dev (when enabled)
- https://openclaw.smadja.dev (when enabled)

## Testing

Run the test script to verify all services:

```bash
./scripts/test-homelab.sh
```

Or test manually:

```bash
# Test main domain
curl -sL https://smadja.dev

# Test specific service
curl -sL https://traefik.smadja.dev

# Check DNS resolution
dig smadja.dev +short
```

## SSH Access

```bash
# Connect to management VM
ssh -i ~/.ssh/oci-homelab ubuntu@158.178.210.98

# Check services
docker ps

# View logs
docker logs cloudflared --tail 20
docker logs traefik --tail 20
```

## Architecture

```
Internet
    ↓
Cloudflare (DNS + Tunnel)
    ↓
cloudflared (OCI VM)
    ↓
traefik (Reverse Proxy)
    ↓
Services (prometheus, blocky, etc.)
```

## Next Steps

1. **Configure Grafana Cloud**
   - Add GRAFANA_CLOUD_API_KEY to Doppler
   - Verify grafana-agent is sending metrics
   - Create dashboards

2. **Enable ARM64 Services**
   - Deploy litellm/openclaw on x86 VM
   - Or use cloud provider (OpenAI, Anthropic, etc.)

3. **Add More Services**
   - Vaultwarden (password manager)
   - Uptime Kuma (monitoring)
   - Homepage (dashboard)

4. **Security**
   - Review Cloudflare Access policies
   - Enable geo-restrictions if needed
   - Set up MFA for internal services

## Troubleshooting

### Site not accessible (Error 522)
- Check cloudflared: `docker logs cloudflared`
- Verify tunnel token in Doppler
- Restart tunnel: `docker restart cloudflared`

### SSL Certificate Issues
- Traefik auto-generates Let's Encrypt certs
- Check: `docker logs traefik | grep -i cert`

### Service Unavailable
- Check container status: `docker ps`
- Check traefik routers: `curl http://localhost:8080/api/http/routers`
