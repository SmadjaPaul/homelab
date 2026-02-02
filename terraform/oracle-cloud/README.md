# Terraform Oracle Cloud (OCI) — Homelab

Provisionne la VM management (Omni, Authentik, Cloudflare Tunnel) et optionnellement les nœuds Kubernetes sur Oracle Cloud. Story **1.3.1** (management VM), Epic 1.3.

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

   Le state est stocké dans un bucket OCI `homelab-tfstate` (Always Free). Le backend OCI utilise la même auth que le provider (`~/.oci/config` ou env `OCI_CLI_*`). Le **namespace** tenancy doit être défini dans `backend.tf` (le backend `oci` n'accepte pas `namespace` via `-backend-config`) :

   - Dans `terraform/oracle-cloud/backend.tf`, remplacer `YOUR_TENANCY_NAMESPACE` par le namespace de ton tenancy.
   - Après un premier apply (ou avec un state existant) : `terraform output -json | jq -r '.tfstate_bucket.value.namespace'`.
   - En CI : le workflow injecte le namespace depuis le secret `OCI_OBJECT_STORAGE_NAMESPACE`.
   - En local : `./init-local.sh <namespace>` ou `OCI_OBJECT_STORAGE_NAMESPACE=<ns> ./init-local.sh` (injecte le namespace puis `terraform init -reconfigure`).

   ```bash
   # Terraform 1.11+ requis pour le backend "oci"
   terraform init -reconfigure
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
| OCI Vault        | KMS Vault `homelab-secrets-vault` + secrets (Cloudflare, Omni, SSH, etc.) pour la CI |

## OCI Vault (secrets pour la CI)

Un **Vault OCI** (KMS, type DEFAULT = virtual vault + software keys, gratuit) et une clé maître sont créés. Les secrets sont stockés dans le Vault si tu fournis les variables (vides = secret non créé). **Limites Free Tier** : Secret Management gratuit ; 5 000 secrets / tenancy, 30 versions actives / secret, 64 KB max / secret.

**En local** : fournir les valeurs via **variables d'environnement** (ex. `.env`). Terraform lit `TF_VAR_vault_secret_*`. Ne jamais committer de valeurs réelles.

**Exemple** (valeurs via variables d’environnement, jamais committées) :

```bash
# Option 1 : .env avec TF_VAR_* (source avant terraform)
set -a && source .env && set +a
terraform apply
```

```bash
# Option 2 : mapper tes noms .env vers TF_VAR
export TF_VAR_vault_secret_cloudflare_api_token="${CLOUDFLARE_API_TOKEN:-}"
export TF_VAR_vault_secret_omni_db_user="${OMNI_DB_USER:-omni}"
export TF_VAR_vault_secret_omni_db_password="${OMNI_DB_PASSWORD:-}"
export TF_VAR_vault_secret_omni_db_name="${OMNI_DB_NAME:-omni}"
terraform apply
```

**En CI** : les workflows définissent `TF_VAR_vault_secrets_managed_in_ci=true`. Le contenu des secrets n'est ni mis à jour ni détruit quand les variables sont vides (`lifecycle { ignore_changes = [secret_content] }`).

**Récupérer les secrets** (CLI OCI) : `terraform output vault_secrets` donne les OCID ; `oci secrets secret-bundle get --secret-id <ocid>` pour le contenu.

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
4. Dans `backend.tf`, remplacer `YOUR_TENANCY_NAMESPACE` par ce namespace, puis `terraform init -reconfigure` et `terraform init -migrate-state` pour copier le state HTTP → OCI.
5. En CI : le workflow injecte le namespace depuis `OCI_OBJECT_STORAGE_NAMESPACE` avant chaque `terraform init`.

## Références

- [Epic 1.3](_bmad-output/planning-artifacts/epics-and-stories-homelab.md) — Omni Cluster Management
- [next-steps OCI + Omni](../../_bmad-output/implementation-artifacts/next-steps-oci-mgmt-and-omni.md)
- [Décisions et limites (state Terraform)](../../docs-site/docs/advanced/decisions-and-limits.md) — Bonnes pratiques state (remote, locking, backups, isolation)
