# Terraform Oracle Cloud (OCI) — Homelab

Provisionne la VM management (Omni, Keycloak, Cloudflare Tunnel) et optionnellement les nœuds Kubernetes sur Oracle Cloud. Story **1.3.1** (management VM), Epic 1.3.

## Prérequis

- Compte OCI avec accès au compartment cible
- [CLI OCI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm) et config `~/.oci/config` (profil `DEFAULT` ou variable `TF_VAR_*`)
- Clé SSH (ex. `ssh-keygen -t ed25519 -f ~/.ssh/oci-homelab`)

## Déploiement

1. **Copier et remplir les variables**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

   Renseigner au minimum :
   - `compartment_id` — OCID du compartment (Console OCI → Identity → Compartments)
   - `ssh_public_key` — contenu de `~/.ssh/oci-homelab.pub`
   - `budget_alert_email` — email pour les alertes budget (1 EUR)
   - `user_ocid` — OCID de l’utilisateur OCI (pour la clé S3 Velero)

2. **Backend (state OCI Object Storage)**

   Le state est stocké dans un bucket OCI `homelab-tfstate` (Always Free). Le backend OCI utilise la même auth que le provider (`~/.oci/config` ou env `OCI_CLI_*`). Le **namespace** tenancy est requis à l’init :

   ```bash
   # Récupérer le namespace (après 1er apply ou depuis output existant)
   NAMESPACE=$(terraform output -json 2>/dev/null | jq -r '.tfstate_bucket.value.namespace // empty')
   # Si vide : faire un apply avec backend http une fois pour créer le bucket (voir Migration ci-dessous)

   terraform init -reconfigure -backend-config="namespace=$NAMESPACE"
   ```

3. **Lancer Terraform**

   ```bash
   terraform plan
   terraform apply
   ```

4. **Récupérer l’IP et SSH**

   ```bash
   terraform output management_vm
   terraform output ssh_connection_commands
   ```

   Connexion à la VM management :
   ```bash
   ssh -i ~/.ssh/oci-homelab ubuntu@<public_ip>
   ```

## Ressources créées

| Ressource        | Rôle |
|------------------|------|
| VCN + subnet     | Réseau public |
| VM management    | 1 OCPU, 6 GB RAM, 50 GB — Ubuntu 24.04, Docker + Docker Compose (cloud-init) |
| IP publique      | IP réservée (statique) pour la VM management |
| (Optionnel)      | Nœuds K8s (voir `variables.tf` / `k8s_nodes`) |
| Budget + alertes | 1 EUR/mois, alertes à 50 %, 80 %, 100 % |
| Object Storage   | Bucket `homelab-tfstate` (state Terraform), bucket Velero (backups) |

## Suite (Story 1.3.2)

Une fois la VM en place : déployer la stack Omni avec `docker/oci-mgmt/` (voir [docker/oci-mgmt/README.md](../../docker/oci-mgmt/README.md) et [next-steps-oci-mgmt-and-omni.md](../../_bmad-output/implementation-artifacts/next-steps-oci-mgmt-and-omni.md)).

## State management (bonnes pratiques)

| Pratique | Implémentation |
|----------|----------------|
| **Remote state** | Backend OCI Object Storage (bucket `homelab-tfstate`), pas de state local par défaut. Collaboration et cohérence local/CI. |
| **State locking** | Verrouillage natif du backend OCI (headers) — une seule écriture à la fois. Concurrency sur le workflow CI en plus. |
| **Versioning / backups** | Versioning activé sur le bucket ; les anciennes versions du state sont conservées. Voir [Récupération du state](#récupération-du-state) en cas d’erreur. |
| **State isolation** | Workspaces : `terraform workspace new dev` / `terraform workspace select prod`. Ou key par env : `-backend-config="key=oracle-cloud/prod/terraform.tfstate"`. Pour la prod, un backend/key dédié est préférable. |
| **Pas de secrets dans le state** | Variables sensibles : `sensitive = true` (ex. `ssh_public_key`, `budget_alert_email`). Ne pas mettre de mots de passe / clés dans `terraform.tfvars` versionné ; utiliser `TF_VAR_*` ou un secret manager. |
| **State en CLI uniquement** | Utiliser `terraform state show`, `terraform state rm`, `terraform state mv`, `terraform refresh` — ne jamais éditer le fichier state à la main. |
| **CI/CD** | Plan/apply/destroy via GitHub Actions ; concurrency par workflow ; state partagé OCI. |

### Récupération du state

En cas de state corrompu ou de rollback :

1. **OCI Console** : Object Storage → bucket `homelab-tfstate` → objet `oracle-cloud/terraform.tfstate` → onglet **Versions**.
2. Télécharger la version voulue, puis la remettre en place (remplacer l’objet courant) ou utiliser `terraform state push` avec le fichier récupéré (à utiliser avec précaution).
3. **CLI OCI** : `oci os object list --bucket-name homelab-tfstate --prefix oracle-cloud/` puis `oci os object get` avec `--version-id` si besoin.

## Migration depuis tfstate.dev (HTTP)

Si tu passais par tfstate.dev et que le bucket OCI n’existe pas encore :

1. Appliquer une fois avec le backend HTTP pour créer le bucket :
   - Restaurer temporairement un `backend.tf` avec `backend "http"` (voir doc tfstate.dev) ou utiliser un override.
   - `terraform init -reconfigure` puis `terraform apply`.
2. Récupérer le namespace : `terraform output -json | jq -r '.tfstate_bucket.value.namespace'`.
3. Ajouter le secret GitHub **OCI_OBJECT_STORAGE_NAMESPACE** (valeur = namespace).
4. Remettre le backend OCI (ce repo) : `terraform init -reconfigure -backend-config="namespace=<namespace>"` puis `terraform init -migrate-state` pour copier le state HTTP → OCI.
5. En CI : le workflow utilise déjà `OCI_OBJECT_STORAGE_NAMESPACE` pour l’init.

## Références

- [Epic 1.3](_bmad-output/planning-artifacts/epics-and-stories-homelab.md) — Omni Cluster Management
- [next-steps OCI + Omni](../../_bmad-output/implementation-artifacts/next-steps-oci-mgmt-and-omni.md)
- [docs/terraform-state-management.md](../../docs/terraform-state-management.md) — Bonnes pratiques state (remote, locking, backups, isolation)
