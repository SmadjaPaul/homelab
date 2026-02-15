# Doppler Project: stream
# Configuration spécifique pour Comet (Stremio addon)

## Required Secrets

### Core Configuration
- **RD_API_KEY** - Real-Debrid API token (✅ déjà ajouté)
- **RATE_LIMIT_PER_MINUTE** - Rate limiting (✅ déjà ajouté à 30)
- **COMET_POSTGRES_PASSWORD** - PostgreSQL password (générer un nouveau)
  ```bash
  openssl rand -hex 16
  ```

### Domain & Networking
- **DOMAIN** - Your domain (e.g., smadja.dev)
  - Used for: `stream.${DOMAIN}`, callbacks, logs

### Optional: Proxy Configuration (Multi-IP)
If you want to use multiple Real-Debrid accounts or rotate IPs:
- **PROXY_URL** - Proxy URL (e.g., http://proxy.example.com:8080)
- **PROXY_USERNAME** - Proxy username
- **PROXY_PASSWORD** - Proxy password

### Optional: Performance Tuning
- **CACHE_TTL** - Cache TTL in seconds (default: 86400 = 24h)
- **MAX_CONCURRENT_STREAMS** - Max concurrent streams per IP (default: 5)

## Secrets to Copy from 'infrastructure' Project

These secrets are needed in both projects:

```bash
# Copy from infrastructure to stream
doppler secrets get DOMAIN -p infrastructure --plain | doppler secrets set DOMAIN -p stream

# Or set manually
doppler secrets set DOMAIN="smadja.dev" -p stream
```

## Complete Setup Commands

```bash
# 1. Set required secrets
doppler secrets set COMET_POSTGRES_PASSWORD="$(openssl rand -hex 16)" -p stream
doppler secrets set DOMAIN="smadja.dev" -p stream

# 2. Optional: Proxy settings (for multi-IP)
# doppler secrets set PROXY_URL="http://proxy.example.com:8080" -p stream
# doppler secrets set PROXY_USERNAME="user" -p stream
# doppler secrets set PROXY_PASSWORD="pass" -p stream

# 3. Optional: Performance tuning
doppler secrets set CACHE_TTL="86400" -p stream
```

## Usage in Docker Compose

```yaml
services:
  comet:
    environment:
      - RD_API_KEY
      - RATE_LIMIT_PER_MINUTE
      - COMET_POSTGRES_PASSWORD
      - DOMAIN
      # Optional:
      - PROXY_URL
      - PROXY_USERNAME
      - PROXY_PASSWORD
      - CACHE_TTL
```

## Deployment

```bash
cd docker/services/comet
doppler run -p stream -c prd -- docker-compose up -d
```

## Note on Project Separation

Keeping 'stream' separate from 'infrastructure' is a good practice:
- ✅ Isolation of streaming-specific secrets
- ✅ Different access controls possible
- ✅ Easier rotation of Real-Debrid keys
- ✅ Clear separation of concerns

However, you'll need to reference both projects in some scripts.
