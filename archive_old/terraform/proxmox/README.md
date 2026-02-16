# Proxmox VE — Terraform (bpg/proxmox)

Configuration Terraform pour **Proxmox VE** avec le provider [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs).

## Pourquoi bpg/proxmox

- **Très maintenu** et compatible Proxmox 8/9
- **API-first** : peu de dépendance au SSH
- **API Token** pour la prod et le CI/CD
- Ressources : VMs, LXC, fichiers, téléchargements, ACL, etc.

Autres providers (Telmate, Terraform-for-Proxmox) sont moins actifs ou moins complets. Bonnes pratiques : [docs-site/docs/advanced/decisions-and-limits.md](../docs-site/docs/advanced/decisions-and-limits.md) (state Terraform).

## Prérequis

1. **Proxmox VE** installé et accessible (ex. `https://192.168.68.51:8006/`).
2. **Utilisateur Proxmox dédié** + **API Token** (recommandé).
3. **ZFS** (optionnel) : créer les pools et storages avant ou après avec `scripts/proxmox/setup-zfs.sh`, puis adapter `pm_storage_vm` / `pm_storage_iso` dans les variables.

## Démarrage

```bash
cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars
# Éditer terraform.tfvars avec l’URL Proxmox et l’API Token

terraform init
terraform plan   # doit afficher les nœuds (data source)
terraform apply
```

## Variables principales

| Variable | Description |
|----------|-------------|
| `pm_api_url` | URL de l’API (ex. `https://192.168.68.51:8006/`) |
| `pm_api_token_id` | Token ID (format `user@realm!tokenname`) |
| `pm_api_token_secret` | Secret du token |
| `pm_insecure` | `true` si certificat auto-signé |
| `pm_storage_vm` | Datastore pour disques VM (ex. `tank-vm` après ZFS) |
| `pm_storage_iso` | Datastore pour ISO/templates |
| `pm_node_name` | Nœud cible (ex. `tatouine`) ; défaut = premier nœud |
| `talos_dev_vm_id` | VM ID pour talos-dev (défaut 100) |
| `talos_prod_cp_vm_id` | VM ID pour talos-prod-cp (défaut 101) |
| `talos_prod_worker_1_vm_id` | VM ID pour talos-prod-worker-1 (défaut 102) |
| `talos_iso_file` | Nom de l’ISO Talos sur le storage (ex. `v1.12.2-metal-amd64.iso`). Vide = pas de CD-ROM. |

## Backend

- **CI/CD** : backend HTTP TFstate.dev (voir `backend.tf`). Définir `TF_HTTP_PASSWORD` (token GitHub).
- **Local** : `backend_override.tf` force un backend local ; le supprimer pour utiliser TFstate.dev.

## Talos VMs (DEV + PROD)

Le module crée **3 VMs** pour les clusters Talos (voir [architecture-proxmox-omni.md](../../_bmad-output/planning-artifacts/architecture-proxmox-omni.md)) :

**Premier boot** : aujourd’hui les VMs sont créées avec un disque vide et (si `talos_iso_file` est défini) un CD-ROM Talos. Il faut démarrer sur l’ISO, puis `talosctl apply-config` pour installer Talos sur le disque. Pour un **boot direct en Talos** (sans étape ISO), il faudrait utiliser l’image disque Talos (ex. `qemu-amd64.raw`) comme disque principal de la VM au lieu de l’ISO — à mettre en place dans le module si besoin.

| VM | Rôle | vCPU | RAM | Disque |
|----|------|------|-----|--------|
| **talos-dev** | DEV single-node (control-plane + worker) | 2 | 4 GB | 50 GB |
| **talos-prod-cp** | PROD control plane | 2 | 4 GB | 50 GB |
| **talos-prod-worker-1** | PROD worker | 6 | 12 GB | 200 GB |

- **Stockage** : `pm_storage_vm` (ex. `tank-vm`). Pour VMs rapides, utiliser `nvme-vm` et adapter la ressource.
- **VM IDs** : 100 (dev), 101 (prod-cp), 102 (prod-worker-1) par défaut ; modifiables via `talos_dev_vm_id`, etc.
- **Premier boot** : définir `talos_iso_file` dans `terraform.tfvars` (ex. `v1.12.2-metal-amd64.iso`) après avoir uploadé l’ISO sur `pm_storage_iso` (ex. tank-iso). Terraform attache l’ISO en CD-ROM et met l’ordre de boot (CD puis disque). Démarrer les VMs, puis exécuter `talosctl apply-config` et récupérer le kubeconfig selon la doc Talos.
- **Quelle image** : ISO Talos metal amd64 sur le storage ISO.

## Suite

- **State Terraform** : [docs-site/docs/advanced/decisions-and-limits.md](../docs-site/docs/advanced/decisions-and-limits.md)
- **ZFS** : [scripts/proxmox/setup-zfs-14tb-only.sh](../../scripts/proxmox/setup-zfs-14tb-only.sh)
