# Architecture d'Accès - Homelab

## Vue d'ensemble

Trois méthodes d'accès selon le type d'utilisateur et le service :

```
Internet
    │
    ├──────────────────┬──────────────────┐
    │                  │                  │
    ▼                  ▼                  ▼
┌──────────────┐ ┌────────────┐ ┌────────────────┐
│ CF Tunnel    │ │ Direct +   │ │ Tailscale VPN  │
│ (Wildcard)   │ │ CF Access  │ │ (Mesh)         │
└───┬──────────┘ └─────┬──────┘ └───────┬────────┘
    │                  │                │
    ▼                  ▼                ▼
K8s Cluster        Comet (8080)    Omni/SSH/Admin
```

## 🌐 1. Cloudflare Tunnel + External DNS

**Architecture qjoly/GitOps** : Tunnel wildcard + DNS automatique

**Pour qui** : Famille, amis (non-tech)
**Accès** : URLs publiques via HTTPS
**Auth** : Authentik (SSO)
**Localisation** : Pod cloudflared dans K8s (namespace `cloudflare`)

### Architecture

```
Internet
    │
    ▼
Cloudflare DNS (*.smadja.dev)
    │
    ├─ CNAME → ${TUNNEL_ID}.cfargotunnel.com
    │
    ▼
Cloudflare Tunnel
    │
    ├─ Ingress Controller (Traefik)
    │   │
    │   ├─ nextcloud.productivity.svc
    │   ├─ matrix.productivity.svc
    │   └─ authentik.infra.svc
    │
    └─ External DNS (crée les records automatiquement)
```

### Fonctionnement

1. **Cloudflared** : Pod dans K8s qui crée le tunnel vers Cloudflare
2. **External DNS** : Regarde les Ingress et crée les DNS records dans Cloudflare
3. **Wildcard** : `*.smadja.dev` pointe vers le tunnel
4. **Ingress Controller** : Traefik route vers les services

### Configuration

#### Cloudflare Tunnel (Helm)

```yaml
# kubernetes/apps/infrastructure/cloudflare/tunnel.yaml
cloudflare:
  tunnelName: "oci-hub-tunnel"
  secretName: "tunnel-credentials"  # Depuis Doppler
  ingress:
    - hostname: "*.smadja.dev"
      service: "http://traefik.infra.svc.cluster.local:80"
      originRequest:
        noTLSVerify: true
    - service: http_status:404
```

#### External DNS (Helm)

```yaml
# kubernetes/apps/infrastructure/cloudflare/external-dns.yaml
provider:
  name: cloudflare
env:
  - name: CF_API_TOKEN
    valueFrom:
      secretKeyRef:
        name: cloudflare-api-key
        key: apiKey
```

#### Exemple d'Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nextcloud
  namespace: productivity
  annotations:
    # External DNS créera: nextcloud.smadja.dev
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
    external-dns.alpha.kubernetes.io/hostname: "nextcloud.smadja.dev"
    external-dns.alpha.kubernetes.io/target: "${TUNNEL_ID}.cfargotunnel.com"

    # Cert-manager pour TLS
    cert-manager.io/cluster-issuer: letsencrypt-production

    # Traefik
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - nextcloud.smadja.dev
      secretName: nextcloud-tls
  rules:
    - host: nextcloud.smadja.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nextcloud
                port:
                  number: 80
