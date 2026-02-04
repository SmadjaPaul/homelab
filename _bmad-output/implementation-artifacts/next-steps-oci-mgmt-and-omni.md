# Prochaines étapes : VM OCI + stack docker/oci-mgmt (Stories 1.3.x)

**Date** : 2026-02-04 (mis à jour après déploiement CI réussi)  
**Contexte** : La VM OCI et la stack docker/oci-mgmt (Omni, Authentik, PostgreSQL, Cloudflared) sont déployées via GitHub Actions. Prochaines étapes = accès sécurisé (Tunnel) et enregistrement du cluster DEV dans Omni.

**Références** : Epic 1.3 (Omni Cluster Management), [epics-and-stories-homelab.md](../planning-artifacts/epics-and-stories-homelab.md), [implementation-progress.md](../planning-artifacts/implementation-progress.md).

---

## 1. État actuel (2026-02-04)

| Story | Statut | Détail |
|-------|--------|--------|
| **1.3.1** Provision OCI Management VM | ✅ Done | VM créée via Terraform, IP dans state |
| **1.3.2** Deploy Omni Server | ✅ Done | **CI** : `.github/workflows/deploy-oci-mgmt.yml` — push sur `docker/oci-mgmt/**` ou `ansible/**` déploie la stack (Omni, PostgreSQL, Authentik, Cloudflared) sur la VM |

## 2. Prochaines étapes recommandées

| Étape | Story | Action |
|-------|--------|--------|
| **3** | **1.3.3** Register DEV Cluster with Omni | Créer un join token dans Omni, installer l’agent sur le cluster DEV, vérifier dans l’UI Omni |
| **4** | **1.3.4** Configure MachineClasses | Définir les MachineClasses dans `omni/machine-classes/` |
| **5** | **3.4.1** Cloudflare Tunnel (accès HTTPS) | Exposer Omni/Authentik en HTTPS via ton domaine (Zero Trust) |

**Tunnel sur OCI** : Quand le tunnel (token Terraform Cloudflare ou manuel) tourne sur la VM OCI, seules les routes **auth** et **omni** (localhost:9000, localhost:8080) sont actives. Les autres hostnames (Grafana, ArgoCD, etc.) pointent vers des services K8s et nécessitent un cloudflared dans le cluster ou un second tunnel.

---

## 3. Story 1.3.1 — Créer la VM OCI (référence)

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


**Note** : Les VMs OCI peuvent maintenant être créées sans problème de capacité.


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

## 4. Suite après 1.3.1 + 1.3.2 (fait)

- **1.3.3** : Enregistrer le cluster DEV dans Omni (join token) — **prochaine action**
- **1.3.4** : Configurer les MachineClasses dans `omni/machine-classes/`
- **Epic 3.3** (Authentik) : Authentik est déjà dans la stack déployée ; config SSO (SAML pour Omni) et design invitation-only + Cloudflare à faire.
- **3.4.1** Cloudflare Tunnel : configurer le tunnel pour accéder à Omni/Authentik en HTTPS (Zero Trust).

---

## 5. Mise à jour du suivi

- **1.3.1** et **1.3.2** : Done. [implementation-progress.md](../planning-artifacts/implementation-progress.md) et [sprint-status.yaml](sprint-status.yaml) mis à jour (2026-02-04).
- **Prochaine story** : 1.3.3 Register DEV Cluster with Omni.
