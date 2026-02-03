# Prochaines étapes : VM OCI + stack docker/oci-mgmt (Stories 1.3.1 & 1.3.2)

**Date** : 2026-02-01  
**Contexte** : Suite à la revue des décisions identité (invitation-only, Cloudflare). Prochaine étape logique = créer la VM management sur Oracle Cloud puis tester l’IaC `docker/oci-mgmt` (Omni).

**Références** : Epic 1.3 (Omni Cluster Management), [epics-and-stories-homelab.md](../planning-artifacts/epics-and-stories-homelab.md), [implementation-progress.md](../planning-artifacts/implementation-progress.md).

---

## 1. Séquence recommandée

| Étape | Story | Action |
|-------|--------|--------|
| **1** | **1.3.1** Provision Oracle Cloud Management VM | Créer la VM avec Terraform `terraform/oracle-cloud/` |
| **2** | **1.3.2** Deploy Omni Server | Déployer la stack `docker/oci-mgmt/` sur la VM (Omni + PostgreSQL) |

---

## 2. Story 1.3.1 — Créer la VM OCI

### Prérequis

- Compte OCI, compartment OCID, clé SSH pour OCI
- Fichier `terraform/oracle-cloud/terraform.tfvars` rempli (voir `terraform.tfvars.example`) :
  - `compartment_id`
  - `ssh_public_key`
  - `budget_alert_email`

### Commandes

```bash
cd terraform/oracle-cloud
terraform init
terraform plan
terraform apply
```

**Capacité ARM OCI** : En région Always Free (ex. `eu-paris-1`), l’erreur « Out of host capacity » est fréquente. Options :

- Relancer `terraform apply` à intervalles
- Utiliser le script `scripts/oci-capacity-retry.sh` s’il existe
- Créer **uniquement** la VM management en mettant `k8s_nodes = []` dans `terraform.tfvars` pour réduire la demande

### Après apply réussi

- **IP publique** : `terraform output management_vm` → champ `public_ip`
- **SSH** : `terraform output ssh_connection_commands` → `management` (ex. `ssh -i ~/.ssh/oci-homelab ubuntu@<public_ip>`)
- **Sur la VM** : Docker et Docker Compose déjà installés par cloud-init ; répertoires `/opt/homelab/{omni,authentik,cloudflared,nginx}` créés

**Doc** : voir `docs-site/docs/advanced/architecture.md` et `terraform/oracle-cloud/README.md` pour la VM management.

---

## 3. Story 1.3.2 — Tester l’IaC docker/oci-mgmt (Omni)

### Prérequis

- VM OCI opérationnelle (1.3.1)
- Accès SSH : `ssh -i ~/.ssh/oci-homelab ubuntu@<management_public_ip>`

### Déploiement

1. **Copier le dossier `docker/oci-mgmt` vers la VM** (depuis ta machine) :

   ```bash
   scp -i ~/.ssh/oci-homelab -r docker/oci-mgmt ubuntu@<management_public_ip>:~/homelab/
   ```

2. **Sur la VM**, créer le fichier `.env` :

   ```bash
   ssh -i ~/.ssh/oci-homelab ubuntu@<management_public_ip>
   cd ~/homelab/oci-mgmt
   cat > .env << 'EOF'
   OMNI_DB_USER=omni
   OMNI_DB_PASSWORD=<mot_de_passe_fort>
   OMNI_DB_NAME=omni
   EOF
   ```

3. **Lancer la stack** :

   ```bash
   docker compose up -d
   ```

4. **Vérifier** : Omni écoute sur le port 8080 ; en production, mettre un reverse proxy HTTPS devant (voir [docker/oci-mgmt/README.md](../../docker/oci-mgmt/README.md)).

### Critères d’acceptation (Story 1.3.2)

- [ ] Omni container running
- [ ] PostgreSQL configuré et healthy
- [ ] Omni accessible (HTTP sur `http://<public_ip>:8080` pour le test ; HTTPS à ajouter plus tard)
- [ ] Compte admin initial créé (selon doc Sidero self-hosted)

**Doc** : [docker/oci-mgmt/README.md](../../docker/oci-mgmt/README.md), [Omni self-hosted](https://omni.siderolabs.com/how-to-guides/self_hosted/).

---

## 4. Suite après 1.3.1 + 1.3.2

- **1.3.3** : Enregistrer le cluster DEV dans Omni (join token)
- **1.3.4** : Configurer les MachineClasses dans `omni/machine-classes/`
- **Epic 3.3** (Authentik) : plus tard, Authentik pourra être ajouté dans `docker/oci-mgmt/` (ou un stack dédié) ; design invitation-only + Cloudflare déjà décidé.

---

## 5. Mise à jour du suivi

Après 1.3.1 réussi : mettre à jour [implementation-progress.md](../planning-artifacts/implementation-progress.md) (1.3.1 = Done, Phase 3 = In Progress si plus bloqué par la capacité OCI).

Après 1.3.2 réussi : 1.3.2 = Done ; passer à 1.3.3 (Register DEV Cluster with Omni).
