# CHANGELOG

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère à [Semantic Versioning](https://semver.org/lang/fr/).

## [Unreleased]

### Added

- **Architecture 100% GitOps** via GitHub Actions
- **Workflow CI/CD modulaire** (.github/workflows/deploy-infra.yml)
  - Phase 1: Cloudflare (DNS, Tunnel, Access)
  - Phase 2: OCI Infrastructure (VMs)
  - Phase 3: Omni Bootstrap (automatisé)
  - Phase 4: Kubernetes Apps (Flux CD)
- **Scripts d'automatisation**
  - `scripts/deploy.sh` - Déploiement local complet
  - `scripts/prepare-deployment.sh` - Vérification prérequis
  - `scripts/check-secrets.sh` - Vérification secrets GitHub
  - `scripts/omni-bootstrap.sh` - Bootstrap Omni automatisé
  - `scripts/setup-doppler.sh` - Configuration Doppler
- **Documentation complète**
  - `docs/GITHUB_SECRETS.md` - Guide des secrets requis
  - `docs/FULLY-AUTOMATED-ARCHITECTURE.md` - Architecture CI/CD
  - `docs/ARGOCD_VS_FLUX.md` - Comparaison et choix de Flux CD
  - `docs/DEPLOYMENT-GUIDE.md` - Guide étape par étape
  - `docs/DEPLOYMENT-ARCHITECTURE.md` - Dépendances et phases
  - `docs/ACCESS-ARCHITECTURE.md` - Méthodes d'accès
- **Configuration Kubernetes**
  - External Secrets Operator (intégration Doppler)
  - Cloudflare Tunnel (via Helm dans K8s)
  - External DNS (automatisation DNS)
  - Cert-manager (certificats TLS)
  - Authentik (configuration complète)
  - Nextcloud (exemple d'application)

### Changed

- **Terraform OCI** - Optimisation pour Free Tier (4 VMs: 1 hub + 3 workers)
- **Structure du repository** - Organisation par type de service (business/productivity/media/infrastructure)
- **Doppler** - 1 projet par service pour granularité maximale
- **Cloudflared** - Passage de Docker (VM) à Pod Kubernetes (GitOps)

### Removed

- **Anciens workflows** - Migration vers architecture modulaire
- **Docker Compose** - Remplacé par Kubernetes + Flux CD

## [1.0.0] - 2024-XX-XX

### Added

- Initial release
- Infrastructure OCI avec Terraform
- Services Docker (Authentik, Nextcloud, etc.)
- Configuration Cloudflare manuelle

---

## Guide de Migration

### Depuis l'ancienne architecture (Docker Compose)

1. **Backup des données**
   ```bash
   # Sur l'ancienne VM
   ./scripts/backup.sh all
   ```

2. **Déployer la nouvelle infrastructure**
   ```bash
   # Via GitHub Actions
   GitHub → Actions → Deploy Infrastructure → Run workflow
   ```

3. **Restaurer les données**
   ```bash
   # Une fois le cluster K8s prêt
   kubectl cp backup/ <pod>:/data/
   ```

### Mise à jour des secrets

Si vous avez déjà des secrets configurés:

1. Vérifier les nouveaux secrets requis:
   ```bash
   ./scripts/check-secrets.sh
   ```

2. Ajouter les secrets manquants sur GitHub

3. Mettre à jour les valeurs existantes si nécessaire

---

## Roadmap

### [2.0.0] - Prochainement

- [ ] Tests automatisés (smoke tests post-déploiement)
- [ ] Monitoring complet (Prometheus + Grafana)
- [ ] Backup automatisé (Kopia)
- [ ] Cluster Home (Proxmox) via Omni
- [ ] Service Mesh (Cilium ou Istio)

### [2.1.0]

- [ ] Multi-région (réplication OCI)
- [ ] Autoscaling (KEDA)
- [ ] GitOps pour Terraform (Atlantis ou Terraform Cloud)

---

## Notes de version

### Versioning

- **MAJOR** - Changements incompatibles (refonte architecture)
- **MINOR** - Nouvelles fonctionnalités (nouveau service)
- **PATCH** - Corrections de bugs

### Branches

- `main` - Production stable
- `develop` - Développement (PR ici)
- `feature/*` - Nouvelles fonctionnalités
- `hotfix/*` - Corrections urgentes

---

## Contributeurs

- Paul Smadja - Architecture et développement initial

## Remerciements

- [qjoly/GitOps](https://github.com/qjoly/GitOps) - Inspiration architecture
- [onedr0p/flux-cluster-template](https://github.com/onedr0p/flux-cluster-template) - Template Flux CD
- [Sidero Labs](https://www.siderolabs.com/) - Talos Linux et Omni
