# Proxmox + Terraform — Bonnes pratiques

Ce document résume les bonnes pratiques pour gérer Proxmox VE avec Terraform et justifie le choix du provider **bpg/proxmox**.

---

## Choix du provider Terraform

### Comparaison des providers Proxmox

| Critère | **bpg/proxmox** | Telmate/proxmox | Terraform-for-Proxmox/proxmox |
|--------|------------------|------------------|-------------------------------|
| Maintenance | ✅ Très active (releases régulières) | Moins active | Variable |
| Ressources | VMs, LXC, fichiers, download, storage, ACL, etc. | VMs (QEMU), LXC | Similaire à bpg |
| Auth | API Token, ticket, user/password | API Token, user/password | API Token, user/password |
| SSH | Optionnel (surtout pour snippets/fichiers) | Souvent requis | Variable |
| Proxmox 8/9 | ✅ Supporté | Support partiel | Supporté |
| OpenTofu | ✅ Compatible | Oui | Oui |

### Recommandation : **bpg/proxmox**

- **Le plus maintenu** et le plus téléchargé (Terraform Registry).
- **API-first** : la plupart des ressources passent par l’API Proxmox, SSH optionnel.
- **API Token** recommandé pour la prod et le CI/CD.
- **Bonne doc** et exemples (cloud-init, cloud images, VMs, LXC).
- **Limitation** : pas de gestion des pools ZFS (création de pool) ; les pools ZFS se créent à la main ou via script (`scripts/proxmox/setup-zfs.sh`), puis les datastores Proxmox (ZFS ou dir sur ZFS) sont utilisés dans Terraform pour les disques VM/LXC.

---

## Bonnes pratiques

### 1. Authentification

- **Privilégier l’API Token** plutôt que user/password :
  - Créer un utilisateur dédié (ex. `terraform-prov@pve`) avec un rôle aux droits minimaux.
  - Créer un API Token pour cet utilisateur.
  - Utiliser les variables d’environnement ou des variables Terraform sensibles (jamais en clair dans le repo).

- **Utilisateur Proxmox dédié** (exemple avec `pveum`) :
  ```bash
  # Rôle avec droits minimaux pour Terraform (VM, storage, etc.)
  pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt SDN.Use"

  pveum user add terraform-prov@pve
  pveum aclmod / -user terraform-prov@pve -role TerraformProv

  # Créer un API Token (via l’UI : Datacenter → Permissions → Users → terraform-prov → Add API Token)
  # ou via CLI selon ta version.
  ```

- Dans Terraform : utiliser des **variables** (ex. `pm_api_token_id`, `pm_api_token_secret`) ou des **variables d’environnement** prises en charge par le provider, et ne pas commiter les secrets.

### 2. État Terraform (state)

- **Backend distant** (TFstate.dev, S3, etc.) pour le state, avec verrouillage.
- Ne pas commiter `terraform.tfstate` ni les fichiers contenant des secrets (`terraform.tfvars` avec tokens).
- Pour le CI/CD : même backend que les autres modules (ex. TFstate.dev avec token GitHub).

### 3. ZFS et stockage

- **Création des pools ZFS** : en dehors de Terraform (script `scripts/proxmox/setup-zfs.sh` ou manuel). Recommandation homelab : miroir **2×14 To uniquement** (les 2×2 To ne dégradent pas le miroir 14 To, mais les laisser de côté simplifie le setup ; voir [proxmox-zfs-storage.md](proxmox-zfs-storage.md)).
- **Cache NVMe (L2ARC/SLOG)** et **stockage rapide** (apps/jeux) : manuel ou script `scripts/proxmox/setup-nvme-cache.sh` ; Terraform ne gère pas les pools ni le cache.
- **Ajout des storages Proxmox** (pvesm) : dans les scripts ou manuellement.
- **Terraform** : utiliser les **datastore_id** existants (ex. `tank-vm`, `nvme-vm`) dans les ressources `proxmox_virtual_environment_vm` ou LXC pour les disques et médias.

### 4. Structure du code

- **Variables** pour l’URL Proxmox, le nœud, les tokens, les noms de datastore.
- **Modules ou fichiers séparés** par rôle (VMs, LXC, fichiers) si la config grossit.
- **Outputs** pour les IP, noms de VM, etc., pour faciliter l’intégration avec Ansible ou d’autres outils.

### 5. TLS / certificats

- En dev ou homelab avec certificat auto-signé : `insecure = true` dans le provider.
- En prod : utiliser un certificat valide ou une CA interne pour éviter `insecure`.

### 6. Ordre de déploiement

1. **Proxmox VE** installé et à jour.
2. **ZFS** : créer pools et datasets, puis ajouter les storages dans Proxmox (script ou manuel).
3. **Utilisateur + API Token** pour Terraform.
4. **Terraform** : provider + ressources (VMs, LXC, etc.) en s’appuyant sur les datastores existants.

---

## Ressources utiles

- [bpg/proxmox – Terraform Registry](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [GitHub bpg/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox)
- [Proxmox VE API](https://pve.proxmox.com/wiki/Proxmox_VE_API)
- Script ZFS homelab : `scripts/proxmox/setup-zfs.sh`
- Module Terraform : `terraform/proxmox/`
