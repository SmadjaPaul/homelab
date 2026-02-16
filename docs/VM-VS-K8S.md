# Répartition des Services: VM vs Kubernetes

## Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                    VM-HUB (oci-hub)                             │
│                    1 OCPU / 4GB RAM                             │
├─────────────────────────────────────────────────────────────────┤
│  🔧 Services Infrastructure (nécessaires avant K8s)             │
│  ├─ Omni Control Plane (port 50000/50001)                      │
│  ├─ Tailscale Subnet Router                                    │
│  └─ Comet Streaming (port 8080)                                │
├─────────────────────────────────────────────────────────────────┤
│  🐳 Docker Runtime                                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Gère le cluster
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CLUSTER KUBERNETES                           │
│                    3 VMs (3 OCPU / 20GB)                        │
├─────────────────────────────────────────────────────────────────┤
│  🌐 Services Publics (via Cloudflare Tunnel)                   │
│  ├─ Authentik (IdP)                                            │
│  ├─ Nextcloud (Cloud)                                          │
│  ├─ Matrix (Chat)                                              │
│  └─ Homepage, Vaultwarden, etc.                                │
├─────────────────────────────────────────────────────────────────┤
│  🔒 Infrastructure K8s                                         │
│  ├─ Cloudflared (Tunnel)                                       │
│  ├─ External DNS                                               │
│  ├─ Cert-manager                                               │
│  ├─ Traefik (Ingress)                                          │
│  └─ External Secrets                                           │
└─────────────────────────────────────────────────────────────────┘
```

## Pourquoi cette répartition ?

### Services sur la VM Hub (Docker)

#### 1. **Omni Control Plane**
**Pourquoi sur VM et pas dans K8s ?**
- Omni est le **control plane** qui gère Kubernetes
- Il doit exister **avant** que le cluster K8s existe
- C'est un "chicken and egg" problem

**Analogie:**
```
Omni = Chef d'orchestre
K8s = Orchestre

Le chef doit être là avant que l'orchestre commence à jouer !
```

#### 2. **Tailscale Subnet Router**
**Pourquoi sur VM ?**
- Doit avoir une IP statique sur le réseau VCN
- Doit tourner 24/7 pour router le trafic admin
- Indépendant du cycle de vie de K8s

**Rôle:**
```
Ton PC (Tailscale) ←──VPN──→ VM-Hub (Subnet Router) ←──→ Réseau privé OCI (10.0.0.0/16)
                              │
                              ├─→ 10.0.1.2 (Omni)
                              ├─→ 10.0.1.10 (K8s Control Plane)
                              └─→ 10.0.1.11 (K8s Worker)
```

#### 3. **Comet (Streaming)**
**Pourquoi sur VM et pas dans K8s ?**
- **Latence:** Streaming temps réel, besoin de <50ms
- **Simplicité:** Un seul container, pas besoin de K8s
- **Performance:** Pas de overhead Kubernetes

**Comparaison:**
```
Sur VM: User → Cloudflare → VM-Hub (2 hops)
Sur K8s: User → Cloudflare → Traefik → Service → Pod (4 hops)
```

### Services dans Kubernetes

#### **Tout le reste !**

**Pourquoi dans K8s ?**

1. **Haute Disponibilité**
   - Si un nœud tombe, les pods redémarment ailleurs
   - Réplication automatique

2. **GitOps**
   - Configuration dans Git
   - Déploiement automatique via Flux CD
   - Rollback facile

3. **Secrets Management**
   - Intégration Doppler
   - Rotation automatique
   - Pas de secrets dans les containers

4. **Scalabilité**
   - Horizontal Pod Autoscaler
   - Ajout de workers facile

## Détail par Service

### Sur la VM Hub (Docker Compose)

| Service | Fichier | Ressources | Pourquoi ici ? |
|---------|---------|------------|----------------|
| **Omni** | `/opt/omni/docker-compose.yaml` | 1 CPU, 2GB RAM | Control plane K8s |
| **Tailscale** | Installé sur l'OS | ~50MB RAM | VPN subnet router |
| **Comet** | `/opt/comet/docker-compose.yaml` | 0.5 CPU, 512MB | Streaming latence |

**Total VM Hub:** ~1.5 CPU / 2.5GB RAM utilisés
**Reste disponible:** 2.5GB RAM pour buffer

### Dans Kubernetes (Helm/Flux)

| Service | Namespace | Ressources | Type |
|---------|-----------|------------|------|
| **Cloudflared** | cloudflare | 100m CPU, 128MB | Tunnel |
| **External DNS** | external-dns | 50m CPU, 64MB | DNS sync |
| **Cert-manager** | cert-manager | 100m CPU, 128MB | TLS |
| **Traefik** | infra | 200m CPU, 256MB | Ingress |
| **Authentik** | authentik | 500m CPU, 1GB | IdP |
| **Nextcloud** | nextcloud | 500m CPU, 512MB | Cloud |
| **PostgreSQL** | (avec apps) | 200m CPU, 512MB | DB |
| **Redis** | (avec apps) | 100m CPU, 256MB | Cache |

**Total K8s:** ~2 CPU / 4GB RAM pour l'infrastructure de base
**Reste disponible:** 1 CPU / 16GB RAM pour les applications

## Architecture de Bootstrap

### Ordre de Démarrage

```
Phase 1: Terraform crée la VM Hub
    │
    ▼
