# Vérification setup Proxmox + Talos vs architecture et mitchross/talos-argocd-proxmox

Ce document compare le setup homelab (Terraform Proxmox + Talos VMs) à :
- **[architecture-proxmox-omni.md](../_bmad-output/planning-artifacts/architecture-proxmox-omni.md)** (référence interne)
- **[mitchross/talos-argocd-proxmox](https://github.com/mitchross/talos-argocd-proxmox)** (référence externe)

---

## 1. Conformité avec l’architecture (architecture-proxmox-omni.md)

### 1.1 Topologie clusters

| Élément | Architecture | Notre setup | Statut |
|--------|--------------|-------------|--------|
| **DEV** | 1 nœud (control-plane + worker), 2 vCPU, 4 GB RAM, 50 GB | talos-dev : 2 vCPU, 4 GB, 50 GB | ✅ |
| **PROD control plane** | talos-prod-cp, 2 vCPU, 4 GB, 50 GB | talos-prod-cp : 2 vCPU, 4 GB, 50 GB | ✅ |
| **PROD worker** | talos-prod-worker-1, 6 vCPU, 12 GB, 200 GB | talos-prod-worker-1 : 6 vCPU, 12 GB, 200 GB | ✅ |
| **Noms** | talos-dev, talos-prod-cp, talos-prod-worker-1 | Idem dans `talos-vms.tf` | ✅ |
| **Stockage** | ZFS (tank-vm après setup) | `pm_storage_vm` (tank-vm par défaut) | ✅ |
| **Réseau** | vmbr0, bridge | vmbr0, virtio | ✅ |

### 1.2 Points communs avec le doc

- Terraform pour les VMs (Phase 1 : « Terraform Proxmox VMs (DEV + PROD nodes) »).
- Pas d’ISO Talos dans Terraform dans l’exemple (on utilise attachement manuel ou script) ; le doc mentionne optionnellement `file_id` pour une image — nous documentons l’ISO en CDROM pour le premier boot.
- Tags : talos, kubernetes, dev/prod, control-plane/worker — présents.

### 1.3 Différences mineures

- **node_name** : le doc montre `"proxmox"` en dur ; nous utilisons `local.node_name` (variable, ex. `tatouine`) — adapté à ton host.
- **CPU** : nous utilisons `type = "host"` — conforme à la [doc Talos Proxmox](https://talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox) (x86-64-v2, kvm64 ou host).

---

## 2. Comparaison avec mitchross/talos-argocd-proxmox

### 2.1 Deux façons de faire (mitchross)

| Méthode | Description | Notre choix |
|--------|-------------|------------|
| **Omni + Sidero Proxmox** | Omni provisionne les VMs sur Proxmox via [omni-infra-provider-proxmox](https://github.com/siderolabs/omni-infra-provider-proxmox). | Nous utilisons **Terraform (bpg/proxmox)** pour créer les VMs ; Omni (sur OCI) servira à **gérer** les clusters une fois en place. |
| **Manual Talos** | VMs créées à la main ou par un autre outil ; config Talos avec talhelper/talosctl ; boot ISO puis `talosctl apply-config`. | C’est notre flux actuel : Terraform crée les VMs → tu attaches l’ISO Talos → `talosctl apply-config`. |

Notre setup correspond donc à la branche **« Manual Talos »** pour la création des VMs, avec Terraform en plus pour l’IaC.

### 2.2 Ce qu’on aligne avec mitchross

- **Sync waves ArgoCD** : déjà prévues dans l’architecture (wave 0–4) ; à mettre en œuvre dans `kubernetes/` comme dans mitchross.
- **Cilium + Gateway API** : prévus dans l’architecture ; à déployer après bootstrap Talos.
- **Pas de SSH sur les nœuds** : gestion via API Talos (talosctl / Omni) — idem mitchross.
- **Bootstrap** : mitchross a un **BOOTSTRAP.md** ; nous avons `docs/proxmox-setup-guide.md`, `docs/proxmox-api-token.md` et le README Talos dans `talos/README.md`. On peut ajouter un **BOOTSTRAP.md** ou une section « Bootstrap Talos (DEV puis PROD) » qui reprend les étapes (génération secrets, gen config, ISO, apply-config).

### 2.3 Bonnes pratiques Talos / Proxmox (officiel Sidero)

- **UEFI + machine q35** : recommandé pour Talos sur Proxmox ([Sidero Proxmox](https://talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox)).
  → À ajouter dans nos VMs : `bios = "ovmf"`, `machine = "q35"` (et EFI disk si requis par le provider).
- **CPU** : type `host` ou kvm64 avec flags x86-64-v2 — déjà en place (`type = "host"`).
- **Pas de hotplug mémoire** : Talos ne gère pas le memory hotplug — ne pas l’activer sur les VMs Talos (par défaut c’est désactivé avec le provider).

---

## 3. Structure du repo vs mitchross

| Élément | mitchross | Notre repo |
|--------|-----------|------------|
| **infrastructure/** | Terraform / config Proxmox / Omni | `terraform/proxmox/` (VMs Talos) ; pas encore d’équivalent « omni » Terraform côté Proxmox |
| **omni/** | Clusters, machine-classes, patches | Prévu dans l’architecture (`omni/clusters/`, `machine-classes/`) ; à créer quand Omni (OCI) sera en place |
| **scripts/** | Bootstrap, déploiement | `scripts/proxmox/` (ZFS, NVMe, post-install) ; `talos/install.sh` |
| **BOOTSTRAP.md** | Guide pas à pas | À formaliser : combiner `proxmox-setup-guide.md`, `talos/README.md` et étapes talosctl |
| **talos/** | iac/talos ou configs Talos | `talos/` avec `controlplane.yaml`, `worker.yaml`, `install.sh`, `README.md` |

Notre `talos/` contient déjà des configs (controlplane, worker) ; à adapter pour **deux clusters** (DEV single-node, PROD cp+worker) et des endpoints distincts.

---

## 4. Actions recommandées

1. **VMs Talos** : ajouter `bios = "ovmf"` et `machine = "q35"` dans `talos-vms.tf` (alignement avec la doc Sidero et les bonnes pratiques Proxmox).
2. **Bootstrap** : rédiger un **BOOTSTRAP.md** (ou une section dédiée) qui décrit : génération des secrets Talos, `talosctl gen config` pour DEV et PROD, attachement ISO, `talosctl apply-config`, puis installation Cilium / ArgoCD comme dans l’architecture.
3. **Configs Talos** : faire évoluer `talos/` pour distinguer cluster DEV (1 nœud) et cluster PROD (cp + worker) avec des endpoints et noms de cluster différents.
4. **Omni** : quand le cluster OCI (Omni) sera déployé, ajouter les définitions dans `omni/` (clusters, machine-classes) et enregistrer les clusters DEV/PROD dans Omni comme dans mitchross.

---

## 5. Récapitulatif

| Critère | Statut |
|--------|--------|
| Specs VMs (vCPU, RAM, disque) vs architecture | ✅ Conformes |
| Noms et rôles (talos-dev, talos-prod-cp, talos-prod-worker-1) | ✅ Conformes |
| Stockage (tank-vm) et réseau (vmbr0) | ✅ Conformes |
| Alignement avec mitchross (Manual Talos + sync waves) | ✅ Cohérent |
| UEFI + q35 pour Talos (Sidero) | ✅ Ajouté dans talos-vms.tf |
| Choix d’image Talos (ISO vs qcow2, version, extensions) | ✅ Voir section 6 |
| BOOTSTRAP / doc bootstrap unifiée | 🔶 À renforcer |
| omni/ et enregistrement clusters dans Omni | ⏳ Après mise en place d’Omni sur OCI |

---

## 6. Choix d’image Talos et bonnes pratiques

Sources : [Talos Proxmox (Sidero)](https://talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox), [Boot Assets](https://talos.dev/v1.11/talos-guides/install/boot-assets), [Image Factory](https://factory.talos.dev), [GitHub releases](https://github.com/siderolabs/talos/releases).

### 6.1 Types d’images disponibles

| Format | Fichier | Usage recommandé |
|--------|---------|-------------------|
| **ISO** | `metal-amd64.iso` | Boot initial en CDROM → installation sur le disque via `talosctl apply-config`. Méthode classique, compatible avec nos VMs (disque vide). |
| **qcow2** | `metal-amd64.qcow2` | Image disque prête à l’emploi : on l’attache comme disque VM → boot direct, pas d’étape d’installation. Idéal pour provisionnement automatisé (Terraform + `file_id`). |
| **raw** | `metal-amd64.raw.zst` | Image raw compressée ; à décompresser puis attacher. Moins pratique que qcow2 pour Proxmox. |

**Recommandation pour notre setup actuel** :
- **ISO** si tu fais le premier boot à la main (attacher l’ISO en CDROM, boot, `talosctl apply-config` sur le disque).
- **qcow2** si tu veux que Terraform télécharge l’image et l’attache comme disque principal : boot direct, pas de CDROM.

### 6.2 Quelle version prendre

- **Talos 1.9.x** : stable, aligné avec l’architecture (Talos 1.9.x, Kubernetes 1.32.x).
- **Talos 1.11.x** : stable récent, doc Proxmox à jour sur [talos.dev/v1.11](https://talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox).
- **Talos 1.12.x** : à suivre selon [releases](https://github.com/siderolabs/talos/releases) et compatibilité K8s.

**Recommandation** : utiliser une **version stable** (1.9.x ou 1.11.x) et la figer dans la doc / scripts (ex. `TALOS_VERSION=1.9.5` ou `1.11.x`).

### 6.3 Où télécharger l’image

| Source | Usage |
|--------|--------|
| **[GitHub releases](https://github.com/siderolabs/talos/releases)** | Images pré-buildées par version (ISO, raw, etc.). URL directe ex. `https://github.com/siderolabs/talos/releases/download/v1.9.5/metal-amd64.iso`. |
| **[Image Factory](https://factory.talos.dev)** | Images **personnalisées** : version, extensions (ex. qemu-guest-agent), arguments noyau. Génère un schematic ID et une URL de téléchargement. |

- **Image standard (ISO ou qcow2)** : GitHub releases suffit.
- **Image avec extension qemu-guest-agent** (recommandé pour Proxmox) : utiliser l’Image Factory, ajouter l’extension `siderolabs/qemu-guest-agent`, puis télécharger l’ISO ou le qcow2 généré.

### 6.4 Extension qemu-guest-agent (Proxmox)

- **Pourquoi** : Proxmox utilise l’agent invité pour shutdown/reboot propres des VMs. Sans agent, l’arrêt peut être forcé (power off).
- **Comment** : image Talos construite avec l’extension **siderolabs/qemu-guest-agent** via [Image Factory](https://factory.talos.dev) (Extensions → `siderolabs/qemu-guest-agent`).
- **Alternative** : utiliser l’ISO standard et installer l’agent plus tard (ex. DaemonSet communautaire [qemu-guest-agent-talos](https://github.com/crisobal/qemu-guest-agent-talos)) ; l’image avec extension est plus propre.

### 6.5 Récap bonnes pratiques image

1. **Version** : 1.9.x ou 1.11.x (stable), à figer (variable ou doc).
2. **Format** : **ISO** pour install manuelle sur disque vide ; **qcow2** pour boot direct depuis une image disque (Terraform ou script).
3. **Source** : **GitHub releases** pour image standard ; **Image Factory** pour image avec qemu-guest-agent (recommandé sur Proxmox).
4. **Extensions** : ajouter **qemu-guest-agent** via Image Factory pour un comportement Proxmox optimal (shutdown/reboot).
5. **CPU** : `host` ou kvm64 + x86-64-v2 (déjà en place).
6. **Mémoire** : pas de hotplug (déjà respecté).
7. **UEFI + q35** : déjà configuré dans `talos-vms.tf`.
