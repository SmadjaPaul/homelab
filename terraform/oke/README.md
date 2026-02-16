# OKE Terraform Configuration

Configuration Terraform pour Oracle Kubernetes Engine (OKE) - Free Tier.

**Tous les secrets sont gérés par Doppler** (projet `infrastructure`).

## Structure

```
terraform/oke/
├── main.tf                    # Configuration principale OKE
├── variables.tf               # Variables
├── outputs.tf                 # Outputs
├── backend.hcl.example        # Exemple configuration backend
├── backend.hcl                # Généré automatiquement (depuis Doppler)
├── terraform.tfvars.example   # Exemple variables
└── README.md                  # Ce fichier
```

## Prérequis

- Terraform >= 1.5.0
- OCI CLI configuré
- [Doppler CLI](https://docs.doppler.com/docs/install-cli) configuré
- Un bucket Object Storage pour le state

## Setup

### 1. Configurer Doppler

```bash
# Login (une fois)
doppler login

# Setup du projet
doppler setup --project infrastructure --config prd
```

### 2. Générer le Backend Config

```bash
# Génère terraform/oke/backend.hcl à partir des secrets Doppler
doppler run -- ./scripts/generate-backend.sh
```

### 3. Déployer

```bash
cd terraform/oke

# Initialiser avec le backend S3 (OCI Object Storage)
terraform init -backend-config=backend.hcl

# Vérifier le plan (avec les variables depuis Doppler)
doppler run -- terraform plan

# Appliquer
doppler run -- terraform apply

# Récupérer les outputs
doppler run -- terraform output
```

**Note**: Toutes les commandes Terraform doivent être préfixées par `doppler run --` pour injecter les secrets.

## Ressources créées

- **VCN** avec subnets privés (workers) et publics (LB)
- **OKE Cluster** Basic (gratuit)
- **Node Pool** avec 2 workers ARM (2 OCPU / 12GB chacun)
- **Security Lists** avec NodePort 30080 ouvert pour Comet
- **NAT Gateway** pour accès Internet des workers
- **Service Gateway** pour services OCI

## Outputs importants

| Output | Description |
|--------|-------------|
| `cluster_id` | ID du cluster OKE |
| `cluster_endpoint` | Endpoint public du cluster |
| `kubeconfig_command` | Commande pour générer le kubeconfig |

## Kubeconfig

```bash
# Générer le kubeconfig
oci ce cluster create-kubeconfig \
  --cluster-id $(terraform output -raw cluster_id) \
  --file ~/.kube/config \
  --region $(terraform output -raw region) \
  --token-version 2.0.0

# Vérifier
kubectl get nodes
```

## Coût

Toutes les ressources sont dans le **Always Free Tier**:
- OKE Basic Cluster: $0
- 2 workers ARM (2 OCPU/12GB): $0
- 200GB storage: $0
- Load balancers: $0 (jusqu'à 2)

**Total: $0/mois**

## Maintenance

### Mise à jour Kubernetes

Modifier `kubernetes_version` dans `terraform.tfvars` puis:

```bash
terraform apply
```

### Scaling

Modifier `size` dans `main.tf` (max 2 nodes pour Free Tier):

```bash
terraform apply
```

### Destruction

```bash
terraform destroy
```

⚠️ **Attention**: Cela détruit tout le cluster et les données!

## Sécurité

- Workers dans subnet **privé** (pas d'IP publique)
- Accès SSH uniquement depuis le VCN
- NAT Gateway pour accès Internet sortant
- NodePort 30080 exposé uniquement pour Comet

## Troubleshooting

### Erreur Backend

```bash
# Vérifier le bucket existe
oci os bucket get --bucket-name terraform-states

# Vérifier le namespace Doppler
doppler secrets get OCI_OBJECT_STORAGE_NAMESPACE

# Régénérer le backend config
doppler run -- ./scripts/generate-backend.sh
```

### Erreur Doppler

```bash
# Vérifier le login
doppler login

# Vérifier le projet est configuré
doppler setup --project infrastructure --config prd

# Lister les secrets disponibles
doppler secrets
```

### Nodes Not Ready

```bash
# Vérifier dans OCI Console
# Compute > Instances > Voir les instances worker

# Logs
oci ce cluster get --cluster-id $(doppler run -- terraform output -raw cluster_id)
```

## Documentation

- [Migration complète](../docs/OKE-MIGRATION.md)
- [Sécurité Comet](../docs/OKE-COMET-SECURITY.md)
- [OCI OKE Documentation](https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengclustercontrolplanes.htm)
