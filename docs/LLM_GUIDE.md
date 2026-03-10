# Guide pour LLM - Infrastructure Homelab

Ce guide est destiné à être utilisé par un agent IA (comme moi) pour comprendre et interagir avec l'infrastructure Homelab.

## Architecture Générale

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           HOMELAB                                      │
│                                                                         │
│  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐  │
│  │    OCI (OKE)     │    │   Cloudflare     │    │   Hetzner     │  │
│  │  ┌────────────┐  │    │    (Tunnel)      │    │ (Storage Box) │  │
│  │  │ K8s Apps   │  │    │  Zero-Trust      │    │     SMB       │  │
│  │  │ + CNPG DB  │◄─┼───►│  + Authentik     │    │    (NAS)      │  │
│  │  │ + Redis    │  │    │   Outpost        │    └───────┬───────┘  │
│  │  └────────────┘  │    └──────────────────┘            │          │
│  └──────────────────┘                                      │          │
│         │                                                  │          │
│         │           Stack Pulumi (Python)                  │          │
│         └──────────────────────────────────────────────────┘          │
│                              │                                         │
│                         apps.yaml                                     │
│                              │                                         │
│                         Doppler                                       │
│                      (Secrets)                                       │
└─────────────────────────────────────────────────────────────────────────┘
```

## Structure du Projet

```
homelab/
├── CLAUDE.md                    # Instructions principales pour agents IA
├── ROADMAP.md                   # Vision à court/moyen/long terme
├── docs/                        # Documentation
│   ├── ARCHITECTURE.md          # Architecture détaillée
│   ├── DEPLOYMENT.md            # Guide de déploiement
│   ├── STORAGE.md               # Stratégie de stockage
│   ├── NETWORKING.md            # Configuration réseau
│   ├── SECRETS.md               # Gestion des secrets
│   └── SERVICE-CATALOG.md       # Catalogue des services
├── kubernetes-pulumi/           # Infrastructure K8s (Pulumi Python)
│   ├── apps.yaml                # ⚠️ SOURCE DE VÉRITÉ - Toutes les apps
│   ├── pyproject.toml           # Dépendances Python
│   ├── shared/                  # Code partagé entre les stacks
│   │   ├── apps/
│   │   │   ├── loader.py       # AppLoader - charge apps.yaml
│   │   │   ├── factory.py      # AppFactory - crée les apps
│   │   │   ├── generic.py      # GenericHelmApp - déploiement Helm générique
│   │   │   ├── base.py         # BaseApp - classe de base
│   │   │   ├── adapters/       # Adaptateurs pour valeurs Helm
│   │   │   │   └── __init__.py # StandardAdapter, AppTemplateAdapter, etc.
│   │   │   ├── common/
│   │   │   │   ├── registry.py          # AppRegistry - orchestrateur principal
│   │   │   │   ├── kubernetes_registry.py # K8s resources (secrets, RBAC, DB)
│   │   │   │   ├── storage_registry.py  # Stockage (PVC, StorageBox)
│   │   │   │   └── authentik_registry.py # Authentik (OIDC, Proxy)
│   │   │   └── impl/            # Implémentations personnalisées
│   │   ├── storage/
│   │   │   └── s3_manager.py   # Gestion des buckets S3
│   │   └── utils/
│   │       ├── schemas.py       # Modèles de données (AppModel, etc.)
│   │       └── storage_validation.py
│   ├── k8s-core/               # Stack 1: Foundation
│   │   ├── Pulumi.yaml
│   │   ├── Pulumi.oci.yaml
│   │   └── __main__.py
│   ├── k8s-storage/            # Stack 2: Stockage & DB
│   │   ├── Pulumi.yaml
│   │   ├── Pulumi.oci.yaml
│   │   └── __main__.py
│   └── k8s-apps/               # Stack 3: Applications
│       ├── Pulumi.yaml
│       ├── Pulumi.oci.yaml
│       └── __main__.py
├── terraform/                   # Infrastructure cloud (OCI, Hetzner)
└── scripts/                    # Scripts utilitaires
```

## Les 3 Stacks Pulumi

### Stack 1: k8s-core (Fondations)
**Répertoire:** `kubernetes-pulumi/k8s-core/`

Déploie:
- Namespaces Kubernetes
- CRDs et Operators (cert-manager, external-secrets, envoy-gateway)
- CSI Drivers (local-path-provisioner, csi-driver-smb)

**Commandes:**
```bash
cd kubernetes-pulumi/k8s-core
uv run pulumi up --stack oci
```

### Stack 2: k8s-storage (Stockage & DB)
**Répertoire:** `kubernetes-pulumi/k8s-storage/`

Déploie:
- Redis
- CloudNativePG (cluster PostgreSQL partagé `homelab-db`)
- Buckets S3 (OCI, R2)
- Storage Box Hetzner

**Commandes:**
```bash
cd kubernetes-pulumi/k8s-storage
uv run pulumi up --stack oci
```

### Stack 3: k8s-apps (Applications)
**Répertoire:** `kubernetes-pulumi/k8s-apps/`

Déploie:
- Toutes les applications définies dans `apps.yaml`
- Authentik (si activé)
- Cloudflared Tunnel

**Commandes:**
```bash
cd kubernetes-pulumi/k8s-apps
uv run pulumi up --stack oci
```

## Comment Ajouter une Nouvelle Application

### 1. Définir dans apps.yaml

```yaml
# kubernetes-pulumi/apps.yaml

