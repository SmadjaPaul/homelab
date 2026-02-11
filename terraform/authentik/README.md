# Terraform – Authentik configuration

Configuration Authentik en IaC : **groupes RBAC**, **applications + providers**, **policies/bindings**, **flows** (recovery, security). Structure **modulaire** (inspirée de [K-FOSS](https://github.com/K-FOSS/auth.kristinejones.dev-TF), [ghndrx/authentik-terraform](https://github.com/ghndrx/authentik-terraform)).
**Utilisateurs** : par défaut gérés dans l’UI (invitations, groupes) ; optionnellement définissables dans Terraform via `authentik_users` (voir [docs/RBAC.md](docs/RBAC.md)).
Design : docs-site/docs/advanced/planning-conclusions.md (§4).

## Prérequis

- Authentik déjà déployé et accessible (Story 3.3.1).
- Un token API Authentik (utilisateur admin ou service account) avec droits suffisants.

## Authentification

Ne pas mettre les identifiants dans le code. Utiliser les variables d’environnement :

```bash
export AUTHENTIK_URL="https://authentik.apps.example.com/"
export AUTHENTIK_TOKEN="<your_api_token>"
```

Ou un fichier `.env` (non versionné) :

```bash
source .env
terraform plan
terraform apply
```

## Structure

- **Racine** : `main.tf` (orchestration modules), `data.tf`, `provider.tf`, `variables.tf`, `outputs.tf`, `smtp-secrets.tf`
- **modules/groups** – Groupes RBAC (admin, family-validated) + attributs
- **modules/policies** – Policies d’expression (admin_only, family_validated_only, block_public_enrollment, etc.)
- **modules/flows** – Recovery flow, login link, security (password, reputation)
- **modules/apps** – Providers + applications (Omni, LiteLLM, OpenClaw, OIDC, Cloudflare Access), outpost
- **modules/bindings** – Policy bindings (groupe + policy par app)
- **modules/users** – (Optionnel) Utilisateurs + assignation aux groupes
- **docs/RBAC.md** – Matrice RBAC et usage des groupes

## Ordre d’exécution

1. Déployer Authentik (Docker Compose / Helm).
2. Créer un token API dans Authentik (Directory → Tokens & App passwords).
3. `terraform init` puis `terraform apply` dans ce répertoire.
4. Stocker les outputs sensibles (client_secret, tokens) dans ESO/Bitwarden.

## Références

- [Terraform Registry – goauthentik/authentik](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
- [Managing Authentik with Terraform (Tim Van Wassenhove)](https://timvw.be/2025/03/18/managing-authentik-with-terraform/)
- [Manage Authentik Resources in Terraform (Christian Lempa)](https://christianlempa.de/videos/authentik-terraform/)
- [GoAuthentik de A à Y – Gérer les accès aux applications](https://une-tasse-de.cafe/blog/goauthentik/#gerer-les-acces-aux-applications)
- [Integrate with ArgoCD](https://integrations.goauthentik.io/infrastructure/argocd/)
