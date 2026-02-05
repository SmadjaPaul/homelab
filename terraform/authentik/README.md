# Terraform – Authentik configuration

Configuration Authentik en IaC : **groupes**, **applications + providers**, **policies/bindings**, **service accounts** uniquement.
Les **utilisateurs humains** et **qui est dans quel groupe** se gèrent dans l'UI Authentik (ou via API), pas dans Terraform.
Design : docs-site/docs/advanced/planning-conclusions.md (§4).
Détail d'implémentation : `_bmad-output/implementation-artifacts/authentik-terraform-implementation.md` (§2).

## Prérequis

- Authentik déjà déployé et accessible (Story 3.3.1).
- Un token API Authentik (utilisateur admin ou service account) avec droits suffisants (bootstrap uniquement).

## Authentification

**En CI (recommandé)** : Le workflow utilise **OAuth2** avec `private_key_jwt` (via clé privée stockée dans OCI Vault) au lieu d'un token statique. Un token bootstrap (`AUTHENTIK_TOKEN`) est nécessaire uniquement pour créer le premier provider OAuth2. Le provider `ci-automation` est utilisé par tous les workflows CI/CD (Omni, Terraform Authentik, ArgoCD, etc.).

**En local (recommandé)** : Utiliser OAuth2 `private_key_jwt` (sans token statique) :

```bash
cd terraform/authentik
source ./auth-oauth2.sh  # Obtient un token OAuth2 automatiquement
terraform plan
terraform apply
```

Le script `auth-oauth2.sh` récupère automatiquement la clé privée depuis OCI Vault et génère un token OAuth2. Voir `README_OAUTH2_LOCAL.md` pour plus de détails.

**En local (fallback avec token statique)** : Utiliser un fichier `.env` (recommandé) :

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

### Via CI (recommandé, avec OAuth2)

**Bootstrap (première fois uniquement)** :

1. Déployer Authentik (Docker Compose / Helm) — déjà fait via `docker/oci-mgmt`.
2. Créer un **token API bootstrap** dans Authentik (Directory → Tokens & App passwords) et l'ajouter comme secret GitHub :
   - Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**
   - **Name** : `AUTHENTIK_TOKEN`
   - **Value** : le token Authentik (expiration: 1 an, ou selon ta politique)
   - **Environnement** : `production`
3. **Première fois uniquement** — importer l'outpost embarqué existant :
   - Option A : via CI — le workflow détecte si l'outpost n'est pas dans l'état et affiche les instructions.
   - Option B : manuellement — `terraform import authentik_outpost.embedded <OUTPOST_UUID>` puis push.
4. Push sur `terraform/authentik/**` → le workflow CI applique automatiquement (utilise `AUTHENTIK_TOKEN` pour le bootstrap).

**Après le bootstrap (OAuth2)** :

5. Après le premier `terraform apply` (via CI), récupérer les outputs `ci_automation_oauth2_client_id` et `ci_automation_oauth2_client_secret` dans les logs du workflow.
6. Ajouter ces secrets GitHub (utilisés par **tous** les workflows CI/CD) :
   - `CI_AUTOMATION_AUTHENTIK_CLIENT_ID` : valeur de `ci_automation_oauth2_client_id`
   - `CI_AUTOMATION_AUTHENTIK_CLIENT_SECRET` : valeur de `ci_automation_oauth2_client_secret` (sensitive)
   - `CI_AUTOMATION_AUTHENTIK_ISSUER_URL` : valeur de `ci_automation_oauth2_issuer_url` (optionnel)
7. **Activer "Client credentials"** dans Authentik UI :
   - Applications → Providers → `ci-automation` → Edit → Grant types → **Client credentials** → Update
8. **Tous les workflows** (Omni GitOps, Terraform Authentik, ArgoCD, etc.) utiliseront automatiquement OAuth2 au lieu de tokens statiques. Le token `AUTHENTIK_TOKEN` peut être conservé comme fallback ou supprimé une fois OAuth2 validé.

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