```

### Services exposés

| URL | Service | Auth | Via |
|-----|---------|------|-----|
| auth.smadja.dev | Authentik | Direct | Tunnel |
| cloud.smadja.dev | Nextcloud | Authentik | Tunnel |
| chat.smadja.dev | Matrix | Authentik | Tunnel |
| element.smadja.dev | Element | Authentik | Tunnel |
| home.smadja.dev | Homepage | Authentik | Tunnel |
| vault.smadja.dev | Vaultwarden | Authentik | Tunnel |
| git.smadja.dev | Gitea | Authentik | Tunnel |

### Avantages

- ✅ **Pas d'IP publique exposée** - Tout passe par le tunnel
- ✅ **DNS automatique** - External DNS crée les records
- ✅ **Wildcard** - Un seul tunnel pour tous les sous-domaines
- ✅ **GitOps** - Configuration dans Git, déployée par Flux
- ✅ **HTTPS automatique** - Cloudflare gère les certificats
- ✅ **WAF/DDoS** - Protection Cloudflare activée

## 🎯 2. Cloudflare Access Direct (Streaming)

**Pour qui** : Toi (streaming)
**Accès** : IP publique directe + Cloudflare Access
**Auth** : Cloudflare Access (email)
**Pourquoi** : Performance (pas de tunnel = moins de latence)

### Services en Direct

| URL/IP | Service | Auth | Pourquoi direct |
|--------|---------|------|-----------------|
| [VM-IP]:8080 | Comet | Cloudflare Access | Latence streaming |

### Architecture

```
Utilisateur
    │
    ▼
Cloudflare Access (Auth email)
    │
    ▼
IP Publique VM-Hub (pas de tunnel)
    │
    ▼
Comet (port 8080)
```

### Configuration

**Sur VM Hub** (Terraform) :
- Comet en Docker (port 8080)
- UFW : Autoriser 8080 depuis Cloudflare IPs uniquement
- Cloudflare Access : Application configurée dans Zero Trust

## 🔒 3. Tailscale (Administration)

**Pour qui** : Toi uniquement (admin)
**Accès** : VPN mesh privé
**Auth** : Tailscale (device + 2FA)
**Usage** : Administration, monitoring, kubectl

### Services via Tailscale

| Service | URL | Accès |
|---------|-----|-------|
| Omni | http://10.0.1.2:50001 | Admin |
| kubectl | kubeconfig local | Admin |
| SSH VMs | ssh ubuntu@10.0.1.x | Admin |
| Prometheus | http://prometheus.infra | Admin |
| Grafana | http://grafana.infra | Admin |
| ArgoCD | http://argocd.infra | Admin |

### Architecture Tailscale

```
Ton Device
    │
    │ Tailscale Client
    ▼
Tailscale Control Plane (cloud)
    │
    ▼
VM-Hub (Subnet Router)
    │
    └──── 10.0.0.0/16 (VCN)
              │
              ├─ 10.0.1.2 (Hub)
              ├─ 10.0.1.10 (K8s CP)
              ├─ 10.0.1.11 (K8s Worker)
              └─ 10.0.1.12 (K8s Worker)
```

### Configuration

**Sur VM Hub** (cloud-init) :
```bash
tailscale up --authkey="${TAILSCALE_AUTH_KEY}" \
  --advertise-routes=10.0.0.0/16 \
  --accept-dns=false
```

## 📊 Tableau Récapitulatif

| Service | Méthode | Utilisateur | Auth | Latence |
|---------|---------|-------------|------|---------|
| Nextcloud | CF Tunnel + External DNS | Famille | Authentik | Normale |
| Matrix | CF Tunnel + External DNS | Famille | Authentik | Normale |
| Authentik | CF Tunnel + External DNS | Tous | Direct | Normale |
| Comet | Direct + CF Access | Toi | CF Access | **Faible** |
| Omni | Tailscale | Toi | Device | Faible |
| kubectl | Tailscale | Toi | Device | Faible |
| SSH | Tailscale | Toi | Device | Faible |

## 🔧 Implémentation GitOps

### 1. Cloudflare Tunnel + External DNS

```yaml
# kubernetes/apps/infrastructure/cloudflare/
├── repository.yaml              # Helm repo cloudflare
├── external-dns-repository.yaml # Helm repo external-dns
├── tunnel.yaml                  # Cloudflared deployment
├── external-dns.yaml            # External DNS deployment
├── example-ingress.yaml         # Exemple d'ingress
└── kustomization.yaml
```

**Flux** déploie automatiquement quand tu pousses sur Git.

### 2. Comet Direct (sur VM Hub)

```yaml
# terraform/oracle-cloud/templates/hub-cloud-init.sh
# Docker Compose pour Comet (port 8080)
# UFW config pour restreindre aux IPs Cloudflare
```

**Terraform** déploie lors du `terraform apply`.

### 3. Tailscale (sur VM Hub)

```yaml
# terraform/oracle-cloud/templates/hub-cloud-init.sh
# Installation + connexion Tailscale (subnet router)
```

**Terraform** configure automatiquement.

## 🚀 Workflow Déploiement

### Nouveau service public (ex: Wiki)

```yaml
# 1. Créer projet Doppler (service-wiki)
# 2. Ajouter secrets dans Doppler

