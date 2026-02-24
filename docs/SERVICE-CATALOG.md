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

## 🔮 Future Implementations & Research (Wishlist)

Cette liste recense des services identifiés pour de futurs besoins. **Ne pas déployer sans audit préalable.**

### 🏠 Family & Home Management
| Service | Usage | Description |
| :--- | :--- | :--- |
| **Immich** | Photos | Alternative haute performance à Google Photos. |
| **Paperless-ngx** | Documents | Gestion et archivage de documents avec OCR. |
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
| **Dify** | Assistant LLM | Plateforme LLMOps complète. Supporte le **RAG**, l'orchestration d'agents et commence à intégrer **MCP**. Idéal pour un assistant sécurisé. |
| **OneAPI** | LLM Gateway | Alternative à LiteLLM spécialisée dans le **contrôle d'usage** (quotas, budgets, clés multi-utilisateurs). |
| **AnythingLLM** | Desktop/Web AI | Workspace IA tout-en-un avec RAG local évolué. |

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
