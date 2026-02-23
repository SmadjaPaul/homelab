# 🗺️ Roadmap Homelab

## Phase 1: Infrastructure & Core (✅ Terminé)

### OCI Cluster
- [x] Nettoyer et restructurer le repository
- [x] Configuration Doppler
- [x] Scripts de bootstrap
- [x] Déployer OKE (Oracle Cloud Kubernetes Engine)
- [x] Installer Flux CD (GitOps)
- [x] Configurer External Secrets Operator (Doppler → K8s)

### Gestion Clusters
- [ ] Déployer **Omni** sur OCI (gestion centralisée des clusters)
  - [ ] Configurer Omni comme control plane
  - [ ] Préparer connection pour cluster Talos à la maison

### Cloudflare Access
- [x] Configurer Cloudflare Tunnel
- [x] Configurer Auth0 comme IdP (Legacy)
- [ ] Migrer vers Authentik comme IdP principal (En cours)
- [x] Configurer Zero Trust RBAC (tous utilisateurs Auth0 acceptés)
- [ ] Affiner les politiques d'accès par service avec Authentik

### TLS/SSL
- [x] Configurer cert-manager (via Let's Encrypt)
- [x] Configurer Cloudflare SSL strict
- [ ] Mettre en place Internal CA pour service-to-service

### Services Déployés
- [x] Homepage (dashboard)
- [x] n8n (automation)
- [x] Traefik (ingress)
- [x] External-DNS (gestion DNS Kubernetes)
- [x] External Secrets Operator
- [x] Lidarr, Audiobookshelf (media)

---

## Phase 2: Business Apps (En cours)

### Services à déployer
- [ ] CloudNativePG (postgresql operator) - requis pour:
  - [ ] Outline (wiki/documentation)
  - [ ] Vikunja (tasks)
  - [ ] Umami (analytics)
- [ ] Umami (analytics)
- [ ] Vaultwarden (passwords)

### Services en réflexion
- [ ] Nextcloud (fichiers, calendar, contacts)
- [ ] Gitea/Forgejo (code self-hosted)
- [ ] Paperless-ngx (documents)
- [ ] Odoo (ERP)

---

## Phase 3: Observability (Monitoring avec Grafana Cloud) (En cours)

### Monitoring (Grafana Cloud)
- [x] Créer compte Grafana Cloud (gratuit)
- [x] Configurer Prometheus remote write vers Grafana Cloud (k8s-monitoring)
- [ ] Configurer dashboards cluster (import depuis Grafana Cloud)
- [ ] Configurer alertes (Slack/Discord/PagerDuty)

### Logging
- [ ] Déployer Loki (centralisé logging)
- [ ] Configurer journalisation cluster
- [ ] Configurer retention policies

### Métriques Applicatives
- [x] Configurer node-exporter (dans k8s-monitoring)
- [x] Configurer metrics-server

---

## Phase 4: Security & Backups (En cours)

### Backup Strategy
- [ ] Configurer Velero (backup cluster)
- [ ] Configurer Kopia ou Restic pour données applicatives
- [ ] Configurer backup vers OCI Object Storage

### Network Policies
- [ ] Déployer network policies
- [ ] Restreindre communication inter-pods
- [ ] Configurer egress policies

### Security
- [x] Configurer Kyverno
- [x] Configurer CrowdSec
- [ ] Configurer RBAC audit

---

## Phase 5: Home Cluster (Talos)

### Home Server Setup
- [ ] Installer Proxmox sur serveur maison
- [ ] Créer VM Talos ou Baremetal (Single Node, 58GB RAM, 10 CPU)
- [ ] Connecter cluster home à Omni (OCI)

### Migration
- [ ] Migrer services média vers Home (Jellyfin, Immich)
- [ ] Configurer backup cluster OCI → Home

---

## Phase 6: CI/CD & Automation

### GitHub Actions
- [x] Pipeline deploy (flux-diff)
- [x] Pipeline Terraform (Cloudflare)
- [x] Pipeline lint/validation

### Automation
- [ ] Renovate (auto-update apps)
- [ ] Flux automation (image updates)

---

## Décisions Techniques

### ✅ Validé
- **OCI OKE** pour cluster cloud (gratuit)
- **Talos** pour cluster home (futur)
- **Omni** (via OCI) pour gestion multi-cluster
- **Doppler** pour secrets (gratuit)
- **Flux CD** pour GitOps
- **Cloudflare** pour DNS, Tunnel, Access (gratuit)
- **Authentik** pour authentification et SSO (Remplacement d'Auth0)
- **Grafana Cloud** pour monitoring (gratuit)
- **Migadu** pour email/SMTP (19 euros par an)
- **Traefik** comme ingress controller

### 🔄 À décider
- **Longhorn** vs **Rook-Ceph** pour storage (si besoin)
- **Backup destination**: OCI Object Storage vs autres

---

## Notes

- Priorité: sécurité > fonctionnalités
- Services critiques d'abord (auth, monitoring)
- Tester avant production
- Documenter chaque étape
- YOLO mode: `export OPENCODE_YOLO=true` ou dire "yolo" au début
