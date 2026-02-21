# Services Cloud & Plans de Réversibilité

Ce document détaille chaque service tiers utilisé, son implémentation "As-Code", et les alternatives pour garantir la souveraineté.

---

## ☁️ Synthèse des Services

| Service | Rôle | Implémentation As-Code | Tiers Utilisé |
| :--- | :--- | :--- | :--- |
| **OCI (Oracle Cloud)** | Hébergement Hub Management | `terraform/oracle-cloud` | Always Free (4 VMs ARM) |
| **Cloudflare** | DNS, WAF, Tunnel Zero Trust | `terraform/cloudflare` | Free Tier |
| **Auth0** | Identity Provider (SSO Primaire) | `terraform/auth0` | Free Tier (7k users) |
| **Doppler** | Gestionnaire de secrets | `doppler.yaml` | Free Tier |
| **Migadu** | Hébergement Email pro | `terraform/migadu` | Payant (Micro) |
| **Grafana Cloud** | Observabilité centralisée | `terraform/grafana-cloud` | Free Tier |

---

## 🛠️ Détail par Service & Plans de Migration

### 1. Identity Management : Auth0
- **Usage actuel** : Authentification Zero Trust (OIDC/SAML) pour le Cloudflare Tunnel et les applications.
- **As-Code** : Module `terraform/auth0`.
- **Réversibilité** : Bien que complexe, un basculement vers **Authentik** ou **Authelia** (auto-hébergé) est le plan à long terme si la souveraineté totale est requise. Pour le moment, Auth0 est privilégié pour sa stabilité.

### 2. Monitoring Sécurité : Data Leaks
- **Usage** : Surveillance des comptes utilisateurs compromis.
- **Service** : **Have I Been Pwned** (API) ou **DeHashed**.
- **Implémentation** : Script n8n ou Check dans Vaultwarden.
- **Plan** : Intégrer des alertes via Telegram/Matrix dès qu'une fuite est détectée.

### 3. Oracle Cloud & Infrastructure Core
- (Même plan : Migration vers VM local Proxmox si besoin de quitter le cloud).

### 4. Cloudflare & Réseau
- (Même plan : Traefik local + VPN Mesh si besoin de quitter Cloudflare).

### 5. Observabilité & Secrets
- (Même plan : Stack LGTM locale pour Grafana, Vault pour les secrets).
