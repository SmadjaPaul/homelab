# OKE Migration Guide

Guide de migration vers Oracle Kubernetes Engine (OKE) - Free Tier

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          OCI Cloud                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    OKE Cluster (Basic)                   │  │
│  │  ┌──────────────────┐      ┌──────────────────┐         │  │
│  │  │  Worker Node 1   │      │  Worker Node 2   │         │  │
│  │  │  2 OCPU / 12GB   │      │  2 OCPU / 12GB   │         │  │
│  │  │                  │      │                  │         │  │
│  │  │  ┌──────────┐   │      │  ┌──────────┐   │         │  │
│  │  │  │  Comet   │   │      │  │ Apps...  │   │         │  │
│  │  │  │ :30080   │   │      │  │          │   │         │  │
│  │  │  └──────────┘   │      │  └──────────┘   │         │  │
│  │  │       │         │      │                  │         │  │
│  │  └───────┼─────────┘      └──────────────────┘         │  │
│  │          │                                               │  │
│  └──────────┼───────────────────────────────────────────────┘  │
│             │                                                   │
│             │  NodePort 30080 (Security List)                   │
│             ▼                                                   │
│     ┌──────────────┐                                           │
│     │   Internet   │                                           │
│     └──────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘

Comet Security:
- Ingress: Port 30080 only (via NodePort)
- Egress: DENY ALL (no outbound connections)
- NetworkPolicy enforces strict isolation
```

## Resources Utilisées (Always Free Tier)

| Resource | Configuration | Cost |
|----------|--------------|------|
| OKE Cluster | Basic (managed) | $0 |
| Worker Nodes | 2 × VM.Standard.A1.Flex (2 OCPU / 12GB) | $0 |
| Storage | 200GB total | $0 |
| Load Balancer | Flexible + Standard (for Traefik) | $0 |
| **Total** | 4 OCPU / 24GB RAM | **$0** |

## Comparaison avec Omni+Talos

| Aspect | OKE | Omni+Talos |
|--------|-----|------------|
| Control Plane | Managed by Oracle (free) | Self-managed (Omni VM) |
| Setup Time | ~10-15 min | ~40 min |
| Maintenance | Minimal | Moderate |
| Flexibility | High | Very High |
| Cost | $0/month | ~$15/month (Omni VM) |
| Node OS | Oracle Linux | Talos Linux |
| ARM Support | Native | Native |

## Prérequis

1. **OCI Account** avec Free Tier
2. **Terraform** >= 1.5.0
3. **OCI CLI** configuré
4. **kubectl**
5. **Doppler CLI** configuré (projet `infrastructure`)

## Configuration

### 1. Doppler Setup

Tous les secrets sont dans Doppler projet `infrastructure`:

```bash
# Login (une fois)
doppler login

# Configurer le projet
doppler setup --project infrastructure --config prd

# Vérifier les secrets
doppler secrets
```

### 2. Variables d'environnement (optionnel)

Si vous ne voulez pas utiliser Doppler pour certaines commandes:

```bash
export OCI_CLI_USER="ocid1.user.oc1..xxx"
export OCI_CLI_TENANCY="ocid1.tenancy.oc1..xxx"
export OCI_CLI_FINGERPRINT="xx:xx:xx..."
export OCI_CLI_KEY_CONTENT=$(cat ~/.oci/oci_api_key.pem)
export OCI_CLI_REGION="eu-paris-1"
```

### 2. Terraform Backend (S3-compatible)

Le state Terraform est stocké dans OCI Object Storage:

```hcl
backend "s3" {
  bucket   = "terraform-states"
  key      = "oke/terraform.tfstate"
  region   = "eu-paris-1"
  endpoint = "https://<namespace>.compat.objectstorage.eu-paris-1.oraclecloud.com"

  skip_region_validation      = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  force_path_style            = true
}
```

### 3. Déploiement

```bash
# 1. Générer le backend config depuis Doppler
doppler run -- ./scripts/generate-backend.sh

# 2. Cloudflare
cd terraform/cloudflare
doppler run -- terraform init
doppler run -- terraform apply

# 3. OKE
cd ../oke
doppler run -- terraform init -backend-config=backend.hcl
doppler run -- terraform apply

