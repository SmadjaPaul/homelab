# Architecture Réseau et Trafic

## Vue d'ensemble

```
Internet
    │
    ├──────────────────┬──────────────────┬──────────────────┐
    │                  │                  │                  │
    ▼                  ▼                  ▼                  ▼
┌──────────┐    ┌──────────────┐   ┌──────────┐    ┌──────────────┐
│ Cloudflare│    │ Cloudflare  │   │ Direct   │    │   Tailscale  │
│  DNS      │    │  Access     │   │ Port 8080│    │    VPN       │
└────┬─────┘    └──────┬───────┘   └────┬─────┘    └──────┬───────┘
     │                 │                │                 │
     │                 │                │                 │
     ▼                 ▼                ▼                 ▼
*.smadja.dev    auth.smadja.dev    Comet           Omni/SSH/kubectl
     │                 │           (Streaming)    (Admin only)
     │                 │                │                 │
     └─────────────────┴────────────────┘                 │
                       │                                  │
                       ▼                                  ▼
              ┌──────────────────┐              ┌──────────────────┐
              │ Cloudflare Tunnel│              │   VM-Hub (OCI)   │
              │   (dans K8s)     │              ├──────────────────┤
              └────────┬─────────┘              │  • Omni (port    │
                       │                        │    50000/50001)  │
                       │                        │  • Tailscale     │
                       ▼                        │  • Comet (port   │
              ┌──────────────────┐              │    8080)         │
              │  Traefik Ingress │              └──────────────────┘
              │   (dans K8s)     │                        │
              └────────┬─────────┘                        │
                       │                                  │
                       ▼                                  ▼
              ┌──────────────────┐              ┌──────────────────┐
              │  K8s Cluster     │◄─────────────┤   K8s Cluster    │
              │  (via Tunnel)    │              │  (via Tailscale) │
              ├──────────────────┤              ├──────────────────┤
              │  • Authentik     │              │  • Tous les pods │
              │  • Nextcloud     │              │  • Monitoring    │
              │  • Matrix        │              │  • Logs          │
              │  • etc.          │              │                  │
              └──────────────────┘              └──────────────────┘
```

## 🖥️ VM Hub (oci-hub) - 1 OCPU / 4GB

### Services sur la VM

La VM **oci-hub** fait tourner uniquement les services **infrastructure/core** qui ne sont pas dans Kubernetes:

| Service | Port | Description | Accès |
|---------|------|-------------|-------|
| **Omni** | 50000 (gRPC)<br>50001 (HTTP) | Control plane Kubernetes | 🔒 Tailscale uniquement |
| **Tailscale** | - | VPN mesh + subnet router | 🔒 Admin uniquement |
| **Comet** | 8080 | Streaming (Stremio addon) | 🌐 Direct + CF Access |
| **Docker** | - | Runtime containers | 🔒 Local only |

### Configuration

**Fichier:** `terraform/oracle-cloud/templates/hub-cloud-init.sh`

```yaml
# Services installés via Docker Compose:
/opt/omni/docker-compose.yaml          # Omni Control Plane
/opt/comet/docker-compose.yaml         # Streaming

# Firewall (UFW):
- Port 22 (SSH) : Autorisé
- Port 8080 (Comet) : Autorisé (pour Cloudflare Access)
- Tout le reste : Bloqué (sauf VCN interne)
```

### Pourquoi ces services sur la VM ?

1. **Omni** : Doit être accessible avant que K8s existe pour bootstrap
2. **Tailscale** : Subnet router pour accès admin au réseau privé
3. **Comet** : Streaming nécessite faible latence (pas de tunnel)

## ☸️ Cluster Kubernetes (3 VMs) - 3 OCPU / 20GB

### Services dans K8s

Tout le reste tourne dans le cluster Kubernetes géré par Omni:

