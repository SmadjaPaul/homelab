# Documentation Réseau Interne - Homelab

## Table des Matières

1. [Architecture Globale](#architecture-globale)
2. [Cloudflare Tunnel (cloudflared)](#cloudflare-tunnel-cloudflared)
3. [Traefik](#traefik)
4. [External DNS](#external-dns)
5. [External Secrets](#external-secrets)
6. [Authentik](#authentik)
7. [Audiobookshelf](#audiobookshelf)
8. [Recommandations d'Amélioration](#recommandations-damélioration)

---

## Architecture Globale

```
Internet → Cloudflare → Cloudflare Tunnel (cloudflared) → Traefik → Kubernetes Services
                                                          ↓
                                            External-DNS (DNS automatique)
                                            External-Secrets (Doppler)
                                            Authentik (SSO)
                                            Applications (audiobookshelf, etc.)
```

### Flux de données

| Route | Destination |
|-------|-------------|
| `home.smadja.dev` | Traefik → homepage |
| `proxmox.smadja.dev` | Proxmox (192.168.68.51:8006) |
| `sso.smadja.dev` | Traefik → Authentik |
| `*.smadja.dev` | Catch-all → Traefik |

---

## Cloudflare Tunnel (cloudflared)

### Installation

- **Méthode**: Deployment Kubernetes (manuel)
- **Image**: `cloudflare/cloudflared:2026.2.0`
- **Namespace**: `cloudflared`

### Configuration

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflared
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:2026.2.0
          args:
            - tunnel
            - --config
            - /etc/cloudflared/config/config.yaml
            - run
```

### Secrets (Doppler via External Secrets)

```yaml
# external-secret.yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cloudflared-creds
  namespace: cloudflared
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler
  target:
    name: cloudflared-creds
  data:
    - secretKey: CLOUDFLARE_ACCOUNT_ID
      remoteRef:
        key: CLOUDFLARE_ACCOUNT_ID
    - secretKey: CLOUDFLARE_TUNNEL_ID
      remoteRef:
        key: CLOUDFLARE_TUNNEL_ID
    - secretKey: CLOUDFLARE_TUNNEL_SECRET
      remoteRef:
        key: CLOUDFLARE_TUNNEL_SECRET
```

### ConfigMap

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: cloudflared
data:
  config.yaml: |
    tunnel: 5825ee88-3939-4e16-ab32-856c6ff7df96
    credentials-file: /etc/cloudflared/credentials/credentials.json
    metrics: 0.0.0.0:2000
    no-autoupdate: true

    ingress:
      - hostname: home.smadja.dev
        originRequest:
          connectTimeout: 30s
          noTLSVerify: true
        service: https://traefik.traefik.svc.cluster.local:443
      - hostname: proxmox.smadja.dev
        originRequest:
          noTLSVerify: true
        service: https://192.168.68.51:8006
      - service: https://traefik.traefik.svc.cluster.local:443
        originRequest:
          noTLSVerify: true
```

---

## Traefik

### Installation (Helm Chart)

| Aspect | Valeur |
|--------|--------|
| **Chart** | traefik |
| **Version** | 30.0.0 |
| **Namespace** | traefik |
| **Service** | ClusterIP |

### Configuration (helmrelease.yaml)

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: traefik
  namespace: traefik
spec:
  chart:
    spec:
      chart: traefik
      version: 30.0.0
      sourceRef:
        kind: HelmRepository
        name: traefik
  values:
    service:
      type: ClusterIP

    metrics:
      prometheus:
        enabled: false

    providers:
      kubernetesIngress:
        enabled: true
        publishedService:
          enabled: false
      kubernetesCRD:
        enabled: true

    ports:
      web:
        redirectTo:
          port: websecure
          priority: 10

    ingressRoute:
      dashboard:
        enabled: false
```

### Providers Kubernetes

| Provider | Type | Ressources |
|----------|------|------------|
| `kubernetesIngress` | Standard | Ingress native K8s |
| `kubernetesCRD` | CRD Traefik | IngressRoute, Middleware, Service |

### Headers requis pour Reverse Proxy

Pour que les applications reçoivent les infos correctes:

```nginx
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header Host $http_host;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

### Exemple d'Ingress (Application)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: authentik
  namespace: security
  annotations:
    external-dns.alpha.kubernetes.io/target: "5825ee88-3939-4e16-ab32-856c6ff7df96.cfargotunnel.com"
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
    traefik.ingress.kubernetes.io/router.entrypoints: "websecure"
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  rules:
    - host: sso.smadja.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: authentik-server
                port:
                  number: 80
  tls:
    - hosts:
        - sso.smadja.dev
```

---

## External DNS

### Installation (Helm Chart)

| Aspect | Valeur |
|--------|--------|
| **Chart** | external-dns |
| **Version** | 1.15.1 |
| **Namespace** | external-dns |
| **Provider** | Cloudflare |

### Configuration

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: external-dns
  namespace: external-dns
spec:
  chart:
    spec:
      chart: external-dns
      version: "1.15.1"
  values:
    provider: cloudflare
    cloudflare:
      proxied: true
    sources:
      - ingress
      - gateway-httproute
    policy: sync
    txtOwnerId: "external-dns"
    domainFilters:
      - "smadja.dev"
    env:
      - name: CF_API_TOKEN
        valueFrom:
          secretKeyRef:
            name: external-dns-secrets
            key: CLOUDFLARE_API_TOKEN
```

### Secrets

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: external-dns-secrets
  namespace: external-dns
spec:
  secretStoreRef:
    name: doppler
    kind: ClusterSecretStore
  target:
    name: external-dns-secrets
  data:
    - secretKey: CLOUDFLARE_API_TOKEN
      remoteRef:
        key: CLOUDFLARE_API_TOKEN
```

---

## External Secrets

### Installation (Helm Chart)

| Aspect | Valeur |
|--------|--------|
| **Chart** | external-secrets |
| **Version** | 1.3.1 |
| **Namespace** | external-secrets |
| **Store** | ClusterSecretStore `doppler` |

### Configuration

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: external-secrets
  namespace: external-secrets
spec:
  chart:
    spec:
      chart: external-secrets
      version: 1.3.1
  values:
    installCRDs: true
    webhook:
      create: true
    certController:
      create: true
```

### ClusterSecretStore (Doppler)

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: doppler
spec:
  provider:
    doppler:
      project: infrastructure
      config: prd
      auth:
        secretRef:
          dopplerToken:
            name: doppler-token
            key: dopplerToken
            namespace: external-secrets
```

---

## Authentik

### Installation (Helm Chart)

| Aspect | Valeur |
|--------|--------|
| **Chart** | authentik |
| **Version** | 2024.12.0 ⚠️ |
| **Namespace** | security |
| **DB** | CloudNativePG |
| **Cache** | Redis externe |

### Configuration

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: authentik
  namespace: security
spec:
  chart:
    spec:
      chart: authentik
      version: "2024.12.0"
  values:
    postgresql:
      enabled: false
    redis:
      enabled: false

    authentik:
      existingSecret:
        secretName: authentik-secret
      postgresql:
        host: authentik-db-rw
        name: authentik
        user: authentik
      redis:
        host: redis-master.storage.svc.cluster.local

    server:
      env:
        - name: AUTHENTIK_COOKIE_DOMAIN
          value: "smadja.dev"
        - name: AUTHENTIK_TRUSTED_PROXY_CHAIN
          value: "10.0.0.0/8"
```

### Secrets

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: authentik-secret
  namespace: security
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler
  target:
    name: authentik-secret
  data:
    - secretKey: AUTHENTIK_SECRET_KEY
      remoteRef:
        key: AUTHENTIK_SECRET_KEY
    - secretKey: AUTHENTIK_BOOTSTRAP_TOKEN
      remoteRef:
        key: AUTHENTIK_BOOTSTRAP_TOKEN
```

### Base de données (CloudNativePG)

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: authentik-db
  namespace: security
spec:
  instances: 1
  storage:
    size: 2Gi
  bootstrap:
    initdb:
      database: authentik
      owner: authentik
```

### URL

- **SSO**: `https://sso.smadja.dev/`
- **Setup initial**: `https://sso.smadja.dev/if/flow/initial-setup/`

---

## Audiobookshelf

### Installation (Helm Chart)

| Aspect | Valeur |
|--------|--------|
| **Chart** | app-template (bjw-s) |
| **Image** | ghcr.io/advplyr/audiobookshelf:latest ⚠️ |
| **Namespace** | media |

### Configuration

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: audiobookshelf
  namespace: media
spec:
  chart:
    spec:
      chart: app-template
      version: "3.2.1"
  values:
    controllers:
      audiobookshelf:
        containers:
          app:
            image:
              repository: ghcr.io/advplyr/audiobookshelf
              tag: latest
            env:
              TZ: Europe/Paris
              AUDIOBOOKSHELF_UID: 1000
              AUDIOBOOKSHELF_GID: 1000
              ROUTER_BASE_PATH: ""
              OIDC_ISSUER_URL: "https://sso.smadja.dev/application/o/audiobookshelf/"
              OIDC_CLIENT_ID: "audiobookshelf"
              OIDC_CLIENT_SECRET:
                valueFrom:
                  secretKeyRef:
                    name: audiobookshelf-secrets
                    key: AUDIOBOOKSHELF_OIDC_CLIENT_SECRET
              OIDC_SCOPE: "openid profile email"
              OIDC_USER_NAME_CLAIM: "preferred_username"

    persistence:
      config:
        existingClaim: audiobookshelf-config
      metadata:
        existingClaim: audiobookshelf-metadata
      audiobooks:
        existingClaim: audiobookshelf-audiobooks
      podcasts:
        existingClaim: audiobookshelf-podcasts
```

### Configuration OIDC

| Paramètre | Valeur |
|-----------|--------|
| Issuer URL | `https://sso.smadja.dev/application/o/audiobookshelf/` |
| Client ID | `audiobookshelf` |
| Scopes | `openid profile email` |
| Username Claim | `preferred_username` |

---

## Recommandations d'Amélioration

### 1. Mettre à jour Authentik

| Actuel | Recommandé |
|--------|------------|
| Chart: 2024.12.0 | 2025.12 ou 2026.2 |

**Commande:**
```bash
helm upgrade authentik authentik/authentik -f values.yaml --version ^2025.12
```

### 2. Figer les tags d'images

| Service | Actuel | Recommandé |
|---------|--------|------------|
| audiobookshelf | `latest` | Version spécifique (ex: `2.12.0`) |
| cloudflared | 2026.2.0 | Dernière version stable |

### 3. Activer Gateway API (Optionnel mais recommandé)

Le Gateway API est plus moderne et standard:

```yaml
# values.yaml Traefik
providers:
  kubernetesGateway:
    enabled: true
  kubernetesCRD:
    enabled: true
```

### 4. Ajouter des middlewares de sécurité

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: traefik
spec:
  headers:
    frameDeny: true
    contentTypeNosniff: true
    browserXssFilter: true
    referrerPolicy: "strict-origin-when-cross-origin"
```

### 5. Mettre en place le monitoring

Activer Prometheus pour Traefik:

```yaml
metrics:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true
```

### 6. Sécuriser le dashboard Traefik

```yaml
ingressRoute:
  dashboard:
    enabled: true
    matchRule: Host(`traefik-admin.smadja.dev`)
    entryPoints:
      - websecure
    middlewares:
      - name: dashboard-auth
```

### 7. Utiliser des HTTPRoute au lieu d'Ingress (Gateway API)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: authentik
  namespace: security
spec:
  parentRefs:
    - name: traefik-gateway
  hostnames:
    - sso.smadja.dev
  rules:
    - backendRefs:
        - name: authentik-server
          port: 80
```

---

## Références

- [Documentation Authentik](https://docs.goauthentik.io/)
- [Documentation Traefik](https://doc.traefik.io/traefik/)
- [Documentation External Secrets](https://external-secrets.io/)
- [Documentation External DNS](https://kubernetes-sigs.github.io/external-dns/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

---

*Dernière mise à jour: Février 2026*
