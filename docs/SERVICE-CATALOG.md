# Catalogue des Services Homelab V1.0

Ce document recense les services gérés par **Pulumi** sur l'infrastructure.

## 🚀 Services Déployés (Actifs)

### Gateway & Identity (OCI - OKE)

| Service | Usage | Namespace | Status |
| :--- | :--- | :--- | :--- |
| **Traefik** | Ingress Controller HTTPS | `traefik` | ✅ |
| **Cloudflared** | Tunnel Edge Zero Trust | `cloudflared` | ✅ |
| **Authentik** | Identity Provider (IdP) & SSO | `security` | ✅ |
| **Vaultwarden** | Mots de passe (OIDC Auto-Provision) | `security` | ✅ |

### Workloads & Data (OCI - OKE)

| Service | Usage | Namespace | Status |
| :--- | :--- | :--- | :--- |
| **Homepage** | Dashboard d'accueil | `default` | ✅ |
| **n8n** | Automatisation (Workflows) | `automation` | ✅ |
| **Navidrome** | Serveur de Streaming Audio | `media` | ✅ |
| **Soulseek** | Partage P2P (Nicotine+) | `media` | ✅ |
| **CloudNativePG** | Clusters PostgreSQL K8s | `databases` | ✅ |
| **Redis** | In-memory Cache | `databases` | ✅ |

---

## 💾 Stockage Utilisé

- **Local Path CSI**: Pour le stockage éphémère rapide des pods.
- **SMB CSI (Hetzner Storage Box)**: Pour le stockage persistant capacitif (Média, Base de données backups). Géré via `StorageBoxManager` et l'API Hetzner Cloud.
- **OCI Object Storage**: Fourniture de buckets S3 natifs de l'Oracle Free Tier.

---

## 🔮 Roadmap Services (V2.0)

Cette liste recense les services identifiés pour de futurs déploiements.

### 🏠 Cloud Personnel (Prochaine Étape)
| Service | Usage | Description |
| :--- | :--- | :--- |
| **Nextcloud** | Fichiers | Cloud personnel sécurisé pour Sync, Calendriers et Contacts. |
| **Paperless-ngx** | Documents | Gestion et archivage OCR de documents administratifs. |
| **Immich** | Photos | Gestionnaire de photos (nécessitera potentiellement le noeud Local Proxmox pour le stockage/encodage). |

### 📊 Observabilité
| Service | Usage | Description |
| :--- | :--- | :--- |
| **Grafana Agent** | Collecte | Envoi des métriques K8s vers Grafana Cloud. |
| **Loki** | Logs | Centralisation des logs applicatifs. |

### 🤖 Intelligence Artificielle Expérimentale
| Service | Usage | Description |
| :--- | :--- | :--- |
| **Dify** | LLMOps | RAG, orchestration d'agents LLM, workflows IA privés. |
| **AnythingLLM** | Desktop/Web AI | Workspace IA tout-en-un. |