**Infrastructure:**
- **Cloudflared** (Tunnel) - Namespace: cloudflare
- **External DNS** - Namespace: external-dns
- **Cert-manager** - Namespace: cert-manager
- **Traefik** (Ingress) - Namespace: infra
- **External Secrets** - Namespace: flux-system

**Applications:**
- **Authentik** (IdP) - Namespace: authentik
- **Nextcloud** (Cloud) - Namespace: nextcloud
- **Matrix** (Chat) - Namespace: matrix
- **etc.**

### Configuration Tunnel

**Fichier:** `kubernetes/apps/infrastructure/cloudflare/tunnel.yaml`

```yaml
# Le tunnel redirige tout le trafic *.smadja.dev vers Traefik
ingress:
  - hostname: "*.smadja.dev"
    service: "http://traefik.infra.svc.cluster.local:80"

# Traefik route ensuite vers les services
```

## 🌐 Gestion du Trafic

### Tableau Récapitulatif

| Service | URL/IP | Méthode | Accès | Auth |
|---------|--------|---------|-------|------|
| **Authentik** | auth.smadja.dev | CF Tunnel → Traefik | Public | Direct (1ère fois) |
| **Nextcloud** | cloud.smadja.dev | CF Tunnel → Traefik | Public | Authentik |
| **Matrix** | chat.smadja.dev | CF Tunnel → Traefik | Public | Authentik |
| **Comet** | [VM-IP]:8080 | Direct (pas de tunnel) | Public | Cloudflare Access |
| **Omni** | [VM-IP]:50001 | Tailscale VPN | Admin | Omni auth |
| **kubectl** | 10.0.1.10 | Tailscale VPN | Admin | kubeconfig |
| **SSH VMs** | 10.0.1.x | Tailscale VPN | Admin | SSH key |

### Flux de Trafic Détaillé

#### 1. Services Web (Nextcloud, Matrix, etc.)

```
Utilisateur
    │
    ▼
https://cloud.smadja.dev
    │
    ▼
Cloudflare DNS (*.smadja.dev → Tunnel)
    │
    ▼
Cloudflare Tunnel (cloudflared pod in K8s)
    │
    ▼
Traefik Ingress Controller (K8s service)
    │
    ▼
Nextcloud Pod (K8s)
```

#### 2. Streaming (Comet)

```
Utilisateur
    │
    ▼
https://[VM-IP]:8080
    │
    ▼
Cloudflare Access (Auth email)
    │
    ▼
UFW (port 8080 autorisé)
    │
    ▼
Comet Container (VM Hub)
```

**Pourquoi pas de tunnel pour Comet ?**
- Latence réduite (streaming temps réel)
- Pas besoin de haute disponibilité
- Pas de données sensibles

#### 3. Administration (Omni, kubectl)

```
Admin (ton PC)
    │
    ▼
Tailscale Client
    │
    ▼
Tailscale Control Plane
    │
    ▼
VM-Hub (Subnet Router)
    │
    ├──── 10.0.1.2:50001 (Omni UI)
    ├──── 10.0.1.10:6443 (K8s API)
    └──── 10.0.1.x:22 (SSH)
```

## 🔒 Sécurité Réseau

### VM Hub (oci-hub)

**UFW (Uncomplicated Firewall):**
```bash
# Autorisé
ufw allow ssh                    # Port 22
ufw allow from 10.0.0.0/16       # VCN interne
# Port 8080 ouvert pour Comet (filtré par Cloudflare Access)

# Bloqué
ufw default deny incoming        # Tout le reste
```

**Fail2ban:**
- Protection SSH brute-force
- 3 tentatives max puis ban 24h

### Cluster Kubernetes

**Network Policies:**
```yaml
# Isolation par namespace
# Ex: Authentik ne peut pas parler à Nextcloud directement
```

**Cilium (optionnel):**
- eBPF pour policies réseau
- Observabilité

## 🛠️ Configuration des Routes

### Tailscale (Subnet Router)

