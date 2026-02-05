# Terraform – Authentik configuration

Configuration Authentik en IaC : **groupes**, **applications + providers**, **policies/bindings**, **service accounts** uniquement.
Les **utilisateurs humains** et **qui est dans quel groupe** se gèrent dans l'UI Authentik (ou via API), pas dans Terraform.
Design : docs-site/docs/advanced/planning-conclusions.md (§4).
Détail d'implémentation : `_bmad-output/implementation-artifacts/authentik-terraform-implementation.md` (§2).

## Prérequis

- Authentik déjà déployé et accessible (Story 3.3.1).
- Un token API Authentik (utilisateur admin ou service account) avec droits suffisants (bootstrap uniquement).

## Authentification

**En CI** : Le workflow utilise un **token statique** (`AUTHENTIK_TOKEN`) depuis GitHub Secrets ou OCI Vault (secret `homelab-authentik-token`). Pas de JWT ni de clé privée en CI.

**En local** : Utiliser un fichier `.env` (recommandé) :

```bash
# Copier l'exemple et remplir votre token
cp .env.example .env
# Éditer .env et mettre votre token

# Charger les variables
source .env
terraform plan
terraform apply
```

Ou exporter directement les variables d'environnement :

```bash
export AUTHENTIK_URL="https://auth.smadja.dev"
export AUTHENTIK_TOKEN="<your_api_token>"
terraform plan
terraform apply
```

**Note** : Le fichier `.env` est dans `.gitignore` et ne sera pas commité.

## Structure

- `provider.tf` – Provider et version.
- `data.tf` – Data sources (flows, certificate).
- `groups.tf` – Groupes (admin, family-validated, optionnel par app).
- `applications_omni.tf` – Application Omni + provider proxy + outpost.
- `applications_ci_automation.tf` – Provider OAuth2 générique pour CI/CD (Omni GitOps, Terraform Authentik, ArgoCD, etc.).
- À ajouter : `policies.tf`, `applications_admin.tf`, `service_accounts.tf`, `outputs.tf`.

## Ordre d'exécution

### Via CI

1. Déployer Authentik (Docker Compose / Helm) — déjà fait via `docker/oci-mgmt`.
2. Créer un **token API** dans Authentik (Directory → Tokens & App passwords) et l'ajouter :
   - **GitHub** : Repo → Settings → Secrets and variables → Actions → `AUTHENTIK_TOKEN`
   - **Ou OCI Vault** : secret `homelab-authentik-token`
3. **Première fois** — importer l'outpost embarqué si besoin (le workflow affiche les instructions).
4. Push sur `terraform/authentik/**` → le workflow utilise `AUTHENTIK_TOKEN` (Vault ou GitHub secret).

**Omni GitOps** utilise le provider OAuth2 `ci-automation` (client_credentials) ou le token statique : configurer `authentik_oauth2_client_id` / `authentik_oauth2_client_secret` dans OCI Vault, ou `AUTHENTIK_TOKEN` en fallback.

### En local (fallback)

```bash
export AUTHENTIK_URL="https://auth.smadja.dev"
export AUTHENTIK_TOKEN="<ton_token>"
# Edit backend.tf: replace YOUR_TENANCY_NAMESPACE with your OCI namespace
terraform init
terraform apply
```

## Géré par ce Terraform

- **Groupes** : admin, family-validated (`groups.tf`).
- **Application Omni** : provider proxy (forward_single), application, liaison groupe **admin** (Policy / Group / User Bindings), et assignation du provider à l'outpost embarqué (`applications_omni.tf`).
- **Provider OAuth2 générique pour CI/CD** : `ci-automation` (machine-to-machine) (`applications_ci_automation.tf`). **Utilisé par tous les workflows** : Omni GitOps, Terraform Authentik, ArgoCD, etc.
- Aucune **politique** à sélectionner à la main : la liaison groupe → application suffit pour l'accès.

## Références

- [Terraform Registry – goauthentik/authentik](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
- [Managing Authentik with Terraform (Tim Van Wassenhove)](https://timvw.be/2025/03/18/managing-authentik-with-terraform/)
- [Manage Authentik Resources in Terraform (Christian Lempa)](https://christianlempa.de/videos/authentik-terraform/)
- [GoAuthentik de A à Y – Gérer les accès aux applications](https://une-tasse-de.cafe/blog/goauthentik/#gerer-les-acces-aux-applications)
- [Integrate with ArgoCD](https://integrations.goauthentik.io/infrastructure/argocd/)
