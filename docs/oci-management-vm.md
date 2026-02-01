# OCI Management VM (Story 1.3.1)

VM Oracle Cloud pour Omni, Keycloak et services de management. Définie et déployée via Terraform dans `terraform/oracle-cloud/`.

## Spécifications (Story 1.3.1)

| Critère | Implémentation |
|--------|-----------------|
| VM OCI | 1 OCPU, 6 GB RAM, 50 GB disque (Always Free ARM: `VM.Standard.A1.Flex`) |
| OS | Ubuntu 24.04 (image Canonical) |
| Docker | Installé par cloud-init au premier boot |
| IP publique | **Réservée** (statique) — `oci_core_public_ip.management` |
| SSH | Clé uniquement (`ssh_authorized_keys` dans les métadonnées) |

## Prérequis

- Compte OCI, compartment OCID, clé API (voir [setup-oci-cicd.md](setup-oci-cicd.md))
- `terraform.tfvars` rempli : `compartment_id`, `ssh_public_key`, `budget_alert_email`, `user_ocid`

## Déploiement

```bash
cd terraform/oracle-cloud
terraform init
terraform plan
terraform apply
```

**Note** : En région Always Free (ex. `eu-paris-1`), la capacité ARM est souvent saturée (« Out of host capacity »). Options :

- Relancer `terraform apply` à intervalles (ex. `scripts/oci-capacity-retry.sh`)
- Créer uniquement la VM management en mettant `k8s_nodes = []` dans `terraform.tfvars` pour réduire la demande

## Après apply

- **IP publique** : `terraform output management_vm` → `public_ip` (IP réservée, stable)
- **SSH** : `ssh -i ~/.ssh/oci-homelab ubuntu@<public_ip>` (ou la commande affichée dans `terraform output ssh_connection_commands`)
- **Docker** : déjà installé par cloud-init ; répertoires `/opt/homelab/{omni,keycloak,cloudflared,nginx}` créés

## Suite (Epic 1.3)

- **1.3.2** : Déployer Omni sur cette VM (Docker Compose dans `docker/oci-mgmt/`)
- **1.3.3** : Enregistrer le cluster DEV dans Omni
- **1.3.4** : Configurer les MachineClasses dans `omni/machine-classes/`
