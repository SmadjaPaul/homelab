# Proxmox — ZFS et stockage (2×14 To, NVMe)

Ce doc clarifie l’usage des disques (2×14 To, NVMe 1 To) et ce qui se fait en **script/manuel** vs **Terraform**.

**Guide pas à pas (SSH puis ZFS 2×14 To)** : [proxmox-setup-guide.md](proxmox-setup-guide.md).

---

## 1. Les 2×2 To dégradent-ils le miroir 2×14 To ?

**Non.** En ZFS, chaque **vdev** est indépendant. Si tu fais :

- **Option A** : un seul pool avec **un** vdev = miroir 2×14 To
  → Le miroir 2×14 To n’est pas “dégradé” par autre chose ; c’est le cas le plus simple.

- **Option B** : un pool avec **deux** vdevs = miroir 2×14 To **+** miroir 2×2 To
  → Le miroir 2×14 To reste un miroir à part entière. En revanche, **tout le pool** dépend des deux vdevs : si un des deux vdevs est perdu (ex. les 2×2 To), **tout le pool** est perdu. Donc les 2×2 To n’affaiblissent pas le miroir 2×14 To en soi, mais ils ajoutent un second point de défaillance pour le pool.

**Recommandation** : **n’utiliser que le miroir 2×14 To**. Script dédié : `scripts/proxmox/setup-zfs-14tb-only.sh` (voir [proxmox-setup-guide.md](proxmox-setup-guide.md)).

---

## 2. NVMe 1 To (OS + cache + apps/jeux rapides)

Tu as **1 To NVMe** avec l’OS installé. Tu veux en utiliser une bonne partie pour :

- **Cache ZFS** (accélérer le pool sur HDD)
- **Stockage rapide** pour applis et jeux

### Terraform peut-il faire ça ?

**Non.** Le provider Terraform **bpg/proxmox** gère des **storages Proxmox** déjà existants (datastores) : il ne crée pas les pools ZFS, ni les vdevs, ni le cache (L2ARC/SLOG), ni les partitions sur le NVMe. Tout ça se fait **sur l’hôte Proxmox**, en **manuel ou script**.

En résumé :

| Élément | Où le faire | Terraform (bpg/proxmox) |
|--------|-------------|--------------------------|
| Pool ZFS (2×14 To miroir) | Script / manuel | ❌ Non |
| L2ARC / SLOG sur NVMe | Script / manuel | ❌ Non |
| Partition NVMe (OS / cache / fast) | Script / manuel | ❌ Non |
| Ajout storage Proxmox (pvesm) | Script / manuel | ❌ Non |
| **Création de VMs/LXC** qui utilisent ces storages | Terraform | ✅ Oui |

Donc : **config ZFS + cache + partition NVMe = manuel ou script** ; **création des VMs et choix du datastore (ex. `tank-vm`, `nvme-vm`) = Terraform**.

### Schéma possible pour le NVMe

- **Partition 1** : déjà utilisée par l’OS (Proxmox).
- **Partition 2** : pour **cache ZFS** du pool `tank` (L2ARC + SLOG) :
  - L2ARC = cache de lecture (ex. 50–100 Go).
  - SLOG = journal d’écriture synchrone (ex. 10–20 Go, miroir si possible).
- **Partition 3** (reste) : **stockage rapide** :
  - Soit un **pool ZFS** dédié (ex. `nvme`) avec un dataset pour VMs/jeux/applis.
  - Soit un **répertoire** monté et ajouté comme storage Proxmox (Dir ou ZFS selon ce que tu crées).

Ensuite, dans Proxmox, tu ajoutes un storage (ZFS ou répertoire) sur cette partition/pool, et dans **Terraform** tu utilises ce storage (ex. `pm_storage_vm = "nvme-vm"`) pour les VMs qui ont besoin de rapidité.

**Script fourni** : `scripts/proxmox/setup-nvme-cache.sh` — ajoute L2ARC et SLOG au pool existant (tank) à partir de partitions NVMe que tu auras créées au préalable. Pour le **stockage rapide** (apps/jeux), en fin de script sont rappelées les commandes : créer une partition sur le reste du NVMe, un pool ZFS dédié (ex. `nvme`), un dataset, puis `pvesm add` pour Proxmox ; Terraform pourra ensuite utiliser ce storage (ex. `nvme-vm`) pour les VMs qui ont besoin de rapidité.

---

## 3. Récap

- **2×14 To en miroir** : pas dégradés par les 2×2 To ; tu peux **ne pas utiliser** les 2×2 To pour rester simple.
- **2×2 To** : optionnels ; si tu les mets dans le même pool que le 2×14 To, le pool entier dépend des deux vdevs.
- **NVMe** : cache (L2ARC/SLOG) + stockage rapide = **toujours en manuel/script** sur l’hôte ; **Terraform** sert à utiliser les storages déjà créés (VMs, disques, datastores).
