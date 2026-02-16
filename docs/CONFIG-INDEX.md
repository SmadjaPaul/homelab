# Index des Configurations

Ce fichier liste l'emplacement de chaque configuration importante dans le repository.

## 🏗️ Infrastructure (Terraform)

### VM Hub (Services Core)

**Fichier:** `terraform/oracle-cloud/templates/hub-cloud-init.sh`

Ce script définit ce qui tourne sur la VM Hub (oci-hub):
- Omni (Control Plane)
- Tailscale (VPN)
- Comet (Streaming)
- Docker
- UFW (Firewall)

**Variables:** `terraform/oracle-cloud/variables.tf` → `management_vm`

### Cluster Kubernetes

**Fichier:** `terraform/oracle-cloud/compute.tf`

Définit les 3 VMs Talos:
- talos-cp-1 (Control Plane)
- talos-worker-1
- talos-worker-2

**Variables:** `terraform/oracle-cloud/variables.tf` → `k8s_nodes`

### Cloudflare

**Module Tunnel:** `terraform/cloudflare/modules/tunnel/main.tf`
- Création du tunnel
- Configuration ingress

**Module DNS:** `terraform/cloudflare/modules/dns/main.tf`
- Records DNS
- CNAME vers tunnel

**Module Access:** `terraform/cloudflare/modules/access/main.tf`
- Authentik OIDC
- Policies

## ☸️ Kubernetes (GitOps)

### Infrastructure K8s

**Cloudflare Tunnel (dans K8s):**
- `kubernetes/apps/infrastructure/cloudflare/tunnel.yaml`
- Déploie cloudflared comme pod
- Redirige *.smadja.dev vers Traefik

**External DNS:**
- `kubernetes/apps/infrastructure/cloudflare/external-dns.yaml`
- Crée automatiquement les DNS records

**Traefik:**
- `kubernetes/apps/infrastructure/traefik/`
- Ingress controller
- Routing vers les services

**Cert-manager:**
- `kubernetes/apps/infrastructure/cert-manager/`
- Certificats TLS Let's Encrypt

### Applications

**Authentik:**
- `kubernetes/apps/business/authentik/`
- HelmRelease, Ingress, Secrets

**Nextcloud:**
- `kubernetes/apps/productivity/nextcloud/`
- HelmRelease, Ingress, Secrets

**Configuration Cluster:**
- `kubernetes/clusters/oci-hub/kustomization.yaml`
- Liste toutes les apps à déployer

## 🔐 Secrets (Doppler)

**Configuration:** `doppler.yaml`

Liste tous les projets Doppler et leurs secrets.

**Sync vers K8s:**
- `kubernetes/apps/infrastructure/external-secrets/`
- External Secrets Operator
- ClusterSecretStore par projet

## 🔄 CI/CD (GitHub Actions)

### Workflows Principaux

**Déploiement Complet:**
- `.github/workflows/deploy-infra.yml`
- 4 phases: Cloudflare → OCI → Omni → K8s

**Terraform:**
- `.github/workflows/terraform.yaml`
- Plan/Apply par module

**Vérifications:**
- `.github/workflows/lint.yaml` - Validation
- `.github/workflows/security.yaml` - Scan sécurité
- `.github/workflows/flux-diff.yaml` - Diff GitOps

## 📊 Monitoring & Debug

### Logs par Service

**VM Hub:**
```bash
# Omni
docker logs omni

# Comet
docker logs comet

# Tailscale
sudo tailscale status
```

**Kubernetes:**
```bash
# Tunnel
kubectl logs -n cloudflare deployment/cloudflare-tunnel

# Traefik
kubectl logs -n infra deployment/traefik

# Authentik
kubectl logs -n authentik deployment/authentik-server
```

### Commandes de vérification

**Terraform:**
```bash
cd terraform/oracle-cloud
terraform output  # Voir IPs
terraform state list  # Voir ressources
```

**Omni:**
```bash
omnictl cluster get oci-hub
omnictl cluster machines -c oci-hub
```

**K8s:**
```bash
kubectl get nodes
kubectl get pods -A
flux get all
```

## 🗺️ Cartographie des Ports

### VM Hub (oci-hub)

| Port | Service | Accès |
|------|---------|-------|
| 22 | SSH | Tailscale + Admin IPs |
| 50000 | Omni gRPC | Tailscale |
| 50001 | Omni HTTP | Tailscale |
| 8080 | Comet | Internet (Cloudflare Access) |

