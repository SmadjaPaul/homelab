---
sidebar_position: 1
---

# Architecture

## Philosophie

Cette architecture suit plusieurs principes :

1. **GitOps** : Tout est dans Git, déployé automatiquement
2. **Zero Trust** : Pas de ports ouverts, accès via tunnels
3. **Coût minimal** : Utilisation des free tiers
4. **Résilience** : Backups automatiques, monitoring proactif

## Environnements

### Local (Proxmox)

| VM | Rôle | Ressources |
|----|------|------------|
| Proxmox Host | Hyperviseur | 64GB RAM, 8 cores |
| talos-dev | Cluster DEV | 4GB RAM |
| talos-prod | Cluster PROD | 16GB RAM |

### Cloud (Oracle)

| VM | Rôle | Ressources |
|----|------|------------|
| oci-mgmt | Management | 1 OCPU, 6GB |
| oci-node-1 | K8s Node | 2 OCPU, 12GB |
| oci-node-2 | K8s Node | 1 OCPU, 6GB |

## Flux de données

```
Utilisateur
    │
    ▼
Cloudflare (WAF + CDN)
    │
    ├──► Tunnel ──► Services publics (home, auth, status)
    │
    └──► Twingate ──► Services admin (grafana, argocd, proxmox)
```

## Sécurité

### Couches de protection

1. **Edge** : Cloudflare WAF, DDoS protection
2. **Accès** : Cloudflare Access, Twingate Zero Trust
3. **Identité** : Authentik SSO (OIDC)
4. **Réseau** : Cilium Network Policies
5. **Secrets** : SOPS encryption, External Secrets

### Authentification

| Type de service | Authentification |
|-----------------|------------------|
| Admin (Grafana, ArgoCD) | Cloudflare Access + Authentik |
| Utilisateur (home, status) | Public ou Authentik |
| Infrastructure (Proxmox) | Twingate + local auth |

## Diagrammes

### Vue d’ensemble

```mermaid
flowchart TB
    subgraph Internet
        User[👤 User]
        CF[☁️ Cloudflare]
        TG[🔐 Twingate]
    end

    subgraph "Oracle Cloud (Free Tier)"
        OCI_MGMT[🖥️ oci-mgmt 1 OCPU / 6GB]
        OCI_N1[🖥️ oci-node-1 2 OCPU / 12GB]
        OCI_N2[🖥️ oci-node-2 1 OCPU / 6GB]
    end

    subgraph "Home Network"
        PVE[🖥️ Proxmox VE]
        NAS[💾 NAS/Storage]
    end

    subgraph "Kubernetes Cluster"
        ARGO[🔄 ArgoCD]
        GRAF[📊 Grafana]
        PROM[📈 Prometheus]
        KEY[🔑 Authentik]
        HOME[🏠 Homepage]
        CFD[🌐 Cloudflared]
        TWC[🔐 Twingate Connector]
    end

    User -->|HTTPS| CF
    User -->|VPN| TG
    CF -->|Tunnel| CFD
    TG -->|Connector| TWC
    CFD --> ARGO & GRAF & KEY & HOME
    TWC --> PVE & NAS & PROM
```

### Flux GitOps

```mermaid
flowchart LR
    subgraph "Development"
        DEV[👨‍💻 Developer]
        GH[📦 GitHub]
    end

    subgraph "CI/CD"
        GHA[⚡ GitHub Actions]
        TF[🏗️ Terraform]
    end

    subgraph "Cluster"
        ARGO[🔄 ArgoCD]
        K8S[☸️ Kubernetes]
    end

    DEV -->|git push| GH
    GH -->|trigger| GHA
    GHA -->|plan/apply| TF
    TF -->|provision| OCI[☁️ Oracle Cloud]
    TF -->|configure| CF[☁️ Cloudflare]
    GH -->|webhook| ARGO
    ARGO -->|sync| K8S
```

### Couches de sécurité

```mermaid
flowchart TB
    subgraph "Layer 1: Edge"
        CF[Cloudflare WAF]
        DDoS[DDoS Protection]
        SSL[SSL/TLS Termination]
    end

    subgraph "Layer 2: Access"
        TG[Twingate Zero Trust]
        CFA[Cloudflare Access]
        KEY[Authentik SSO]
    end

    subgraph "Layer 3: Network"
        CIL[Cilium CNI]
        NP[Network Policies]
    end

    subgraph "Layer 4: Application"
        RBAC[Kubernetes RBAC]
        SEC[SOPS Secrets]
    end

    CF --> TG & CFA
    TG & CFA --> KEY
    KEY --> CIL
    CIL --> RBAC
```

### Carte des services

```mermaid
graph TB
    subgraph "Public (Cloudflare Tunnel)"
        home[🏠 home]
        graf[📊 grafana]
        argo[🔄 argocd]
        auth[🔑 auth]
    end

    subgraph "Privé (Twingate)"
        prom[📈 prometheus]
        alert[🔔 alertmanager]
        pve[🖥️ proxmox]
    end

    CF{Cloudflare Tunnel} --> home & graf & argo & auth
    TG{Twingate} --> prom & alert & pve
```
