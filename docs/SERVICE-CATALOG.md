# Catalogue des Services Homelab V1.0

Ce document recense les services gérés par **Pulumi** sur l'infrastructure.

## 🚀 Services Déployés (Actifs)

### Gateway & Identity (OCI - OKE)

| Service | Usage | Namespace | Status |
| :--- | :--- | :--- | :--- |
| **Envoy Gateway** | Ingress Controller HTTPS | `envoy-gateway-system` | ✅ |
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

## 🔮 Future Implementations & Research (Wishlist)

Cette liste recense des services identifiés pour de futurs besoins. **Ne pas déployer sans audit préalable.**

### 🏠 Family & Home Management
| Service | Usage | Description |
| :--- | :--- | :--- |
| **Home Assistant** | Domotique | Hub central pour la maison connectée. |
| **Jellyfin** | Media Center | Alternative libre à Plex pour le streaming vidéo. |
| **Ryot** | Tracking | Suivi de vie (films, sport, livres) polyvalent. |

### 💼 Small Business & Productivity
| Service | Usage | Description |
| :--- | :--- | :--- |
| **Vikunja** | Tasks | Gestion de tâches et projets (Kanban/Gantt). |
| **AFFiNE** | Knowledge Base | Alternative à Notion et Miro pour la collaboration. |
| **Zulip** | Communication | Chat d'équipe avec fils de discussion (Slack alt). |
| **ERPNext** | Business | Suite ERP complète (Compta, HR, Stock). |
| **Metabase** | Analytics | BI simple pour explorer les données des DBs. |
| **Postiz** | Marketing | Planification et gestion des réseaux sociaux. |
| **Kestra** | Automation | **Recommandé** : Alternative légère à n8n/Airflow. Workflows en YAML (IaC pur), topologie DAG native, très performant. |
| **Windmill** | Automation | Alternative code-first (TypeScript/Python/Rust) gérable via Git. |

### 🤖 Artificial Intelligence (Secure)
| Service | Usage | Description |
| :--- | :--- | :--- |
| **OneAPI** | LLM Gateway | Alternative à LiteLLM spécialisée dans le **contrôle d'usage** (quotas, budgets, clés multi-utilisateurs). |

### 🖥️ Infrastructure & Device Management
| Service | Usage | Description |
| :--- | :--- | :--- |
| **Fleet DM** | Fleet Mgmt | Gestion de parc informatique (Linux, Mac, Windows) via osquery. |
| **Netbird** | Mesh VPN | Alternative à Tailscale/ZeroTier auto-hébergée. |

### ⚡ "Superpowers" (OSINT & Pentest)
| Service | Usage | Description |
| :--- | :--- | :--- |
| **SpiderFoot** | OSINT | Automatisation de la collecte d'infos publiques. |
| **Recon-ng** | Reconnaissance | Framework complet pour la reconnaissance web. |
| **OWASP ZAP** | Security | Scanner de vulnérabilités pour applications web. |
| **Infection Monkey** | Pentest | Simulation d'attaques pour tester la résilience réseau (semi-auto). |
| **sqlmap** | Security | Test d'injection SQL automatisé. |