# 4. Récupérer le kubeconfig
oci ce cluster create-kubeconfig \
  --cluster-id $(doppler run -- terraform output -raw cluster_id) \
  --file ~/.kube/config \
  --region eu-paris-1 \
  --token-version 2.0.0

# 5. Vérifier
kubectl get nodes
```

## Comet - Sécurité Réseau

### NetworkPolicy (Strict Isolation)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: comet-deny-egress
  namespace: media
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: comet
  policyTypes:
    - Egress
    - Ingress
  ingress:
    # Allow from Traefik only
    - from:
        - namespaceSelector:
            matchLabels:
              name: traefik
      ports:
        - protocol: TCP
          port: 8080
    # Allow NodePort access
    - ports:
        - protocol: TCP
          port: 8080
  egress: []  # DENY ALL
```

### NodePort Service

Comet est exposé via NodePort sur le port **30080**:
- **Avantage**: Latence minimale (pas de load balancer)
- **Sécurité**: Limité au port 30080 via OCI Security List
- **Accès**: `http://<worker-ip>:30080`

### OCI Security List

```hcl
# NodePort 30080 ouvert pour Comet
ingress_security_rules {
  protocol    = "6"  # TCP
  source      = "0.0.0.0/0"
  description = "Comet streaming NodePort"
  tcp_options {
    min = 30080
    max = 30080
  }
}
```

## Commandes utiles

```bash
# Voir les nodes
kubectl get nodes -o wide

# Voir les pods
kubectl get pods -A

# Accès direct à Comet
kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'
# Puis: curl http://<ip>:30080

# Vérifier la NetworkPolicy
kubectl describe networkpolicy comet-deny-egress -n media

# Logs Comet
kubectl logs -n media -l app.kubernetes.io/name=comet -f
```

## GitHub Actions

Le workflow `.github/workflows/deploy-oke.yml` automatise:
1. Déploiement Cloudflare
2. Création du cluster OKE
3. Configuration kubectl
4. Déploiement des applications (Flux CD)
5. Application des NetworkPolicies

### Secrets requis

```
OCI_CLI_USER
OCI_CLI_TENANCY
OCI_CLI_FINGERPRINT
OCI_CLI_KEY_CONTENT
OCI_COMPARTMENT_ID
CLOUDFLARE_API_TOKEN
CLOUDFLARE_TUNNEL_SECRET
... (voir workflow)
```

## Migration depuis Omni+Talos

1. **Sauvegarder** les données importantes (volumes PVC)
2. **Déployer** le nouveau cluster OKE
3. **Restaurer** les données
4. **Mettre à jour** DNS vers le nouveau cluster
5. **Détruire** l'ancien infrastructure Omni

## Troubleshooting

### Nodes not Ready
```bash
kubectl describe node <node-name>
# Vérifier les events OCI Console
```

### Comet inaccessible
```bash
# Vérifier le service
kubectl get svc -n media

# Vérifier la NetworkPolicy
kubectl get networkpolicy -n media

# Tester depuis un pod
kubectl run test --image=busybox -it --rm -- wget -O- http://comet:8080
```

### Terraform Backend Error
```bash
# Vérifier le namespace Object Storage
oci os ns get

# Vérifier le bucket existe
oci os bucket get --bucket-name terraform-states
```

## Limites Free Tier

- **4 OCPU** maximum (2 nodes × 2 OCPU)
- **24GB RAM** maximum (2 nodes × 12GB)
- **200GB** storage total (boot + block volumes)
- **2** Load Balancers maximum (1 flexible + 1 standard)

## Avantages OKE

✅ **Managed**: Pas de maintenance du control plane
✅ **Gratuit**: Basic cluster = $0
✅ **Simple**: Déploiement en 15 min vs 40 min
✅ **Sécurisé**: NetworkPolicies natives
✅ **Intégré**: IAM OCI, monitoring, logging

## Notes

- Les workers utilisent **Oracle Linux 8** (pas Talos)
- Les mises à jour du control plane sont gérées par Oracle
- Les workers peuvent être mis à jour via Terraform
- Cloudflared fonctionne identiquement sur OKE
