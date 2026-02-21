# Guide de Déploiement

Ce guide détaille les étapes pour initialiser et maintenir votre infrastructure souveraine.

## 🚀 Bootstrap Initial

L'infrastructure se déploie en plusieurs phases pour respecter les dépendances critiques (notamment entre Omni, Talos et Authentik).

### Phase 0 : Prérequis locaux
- Installation des outils : `terraform`, `kubectl`, `helm`, `talosctl`, `doppler`, `flux`.
- Connexion Doppler : `doppler login`.

### Phase 1 : Cloud Core (Terraform)
1. **Setup Doppler** : Exécutez `./scripts/setup-doppler.sh` pour créer les projets.
2. **Secrets** : Remplissez les secrets critiques dans Doppler (OCI, Cloudflare).
3. **Provisioning** :
   ```bash
   cd terraform/oracle-cloud
   doppler run -- terraform init
   doppler run -- terraform apply
   ```
   *Ceci déploie les VMs OCI (Hub & Control Plane).*

### Phase 2 : Configuration Omni & Talos
1. **Omni UI** : Accédez à votre instance Omni (via l'IP de la VM Hub ou tunnel).
2. **Cluster Creation** : Créez un cluster dans Omni, générez l'image Talos.
3. **Talos Bootstrap** : Appliquez la configuration Talos sur les noeuds via Omni.
4. **Kubeconfig** : Récupérez le kubeconfig via Omni :
   ```bash
   omnictl kubeconfig -c cluster-name > ~/.kube/config
   ```

### Phase 3 : GitOps Bootstrap (Flux CD)
1. **Flux Install** :
   ```bash
   flux bootstrap github ...
   ```
2. **Secrets Sync** : Déployez **External Secrets Operator** pour lier Doppler à Kubernetes.

---

## 🏗️ Déploiement du Cluster Home (Proxmox)

Une fois le Hub Cloud stable :
1. **VMs Talos** : Créez vos VMs sur Proxmox (12 CPU / 64GB RAM).
2. **Omni Pairing** : Appairez ces nouveaux noeuds à votre instance Omni existante sur OCI.
3. **Storage** : Déployez votre VM TrueNAS et configurez les partages NFS/SMB pour le cluster Talos local.

---

## 🛠️ Maintenance Quotidienne

- **Secrets** : Toute modification se fait dans Doppler, ESO synchronise automatiquement.
- **Updates** : Renovate surveille les versions et propose des PRs automatiquement.
- **GitOps** : Toute modification des manifests dans `kubernetes/` est appliquée par Flux dans les minutes qui suivent.
