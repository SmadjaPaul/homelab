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

2. **Lancer Terraform**

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Récupérer l’IP et SSH**

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
| Object Storage   | Bucket Velero (backups) |

## Suite (Story 1.3.2)

Une fois la VM en place : déployer la stack Omni avec `docker/oci-mgmt/` (voir [docker/oci-mgmt/README.md](../../docker/oci-mgmt/README.md) et [next-steps-oci-mgmt-and-omni.md](../../_bmad-output/implementation-artifacts/next-steps-oci-mgmt-and-omni.md)).

## Références

- [Epic 1.3](_bmad-output/planning-artifacts/epics-and-stories-homelab.md) — Omni Cluster Management
- [next-steps OCI + Omni](../../_bmad-output/implementation-artifacts/next-steps-oci-mgmt-and-omni.md)
