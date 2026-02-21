# Catalogue des Services

Ce document recense les services déployés ou prévus, leur usage, et leur localisation.

## 🌐 Architecture Réseau & Trafic

Le cluster OKE (Oracle Cloud) **n'a pas d'IP publique**. Tout le trafic externe passe par un **Cloudflare Tunnel**.

```
Utilisateur → Cloudflare Edge → cloudflared (pod K8s) → Kong Gateway → Service
```

### Flux détaillé

| Étape | Composant | Rôle |
| :--- | :--- | :--- |
| 1 | **Cloudflare DNS** | CNAME `*.smadja.dev` → `<tunnel-id>.cfargotunnel.com` (géré par Terraform) |
| 2 | **Cloudflare Access** | Auth0 SAML login + RBAC par rôle (admin, family, etc.) |
| 3 | **cloudflared** (pod) | Tunnel QUIC vers le cluster, catch-all → Kong |
| 4 | **Kong Gateway** | Routage `HTTPRoute` vers les services internes (`ClusterIP`) |

### Services exposés

| URL | Service | Namespace | Port backend | Accès | Credentials |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `home.smadja.dev` | Homepage | `public` | 80 | admin, family, professional, media_user | aucun |
| `grafana.smadja.dev` | Grafana | `o11y` | 80 (→3000) | admin | `admin` / `admin` |
| `n8n.smadja.dev` | n8n | `automation` | 5678 | admin | aucun (open) |
| `omni.smadja.dev` | Omni | `omni` | 443 | admin | OIDC/WebAuthn |
| `proxmox.smadja.dev` | Proxmox VE | local | 8006 | admin | identifiants Proxmox |

> **DNS** : géré par Terraform (`terraform/cloudflare`), pas par `external-dns`.
> **Kong** : `ClusterIP` — pas de LoadBalancer, le trafic arrive via cloudflared.

## 🚀 Services Core & Business

| Service | Catégorie | Usage | Cible |
| :--- | :--- | :--- | :--- |
| **Omni** | Infrastructure | Gestion multi-cluster Talos | Cloud (OCI) |
| **Auth0** | Sécurité | Identité (IdP) & SSO (SAML/OIDC) | Cloud (SaaS) |
| **Doppler** | Sécurité | Orchestration des secrets & Sync K8s | Cloud (SaaS) |
| **Nextcloud** | Cloud Perso | Fichiers, agenda, contacts | Home (Data) |
| **Immich** | Photos | Galerie photo souveraine | Home (Data) |
| **Vaultwarden** | Sécurité | Gestionnaire de mots de passe | Cloud (OCI) |
| **FleetDM** | Business | Gestion des devices (MDM/osquery) | Home |
| **Odoo** | Business | Gestion d'entreprise (ERP/CRM) | Home |
| **Paperless-ngx** | Business | Archivage factures & OCR | Home |
| **Actual Budget** | Finance | Gestion budget & patrimoine | Home |

---

## 🧠 Gestion de la Connaissance & PKM (Markdown)

| Service | Usage | Recommandation | Cible |
| :--- | :--- | :--- | :--- |
| **Git Server** | Sync Obsidian / Code | **Forgejo** (Gitea fork) | Home |
| **Markdown Wiki**| Éditeur Markdown live | **SilverBullet** | Home |
| **Bookmarks** | Gestionnaire liens/lecture | **Linkwarden** | Home |

---

## 🛡️ Sécurité & OSINT (En réflexion pour souveraineté)

| Service | Usage | Recommandation | Cible |
| :--- | :--- | :--- | :--- |
| **Firewall/IDS** | Protection réseau & IPS | **CrowdSec** | Home |
| **DNS Security** | Filtrage AdBlock & Sécurité | **AdGuard Home** | Home |
| **Data Leak** | Surveillance fuites utilisateurs | **Have I Been Pwned (via API)** | Cloud |
| **Pentest** | Outils d'attaque (Metasploit/ZAP) | **Kali Linux (VM)** | Home |
| **OSINT** | Recherche d'info (Sherlock/SpiderFoot)| **SpiderFoot** | Home |

---

## 📢 Communication & Publication (À explorer)

| Service | Usage | Recommandation | Cible |
| :--- | :--- | :--- | :--- |
| **Blog** | Publication de contenus & Blog | **Ghost** | Home |
| **Newsletter** | Envoi de newsletters & Mailing | **Listmonk** | Home |
| **Matrix** | Chat | **Synapse** (Echange OpenClaw) | Home |
| **Flux RSS** | Agrégateur news | **FreshRSS** | Home |

---

## 🎯 Productivité & Vie Domestique (À explorer)

| Service | Usage | Recommandation | Cible |
| :--- | :--- | :--- | :--- |
| **ToDo List** | Gestion tâches pro/perso | **Vikunja** | Home |
| **Home ERP** | Stock, courses, tâches ménage | **Grocy** | Home |
| **Social** | Publication multi-plateforme | **n8n (Automations)** | Home |

---

## 🤖 Intelligence Artificielle

| Service | Usage | Recommandation | Cible |
| :--- | :--- | :--- | :--- |
| **Gateway IA** | Proxy unique pour LLMs | **LiteLLM** | Cloud (OCI) |
| **Assistant** | Agent autonome & UI | **OpenClaw + OpenWebUI** | Home |

---

## 🩺 Santé & Bien-être

| Service | Usage | Recommandation | Cible |
| :--- | :--- | :--- | :--- |
| **Fitness** | Suivi musculation & nutrition | **Wger** | Home |
| **Dashboard** | Suivi Garmin / Poids / Santé | **Grafana + InfluxDB** | Home |

---

## 🛠️ Maintenance & Admin

| Service | Usage | Recommandation | Cible |
| :--- | :--- | :--- | :--- |
| **Monitoring** | Status page & Alerting | **Uptime Kuma** | Cloud (OCI) |
| **Dashboard** | Portail d'accès centralisé | **Homepage** | Home |
| **Updates** | Mise à jour auto des images | **Renovate (K8s)** | Cloud |
| **Backup** | Sauvegarde cluster | **Velero** | Cloud |

---

## 🎬 Services Hors-Cluster (VPS / Docker Simple)

| Service | Usage | Cible |
| :--- | :--- | :--- |
| **Comet** | Add-on Stremio (Stremio/Debrid) | VPS (Docker) |
| **Zilean** | Indexeur Debrid | VPS (Docker) |
| **Stremio** | Client média final | Client Side |
