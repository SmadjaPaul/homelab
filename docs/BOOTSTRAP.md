# Bootstrap Talos (DEV puis PROD)

Guide pas à pas pour démarrer les clusters Talos sur Proxmox après création des VMs par Terraform.

**Prérequis** : VMs créées (`terraform/proxmox`), ISO Talos uploadée sur `tank-iso`, variable `talos_iso_file` définie dans `terraform.tfvars`, et `terraform apply` exécuté pour attacher le CD-ROM et l’ordre de boot.

---

## 1. Préparer l’environnement local

- **talosctl** : [Installation](https://www.talos.dev/latest/talos-guides/install/talosctl/) (macOS : `brew install talosctl`).
- **kubectl** : requis pour vérifier le cluster après bootstrap.
- Créer un répertoire par cluster pour ne pas mélanger secrets et configs :
  ```bash
  mkdir -p talos/dev talos/prod
  ```

---

## 2. Cluster DEV (single-node : talos-dev) — détaillé

### 2.1 Démarrer la VM et récupérer l’IP

1. Dans Proxmox : **Datacenter** → **tatouine** → VM **talos-dev** (ID 100) → bouton **Start**.
2. La VM boot sur l’ISO Talos (écran bleu / invite Talos). Elle doit obtenir une IP en DHCP sur `vmbr0`.

**Récupérer l’IP** (une des méthodes) :

- **Proxmox** : VM **talos-dev** → onglet **Network** (après quelques secondes) — pas toujours disponible selon la version.
- **Depuis ta machine**, même réseau que le Proxmox (ex. 192.168.68.x) :
  ```bash
  # Table ARP : cherche une nouvelle IP après avoir démarré la VM
  arp -a

  # Ou scan du sous-réseau (remplace par ton réseau)
  nmap -sn 192.168.68.0/24
  ```
- **Console Proxmox** : VM → **Console** → sur l’écran Talos, l’IP peut s’afficher au boot.

Note l’IP, ex. `192.168.68.120`. On l’appellera `<IP_DEV>` dans la suite.

### 2.2 Générer les secrets du cluster

Les secrets (talosctl, etcd, Kubernetes) doivent être uniques par cluster et **ne jamais être commités**.

```bash
cd talos/dev
talosctl gen secrets -o secrets.yaml
```

Cela crée `secrets.yaml` (à garder local, ajouté à `.gitignore`). Un seul fichier par cluster.

### 2.3 Générer la config machine (controlplane)

Pour un **single-node DEV**, le nœud est à la fois control plane et (implicitement) worker. On ne génère que le type `controlplane`.

```bash
talosctl gen config homelab-dev https://<IP_DEV>:6443 \
  --with-secrets-from secrets.yaml \
  --output-dir . \
  --output-types controlplane
```

Remplace `<IP_DEV>` par l’IP réelle, ex. :

```bash
talosctl gen config homelab-dev https://192.168.68.120:6443 \
  --with-secrets-from secrets.yaml \
  --output-dir . \
  --output-types controlplane
```

**Fichiers créés** : `controlplane.yaml`, `worker.yaml` (vide ou inutilisé pour le dev single-node), et éventuellement `talosconfig`. On utilise uniquement `controlplane.yaml` pour talos-dev.

**Signification** :
- `homelab-dev` : nom du cluster (tu peux le changer).
- `https://<IP_DEV>:6443` : endpoint de l’API Kubernetes (pour un seul nœud, c’est l’IP de ce nœud).
- `--output-types controlplane` : on ne génère que la config control plane.

### 2.4 Adapter la config (optionnel)

- **Réseau** : par défaut Talos utilise DHCP. Si ton réseau le fournit, rien à faire. Sinon, tu peux ajouter un patch pour adresse statique (voir doc Talos).
- **Disque d’installation** : nos VMs Proxmox utilisent **SCSI** (`scsi0`). Sous Talos, le disque est en général **`/dev/sda`**. La config générée contient souvent déjà `machine.install.disk: /dev/sda`. Si ce n’est pas le cas, édite `controlplane.yaml` et ajoute ou modifie :
  ```yaml
  machine:
    install:
      disk: /dev/sda
  ```
- **Validation** (optionnel) :
  ```bash
  talosctl validate --config controlplane.yaml
  ```

### 2.5 Appliquer la config sur la VM (premier boot depuis l’ISO)

À ce stade, la VM tourne **depuis l’ISO** (mémoire, pas encore installé sur disque). On envoie la config pour qu’elle s’installe sur le disque et redémarre.

```bash
talosctl apply-config --insecure --nodes <IP_DEV> --file controlplane.yaml
```

- `--insecure` : nécessaire tant que le cluster n’est pas bootstrappé (pas encore de certificats de confiance).
- Tu dois voir une confirmation du type : « applying config... » puis la VM **redémarre** et installe Talos sur `/dev/sda`.

**Attendre 1 à 2 minutes** que l’installation se fasse et que la VM revienne avec Talos installé sur disque.

### 2.6 Bootstrap du cluster (etcd, API Kubernetes)

Une fois la VM revenue avec Talos sur disque, on lance le bootstrap : initialisation d’etcd et des composants control plane.

```bash
talosctl bootstrap --nodes <IP_DEV>
```

En cas d’erreur « connection refused » ou timeout : attendre encore 30 s et réessayer. Le service Talos peut mettre un peu de temps à écouter.

### 2.7 Récupérer le kubeconfig

```bash
talosctl kubeconfig --nodes <IP_DEV> -n default --output kubeconfig-dev
```

Puis :

```bash
export KUBECONFIG=$PWD/kubeconfig-dev
kubectl get nodes
```

Tu dois voir un nœud `Ready` (ex. `homelab-dev-master-1` ou le hostname de la VM). Le cluster DEV est opérationnel.

**Résumé des commandes DEV** (à exécuter dans l’ordre, en remplaçant `<IP_DEV>`) :

```bash
cd talos/dev
talosctl gen secrets -o secrets.yaml
talosctl gen config homelab-dev https://<IP_DEV>:6443 --with-secrets-from secrets.yaml --output-dir . --output-types controlplane
talosctl apply-config --insecure --nodes <IP_DEV> --file controlplane.yaml
# Attendre 1–2 min (redémarrage + installation)
talosctl bootstrap --nodes <IP_DEV>
talosctl kubeconfig --nodes <IP_DEV> -n default --output kubeconfig-dev
export KUBECONFIG=$PWD/kubeconfig-dev && kubectl get nodes
```

Une fois le cluster DEV opérationnel, on peut passer au PROD.

**Dépannage DEV** :
- **« connection refused » ou timeout** sur `apply-config` / `bootstrap` : la VM n’a pas encore fini de booter ou le service Talos n’écoute pas. Attendre 1–2 min et réessayer.
- **Pas d’IP** : vérifier que `vmbr0` a bien un accès DHCP (ou configurer une IP statique dans un patch Talos).
- **Installation sur le mauvais disque** : éditer `controlplane.yaml`, `machine.install.disk: /dev/sda` (ou `/dev/vda` selon ce que Talos voit — console Proxmox pour vérifier).

---

## 3. Cluster PROD (talos-prod-cp + talos-prod-worker-1)

### 3.1 Démarrer les VMs

- Démarrer **talos-prod-cp** puis **talos-prod-worker-1**.
- Noter l’IP du control plane (ex. `192.168.68.121`) et celle du worker (ex. `192.168.68.122`).

### 3.2 Générer secrets et config PROD

```bash
cd talos/prod
talosctl gen secrets -o secrets.yaml
talosctl gen config homelab-prod https://<IP_PROD_CP>:6443 \
  --with-secrets-from secrets.yaml \
  --output-dir . \
  --output-types controlplane,worker
```

Remplacer `<IP_PROD_CP>` par l’IP de **talos-prod-cp**.

### 3.3 Appliquer config control plane puis worker

```bash
talosctl apply-config --insecure --nodes <IP_PROD_CP> --file controlplane.yaml
# Attendre que le control plane soit installé et redémarré
talosctl apply-config --insecure --nodes <IP_PROD_WORKER> --file worker.yaml
```

Remplacer `<IP_PROD_WORKER>` par l’IP de **talos-prod-worker-1**.

### 3.4 Bootstrap et kubeconfig PROD

```bash
talosctl bootstrap --nodes <IP_PROD_CP>
talosctl kubeconfig --nodes <IP_PROD_CP> -n default --output kubeconfig-prod
export KUBECONFIG=$PWD/kubeconfig-prod
kubectl get nodes
```

---

## 4. Après le bootstrap

- **Retirer le CD-ROM** (optionnel) : dans Terraform, vider `talos_iso_file` puis `terraform apply`, ou détacher l’ISO à la main dans Proxmox pour que les VMs bootent uniquement sur disque.
- **CNI** : installer Cilium (ou autre) selon l’architecture.
- **GitOps** : déployer Argo CD et les apps selon les waves définies dans l’architecture.

---

## Références

- [Talos - Proxmox](https://www.talos.dev/latest/talos-guides/install/virtualized-platforms/proxmox/)
- [Talos - Creating a cluster](https://www.talos.dev/latest/talos-guides/install/boot-to-talos/)
- `docs/proxmox-talos-setup-verification.md` — bonnes pratiques ISO / versions
- `terraform/proxmox/README.md` — variables et premier boot
