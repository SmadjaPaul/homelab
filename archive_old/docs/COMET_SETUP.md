# Comet Setup Guide with Real-Debrid

## 🎯 What is Comet?

Comet is a Stremio addon that proxies Real-Debrid streams, allowing you to:
- Search and stream content directly from Real-Debrid
- Use multiple Real-Debrid accounts (proxy rotation)
- Cache results in PostgreSQL for faster searches

## 📋 Prerequisites

Before starting, make sure you have:
1. **Real-Debrid account** - Premium subscription recommended
2. **Real-Debrid API key** - Get it from https://real-debrid.com/apitoken
3. **Stremio installed** - On your device (PC, phone, TV, etc.)

## 🔑 Getting Your Real-Debrid API Key

1. Go to https://real-debrid.com
2. Log in to your account
3. Navigate to: https://real-debrid.com/apitoken
4. Copy your API token (looks like: `ABC123XYZ...`)
5. **Keep this token secure!** - It provides full access to your account

## 🚀 Deployment Steps

### 1. Add Secrets to Doppler

```bash
# Real-Debrid API key
doppler secrets set RD_API_KEY="your_rd_api_key_here" -p infrastructure

# Comet PostgreSQL password (generate new one)
doppler secrets set COMET_POSTGRES_PASSWORD="$(openssl rand -hex 16)" -p infrastructure
```

### 2. Deploy Comet

```bash
cd docker/services/comet
doppler run -p infrastructure -c prd -- docker-compose up -d
```

### 3. Verify Deployment

```bash
# Check containers are running
docker ps | grep comet

# View logs
docker logs -f comet
```

You should see:
- `comet` container running on port 8000
- `comet-postgres` container running
- `zilean` container running (optional, for metadata)

## 🔧 Configure Stremio

### 1. Install the Addon

1. Open Stremio on your device
2. Go to **Addons** (puzzle icon)
3. Click **+ Add Addon**
4. Enter your Comet URL:
   ```
   https://stream.smadja.dev/manifest.json
   ```
5. Click **Install**

### 2. Configure Real-Debrid in Comet

Comet automatically uses the `RD_API_KEY` environment variable. No additional configuration needed!

### 3. Test Streaming

1. Search for a movie or TV show in Stremio
2. Look for results with "Comet" label
3. Click on a stream
4. It should start playing via Real-Debrid

## 🛠️ Configuration Options

### Environment Variables

Edit `docker/services/comet/docker-compose.yml` to customize:

```yaml
environment:
  # Core settings
  - COMET_HOST=0.0.0.0
  - COMET_PORT=8000

  # Real-Debrid
  - RD_API_KEY=${RD_API_KEY}

  # Database
  - DATABASE_URL=postgresql://comet:${COMET_POSTGRES_PASSWORD}@postgres:5432/comet

  # Cache TTL (in seconds) - default 24 hours
  - CACHE_TTL=86400

  # Rate limiting - requests per minute per IP
  - RATE_LIMIT_PER_MINUTE=60

  # Optional: Proxy for multi-IP rotation
  - PROXY_URL=${PROXY_URL:-}
  - PROXY_USERNAME=${PROXY_USERNAME:-}
  - PROXY_PASSWORD=${PROXY_PASSWORD:-}
```

### Proxy Configuration (Optional)

If you want to use multiple Real-Debrid accounts or rotate IPs:

```bash
# Add to Doppler
doppler secrets set PROXY_URL="http://proxy.example.com:8080" -p infrastructure
doppler secrets set PROXY_USERNAME="user" -p infrastructure
doppler secrets set PROXY_PASSWORD="pass" -p infrastructure

# Redeploy
doppler run -p infrastructure -c prd -- docker-compose up -d
```

## 🔒 Security Considerations

### 1. Keep Your API Key Secret

- Never commit `RD_API_KEY` to git
- Use Doppler for secret management
- Rotate the key if compromised (get new one from Real-Debrid)

### 2. Rate Limiting

Comet has built-in rate limiting (60 requests/minute default). Adjust in docker-compose.yml if needed:

```yaml
- RATE_LIMIT_PER_MINUTE=100  # Increase if needed
```

### 3. Access Control

The current setup allows public access to Comet. To restrict access:

