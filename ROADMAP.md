# 🗺️ Roadmap Homelab

## Phase 1: Fondations (Semaine 1-2)

### Infrastructure
- [x] Nettoyer et restructurer le repository
- [x] Configuration Doppler
- [x] Scripts de bootstrap
- [ ] Déployer VMs OCI avec Terraform
  - [ ] VM Hub (Omni)
  - [ ] VM 1 (Control Plane Talos)
  - [ ] VM 2 (Worker Talos)
  - [ ] VM 3 (Worker Talos)
- [ ] Configurer Omni Control Plane
- [ ] Créer cluster Talos avec Omni

### Kubernetes Core
- [ ] Installer External Secrets Operator
- [ ] Configurer sync Doppler → Kubernetes
- [ ] Installer cert-manager
- [ ] Configurer Let's Encrypt + Cloudflare DNS

## Phase 2: Ingress & Sécurité (Semaine 3)

- [ ] Déployer Traefik (Ingress Controller)
- [ ] Configurer Cloudflare Tunnel
- [ ] Déployer Authentik
  - [ ] Configurer providers (Google OAuth)
  - [ ] Créer applications (Nextcloud, etc.)
  - [ ] Configurer policies
- [ ] Déployer Authelia (backup/fallback)

## Phase 3: Services Professionnels (Semaine 4-5)

- [ ] Déployer Nextcloud
- [ ] Déployer Gitea
- [ ] Déployer Vaultwarden
- [ ] Déployer Homepage (dashboard)

## Phase 4: Business Stack (Semaine 6-8)

- [ ] Déployer Odoo (ERP)
- [ ] Déployer FleetDM (MDM)
  - [ ] Configurer osquery
  - [ ] Enroller devices
- [ ] Déployer Snipe-IT (ITAM)
- [ ] Déployer Wazuh (SIEM)

## Phase 5: Services Famille (Semaine 9-10)

- [ ] Déployer Matrix (chat)
- [ ] Déployer Immich (photos)
- [ ] Déployer Jellyfin (streaming - local)

## Phase 6: Home Lab (Semaine 11+)

- [ ] Installer Proxmox
- [ ] Créer VMs Talos (Home)
- [ ] Connecter cluster Home à Omni
- [ ] Migrer services média vers Home
- [ ] Configurer backup Kopia → B2

## Phase 7: Optimisation (Continu)

- [ ] Monitoring Grafana Cloud
- [ ] Alerting
- [ ] Documentation
- [ ] CI/CD GitHub Actions
- [ ] Renovate (auto-update)

## Décisions Techniques

### ✅ Validé
- **Omni** pour gestion clusters
- **Doppler** pour secrets
- **Flux CD** pour GitOps
- **Talos** pour OS Kubernetes
- **OCI** pour cloud (Always Free)

### 🔄 À décider
- **Traefik** vs **Cilium Gateway API**
- **Authentik** vs **Authelia** (ou les deux)
- **Longhorn** vs **Rook-Ceph** pour storage

## Notes

- Priorité: sécurité > fonctionnalités
- Services critiques d'abord (auth, ingress)
- Tester en staging avant production
- Documenter chaque étape
