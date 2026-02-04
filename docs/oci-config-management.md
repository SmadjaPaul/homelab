# Gestion des configs OCI (Phases A & B)

Ce document liste les **outils et services** qui aident à gérer plus facilement les différentes configurations (Terraform, Omni, Ansible, secrets) pour les phases OCI-First.

---

## Déjà en place

| Outil | Rôle | Utilisation |
|-------|------|-------------|
| **Taskfile (OCI)** | Point d’entrée unique pour Phase A/B | `task oci:phase-a`, `task oci:terraform:apply`, `task oci:omni:create`, etc. |
| **Ansible** | Déploiement stack oci-mgmt | `ansible/playbooks/oci-mgmt-deploy.yml`, `install-argocd.yml` |
| **SOPS** | Secrets chiffrés (Cloudflare, etc.) | `secrets/*.enc.yaml`, `.sops.yaml` |
| **Terraform** | Infra OCI, Cloudflare, Authentik | `terraform/oracle-cloud/`, `terraform/cloudflare/`, `terraform/authentik/` |

Le Taskfile OCI est inclus dans le Taskfile racine : `task oci:phase-a` ou `task oci:terraform:plan` depuis la racine du repo.

**CI GitHub Actions** : les déploiements sont faits par les workflows (source de vérité). Le workflow *Terraform Oracle Cloud* utilise le même Taskfile (`task oci:terraform:apply`) après `terraform init` pour l’apply ; voir [.github/DEPLOYMENTS.md](../.github/DEPLOYMENTS.md).

---

## Recommandations pour simplifier encore

### 1. **direnv + .envrc** (variables d’environnement)

Éviter de retaper les variables à chaque commande (Taskfile, Terraform, Ansible).

- **direnv** : charge un `.envrc` en entrant dans le répertoire ; les vars sont disponibles pour `task`, `terraform`, `ansible`.
- Fichier exemple : `.envrc.example` (à copier en `.envrc` et adapter).

Variables utiles :

- `OMNI_URL`, `CLUSTER_NAME` (Taskfile / Ansible)
- `TF_VAR_*` (Terraform OCI)
- Optionnel : `JOIN_TOKEN`, `CONTROL_PLANE_IP` quand tu fais l’enregistrement Omni (ou les passer en one-shot à la commande).

**Exemple `.envrc.example`** :

```bash
# OCI / Omni (pour task oci:* et Ansible)
export OMNI_URL="https://omni.smadja.dev"
export CLUSTER_NAME="cloud"
export TF_OCI_DIR="terraform/oracle-cloud"

# Terraform OCI (exemple, à adapter)
# export TF_VAR_compartment_ocid="ocid1..."
# export TF_VAR_tenancy_ocid="ocid1..."
```

Après `direnv allow`, les commandes comme `task oci:terraform:plan` ou `task oci:omni:create` utilisent ces valeurs par défaut.

---

### 2. **External Secrets Operator (ESO)** – Phase B / K8s

Pour les **secrets dans le cluster** (oauth2-proxy, clients Authentik, etc.) :

- **ESO** synchronise des secrets depuis un backend (OCI Vault, AWS Secrets Manager, etc.) vers des `Secret` Kubernetes.
- Tu gardes une seule source de vérité (ex. OCI Vault déjà utilisé pour la CI) et les pods lisent les secrets via K8s.
- Utile pour 3.3.2 (oauth2-proxy), 3.3.3 (Authentik) et les apps Phase C (Nextcloud, Vaultwarden, etc.).

À prévoir quand le cluster CLOUD est en place : chart Helm ESO + `ClusterSecretStore` ou `SecretStore` pointant vers OCI Vault.

---

### 3. **Ansible “orchestrateur” (optionnel)**

Pour enchaîner plusieurs playbooks avec un seul appel :

- Un playbook “site” (ex. `ansible/playbooks/site-oci.yml`) qui inclut les rôles ou playbooks avec **tags** :
  - `--tags phase-a` : Terraform (via local ou CI) + omni-create + rappel pour omni-register.
  - `--tags phase-b` : pas d’automatisation complète tant que Cloudflare Tunnel / oauth2-proxy / Authentik sont en cours ; une fois les playbooks prêts, les regrouper sous un tag `phase-b`.

Alternative : garder le **Taskfile** comme orchestrateur (comme aujourd’hui) et Ansible par étape ; c’est déjà clair et maintenable.

---

### 4. **Phase B dans le Taskfile**

Les tâches Phase B peuvent rester des rappels + liens vers la doc tant que les stories 3.4.1, 3.3.2, 3.3.3 ne sont pas codées. Quand tu auras des commandes concrètes (Terraform, Helm, ArgoCD), tu pourras ajouter :

- `task oci:phase-b:tunnel` → config ou apply Cloudflare Tunnel
- `task oci:phase-b:oauth2-proxy` → deploy ou sync oauth2-proxy
- `task oci:phase-b:authentik` → apply Terraform Authentik

Cela garde un seul point d’entrée pour toute la roadmap OCI.

---

## Résumé

- **Court terme** : utiliser **direnv + .envrc** (à partir de `.envrc.example`) pour ne plus repasser les variables à la main.
- **Phase B (K8s)** : prévoir **External Secrets Operator** pour les secrets (oauth2-proxy, Authentik, apps).
- **Orchestration** : **Taskfile OCI** suffit ; Ansible en complément par playbook/étape. Enrichir le Taskfile Phase B au fur et à mesure des stories.

Références : [OCI-First Roadmap](../_bmad-output/planning-artifacts/oci-first-roadmap.md), [Implementation Progress](../_bmad-output/planning-artifacts/implementation-progress.md).