**Option A: Cloudflare Access** (before Comet)
- Add Cloudflare Access application for stream.smadja.dev
- Requires authentication before accessing Comet

**Option B: Basic Auth via Traefik**
```yaml
labels:
  - "traefik.http.middlewares.comet-auth.basicauth.users=user:$$apr1$$H6uskkkW$$IgXLP6ewTrSuBkTrqE8wj/"
  - "traefik.http.routers.comet.middlewares=comet-auth,comet-ratelimit"
```

Generate password hash:
```bash
echo $(htpasswd -nb user yourpassword) | sed -e s/\\$/\\$\\$/g
```

### 4. CrowdSec Protection

Already configured in docker-compose.yml. CrowdSec will:
- Detect and block malicious IPs
- Use community blocklists
- Protect against brute force attacks

## 📊 Monitoring

### View Logs

```bash
# Real-time logs
docker logs -f comet

# Last 100 lines
docker logs --tail 100 comet

# All services
docker-compose logs -f
```

### Check Health

```bash
# Test Comet API
curl https://stream.smadja.dev/manifest.json

# Should return addon manifest
```

### Prometheus Metrics

Comet exposes metrics at `/metrics`:
```bash
curl https://stream.smadja.dev/metrics
```

Add to Prometheus (already configured in monitoring/)

## 🐛 Troubleshooting

### "No streams found"

1. Check Real-Debrid API key is valid:
   ```bash
   curl -H "Authorization: Bearer YOUR_API_KEY" https://api.real-debrid.com/rest/1.0/user
   ```

2. Verify Comet can reach Real-Debrid:
   ```bash
   docker exec comet curl -s https://api.real-debrid.com/rest/1.0/user -H "Authorization: Bearer YOUR_API_KEY"
   ```

3. Check Zilean is running (for metadata):
   ```bash
   docker logs zilean
   ```

### "Connection refused" or 502 error

1. Check Traefik routing:
   ```bash
   docker logs traefik | grep comet
   ```

2. Verify Comet is healthy:
   ```bash
   docker ps | grep comet
   curl http://localhost:8000/manifest.json
   ```

### PostgreSQL connection errors

1. Check PostgreSQL is running:
   ```bash
   docker ps | grep postgres
   docker logs comet-postgres
   ```

2. Verify password in Doppler:
   ```bash
   doppler secrets get COMET_POSTGRES_PASSWORD -p infrastructure
   ```

3. Reset if needed:
   ```bash
   cd docker/services/comet
   docker-compose down -v  # WARNING: Clears cache data
   doppler run -p infrastructure -c prd -- docker-compose up -d
   ```

### High memory usage

Comet caches results in PostgreSQL. To clear cache:

```bash
docker exec comet-postgres psql -U comet -c "TRUNCATE TABLE cache;"
```

Or adjust `CACHE_TTL` to reduce cache duration.

## 📈 Performance Tuning

### For 20+ users

1. **Increase rate limits**:
   ```yaml
   - RATE_LIMIT_PER_MINUTE=120
   ```

2. **Increase cache TTL**:
   ```yaml
   - CACHE_TTL=172800  # 48 hours
   ```

3. **Add more PostgreSQL resources**:
   ```yaml
   services:
     postgres:
       deploy:
         resources:
           limits:
             memory: 1G
   ```

4. **Enable connection pooling** (advanced):
   Use PgBouncer between Comet and PostgreSQL

## 🔄 Updating Comet

```bash
cd docker/services/comet

# Pull latest image
docker-compose pull

# Recreate containers
doppler run -p infrastructure -c prd -- docker-compose up -d

# Verify
docker ps | grep comet
```

## 🆘 Getting Help

- **Comet Issues**: https://github.com/g0ldyy/comet/issues
- **Real-Debrid Docs**: https://api.real-debrid.com/
- **Stremio Community**: https://www.reddit.com/r/Stremio/

## ✅ Checklist

- [ ] Real-Debrid account created and premium active
- [ ] API key obtained from https://real-debrid.com/apitoken
- [ ] API key added to Doppler (`RD_API_KEY`)
- [ ] Comet deployed and running
- [ ] DNS record stream.smadja.dev points to correct IP
- [ ] Stremio addon installed
- [ ] Test stream works
- [ ] Rate limiting configured appropriately
- [ ] Monitoring enabled

---

*Last updated: 2026-02-15*
