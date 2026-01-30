---
sidebar_position: 1
---

# Services

## Vue d'ensemble

### Services utilisateurs

| Service | URL | Description |
|---------|-----|-------------|
| Homepage | home.smadja.dev | Dashboard d'accueil |
| Auth | auth.smadja.dev | Connexion SSO |
| Status | status.smadja.dev | État des services |
| Feedback | feedback.smadja.dev | Bug reports & features |

### Services admin

| Service | URL | Description |
|---------|-----|-------------|
| Grafana | grafana.smadja.dev | Dashboards monitoring |
| ArgoCD | argocd.smadja.dev | GitOps deployments |
| Prometheus | prometheus.smadja.dev | Métriques |
| Proxmox | proxmox.smadja.dev | Hyperviseur |

## Catégories

### Monitoring

- **Prometheus** : Collecte de métriques
- **Grafana** : Visualisation
- **Loki** : Agrégation de logs
- **Alertmanager** : Gestion des alertes

### Identity

- **Keycloak** : SSO (OIDC)
- **Cloudflare Access** : Zero trust pour services admin

### Infrastructure

- **cert-manager** : Certificats TLS
- **cloudflared** : Tunnel Cloudflare
- **Twingate** : VPN zero trust
- **Reloader** : Auto-restart sur config change

### Backup

- **Velero** : Backup Kubernetes
- **ZFS Snapshots** : Backup local Proxmox

### User Experience

- **Uptime Kuma** : Status page
- **Fider** : Feedback portal
- **Homepage** : Dashboard

## Déploiement

Tous les services sont déployés via ArgoCD depuis Git :

```
GitHub (main) → ArgoCD → Kubernetes
```

Chaque service a son propre dossier :

```
kubernetes/apps/
├── homepage/
│   └── application.yaml
├── keycloak/
│   └── application.yaml
└── uptime-kuma/
    ├── application.yaml
    └── manifests/
        └── deployment.yaml
```

## Ajout d'un service

1. Créer le dossier dans `kubernetes/apps/<service>/`
2. Créer `application.yaml` (ArgoCD Application)
3. Ajouter au `kustomization.yaml` parent
4. Commit & push → ArgoCD sync automatique

Voir [Guide: Ajouter un service](/guides/add-service) pour les détails.
