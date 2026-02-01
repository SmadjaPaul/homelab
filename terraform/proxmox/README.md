# Proxmox VE — Terraform (bpg/proxmox)

Configuration Terraform pour **Proxmox VE** avec le provider [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs).

## Pourquoi bpg/proxmox

- **Très maintenu** et compatible Proxmox 8/9
- **API-first** : peu de dépendance au SSH
- **API Token** pour la prod et le CI/CD
- Ressources : VMs, LXC, fichiers, téléchargements, ACL, etc.

Autres providers (Telmate, Terraform-for-Proxmox) sont moins actifs ou moins complets. Voir [docs/proxmox-terraform-best-practices.md](../docs/proxmox-terraform-best-practices.md) pour la comparaison et les bonnes pratiques.

## Prérequis

1. **Proxmox VE** installé et accessible (ex. `https://192.168.68.51:8006/`).
2. **Utilisateur Proxmox dédié** + **API Token** (recommandé) — voir [bonnes pratiques](../docs/proxmox-terraform-best-practices.md#1-authentification).
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

| VM | Rôle | vCPU | RAM | Disque |
|----|------|------|-----|--------|
| **talos-dev** | DEV single-node (control-plane + worker) | 2 | 4 GB | 50 GB |
| **talos-prod-cp** | PROD control plane | 2 | 4 GB | 50 GB |
| **talos-prod-worker-1** | PROD worker | 6 | 12 GB | 200 GB |

- **Stockage** : `pm_storage_vm` (ex. `tank-vm`). Pour VMs rapides, utiliser `nvme-vm` et adapter la ressource.
- **VM IDs** : 100 (dev), 101 (prod-cp), 102 (prod-worker-1) par défaut ; modifiables via `talos_dev_vm_id`, etc.
- **Premier boot** : définir `talos_iso_file` dans `terraform.tfvars` (ex. `v1.12.2-metal-amd64.iso`) après avoir uploadé l’ISO sur `pm_storage_iso` (ex. tank-iso). Terraform attache l’ISO en CD-ROM et met l’ordre de boot (CD puis disque). Démarrer les VMs, puis suivre [docs/BOOTSTRAP.md](../docs/BOOTSTRAP.md) pour `talosctl apply-config` et récupération du kubeconfig.
- **Quelle image prendre** (ISO vs qcow2, version, extensions) : voir [docs/proxmox-talos-setup-verification.md](../docs/proxmox-talos-setup-verification.md#6-choix-dimage-talos-et-bonnes-pratiques).

## Suite

- **Bonnes pratiques** : [docs/proxmox-terraform-best-practices.md](../docs/proxmox-terraform-best-practices.md)
- **ZFS** : [docs/proxmox-setup-guide.md](../docs/proxmox-setup-guide.md), [scripts/proxmox/setup-zfs-14tb-only.sh](../../scripts/proxmox/setup-zfs-14tb-only.sh)
