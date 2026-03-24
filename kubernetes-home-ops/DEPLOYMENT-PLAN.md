# Plan de Déploiement — kubernetes-home-ops (Single-Node Talos)

## Contexte

Ce repo est une adaptation de [bjw-s-labs/home-ops](https://github.com/bjw-s-labs/home-ops) (cluster 3 nœuds Talos Linux) vers un **homelab single-node Talos** sur Proxmox.

### Serveur cible
- **IP** : `192.168.68.58`
- **Type** : VM Proxmox, single-node Talos Linux
- **Domaine** : `smadja.dev` (DNS chez OVH, gestion via Cloudflare et/ou OVH)
- **Réseau** : Pas de bond, pas de VLANs, pas de BGP — une seule NIC

### Repo source (bjw-s) — conçu pour :
- 3 nœuds physiques (delta, enigma, felix) avec Intel igc NICs
- Bond interface (2 NICs active-backup, MTU 9000)
- BGP peering avec routeur UniFi (ASN 64513/64514)
- Rook-Ceph (réplication x3 cross-host)
- VLANs IoT (303) et VPN (305)
- Secrets via 1Password Connect
- Backup via VolSync/Kopia vers NAS (gladius.bjw-s.internal)

### Ce qui a déjà été adapté
- `cilium/app/helmrelease.yaml` : routingMode=tunnel, BIGTCP=false, LB mode=snat, BGP=false, devices=eth0
- `external-dns/app/` : configuré pour Cloudflare (CF_API_TOKEN via ExternalSecret)
- `bootstrap/helmfile.d/templates/values.yaml.gotmpl` : chemin corrigé pour lire les HelmRelease

---

## Prérequis — Secrets & Accès

### 1Password Connect (méthode actuelle du repo)
Le repo utilise **1Password Connect** comme secret store. Il faut :
- Un compte 1Password avec les vaults **"Automation"** et **"Services"**
- Un **1Password Connect Server** token + credentials JSON
- Ces données sont bootstrapées via `resources.yaml.j2` qui utilise `op://` URIs

**Secret bootstrap** (fichier `kubernetes/bootstrap/resources.yaml.j2`) :
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: onepassword-secret
  namespace: external-secrets
stringData:
  1password-credentials.json: op://Automation/1password connect/credentials
  token: op://Automation/1password connect/token
```

⚠️ **Alternative** : Si Paul n'a pas 1Password Connect, il faudra soit :
- Remplacer par **Doppler** (utilisé dans son autre projet kubernetes-pulumi)
- Créer les secrets Kubernetes manuellement

### Cloudflare
- Token API avec permissions **Zone:DNS:Edit** sur `smadja.dev`
- Stocké dans 1Password vault "cloudflare" → propriété `CLOUDFLARE_API_TOKEN`

### OVH (pour cert-manager DNS01)
- Le ClusterIssuer utilise le webhook OVH pour la validation DNS Let's Encrypt
- Nécessite un secret `ovh-issuer-secret` avec : `applicationKey`, `applicationSecret`, `consumerKey`
- Ces credentials viennent probablement de 1Password aussi

### Talos
- Secrets Talos dans `kubernetes/talos/secrets.yaml` (tokens, CA, etc.)
- Les `op://` dans machineconfig.yaml.j2 sont résolus via l'outil `just template`

---

## Architecture des composants

### Chaîne de boot (helmfile `01-apps.yaml`)
```
cilium → coredns → spegel → cert-manager-webhook-ovh → cert-manager → external-secrets → onepassword-connect → flux-operator → flux-instance
```

### Flux GitOps
Une fois Flux déployé, il réconcilie `kubernetes/apps/` via `kubernetes/flux/cluster/cluster.yaml`.

⚠️ **CRITIQUE** : Le flux-instance pointe actuellement vers le repo **bjw-s** :
```yaml
sync:
  url: https://github.com/bjw-s-labs/home-ops.git
  ref: refs/heads/main
  path: kubernetes/flux/cluster
```
→ **Doit être changé** vers le repo de Paul.

### Exposition des services
- **Envoy Gateway** : 2 Gateways (external `10.1.6.41`, internal `10.1.6.42`) — ces IPs doivent être adaptées
- **External-DNS** : sync des HTTPRoutes vers Cloudflare
- **Cert-Manager** : wildcard `*.smadja.dev` via Let's Encrypt + OVH DNS01

---

## Plan d'implémentation

### Phase 0 — Configuration Talos Single-Node

#### 0.1 Créer le fichier node
**Fichier** : `kubernetes/talos/nodes/homelab.yaml.j2` (nouveau)

```yaml
---
machine:
  install:
    diskSelector:
      # ADAPTER: modèle du disque du serveur Proxmox
      model: "QEMU HARDDISK"  # ou le vrai disque passthrough
  type: controlplane
---
apiVersion: v1alpha1
kind: HostnameConfig
hostname: homelab
---
apiVersion: v1alpha1
kind: LinkAliasConfig
name: net0
selector:
    # ADAPTER: driver et MAC de la NIC de la VM
    match: link.driver == "virtio_net"  # ou le bon driver
```

**Action** : Identifier le driver et MAC via `talosctl get links -n 192.168.68.58`

#### 0.2 Adapter machineconfig.yaml.j2

**Changements requis dans** `kubernetes/talos/machineconfig.yaml.j2` :

| Section | Avant (bjw-s) | Après (single-node) |
|---------|---------------|---------------------|
| `cluster.controlPlane.endpoint` | `https://10.1.6.50:6443` | `https://192.168.68.58:6443` |
| `cluster.apiServer.certSANs` | `10.1.6.50`, `k8s.bjw-s.internal` | `192.168.68.58`, `k8s.smadja.dev` |
| `kubelet.nodeIP.validSubnets` | `10.1.1.0/24` | `192.168.68.0/24` |
| `etcd.advertisedSubnets` | `10.1.1.0/24` | `192.168.68.0/24` |
| BondConfig (lignes 178-183) | bond0 active-backup MTU 9000 | **Supprimer** — utiliser la NIC directement |
| DHCPv4Config (lignes 188-189) | bond0 | **Supprimer** ou adapter si DHCP voulu |
| VLANConfig IoT 303 (lignes 191-196) | bond0.303 | **Supprimer** |
| VLANConfig VPN 305 (lignes 198-205) | bond0.305 | **Supprimer** |
| WatchdogTimerConfig (207-209) | /dev/watchdog0 | **Garder** ou supprimer si VM |
| kernel.modules thunderbolt | nbd, thunderbolt | Garder nbd, **supprimer thunderbolt** (VM) |
| vm.nr_hugepages | 1024 | Réduire ou supprimer selon RAM dispo |

**Réseau simplifié** — remplacer tout le bloc Bond+VLAN+DHCP par :
```yaml
---
apiVersion: v1alpha1
kind: DHCPv4Config
name: net0
clientIdentifier: mac
```

Ou si IP statique préférée (recommandé pour un serveur) :
```yaml
---
apiVersion: v1alpha1
kind: StaticAddressConfig
name: net0
addresses:
  - 192.168.68.58/24
gateway: 192.168.68.1
```

#### 0.3 Supprimer les nodes inutiles
- Supprimer `nodes/delta.yaml.j2`, `nodes/enigma.yaml.j2`, `nodes/felix.yaml.j2`
- Ou les garder et ne pas les appliquer

---

### Phase 1 — Cilium (CNI) — VERROU PRINCIPAL

#### 1.1 Vérifier le nom d'interface réseau
```bash
talosctl get links -n 192.168.68.58
```
Identifier l'interface principale (probablement `eth0`, `enp0s18`, ou `ens18` selon Proxmox).

#### 1.2 Adapter helmrelease.yaml
**Fichier** : `kubernetes/apps/kube-system/cilium/app/helmrelease.yaml`

Changements :
```yaml
# Adapter si l'interface n'est pas eth0
devices: eth0           # ← résultat de 1.1
directRoutingDevice: eth0  # ← résultat de 1.1

# Activer L2 Announcements (remplacement du BGP pour single-node)
l2announcements:
  enabled: true     # ← actuellement false

# Garder BGP désactivé
bgpControlPlane:
  enabled: false    # ← déjà fait
```

#### 1.3 Remplacer la config réseau L3/BGP par L2
**Fichier** : `kubernetes/apps/kube-system/cilium/config/l3.yaml`

**Supprimer tout le contenu** (BGP advertisement, peer config, cluster config, service kube-api) et remplacer par :

```yaml
---
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: l2-policy
spec:
  interfaces:
    - ^eth0$   # ← adapter selon l'interface réelle
  externalIPs: true
  loadBalancerIPs: true
```

**Fichier** : `kubernetes/apps/kube-system/cilium/config/pool.yaml`

Adapter le pool d'IPs LoadBalancer :
```yaml
apiVersion: cilium.io/v2
kind: CiliumLoadBalancerIPPool
metadata:
  name: pool
spec:
  allowFirstLastIPs: "Yes"
  blocks:
    - start: 192.168.68.200
      stop: 192.168.68.250
      # ← adapter au range libre sur le réseau 192.168.68.0/24
```

**Fichier** : `kubernetes/apps/kube-system/cilium/config/kustomization.yaml`

Garder les deux resources mais renommer l3.yaml en l2.yaml (optionnel, cosmétique) :
```yaml
resources:
  - ./l2.yaml   # anciennement l3.yaml
  - ./pool.yaml
```

#### 1.4 Adapter le hook postsync du bootstrap
**Fichier** : `kubernetes/bootstrap/helmfile.d/01-apps.yaml`

Le hook attend les CRDs BGP. Changer pour attendre les CRDs L2 :
```yaml
hooks:
  - command: bash
    args:
      - -c
      - until kubectl get crd ciliumloadbalancerippools.cilium.io ciliuml2announcementpolicies.cilium.io &>/dev/null; do sleep 5; done
    events:
      - postsync
```

Et adapter le kubectl apply pour pointer vers le bon fichier config.

#### 1.5 Validation
```bash
cilium status
kubectl get ciliumloadbalancerippools
kubectl get ciliuml2announcementpolicies
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium
```

---

### Phase 2 — CoreDNS

**Fichier** : `kubernetes/apps/kube-system/coredns/app/helmrelease.yaml`

Changement : réduire les replicas pour single-node :
```yaml
replicaCount: 1   # ← actuellement 2
```

**Validation** :
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl run -it --rm debug --image=busybox:1.36 --restart=Never -- nslookup kubernetes.default
```

---

### Phase 3 — Storage

#### 3.1 Désactiver Rook-Ceph
Rook-Ceph est inutile en single-node (réplication x3 sur un seul host = gaspillage).

**Fichier** : `kubernetes/apps/kustomization.yaml`

Commenter ou supprimer la ligne :
```yaml
# - rook-ceph   ← désactivé pour single-node
```

#### 3.2 Promouvoir OpenEBS comme storage par défaut
**Fichier** : `kubernetes/apps/openebs/openebs/app/helmrelease.yaml`

```yaml
hostpathClass:
  enabled: true
  name: openebs-hostpath
  basePath: /var/mnt/local-hostpath
  isDefaultClass: true    # ← changer de false à true
```

#### 3.3 Adapter les PVCs des apps
Toutes les apps qui utilisent `storageClassName: ceph-block` doivent être changées en `openebs-hostpath`.

**Rechercher** :
```bash
grep -r "ceph-block\|ceph-filesystem" kubernetes/apps/ --include="*.yaml" -l
```

Chaque fichier trouvé doit être mis à jour : `storageClassName: openebs-hostpath`

⚠️ **Note** : `ceph-filesystem` (ReadWriteMany) n'a pas d'équivalent direct avec OpenEBS hostpath (ReadWriteOnce uniquement). Pour les apps qui ont besoin de RWX, envisager NFS ou accepter RWO en single-node.

---

### Phase 4 — Secrets (1Password Connect)

#### Option A : Garder 1Password Connect (recommandé si compte 1Password existant)

1. Créer les entries dans 1Password :
   - Vault **"Automation"** : entry "1password connect" avec `credentials` (JSON) et `token`
   - Vault **"Automation"** : entry "talos" avec tous les `MACHINE_*` et `CLUSTER_*` secrets
   - Vault **"cloudflare"** : entry avec `CLOUDFLARE_API_TOKEN`
   - Vault (à déterminer) : entry "ovh-issuer-secret" avec `applicationKey`, `applicationSecret`, `consumerKey`

2. Bootstrap les secrets :
```bash
# Le Justfile fait ça automatiquement via `just resources`
# Mais manuellement :
op inject -i kubernetes/bootstrap/resources.yaml.j2 | kubectl apply --server-side -f -
```

#### Option B : Remplacer par des secrets Kubernetes manuels

Si pas de 1Password, créer les secrets directement :

```bash
# Cloudflare token pour external-dns
kubectl create secret generic external-dns-secret \
  -n network \
  --from-literal=api-token=<CF_API_TOKEN>

# OVH credentials pour cert-manager
kubectl create secret generic ovh-issuer-secret \
  -n cert-manager \
  --from-literal=applicationKey=<OVH_APP_KEY> \
  --from-literal=applicationSecret=<OVH_APP_SECRET> \
  --from-literal=consumerKey=<OVH_CONSUMER_KEY>
```

Et désactiver onepassword-connect dans le bootstrap :
- Retirer de `01-apps.yaml`
- Retirer de `kubernetes/apps/external-secrets/kustomization.yaml`

⚠️ **Impact** : Toutes les `ExternalSecret` du repo devront être remplacées par des secrets manuels ou un autre provider (Doppler).

#### Option C : Remplacer par Doppler (cohérent avec kubernetes-pulumi)

Changer le ClusterSecretStore pour utiliser le provider Doppler :
```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: doppler
spec:
  provider:
    doppler:
      auth:
        secretRef:
          dopplerToken:
            name: doppler-token
            key: token
            namespace: external-secrets
```

Et adapter toutes les ExternalSecret pour pointer vers Doppler au lieu de 1Password.

---

### Phase 5 — Cert-Manager & TLS

**Aucun changement requis** si les credentials OVH sont disponibles.

Le ClusterIssuer utilise OVH DNS01 pour valider `*.smadja.dev` via Let's Encrypt.

**Validation** :
```bash
kubectl get clusterissuers
kubectl get certificates -A
kubectl describe certificate smadja.dev -n network
```

---

### Phase 6 — Flux Instance

#### 6.1 Changer l'URL du repo Git
**Fichier** : `kubernetes/apps/flux-system/flux-instance/app/helmrelease.yaml`

```yaml
sync:
  kind: GitRepository
  url: https://github.com/<PAUL_GITHUB_USER>/homelab.git  # ← repo de Paul
  ref: refs/heads/main
  path: kubernetes/flux/cluster
```

⚠️ **CRITIQUE** : Sans ce changement, Flux va réconcilier depuis le repo bjw-s original.

#### 6.2 Vérifier le repo est accessible
Si repo privé, ajouter un secret Git :
```bash
kubectl create secret generic flux-system \
  -n flux-system \
  --from-literal=username=git \
  --from-literal=password=<GITHUB_PAT>
```

---

### Phase 7 — Envoy Gateway & Exposition

#### 7.1 Adapter les IPs LoadBalancer des Gateways
**Fichier** : `kubernetes/apps/network/envoy-gateway/gateway/external.yaml`
```yaml
infrastructure:
  annotations:
    lbipam.cilium.io/ips: 192.168.68.201  # ← IP dans le pool Cilium
```

**Fichier** : `kubernetes/apps/network/envoy-gateway/gateway/internal.yaml`
```yaml
infrastructure:
  annotations:
    lbipam.cilium.io/ips: 192.168.68.202  # ← IP dans le pool Cilium
```

#### 7.2 Réduire les replicas Envoy
**Fichier** : `kubernetes/apps/network/envoy-gateway/gateway/envoy.yaml`
```yaml
envoyDeployment:
  replicas: 1   # ← actuellement 2
```

#### 7.3 Adapter External-DNS targets
Les annotations `external-dns.alpha.kubernetes.io/target` dans les gateways pointent vers `ingress-ext.smadja.dev` et `ingress-int.smadja.dev`.

Il faut que ces DNS records pointent vers les bonnes IPs (celles du pool Cilium) ou vers l'IP du serveur directement.

---

### Phase 8 — Désactiver les apps non essentielles

**Fichier** : `kubernetes/apps/kustomization.yaml`

Pour le déploiement initial, ne garder que l'infrastructure de base :

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  # P0 — Infrastructure
  - cert-manager
  - external-secrets
  - kube-system
  - openebs
  # P1 — Réseau & Observabilité
  - network
  - observability
  # P2 — Système
  - system
  # Désactivés pour le déploiement initial :
  # - actions-runner-system
  # - ai
  # - downloads
  # - home-automation
  # - jobs
  # - kguardian
  # - media
  # - renovate
  # - rook-ceph
  # - security
  # - selfhosted
  # - system-upgrade
```

Réactiver progressivement une fois l'infra stable.

---

### Phase 9 — Adaptations des composants système

#### 9.1 Spegel (registry mirror)
Inutile en single-node (le cache d'images local suffit). Peut être désactivé dans `kube-system/kustomization.yaml`.

#### 9.2 Descheduler
Inutile en single-node (rien à rééquilibrer). Désactiver dans `system/kustomization.yaml`.

#### 9.3 External-Secrets webhook
**Fichier** : `kubernetes/apps/external-secrets/external-secrets/app/helmrelease.yaml`
```yaml
webhook:
  replicaCount: 1   # ← actuellement 2
```

#### 9.4 VolSync / Kopia
Le backup VolSync pointe vers `gladius.bjw-s.internal` (NAS bjw-s). Désactiver ou adapter vers un NAS local.

#### 9.5 Intel GPU Resource Driver
Supprimer de `kube-system/kustomization.yaml` si pas de GPU Intel dans la VM.

#### 9.6 Multus
Probablement inutile en single-node sans VLANs. Désactiver dans `network/kustomization.yaml`.

#### 9.7 Newt
Service spécifique à bjw-s. Désactiver dans `network/kustomization.yaml`.

---

## Ordre d'exécution

### Pré-bootstrap
```bash
# 1. Installer les outils requis
brew install talosctl helmfile kubectl just age sops

# 2. Vérifier la connexion au nœud Talos
talosctl -n 192.168.68.58 -e 192.168.68.58 version

# 3. Identifier l'interface réseau
talosctl -n 192.168.68.58 get links

# 4. Identifier le disque
talosctl -n 192.168.68.58 get disks
```

### Bootstrap
```bash
cd kubernetes-home-ops

# Si utilisation du Justfile (méthode bjw-s)
just bootstrap

# OU manuellement, étape par étape :

# 1. Appliquer la config Talos
talosctl apply-config -n 192.168.68.58 -e 192.168.68.58 \
  --file kubernetes/talos/clusterconfig/homelab.yaml

# 2. Bootstrap Kubernetes
talosctl bootstrap -n 192.168.68.58 -e 192.168.68.58

# 3. Récupérer kubeconfig
talosctl kubeconfig -n 192.168.68.58 -e 192.168.68.58 \
  --force-context-name home-ops .

# 4. Attendre que le nœud soit prêt (sera NotReady sans CNI)
kubectl get nodes

# 5. Créer les namespaces
find kubernetes/apps -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | \
  while read ns; do kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -; done

# 6. Appliquer les secrets bootstrap (1Password)
op inject -i kubernetes/bootstrap/resources.yaml.j2 | kubectl apply --server-side -f -

# 7. Installer les CRDs
helmfile -f kubernetes/bootstrap/helmfile.d/00-crds.yaml template -q | \
  yq ea 'select(.kind == "CustomResourceDefinition")' | \
  kubectl apply --server-side --field-manager bootstrap --force-conflicts -f -

# 8. Installer les apps (Cilium → ... → Flux)
helmfile -f kubernetes/bootstrap/helmfile.d/01-apps.yaml sync --hide-notes

# 9. Vérifier
kubectl get pods -A
cilium status
flux get all
```

### Post-bootstrap
```bash
# Vérifier Cilium
cilium status
kubectl get ciliumloadbalancerippools
kubectl get ciliuml2announcementpolicies

# Vérifier DNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Vérifier Flux
flux get kustomizations
flux get helmreleases -A

# Vérifier les certificats
kubectl get certificates -A
kubectl get clusterissuers

# Vérifier l'exposition
kubectl get svc -A --field-selector spec.type=LoadBalancer
curl -k https://192.168.68.201  # envoy-external
```

---

## Fichiers à modifier — Récapitulatif

| # | Fichier | Action | Priorité |
|---|---------|--------|----------|
| 1 | `talos/nodes/homelab.yaml.j2` | **Créer** | P0 |
| 2 | `talos/machineconfig.yaml.j2` | Supprimer bond/VLANs, adapter IPs/subnets | P0 |
| 3 | `cilium/app/helmrelease.yaml` | l2announcements=true, vérifier interface | P0 |
| 4 | `cilium/config/l3.yaml` | Remplacer BGP par L2AnnouncementPolicy | P0 |
| 5 | `cilium/config/pool.yaml` | Adapter IP range (192.168.68.x) | P0 |
| 6 | `cilium/config/kustomization.yaml` | Renommer référence l3→l2 | P0 |
| 7 | `bootstrap/helmfile.d/01-apps.yaml` | Adapter hook postsync CRDs | P0 |
| 8 | `coredns/app/helmrelease.yaml` | replicas: 1 | P1 |
| 9 | `flux-instance/app/helmrelease.yaml` | Changer URL repo Git | P0 |
| 10 | `apps/kustomization.yaml` | Désactiver apps non P0 | P1 |
| 11 | `envoy-gateway/gateway/external.yaml` | Adapter IP LB | P1 |
| 12 | `envoy-gateway/gateway/internal.yaml` | Adapter IP LB | P1 |
| 13 | `envoy-gateway/gateway/envoy.yaml` | replicas: 1 | P1 |
| 14 | `openebs/app/helmrelease.yaml` | isDefaultClass: true | P1 |
| 15 | `external-secrets/app/helmrelease.yaml` | webhook replicas: 1 | P2 |
| 16 | Tous les PVCs `ceph-block` | → `openebs-hostpath` | P2 |
| 17 | `rook-ceph` dans kustomization.yaml | Commenter/supprimer | P1 |

---

## Pièges connus

1. **Flux pointe vers le repo bjw-s** — Si non corrigé, Flux va écraser les changements locaux
2. **Les ExternalSecrets dépendent de 1Password** — Si pas configuré, aucun secret ne sera créé → les apps crashent
3. **Cert-manager webhook OVH** — Nécessite les credentials OVH, sinon pas de certificats TLS
4. **VolSync backup** pointe vers `gladius.bjw-s.internal` — Un NAS qui n'existe pas sur ce réseau
5. **Cilium ipv4NativeRoutingCIDR** est `10.244.0.0/16` — C'est le CIDR des pods, c'est correct, ne pas changer
6. **k8sServiceHost: 127.0.0.1 / k8sServicePort: 7445** — C'est KubePrism (proxy local Talos), correct pour single-node
7. **Le pool Cilium LB** (`pool.yaml`) doit utiliser des IPs **non utilisées** sur le réseau — vérifier les baux DHCP du routeur
8. **allowSchedulingOnControlPlanes: true** — Déjà activé, nécessaire pour single-node
