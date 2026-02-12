# Déploiement — OCI Management Stack

Ordre des opérations pour déployer ou mettre à jour la stack (Traefik, Cloudflared, Authentik, Omni, LiteLLM) sur la VM OCI.

---

## Prérequis

- **VM OCI** : créée par Terraform (`terraform/oracle-cloud`), IP de management connue.
- **Secrets OCI Vault** : `postgres_password`, `authentik_secret_key`, `cloudflare_tunnel_token`, clé SSH de la VM. Optionnel : `litellm_master_key`, `litellm_salt_key` (pour l’admin API LiteLLM et Terraform).
- **Tunnel Cloudflare** : activé (`enable_tunnel = true`) et hostnames configurés (auth, omni, llm) dans `terraform/cloudflare`.

---

## Ordre recommandé

### 1. Terraform Cloudflare (tunnel + DNS)

Pour que **llm.smadja.dev** pointe vers le tunnel :

```bash
cd terraform/cloudflare
terraform init -reconfigure
terraform plan   # vérifier ingress llm + homelab_services.litellm
terraform apply
```

Cela met à jour la config du tunnel (ingress `llm.${var.domain}` → `http://localhost:8080`) et le CNAME DNS si `homelab_services` contient `litellm`.

### 2. Terraform Authentik (applications LiteLLM + outpost)

Pour que l’accès à LiteLLM soit protégé par Forward Auth :

```bash
cd terraform/authentik
# AUTHENTIK_URL et AUTHENTIK_TOKEN en env (ou tfvars)
terraform init -reconfigure
terraform plan   # vérifier applications_litellm.tf + outpost avec omni + litellm
terraform apply
```

Après apply : l’outpost « Homelab Forward Auth » gère Omni et LiteLLM. Si le token outpost a changé, mettre à jour `AUTHENTIK_OUTPOST_TOKEN` dans les secrets (OCI Vault ou `.env` sur la VM) et redémarrer le conteneur `authentik-outpost-proxy`.

### 3. Déploiement de la stack sur la VM

**Option A — CI (recommandé)**
Push sur `main` (fichiers sous `docker/oci-mgmt/**`, `ansible/**`, ou `terraform/authentik/**`, etc.) déclenche le workflow **Deploy OCI Management Stack** (`.github/workflows/deploy-oci-mgmt.yml`).
Ou lancer à la main : **Actions → Deploy OCI Management Stack → Run workflow**.

Le workflow : récupère l’IP de la VM (Terraform OCI output), récupère les secrets (OCI Vault), exécute Ansible pour copier `docker/oci-mgmt/` et lancer `docker compose up -d`, puis vérifie les conteneurs (dont `oci-mgmt-litellm`).

**Option B — Manuel (depuis ta machine)**
À la racine du repo, avec les secrets en variables ou en fichier :

```bash
ansible-playbook ansible/playbooks/oci-mgmt-deploy.yml \
  -i "oci_mgmt," \
  -e "ansible_host=IP_DE_LA_VM" \
  -e "ansible_user=ubuntu" \
  -e "ansible_ssh_private_key_file=~/.ssh/ta_cle" \
  -e "project_root=$(pwd)" \
  -e "cloudflare_tunnel_token=..." \
  -e "postgres_password=..." \
  -e "authentik_secret_key=..."
```

Optionnel : `-e "litellm_master_key=..."` et `-e "litellm_salt_key=..."` si tu veux l’admin API LiteLLM.

### 4. Post-déploiement

- **Authentik** : vérifier que le groupe **admin** est bien lié à l’application **LiteLLM** (Applications → LiteLLM → Policy/Group Bindings). La policy `admin_only` est déjà liée par Terraform ; le binding du groupe peut se faire en UI si besoin.
- **LiteLLM** : ouvrir https://llm.smadja.dev → redirection vers Authentik, puis accès à l’UI LiteLLM. Ajouter les modèles (ex. Synthetic) et les clés via l’UI ou plus tard via Terraform (`terraform/litellm/`).
- **Tunnel** : si tu n’utilises pas Terraform pour le tunnel, ajouter manuellement dans Cloudflare Zero Trust le hostname **llm.smadja.dev** → `http://localhost:8080`.

---

## Vérifications rapides

| Vérification | Commande / action |
|--------------|-------------------|
| Conteneurs sur la VM | `ssh ubuntu@IP "cd /home/ubuntu/homelab/oci-mgmt && docker compose ps"` |
| Traefik + Auth | `curl -sI -H 'Host: auth.smadja.dev' http://IP:8080` (depuis la VM ou un outil) |
| Omni (après login) | https://omni.smadja.dev |
| LiteLLM (après login) | https://llm.smadja.dev |

---

## En cas de problème

- **Error 1033 (Cloudflare Tunnel error)** : Cloudflare ne résout pas le tunnel → cloudflared sur la VM n’est pas connecté ou utilise un token invalide. Récupérer le token à jour : `terraform -chdir=terraform/cloudflare output -raw tunnel_token`, mettre à jour `CLOUDFLARE_TUNNEL_TOKEN` dans les secrets / `.env` de la VM, puis `docker compose up -d --force-recreate cloudflared`. Voir le [runbook Cloudflare Tunnel et Access](../../docs-site/docs/runbooks/cloudflare-tunnel-and-access.md).
- **Code Cloudflare Access (one-time PIN)** à chaque visite : activer Authentik comme IdP dans `terraform/cloudflare` (`authentik_oidc_enabled = true` + variables OIDC depuis `terraform/authentik output cloudflare_access_oidc`). Détail dans le même runbook.
- **502 Bad Gateway** : Traefik tourne mais le backend (Authentik, Omni, LiteLLM) pas encore prêt. Attendre 1–2 min ou `docker compose logs -f` sur la VM.
- **Authentik « Aucune intégration active »** : l’outpost n’a pas le provider LiteLLM/Omni. Vérifier `terraform/authentik` (outpost avec `protocol_providers = [omni, litellm]`) et réappliquer.
- **LiteLLM ne démarre pas** : `docker compose logs litellm` ; si `model_list` vide pose souci, ajouter un modèle minimal dans `litellm/config.yaml` ou via l’UI après premier démarrage.
- **Secrets manquants en CI** : s’assurer que les secrets listés dans le workflow (OCI Vault + GitHub) sont bien renseignés. Pour LiteLLM, `litellm_master_key` / `litellm_salt_key` sont optionnels (laisser vides si non utilisés).

---

*Voir aussi [README.md](./README.md) pour l’architecture et la config des services.*
