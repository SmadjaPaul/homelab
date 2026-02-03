# Terraform – Authentik configuration

Configuration Authentik en IaC : **groupes**, **applications + providers**, **policies/bindings**, **service accounts** uniquement.
Les **utilisateurs humains** et **qui est dans quel groupe** se gèrent dans l’UI Authentik (ou via API), pas dans Terraform.
Design : docs-site/docs/advanced/planning-conclusions.md (§4).
Détail d’implémentation : `_bmad-output/implementation-artifacts/authentik-terraform-implementation.md` (§2).

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

- `provider.tf` – Provider et version.
- `data.tf` – Data sources (flows, certificate).
- `groups.tf` – Groupes (admin, family-validated, optionnel par app).
- À ajouter : `policies.tf`, `applications.tf`, `applications_admin.tf`, `service_accounts.tf`, `outputs.tf`.

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
