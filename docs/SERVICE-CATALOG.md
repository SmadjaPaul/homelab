# Catalogue des Services (Hybride K8s)

Ce document recense les services gérés par **Flux CD** sur les deux environnements.

## 🚀 Services Déployés

### Gateway & Cloud Infrastructure (OCI - OKE)

| Service | Usage | Namespace | Status |
| :--- | :--- | :--- | :--- |
| **Traefik** | Ingress Controller | `traefik` | ✅ |
| **Cloudflared** | Tunnel Zero Trust | `cloudflared` | ✅ |
| **Authentik** | Identity Provider & SSO | `security` | ✅ |
| **Vaultwarden** | Mots de passe | `security` | 📅 Planifié |

### Workloads & Data (Home - Talos SNC)

| Service | Usage | Namespace | Status |
| :--- | :--- | :--- | :--- |
| **n8n** | Automatisation | `automation` | ✅ |
| **Lidarr** | Musique | `media` | ✅ |
| **Audiobookshelf** | Livres Audio | `media` | ✅ |
| **CloudNativePG** | Bases de données | `databases` | ✅ |

## 💾 Sauvegardes & Persistance
- **PV/PVC** : Stockage local (local-path) pour la performance.
- **Offsite** : Backups CNPG vers OCI S3 via External Secrets.