La VM Hub annonce le réseau 10.0.0.0/16 à Tailscale:

```bash
tailscale up \
  --advertise-routes=10.0.0.0/16 \
  --accept-dns=false
```

**Résultat:** Depuis ton PC Tailscale, tu peux pinger:
- 10.0.1.2 (VM Hub)
- 10.0.1.10 (Talos CP)
- 10.0.1.11 (Talos Worker)
- Tous les pods K8s via leur IP

### Cloudflare Tunnel

Configuration automatique via Terraform:

```hcl
module "tunnel" {
  source = "./modules/tunnel"

  # Le tunnel est créé avec un secret
  # Les pods cloudflared dans K8s utilisent ce secret pour se connecter
}
```

### External DNS

Crée automatiquement les DNS records:

```yaml
# Quand tu crées un Ingress avec annotation:
external-dns.alpha.kubernetes.io/hostname: "wiki.smadja.dev"

# External DNS crée:
# CNAME wiki.smadja.dev → [TUNNEL_ID].cfargotunnel.com
```

## 📊 Monitoring Réseau

### Commandes utiles

```bash
# Sur VM Hub
sudo tailscale status                    # Voir les pairs
sudo tailscale netcheck                  # Tester connectivité
sudo ufw status                          # Voir règles firewall

# Dans K8s
kubectl get svc -A                       # Voir tous les services
kubectl get ingress -A                   # Voir tous les ingress
kubectl logs -n cloudflare deployment/cloudflare-tunnel  # Logs tunnel

# Test connectivité
curl -I https://cloud.smadja.dev         # Test HTTPS
tailscale ping 10.0.1.2                  # Test VPN
```

### Dashboards

- **Cloudflare Dashboard:** Analytics DNS, Tunnel, Access
- **Omni Dashboard:** État des nœuds Talos
- **K8s Dashboard:** kubectl / Lens / k9s

## 🚨 Troubleshooting

### Problème: Impossible d'accéder à Nextcloud

```bash
# 1. Vérifier DNS
dig cloud.smadja.dev
# Doit retourner: [TUNNEL_ID].cfargotunnel.com

# 2. Vérifier tunnel
kubectl logs -n cloudflare deployment/cloudflare-tunnel
# Chercher "connected" ou erreurs

# 3. Vérifier Traefik
kubectl get pods -n infra
kubectl logs -n infra deployment/traefik

# 4. Vérifier Nextcloud
kubectl get pods -n nextcloud
kubectl logs -n nextcloud deployment/nextcloud
```

### Problème: Pas accès admin (Omni)

```bash
# 1. Vérifier Tailscale
tailscale status
# Doit montrer VM-Hub comme "connected"

# 2. Tester ping
ping 10.0.1.2

# 3. Tester Omni
curl -k https://10.0.1.2:50001
# Doit retourner HTML (même si auth required)
```

### Problème: Comet inaccessible

```bash
# 1. Vérifier que le service tourne (sur VM Hub)
ssh ubuntu@[VM_IP] "docker ps | grep comet"

# 2. Vérifier port
ssh ubuntu@[VM_IP] "sudo netstat -tlnp | grep 8080"

# 3. Vérifier Cloudflare Access
# Aller sur Cloudflare Dashboard → Access → Applications
# Vérifier que [VM_IP]:8080 est protégé
```

## 📝 Résumé

| Où ? | Quoi ? | Comment y accéder ? |
|------|--------|-------------------|
| **VM Hub** | Omni, Tailscale, Comet | Tailscale (admin), Direct (Comet) |
| **K8s Cluster** | Toutes les apps web | Cloudflare Tunnel (public) |
| **Internet** | DNS Cloudflare | Cloudflare gère les routes |

**Règle d'or:**
- Services publics → K8s + Tunnel
- Admin/Infrastructure → VM + Tailscale
- Streaming/Latence critique → VM + Direct