### Cluster K8s

**Ports internes (via Traefik):**
- 80/443 : Toutes les applications web
- Ingress redirige vers les services

**Ports Node:**
- 6443 : K8s API (Tailscale)
- 10250 : Kubelet
- 8472 : Flannel/Cilium

## 📁 Structure Complète

```
.
├── .github/workflows/          # CI/CD GitHub Actions
│   ├── deploy-infra.yml       # Workflow principal
│   └── ...
│
├── terraform/                  # Infrastructure as Code
│   ├── oracle-cloud/          # VMs OCI
│   │   ├── templates/
│   │   │   └── hub-cloud-init.sh  # ⭐ Config VM Hub
│   │   ├── compute.tf         # Définition VMs
│   │   └── variables.tf       # Variables
│   │
│   └── cloudflare/            # DNS, Tunnel
│       └── modules/
│           ├── tunnel/        # ⭐ Config Tunnel
│           ├── dns/           # ⭐ Config DNS
│           └── access/        # ⭐ Config Access
│
├── kubernetes/                # Apps Kubernetes
│   ├── apps/
│   │   ├── infrastructure/    # ⭐ Infra K8s (Tunnel, etc.)
│   │   │   └── cloudflare/
│   │   │       ├── tunnel.yaml      # ⭐ Cloudflared
│   │   │       └── external-dns.yaml
│   │   ├── business/          # Apps pro
│   │   │   └── authentik/
│   │   └── productivity/      # Apps perso
│   │       └── nextcloud/
│   │
│   └── clusters/
│       └── oci-hub/
│           └── kustomization.yaml  # ⭐ Liste des apps
│
├── scripts/                   # Scripts utilitaires
│   ├── deploy.sh             # ⭐ Déploiement local
│   ├── omni-bootstrap.sh     # ⭐ Bootstrap Omni
│   └── check-secrets.sh      # Vérification secrets
│
├── docs/                      # Documentation
│   ├── VM-VS-K8S.md          # ⭐ VM vs K8s
│   ├── NETWORK-ARCHITECTURE.md # ⭐ Réseau
│   └── ...
│
└── doppler.yaml              # ⭐ Config Doppler
```

## 🔍 Recherche Rapide

### "Où est défini X ?"

| X | Emplacement |
|---|-------------|
| **Ce qui tourne sur la VM Hub** | `terraform/oracle-cloud/templates/hub-cloud-init.sh` |
| **La taille des VMs** | `terraform/oracle-cloud/variables.tf` → lignes 40-85 |
| **Le tunnel Cloudflare** | `kubernetes/apps/infrastructure/cloudflare/tunnel.yaml` |
| **Les apps déployées** | `kubernetes/clusters/oci-hub/kustomization.yaml` |
| **Le mot de passe Authentik** | Projet Doppler `service-authentik` → `AUTHENTIK_BOOTSTRAP_PASSWORD` |
| **Les secrets K8s** | `kubernetes/apps/*/external-secret.yaml` |
| **Le workflow CI** | `.github/workflows/deploy-infra.yml` |
| **Le routing HTTP** | `kubernetes/apps/*/ingress.yaml` |
| **Le firewall VM** | `terraform/oracle-cloud/templates/hub-cloud-init.sh` → lignes 43-49 |
| **Le DNS** | `terraform/cloudflare/modules/dns/main.tf` |

## 🆘 Troubleshooting Guide

### Je ne trouve pas...

**La config d'un service:**
```bash
# Chercher par nom
grep -r "service-name" kubernetes/
grep -r "service-name" terraform/
```

**Où est utilisé un secret:**
```bash
# Chercher dans K8s
grep -r "SECRET_NAME" kubernetes/

# Chercher dans Terraform
grep -r "secret" terraform/
```

**La définition d'une VM:**
```bash
# OCI VMs
grep -A 20 "resource.*oci_core_instance" terraform/oracle-cloud/compute.tf
```

## 📝 Notes

- Toutes les configurations sont versionnées dans Git
- Les secrets ne sont jamais dans Git (Doppler + External Secrets)
- Les workflows CI utilisent ces mêmes fichiers
- Flux CD lit les fichiers dans `kubernetes/` pour déployer
