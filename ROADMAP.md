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


- [ ] Configurer providers OAuth/OIDC (Terraform échoue - bug provider)
- [ ] Configurer sources (Google, etc.)
- [ ] Créer applications protégés
- [ ] Configurer groups et policies
- [ ] Configurer SMTP (Migadu) - **manuel requis pour l'instant**

### Cloudflare Access
- [x] Configurer Cloudflare Tunnel
- [ ] Créer Access Policies par application
- [ ] Configurer Zero Trust RBAC

### TLS/SSL
- [x] Configurer cert-manager (via Let's Encrypt)
- [x] Configurer Cloudflare SSL strict
- [ ] Mettre en place Internal CA pour service-to-service

## Phase 3: Observability (Monitoring avec Grafana Cloud)

### Monitoring (Grafana Cloud)
- [ ] Créer compte Grafana Cloud (gratuit)
- [ ] Configurer Prometheus remote write vers Grafana Cloud
- [ ] Déployer Grafana Agent pour collecte métriques
- [ ] Configurer dashboards cluster (import depuis Grafana Cloud)
- [ ] Configurer alertes (Slack/Discord/PagerDuty)

### Logging
- [ ] Déployer Loki (centralisé logging)
- [ ] Configurer journalisation cluster
- [ ] Configurer retention policies

### Métriques Applicatives
- [x] Configurer node-exporter (dans kube-prometheus-stack)
- [x] Configurer metrics-server
- [ ] Configurer Grafana Agent pour logs applicatifs

## Phase 4: Services (core)

### Services Infrastructure
- [x] Homepage (dashboard)
- [x] Déployer services internes

### Services Professionnels
- [ ] Nextcloud (fichiers, calendar, contacts)
- [ ] Gitea (code self-hosted)
- [ ] Vaultwarden (passwords)

### Services Famille
- [ ] Immich (photos)
- [ ] Jellyfin (streaming local)
- [ ] Matrix (chat)

## Phase 5: Security & Backups

### Backup Strategy
- [ ] Configurer Velero (backup cluster)
- [ ] Configurer Kopia ou Restic pour données applicatives
- [ ] Configurer backup vers OCI Object Storage

### Network Policies
- [ ] Déployer network policies (Calico/Cilium)
- [ ] Restreindre communication inter-pods
- [ ] Configurer egress policies

### Security
- [ ] Configurer Kyverno ou OPA Gatekeeper
- [ ] Déployer security scanning (Trivy)
- [ ] Configurer RBAC audit

## Phase 6: Home Cluster (Talos)

### Home Server Setup
- [ ] Installer Proxmox sur serveur maison
- [ ] Créer VMs Talos
- [ ] Connecter cluster home à Omni (OCI)

### Migration
- [ ] Migrer services média vers Home (Jellyfin, Immich)
- [ ] Configurer backup cluster OCI → Home

## Phase 7: CI/CD & Automation

### GitHub Actions
- [x] Pipeline deploy (flux-diff)
- [ ] Pipeline Terraform (Cloudflare - en cours)
- [x] Pipeline lint/validation

### Automation
- [ ] Renovate (auto-update apps)
- [ ] Flux automation (image updates)

## Phase 8: End Users

### Onboarding
- [ ] Créer guide quickstart pour utilisateurs
- [ ] Configurer self-service access
- [ ] Documenter les services disponibles

## Décisions Techniques

### ✅ Validé
- **OCI OKE** pour cluster cloud (gratuit)
- **Talos** pour cluster home (futur)
- **Omni** (via OCI) pour gestion multi-cluster
- **Doppler** pour secrets (gratuit)
- **Flux CD** pour GitOps
- **Cloudflare** pour DNS, Tunnel, Access (gratuit)
- **Grafana Cloud** pour monitoring (gratuit)
- **Migadu** pour email/SMTP ( 19 euros par an)

### 🔄 À décider
- **Longhorn** vs **Rook-Ceph** pour storage (si besoin)
- **Backup destination**: OCI Object Storage vs autres

## Notes

- Priorité: sécurité > fonctionnalités
- Services critiques d'abord (auth, monitoring)
- Tester avant production
- Documenter chaque étape
- YOLO mode: `export OPENCODE_YOLO=true` ou dire "yolo" au début