apps:
  - name: mon-app              # Nom unique
    category: protected        # public | protected | internal | database
    tier: standard            # critical | standard | ephemeral
    namespace: homelab        # Namespace K8s
    port: 8080               # Port du service
    hostname: app.smadja.dev # Hostname public (si exposé)
    mode: protected          # public | protected | internal
    clusters: [oci]          # Clusters cibles
    dependencies: [cnpg-system, external-secrets, cloudflared]

    # Configuration Helm
    helm:
      chart: mon-app
      repo: https://charts.example.com
      version: 1.0.0
      values:                # Valeurs personnalisées
        replicaCount: 1

    # Stockage persistant
    storage:
      - name: data
        size: 10Gi
        mount_path: /data
        storage_class: local-path  # local-path | oci-bv | hetzner-smb

    # Base de données (utilise le cluster partagé homelab-db)
    database:
      local: true
      size: 5Gi
      storage_class: oci-bv

    # Secrets (référence Doppler)
    secrets:
      - name: mon-app-creds
        keys:
          API_KEY: MON_APP_API_KEY

    # Resources K8s
    resources:
      requests:
        cpu: 100m
        memory: 128Mi

    # Tests
    test:
      routing: true
      expected_endpoints: [https://app.smadja.dev]
```

### 2. Classes Principales

#### AppModel (`shared/utils/schemas.py`)
Modèle de données unifié pour toutes les applications. Définit:
- `name`, `namespace` - Identité
- `port`, `hostname`, `mode` - Exposition réseau
- `category`, `tier` - Classification
- `helm` - Configuration Helm
- `storage[]` - Volumes persistants
- `secrets[]` - Secrets Doppler
- `database` - Configuration DB

#### AppRegistry (`shared/apps/common/registry.py`)
Orchestrateur principal qui:
- Crée les namespaces
- Gère les secrets (ExternalSecrets)
- Provisionne le stockage
- Gère la DB partagée

#### KubernetesRegistry (`shared/apps/common/kubernetes_registry.py`)
Gère les ressources K8s:
- ServiceAccounts
- PodDisruptionBudgets
- ServiceMonitors
- **Cluster DB partagé (CNPG)**
- **Jobs de provisioning DB** pour chaque app

#### StorageRegistry (`shared/apps/common/storage_registry.py`)
Gère le stockage:
- PVCs via StorageProvisionerFactory
- Hetzner StorageBox

#### HelmValuesAdapter (`shared/apps/adapters/__init__.py`)
Patron Strategy pour transformer les valeurs Helm:
- `HelmValuesAdapter` - Standard
- `AppTemplateAdapter` - Pour charts bjw-s
- `AuthentikAdapter` - Pour Authentik
- `NextcloudAdapter` - Pour Nextcloud
- `PaperlessAdapter` - Pour Paperless
- `HomepageAdapter` - Pour Homepage

### 3. Pattern de Déploiement

```
1. AppLoader.load_for_cluster() → Lit apps.yaml
2. AppRegistry.register_app() → Crée namespace, secrets, PVC, DB
3. AppFactory.create() → Crée GenericHelmApp
4. GenericHelmApp.deploy() → Déploie via Helm Release
5. Adapter.get_final_values() → Transforme les valeurs Helm
```

## Gestion des Secrets

### Ajouter un Secret

1. **Dans Doppler:** Créer la clé dans le projet `homelab`, config `prd`

2. **Dans apps.yaml:**
```yaml
secrets:
  - name: mon-app-secret
    keys:
      MA_CLE: MA_CLE_DOPPLER
```

### Secret Manquant

Si `pulumi preview` échoue avec:
```
ValueError: CRITICAL ERROR: Secret key 'XYZ' required by app '...' is MISSING in Doppler
```

➡️ Ajouter la clé dans Doppler, puis relancer `pulumi up`

## Gestion DNS (Auto-Discovery)

DNS est géré par **external-dns** (opérateur K8s), PAS par le code Pulumi.

### Comment ça marche
1. L'Outpost Authentik crée automatiquement un Ingress dans le namespace `authentik`
2. external-dns surveille cet Ingress et extrait les hostnames
3. Pour chaque hostname, external-dns crée un CNAME vers `<tunnel-id>.cfargotunnel.com`
4. Aucune intervention manuelle nécessaire

### Dépannage DNS

Si un hostname ne résout pas:
1. Vérifier l'Ingress de l'Outpost: `kubectl get ingress -n authentik -o yaml`
2. Vérifier les logs external-dns: `kubectl logs -n external-dns deployment/external-dns`
3. **NE PAS** créer d'enregistrements DNS manuellement dans Cloudflare

### Erreurs Courantes
- **400/404 Cloudflare API errors**: Conflit entre Pulumi DNS et external-dns → migrer vers auto-discovery (voir ARCHITECTURE.md)
- **Hostname ne résout pas**: Vérifier que l'app est protégée par Authentik (mode: protected dans apps.yaml)

## Base de Données Partagée

### Architecture
- **Cluster:** `homelab-db` (CloudNativePG)
- **Namespace:** `cnpg-system`
- **Service:** `homelab-db-rw.cnpg-system.svc.cluster.local`
- **Storage:** 2x50GB OCI Block Volume (HA)

### Provisioning par App
Chaque app avec `database.local: true` obtient:
1. Un utilisateur PostgreSQL (`{app.name}`)
2. Une base de données (`{app.name}`)
3. Un secret K8s `{app.name}-db-app` contenant:
   - `host`, `username`, `password`, `dbname`

Le job de provisioning (`{app.name}-db-provision`) crée l'utilisateur et la DB automatiquement.

## Commandes Utiles

### Déploiement
```bash
cd kubernetes-pulumi/k8s-apps

# Le passphrase Pulumi est vide - utiliser une variable d'environnement
export PULUMI_CONFIG_PASSPHRASE=""

# Prévisualiser les changements
uv run pulumi preview --stack oci

# Appliquer les changements
uv run pulumi up --stack oci
```

### Debug Cluster
```bash
# Voir les pods
kubectl get pods -A

# Logs d'un pod
kubectl logs <pod-name> -n <namespace>

# Description d'un pod
kubectl describe pod <pod-name> -n <namespace>

# Events récents
kubectl get events --sort-by='.lastTimestamp' -A

# Voir les secrets
kubectl get secret -n <namespace>

# Voir les PVCs
kubectl get pvc -A

# Exec dans un pod
kubectl exec -it <pod-name> -n <namespace> -- sh
```

### State Pulumi
```bash
# Voir l'état
uv run pulumi stack --stack oci

# Refresh pour synchroniser avec le cluster
uv run pulumi refresh --stack oci
```

## Common Issues et Solutions

### 1. PVC Pending
```bash
# Vérifier les StorageClasses
kubectl get storageclass

# Vérifier les événements
kubectl get events -A | grep FailedBinding
```

### 2. CrashLoopBackOff
```bash
# Voir les logs
kubectl logs <pod> -n <ns> --previous
kubectl describe pod <pod> -n <ns>
```

### 3. Secret Non Sync
```bash
# Vérifier ExternalSecret
kubectl get externalsecret -A
kubectl describe externalsecret <name> -n <ns>
```

### 4. DB Connection Failed
```bash
# Vérifier le cluster CNPG
kubectl get clusters.postgresql.cnpg.io -n cnpg-system

# Vérifier les jobs de provisioning
kubectl get jobs -n cnpg-system

# Logs du job
kubectl logs job/<app>-db-provision -n cnpg-system
```

## Notes Importantes pour les LLMs

1. **apps.yaml est la source de vérité** - Ne pas ajouter de code Python pour des apps simples
2. **Tout passe par Pulumi** - Pas de `kubectl apply` direct pour éviter les désynchronisations
3. **Doppler pour les secrets** - Jamais de secrets en dur dans le code
4. **Déploiement séquentiel** - k8s-core → k8s-storage → k8s-apps
5. **Cluster partagé** - Une seule instance CNPG (`homelab-db`) pour toutes les apps
6. **Storage Class:**
   - `local-path` - Disque local (éphémère)
   - `oci-bv` - Block Volume OCI (persistant, min 50GB)
   - `hetzner-smb` - Hetzner Storage Box (capacité)
