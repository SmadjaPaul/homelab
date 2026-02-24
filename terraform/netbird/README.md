# NetBird Terraform

Gestion du VPN NetBird pour l'accès aux clusters Kubernetes et l'interconnexion cluster-to-cluster.

## Architecture

```
┌─────────────────┐         ┌─────────────────┐
│   Workstation   │         │  Cluster local  │
│   (Remote A)    │◄───────►│  (Talos/Proxmox)│
└─────────────────┘   P2P   └────────┬────────┘
                                     │
                                     │ Network routes
                                     ▼
                              ┌─────────────────┐
                              │  Cluster OCI    │
                              │  (OKE)         │
                              └─────────────────┘
```

## Prérequis

- Terraform >= 1.12
- Doppler CLI ou token API
- Compte NetBird Cloud

## Configuration

### 1. Variable d'environnement API NetBird

Le provider NetBird utilise la variable d'environnement `NETBIRD_API_KEY`:

```bash
# Via Doppler
export NETBIRD_API_KEY=$(doppler secrets get NETBIRD_API_KEY --plain)

# Ou manuellement
export NETBIRD_API_KEY="votre_api_key"
```

### 2. Initialisation

```bash
cd terraform/netbird
terraform init
```

### 3. Planification

```bash
terraform plan -var-file=terraform.tfvars
```

### 4. Déploiement

```bash
terraform apply -var-file=terraform.tfvars
```

## Configuration des variables

Voir `terraform.tfvars.example` pour les valeurs par défaut.

| Variable | Description | Défaut |
|----------|-------------|--------|
| `network_name` | Nom du réseau NetBird | homelab |
| `enable_local_cluster` | Activer cluster Talos local | true |
| `enable_oci_cluster` | Activer cluster OKE OCI | true |
| `enable_workstation` | Activer clé workstation | true |
| `local_cluster_pod_cidr` | CIDR pods Talos | 10.42.0.0/16 |
| `local_cluster_service_cidr` | CIDR services Talos | 10.43.0.0/16 |
| `oci_cluster_pod_cidr` | CIDR pods OKE | 10.244.0.0/16 |
| `oci_cluster_service_cidr` | CIDR services OKE | 10.245.0.0/16 |
| `setup_key_type` | Type de clé (reusable/one-off) | reusable |
| `setup_key_usage_limit` | Limite d'utilisation (0=illimité) | 0 |
| `setup_key_expiry_seconds` | Expiration en secondes (0=jamais) | 0 |

## Ressources créées

### Groupes
- `k8s-routers` - Routers Kubernetes (Talos + OKE)
- `workstations` - Postes de travail

### Setup Keys (stockées dans Doppler)
- `NETBIRD_SETUP_KEY_LOCAL` - Cluster Talos local
- `NETBIRD_SETUP_KEY_OCI` - Cluster OKE OCI
- `NETBIRD_SETUP_KEY_WORKSTATION` - Postes de travail

### Routes (Remote Network Access)
- `local_cluster_pods` - Route vers pods Talos
- `local_cluster_services` - Route vers services Talos
- `oci_cluster_pods` - Route vers pods OKE
- `oci_cluster_services` - Route vers services OKE

### Politiques
- `workstation_to_k8s` - Accès workstations → clusters K8s

## Connexion des peers

### Cluster Kubernetes (DaemonSet)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: netbird
  namespace: netbird
spec:
  selector:
    matchLabels:
      app: netbird
  template:
    metadata:
      labels:
        app: netbird
    spec:
      hostNetwork: true
      containers:
        - name: netbird
          image: netbirdio/netbird:latest
          env:
            - name: NB_SETUP_KEY
              valueFrom:
                secretKeyRef:
                  name: netbird-secrets
                  key: SETUP_KEY
            - name: NB_HOSTNAME
              value: "k8s-router"
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
                - SYS_ADMIN
                - SYS_RESOURCE
```

### Postes de travail

```bash
# Récupérer la clé depuis Doppler
export NETBIRD_SETUP_KEY=$(doppler secrets get NETBIRD_SETUP_KEY_WORKSTATION --plain)

# Installer et connecter
curl -fsSL https://pkgs.netbird.io/install.sh | sh
netbird up --setup-key $NETBIRD_SETUP_KEY
```

## Secrets Doppler

Après déploiement, les secrets suivants sont créés dans Doppler:

- `NETBIRD_SETUP_KEY_LOCAL` - Clé pour cluster local
- `NETBIRD_SETUP_KEY_OCI` - Clé pour cluster OCI
- `NETBIRD_SETUP_KEY_WORKSTATION` - Clé pour postes de travail
- `NETBIRD_NETWORK_ID` - ID du réseau NetBird

## Nettoyage

```bash
terraform destroy -var-file=terraform.tfvars
```

⚠️ Les setup keys seront révoquées et les routes supprimées.