# 3. Créer Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wiki
  namespace: productivity
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "wiki.smadja.dev"
    external-dns.alpha.kubernetes.io/target: "${TUNNEL_ID}.cfargotunnel.com"
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - wiki.smadja.dev
      secretName: wiki-tls
  rules:
    - host: wiki.smadja.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: wiki
                port:
                  number: 80
```

```bash
# 4. Pousser sur Git
git add .
git commit -m "Add wiki"
git push

# 5. Flux déploie automatiquement:
#    - App dans K8s
#    - External DNS crée: wiki.smadja.dev → Tunnel
#    - Cert-manager génère certificat TLS
#    - Accessible via https://wiki.smadja.dev
```

### Nouveau service admin (ex: Backup UI)

```yaml
# 1. Créer HelmRelease
# 2. Pas d'ingress (pas exposé sur Internet)
# 3. Accès via Tailscale uniquement
# 4. URL interne: http://backup.infra.svc.cluster.local
```

## ⚠️ Sécurité

### À ne JAMAIS faire

- ❌ Exposer Omni sur Internet (toujours Tailscale)
- ❌ Exposer SSH sur Internet (toujours Tailscale)
- ❌ Committer des tokens dans Git
- ❌ Donner accès Tailscale à la famille (trop puissant)
- ❌ Oublier `--advertise-routes` sur Tailscale

### Bonnes pratiques

- ✅ Cloudflare Access sur tous les services directs
- ✅ Authentik sur tous les services tunnel
- ✅ 2FA obligatoire partout
- ✅ Geo-blocking FR sur Cloudflare
- ✅ Rotation régulière des tokens

## 🆘 Dépannage

### Tunnel ne fonctionne pas

```bash
# Vérifier le pod
kubectl logs -n cloudflare deployment/cloudflare-tunnel

# Vérifier le secret
kubectl get secret tunnel-credentials -n cloudflare

# Redémarrer
kubectl rollout restart deployment/cloudflare-tunnel -n cloudflare
```

### External DNS ne crée pas les records

```bash
# Vérifier logs
kubectl logs -n external-dns deployment/external-dns

# Vérifier permissions du token Cloudflare
# Le token doit avoir droit: Zone:Read, DNS:Edit
```

### Tailscale ne fonctionne pas

```bash
# Sur la VM Hub
sudo tailscale status
sudo tailscale up --advertise-routes=10.0.0.0/16

# Sur ton device
tailscale ping 10.0.1.2
```

### Accès direct Comet bloqué

```bash
# Vérifier UFW sur VM Hub
sudo ufw status

# Vérifier Cloudflare Access
# Aller sur: Cloudflare Zero Trust → Access → Applications
```

## 📚 Documentation

- [Cloudflare Tunnel docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [External DNS docs](https://github.com/kubernetes-sigs/external-dns)
- [qjoly/GitOps cloudflare.md](../cloudflare.md) - Documentation de référence
- [Tailscale Subnet Router](https://tailscale.com/kb/1019/subnets)
