# Architecture Simplifiée - OKE (Oracle Kubernetes Engine)

## Pourquoi migrer vers OKE ?

**Tes contraintes:**
- ✅ Sécurisé
- ✅ Rapide à déployer
- ✅ Peu de maintenance
- ✅ Pas besoin de Talos spécifiquement

**OKE répond à tout:**
- **Control plane managé** = 0 maintenance
- **Déploiement en 20 min** vs 40 min
- **Sécurité enterprise** (géré par Oracle)
- **Standard Kubernetes** = doc abondante

## 🏗️ Architecture OKE Proposée

```
Internet
    │
    ▼
Cloudflare (DNS/WAF/Tunnel)
    │
    ├──────────────────────────────────────┐
    │                                      │
    ▼                                      ▼
┌──────────────────────┐          ┌──────────────┐
│ OKE Control Plane    │          │  VM Hub      │
│ (Gratuit - Managé    │          │  (Optionnel) │
│  par Oracle)         │          │  - Comet     │
└──────────┬───────────┘          │  - Tailscale?│
           │                      └──────────────┘
           │                              │
           ▼                              │
┌──────────────────────┐                 │
│ Worker Nodes (2 VMs) │◄────────────────┘
│ ARM - 2 OCPU / 12GB  │      VPN Admin
│ each                 │
├──────────────────────┤
│ • Longhorn (storage) │
│ • Flux CD (GitOps)   │
│ • Authentik          │
│ • Nextcloud          │
│ • etc.               │
└──────────────────────┘
```

## ✅ Avantages vs Omni+Talos

| Aspect | OKE | Omni+Talos |
|--------|-----|------------|
| **Temps déploiement** | 20 min | 40 min |
| **Maintenance** | ⭐⭐⭐⭐⭐ (Aucune) | ⭐⭐ (Omni VM à gérer) |
| **Complexité** | ⭐⭐ (Standard) | ⭐⭐⭐⭐ (Talos spécifique) |
| **Documentation** | ⭐⭐⭐⭐⭐ (Standard K8s) | ⭐⭐ (Talos/Omni) |
| **Mise à jour K8s** | Automatique (1 clic) | Manuelle (complexe) |
| **Stockage** | Longhorn (simple) | Rook-Ceph (complexe) |

## 📦 Configuration OKE (4 OCPU / 24GB)

### Workers (2 VMs)
```yaml
Node 1: 2 OCPU / 12GB RAM / 100GB disk
Node 2: 2 OCPU / 12GB RAM / 100GB disk

Total: 4 OCPU / 24GB / 200GB ✅ (Free Tier)
```

### Option: VM Hub Minimal (si besoin)
Si tu veux garder Comet en dehors du cluster:
```yaml
VM Hub: 1 OCPU / 4GB (optionnel)
- Comet (streaming)
- Pas besoin d'Omni!
```

Sinon, **tout dans OKE** (même Comet).

## 🔧 Migration Proposée

### Étape 1: Simplifier Terraform

**Supprimer:**
- `terraform/oracle-cloud/` (complexe avec Talos)
- VM Hub dédiée
- Scripts Omni bootstrap

**Créer:**
- `terraform/oke/` (simple et standard)

### Étape 2: OKE Simple

```hcl
# terraform/oke/main.tf
resource "oci_containerengine_cluster" "k8s" {
  name           = "homelab-oke"
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.homelab.id
  kubernetes_version = "v1.31.0"

  options {
    service_lb_subnet_ids = [oci_core_subnet.public.id]
  }
}

resource "oci_containerengine_node_pool" "workers" {
  cluster_id     = oci_containerengine_cluster.k8s.id
  name           = "workers"
  node_shape     = "VM.Standard.A1.Flex"

  node_shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  size = 2  # 2 workers

  node_config_details {
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id          = oci_core_subnet.private.id
    }
  }
}
```

### Étape 3: Kubernetes (Identique)

Tes manifests Kubernetes restent **identiques**:
- `kubernetes/apps/infrastructure/cloudflare/` ✅
- `kubernetes/apps/business/authentik/` ✅
- `kubernetes/apps/productivity/nextcloud/` ✅
- Flux CD fonctionne pareil ✅

## 🚀 Workflow CI/CD Simplifié

```yaml
# .github/workflows/deploy-oke.yml
name: Deploy OKE

on:
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Deploy OKE
        run: |
          cd terraform/oke
          terraform init
          terraform apply -auto-approve

      - name: Configure kubectl
        run: |
          oci ce cluster create-kubeconfig \
            --cluster-id $(terraform output -raw cluster_id) \
            --file $HOME/.kube/config

      - name: Install Flux
        run: flux install

      - name: Deploy Apps
        run: kubectl apply -k kubernetes/clusters/oci-hub
```

**Durée: 20 minutes** (vs 40 actuellement)

## 🔐 Sécurité avec OKE

### 1. **Control Plane Sécurisé**
- Géré par Oracle (même niveau que production OCI)
- Isolé des workers
- HA automatique (3 nœuds master cachés)

### 2. **Network Policies**
```yaml
# Toujours possible avec OKE
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### 3. **Pod Security Standards**
```yaml
# OKE supporte PSS
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

### 4. **Cloudflare Access/Tunnel**
Identique à notre setup actuel (pas de changement)

## 📊 Comparaison Maintenance

### OKE (Proposé)
```
Mois 1: Déploiement initial (20 min)
Mois 2-12: Rien (mise à jour auto optionnelle)
Année 2: Click "Upgrade" dans OCI console (5 min)
```

### Omni+Talos (Actuel)
```
Mois 1: Déploiement (40 min) + debug probable
Mois 2-12: Surveillance Omni VM + maj manuelles
Année 2: Migration Talos complexe + update Omni
```

## 🎯 Ma Recommandation Finale

**Va avec OKE si:**
- Tu veux un **homelab qui marche** rapidement
- Tu n'as **pas de temps** pour maintenance
- Tu préfères **standard** (plus de doc/support)
- Tu veux **Longhorn** (storage simple et efficace)

**Reste avec Omni+Talos si:**
- Tu veux **apprendre** Talos (vraiment cool comme techno)
- Tu as besoin de **contrôle total** du control plane
- Tu aimes **expérimenter** (même si ça casse parfois)

## 🔧 Migration Facile

Si tu veux migrer, je peux:

1. **Créer** `terraform/oke/` (configuration simple)
2. **Simplifier** les workflows CI/CD
3. **Adapter** la doc pour OKE
4. **Garder** tous tes manifests K8s (ils sont compatibles)

**Temps de migration:** 2-3 heures de travail
**Gain:** 50% de temps en moins sur chaque déploiement

Tu veux que je prépare la version OKE ?
