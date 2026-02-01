# Terraform State Management — Bonnes pratiques Homelab

Ce document centralise les pratiques de gestion du state Terraform pour le homelab (OCI, Cloudflare, OVHcloud, Proxmox).

## 1. Remote State (backend distant)

- **Objectif** : State stocké dans un backend distant (OCI Object Storage, TFstate.dev, etc.), pas en local uniquement.
- **Bénéfices** : Collaboration, pas de corruption par écriture locale seule, versioning/backups côté backend.
- **Homelab** :
  - **OCI** : backend `oci` → bucket `homelab-tfstate` (voir [terraform/oracle-cloud/README.md](../terraform/oracle-cloud/README.md)).
  - **Cloudflare / OVHcloud** : TFstate.dev ou backends dédiés selon config dans chaque `backend.tf`.

## 2. State Locking

- **Objectif** : Une seule écriture concurrente sur le state (éviter conflits et perte de données).
- **Homelab** :
  - Backend OCI : verrouillage natif (headers OCI).
  - CI : `concurrency` par workflow (une run Terraform OCI à la fois).
  - Ne pas utiliser `-lock=false` en prod sauf contournement temporaire documenté.

## 3. State Isolation (environnements / composants)

- **Objectif** : Séparer les states par environnement (dev/staging/prod) ou par composant (réseau, compute, storage) pour limiter le blast radius.
- **Homelab** :
  - **Workspaces** : `terraform workspace new dev`, `terraform workspace select prod` (même backend, préfixe dans le key).
  - **Key par env** : `-backend-config="key=oracle-cloud/prod/terraform.tfstate"` pour un state prod dédié.
  - **Modules séparés** : `terraform/oracle-cloud`, `terraform/cloudflare`, etc. ont chacun leur state (backend config par répertoire).

## 4. Éviter les données sensibles dans le state

- **Objectif** : Pas de mots de passe, clés API ou données personnelles en clair dans le state (il est stocké en remote).
- **Pratiques** :
  - Variables contenant des secrets ou données personnelles : `sensitive = true` dans `variables.tf`.
  - Ne pas commiter `terraform.tfvars` avec des secrets ; utiliser `TF_VAR_*` ou un secret manager (GitHub Secrets, Vault).
  - Outputs sensibles : `sensitive = true` (ex. `velero_s3_credentials`).

## 5. Gestion du state via la CLI uniquement

- **Objectif** : Ne jamais éditer le fichier state à la main (JSON) ; utiliser les commandes Terraform.
- **Commandes utiles** :
  - `terraform state show <resource>` — inspecter une ressource.
  - `terraform state rm <resource>` — retirer une ressource du state (sans détruire l’objet en cloud).
  - `terraform state mv <src> <dst>` — déplacer/renommer dans le state.
  - `terraform refresh` — mettre le state en phase avec l’infra réelle.
- **À ne pas faire** : Ouvrir/éditer le fichier state (`.tfstate`) manuellement.

## 6. CI/CD et state

- **Objectif** : Plan/apply automatisés, traçabilité, rollback possible.
- **Homelab** : GitHub Actions (terraform-oci, terraform-cloudflare, terraform-ovhcloud) ; state partagé avec le backend configuré dans chaque workflow ; concurrency pour éviter deux writes simultanés.

## 7. Backups et récupération

- **Objectif** : Pouvoir restaurer un state précédent en cas d’erreur ou de corruption.
- **Homelab OCI** :
  - Versioning activé sur le bucket `homelab-tfstate` ; les anciennes versions de l’objet state sont conservées.
  - **Récupération** : OCI Console → Object Storage → bucket → objet state → onglet Versions ; télécharger la version voulue. Puis soit remplacer l’objet courant, soit utiliser `terraform state push` avec précaution (voir [terraform/oracle-cloud/README.md](../terraform/oracle-cloud/README.md)#récupération-du-state).
- **Tester** : Périodiquement vérifier qu’une ancienne version du state est bien listée et téléchargeable.

## Références

- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/settings/backends/configuration)
- [Backend Type: oci](https://developer.hashicorp.com/terraform/language/backend/oci)
- [terraform/oracle-cloud/README.md](../terraform/oracle-cloud/README.md) — State management OCI
