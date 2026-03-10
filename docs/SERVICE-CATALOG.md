# Catalogue des Services Homelab V2.0

Ce document recense les services gérés par **Pulumi** sur l'infrastructure.

## 🚀 Services Déployés (Actifs)

### Gateway & Identity (OCI - OKE - 2 Nodes)

| Service | Usage | Namespace | URL | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Envoy Gateway** | Ingress Controller HTTPS | `envoy-gateway` | - | ✅ |
| **Cloudflared** | Tunnel Edge Zero Trust | `cloudflared` | - | ✅ |
| **Authentik** | Identity Provider (IdP) & SSO | `authentik` | [auth.smadja.dev](https://auth.smadja.dev) | ✅ |
| **Vaultwarden** | Mots de passe (OIDC Auto-Provision) | `vaultwarden` | [vault.smadja.dev](https://vault.smadja.dev) | ✅ |

### Workloads & Data (OCI - OKE)

| Service | Usage | Namespace | URL | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Homepage** | Dashboard d'accueil | `homelab` | [home.smadja.dev](https://home.smadja.dev) | ✅ |
| **Navidrome** | Serveur de Streaming Audio | `music` | [music.smadja.dev](https://music.smadja.dev) | ✅ |
| **Soulseek** | Partage P2P (slskd) | `music` | [soulseek.smadja.dev](https://soulseek.smadja.dev) | ✅ |
| **Audiobookshelf** | Livres Audio | `audiobooks` | [audiobooks.smadja.dev](https://audiobooks.smadja.dev) | ✅ |
| **Nextcloud** | Cloud & Fichiers | `productivity` | [cloud.smadja.dev](https://cloud.smadja.dev) | ⏳ (Setup) |
| **Paperless-ngx** | Gestion de Documents | `productivity` | [paperless.smadja.dev](https://paperless.smadja.dev) | ⏳ (SSO Partial) |
| **Open-WebUI** | Interface IA / LLM | `ai` | [ai.smadja.dev](https://ai.smadja.dev) | ✅ |
| **Envoy AI Gateway** | Proxy & Securité LLM | `observability` | - | ✅ |

### Infrastructure

| Service | Usage | Namespace | Status |
| :--- | :--- | :--- | :--- |
| **CloudNativePG** | Clusters PostgreSQL K8s | `cnpg-system` | ✅ |
| **Prometheus/Loki** | Stack Observabilité | `observability` | ✅ |
| **External Secrets** | Gestion Secrets (Doppler) | `external-secrets` | ✅ |

---

## 💾 Stockage & Quotas (Optimisé V2)

- **OCI Block Storage (Consolidé)**: Un unique cluster HA **homelab-db** de **2 x 50GB** (100GB total) pour toutes les bases de données applicatives. Respecte la limite "Always Free" de 200GB (incluant les volumes de boot).
- **Local Path CSI**: Utilisé pour les données éphémères ou haute performance (Redis, Caches, Temp).
- **SMB CSI (Hetzner Storage Box)**: Pour les gros volumes de données persistantes (Nextcloud Data, Navidrome Music, Paperless Documents).
- **OCI Object Storage**: Buckets S3 pour les backups automatiques de `homelab-db`.

---

## 🔮 Roadmap Services (Wishlist)

- **Immich**: Photos (Prochaine étape majeure).
- **Home Assistant**: Domotique.
- **cal.com**: prise de rendezvous auto.
- **Add guard home**: add blocker.
- **SearXGN**: search engine.

---

> **Note**: Ce catalogue doit correspondre à `apps.yaml`. En cas de doute, `apps.yaml` est la source de vérité.
