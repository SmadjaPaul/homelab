# Applications Kubernetes

Ce repertoire contient les applications deployees sur les clusters via Flux.

## Structure

```
apps/
├── base/                    # Ressources communes (non deployees directement)
│   └── README.md
│
├── infra/                    # Infrastructure
│   ├── traefik/            # Reverse proxy / Ingress
│   ├── cloudflared/        # Cloudflare Tunnel
│   ├── external-dns/       # DNS automatique
│   ├── external-secrets/   # Secrets Doppler
│   ├── cert-manager/       # Certificates
│   ├── storage/
│   │   ├── cloudnative-pg/  # PostgreSQL operator
│   │   └── redis/
│   ├── netbird/            # VPN
│   ├── aiven-operator/    # Aiven operator
│   ├── velero/             # Backup
│   ├── omni/               # Cluster management
│   ├── descheduler/       # Pod scheduling
│   └── reloader/           # Config reload
│
├── security/                # Applications de securite
│   ├── authentik/          # SSO / Identity Provider
│   ├── vaultwarden/      # Password manager
│   ├── kyverno/           # Policy engine
│   ├── crowdsec/          # IDS
│   └── tetragon/          # Tracing
│
├── media/                   # Applications media
│   ├── audiobookshelf/
│   ├── immich/
│   ├── navidrome/
│   └── lidarr/
│
├── automation/             # Automation
│   └── n8n/
│
├── business/                # Applications business
│   ├── outline/           # Wiki
│   ├── vikunja/          # Todo
│   ├── paperless-ngx/    # Documents
│   ├── umami/            # Analytics
│   ├── fleetdm/          # MDM
│   └── odoo/             # ERP
│
├── public/                  # Applications publiques
│   └── homepage/
│
├── o11y/                    # Observability
│   └── k8s-monitoring/
│
└── finance/
    └── actual-budget/
```

## Ajouter une nouvelle application

### 1. Structure de base

Creer la structure suivante:
```
apps/<categorie>/<app>/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── helmrelease.yaml
│   ├── external-secret.yaml (si necessaire)
│   └── ingress.yaml (si necessaire)
└── overlays/              # Optionnel: variations par cluster
    ├── local/
    └── oci/
```

### 2. Fichier kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: mon-app

resources:
  - namespace.yaml
  - helmrelease.yaml
```

### 3. Configuration HelmRelease

Voir les examples existants pour la configuration.

### 4. Reference dans le cluster

Ajouter dans `clusters/<cluster>/clusters/<cluster>/apps.yaml`:
```yaml
- ../../apps/<categorie>/<app>/
```

## Variables d'environnement communes

| Variable | Description |
|----------|-------------|
| `AUTHENTIK_SECRET_KEY` | Cle secrete pour authentik |
| `CLOUDFLARE_API_TOKEN` | Token API Cloudflare |
| `DOPPLER_TOKEN` | Token Doppler |

## Tips

- Toujours specifier une version fixe (`version: "1.2.3"`) pour la production
- Utiliser `latest` uniquement pour le developpement
- Configurer `driftDetection` pour la production
- Toujours tester en local avant de pusher en prod
