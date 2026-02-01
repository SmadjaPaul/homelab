# Guide setup Proxmox — SSH puis ZFS 2×14 To

Ce guide permet de déléguer un maximum d’actions : une fois l’accès SSH configuré depuis ton Mac, tu pourras exécuter les scripts à distance (ou copier-coller les commandes fournies).

**Ordre des étapes :**

1. **Accès SSH** (depuis ton Mac → Proxmox)
2. **Post-install** (optionnel, une fois la clé SSH en place)
3. **ZFS 2×14 To** (miroir uniquement, script non interactif)
4. **NVMe** (cache + stockage rapide, après ZFS)

---

## Étape 1 — Accès SSH

### 1.1 Trouver l’IP du serveur Proxmox

- **Option A** : Depuis l’écran/console du serveur, l’IP est souvent affichée au login.
- **Option B** : Depuis ton routeur (DHCP / liste des appareils).
- **Option C** : Depuis un autre poste sur le même réseau : `arp -a` ou scanner (ex. `nmap -sn 192.168.1.0/24`).

On suppose par la suite que l’IP est `PROXMOX_IP` (ex. `192.168.1.100`). Remplace par la tienne.

### 1.2 Connexion initiale (mot de passe root)

Depuis ton **Mac** :

```bash
ssh root@PROXMOX_IP
```

Utilise le mot de passe root défini à l’installation de Proxmox. Si la connexion fonctionne, tu es sur le serveur.

### 1.3 Clé SSH (pour ne plus taper le mot de passe et sécuriser)

**Sur ton Mac** (pas sur le serveur) :

1. Générer une clé SSH si tu n’en as pas :
   ```bash
   ls -la ~/.ssh/id_ed25519.pub 2>/dev/null || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
   ```

2. Copier la clé publique vers Proxmox (tu entres une dernière fois le mot de passe root) :
   ```bash
   ssh-copy-id root@PROXMOX_IP
   ```

3. Tester la connexion sans mot de passe :
   ```bash
   ssh root@PROXMOX_IP "hostname"
   ```
   Si ça affiche le hostname sans demander de mot de passe, c’est bon.

À partir de là, tu peux lancer toutes les commandes suivantes depuis ton Mac avec `ssh root@PROXMOX_IP '...'` ou en te connectant une fois et en exécutant les scripts sur le serveur.

### 1.4 (Optionnel) Renforcer SSH côté serveur

Une fois la clé en place, tu peux désactiver la connexion root par mot de passe (recommandé). À faire **sur le serveur** après avoir vérifié que `ssh root@PROXMOX_IP` fonctionne avec la clé :

```bash
# Sur le serveur Proxmox (en SSH)
sed -i 's/#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl restart sshd
```

Ou en une ligne depuis ton Mac :

```bash
ssh root@PROXMOX_IP "sed -i 's/#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config && systemctl restart sshd"
```

---

## Étape 2 — Post-install (optionnel)

Si tu veux appliquer le post-install (dépôts, mises à jour, paquets utiles, IOMMU, etc.) **après** avoir mis ta clé SSH en place :

**Depuis ton Mac** (en remplaçant `PROXMOX_IP` et le chemin du repo) :

```bash
cd /chemin/vers/homelab
scp scripts/proxmox/post-install.sh root@PROXMOX_IP:/tmp/
ssh root@PROXMOX_IP "bash /tmp/post-install.sh"
```

Le script configure notamment SSH en `prohibit-password` ; assure-toi que ta clé est déjà installée avant de l’exécuter.

---

## Étape 3 — ZFS 2×14 To (miroir uniquement)

On utilise **uniquement** les 2 disques de 14 To en miroir (pas les 2×2 To).

### 3.1 Identifier les deux disques 14 To

Sur le serveur (ou en SSH) :

```bash
ssh root@PROXMOX_IP "lsblk -d -o NAME,SIZE,MODEL,SERIAL"
```

Repère les deux disques d’environ **14 T** (noms du type `sda`, `sdb`, etc.). Note les deux noms (ex. `sda` et `sdb`). **Ne prends pas** le NVMe (souvent `nvme0n1`) ni les petits disques.

### 3.2 Lancer le script ZFS 2×14 To

**Depuis ton Mac** (remplace `PROXMOX_IP`, `sda`, `sdb` par ton IP et tes disques) :

```bash
cd /chemin/vers/homelab
scp scripts/proxmox/setup-zfs-14tb-only.sh root@PROXMOX_IP:/tmp/
ssh root@PROXMOX_IP "chmod +x /tmp/setup-zfs-14tb-only.sh"
ssh root@PROXMOX_IP "CONFIRM=yes /tmp/setup-zfs-14tb-only.sh sda sdb"
```

- `sda` et `sdb` : les deux disques 14 To (ordre indifférent pour un miroir).
- `CONFIRM=yes` : évite la demande de confirmation (à utiliser seulement quand tu es sûr des noms de disques).

Le script crée :

- un pool ZFS `tank` en miroir sur les deux disques ;
- les datasets : `vm-disks`, `containers`, `backups`, `iso`, `snippets` ;
- les storages Proxmox : `tank-vm`, `tank-iso`, `tank-backup` ;
- une tâche cron mensuelle de scrub ZFS.

### 3.3 Vérification

```bash
ssh root@PROXMOX_IP "zpool status tank && zfs list -r tank"
```

Dans l’interface Proxmox (Datacenter → Storage), tu dois voir `tank-vm`, `tank-iso`, `tank-backup`.

---

## Étape 4 — NVMe (cache + stockage rapide)

À faire **après** le pool `tank` (étape 3). Le NVMe contient déjà l’OS ; on utilise le reste pour :

- **L2ARC + SLOG** (cache du pool `tank`) ;
- **Pool rapide** (apps, jeux, VMs rapides).

Cette étape est **manuelle** (partitionnement + scripts) car elle dépend de la taille de ta partition OS et de ce que tu veux allouer au cache vs au pool rapide.

Voir le script et les instructions dans :

- `scripts/proxmox/setup-nvme-cache.sh` — ajout L2ARC/SLOG au pool `tank` ;
- `docs/proxmox-zfs-storage.md` — schéma des partitions NVMe et commandes pour le pool rapide.

En résumé :

1. Créer des partitions sur le reste du NVMe (L2ARC, SLOG, puis espace pour pool rapide).
2. Lancer `setup-nvme-cache.sh` pour attacher L2ARC et SLOG à `tank`.
3. Créer un pool ZFS sur la partition dédiée (ex. `nvme`) et l’ajouter comme storage Proxmox (ex. `nvme-vm`).

Ensuite, dans Terraform, tu pourras utiliser `pm_storage_vm = "nvme-vm"` pour les VMs qui ont besoin de rapidité.

---

## Récap — Ordre et délégaution

| Étape | Où | Action |
|-------|-----|--------|
| 1 | Mac | SSH + `ssh-copy-id` → plus besoin de mot de passe |
| 2 | Mac → Proxmox | (Optionnel) `scp` + `post-install.sh` |
| 3 | Mac → Proxmox | `scp` + `setup-zfs-14tb-only.sh` avec les 2 disques 14 To |
| 4 | Proxmox | Manuel / `setup-nvme-cache.sh` + partitionnement NVMe |

Une fois l’étape 1 faite, tu peux exécuter toutes les commandes des étapes 2 et 3 depuis ton Mac en SSH ; l’étape 4 reste manuelle sur le serveur (partitionnement et choix des tailles).