Phase 2: Cloud-init s'exécute sur VM Hub
    ├─ Installe Docker
    ├─ Démarre Omni
    ├─ Configure Tailscale
    └─ Démarre Comet
    │
    ▼
Phase 3: Omni crée le cluster K8s
    ├─ Génère image Talos
    ├─ Déploie sur les 3 VMs
    └─ Cluster prêt
    │
    ▼
Phase 4: Flux CD déploie les apps
    ├─ Cloudflared (se connecte au tunnel)
    ├─ External DNS (crée les records)
    ├─ Traefik (reçoit le trafic)
    └─ Applications (Authentik, Nextcloud...)
```

### Dépendances

```
VM Hub (Omni)
    │
    ├─ Dépend de: Rien (1er service)
    │
    ▼
K8s Cluster (Talos)
    │
    ├─ Dépend de: Omni (reçoit config)
    │
    ▼
Apps K8s (Flux CD)
    │
    ├─ Dépend de: Cluster K8s
    └─ Dépend de: Cloudflared (pour accès externe)
```

## Cas d'usage: Que se passe-t-il si...

### ...le cluster K8s tombe ?

```
❌ Authentik inaccessible (dans K8s)
❌ Nextcloud inaccessible (dans K8s)
✅ Omni toujours accessible (sur VM)
✅ Comet toujours accessible (sur VM)
✅ Tailscale fonctionne toujours (sur VM)

→ Tu peux debug via Omni et Tailscale
```

### ...la VM Hub tombe ?

```
❌ Omni inaccessible
❌ Impossible de manager K8s
❌ Comet inaccessible
⚠️  K8s continue de tourner (mais pas de control plane)
⚠️  Tailscale down (pas d'accès admin)

→ Gros problème ! Mais K8s continue de servir les apps
→ Redémarrer la VM ou restore depuis backup
```

### ...un worker K8s tombe ?

```
✅ Omni OK (sur VM)
✅ Control Plane OK (sur talos-cp-1)
⚠️  Pods redéployés sur autres workers
✅ Service continu (grâce aux replicas)

→ Kubernetes gère automatiquement
```

## Migration d'un service de VM vers K8s

### Scénario: Tu veux déplacer Comet dans K8s

**Avantages:**
- GitOps (config dans Git)
- HA (redémarrage automatique)
- Secrets management

**Inconvénients:**
- Plus de latence (tunnel)
- Complexité inutile pour un service simple

**Comment faire:**

1. Créer le manifest K8s:
```yaml
# kubernetes/apps/media/comet/
apiVersion: apps/v1
kind: Deployment
metadata:
  name: comet
  namespace: media
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: comet
        image: ghcr.io/g0ldyy/comet:latest
        ports:
        - containerPort: 8080
```

2. Changer l'ingress:
```yaml
# Avant (Direct sur VM)
IP_PUBIQUE_VM:8080 → Comet

# Après (Via Tunnel)
comet.smadja.dev → Tunnel → Traefik → Comet Pod
```

3. Pusher sur Git → Flux déploie

4. Stopper sur VM:
```bash
ssh ubuntu@vm-hub "cd /opt/comet && docker compose down"
```

## Monitoring: Où regarder ?

### Sur la VM Hub

```bash
# Se connecter
ssh ubuntu@$(terraform output -raw hub_public_ip)

# Voir les containers
docker ps

# Logs Omni
docker logs omni

# Status Tailscale
sudo tailscale status

# Status Comet
docker logs comet
```

### Dans Kubernetes

```bash
# Voir tous les pods
kubectl get pods -A

# Logs Cloudflared (tunnel)
kubectl logs -n cloudflare deployment/cloudflare-tunnel

# Logs Traefik (ingress)
kubectl logs -n infra deployment/traefik

# Voir services
kubectl get svc -A

# Voir ingress (routes HTTP)
kubectl get ingress -A
```

## Bonnes pratiques

### ✅ À mettre sur la VM

- **Control planes** (Omni, Rancher, etc.)
- **VPN/Réseau** (Tailscale, Wireguard)
- **Services simples** avec besoin latence (Streaming)
- **Services critiques** pour le bootstrap de K8s

### ✅ À mettre dans K8s

- **Applications web** (Nextcloud, Matrix, etc.)
- **Services avec état** (DB, cache)
- **Services nécessitant HA**
- **Tout ce qui change souvent** (GitOps)

### ❌ À ne PAS faire

- Mettre Omni dans K8s (chicken-egg problem)
- Mettre Tailscale dans K8s (perte connexion admin si K8s down)
- Mettre des services critiques uniquement dans K8s (single point of failure)

## Résumé

| Critère | VM Hub | K8s Cluster |
|---------|--------|-------------|
| **Disponibilité** | 99% (single node) | 99.9% (multi-node) |
| **Mise à jour** | Manuelle | GitOps automatique |
| **Latence** | Minimale | Légèrement supérieure |
| **Complexité** | Simple | Plus complexe |
| **Use case** | Infrastructure core | Applications |

**Règle du pouce:**
> Si le service est nécessaire pour démarrer ou gérer K8s → VM
> Si le service est une application métier → K8s
