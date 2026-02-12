# Terraform – Authentik configuration

Configuration Authentik en IaC : **groupes RBAC**, **applications + providers**, **policies/bindings**, **flows** (recovery, security). Structure **modulaire** (inspirée de [K-FOSS](https://github.com/K-FOSS/auth.kristinejones.dev-TF), [ghndrx/authentik-terraform](https://github.com/ghndrx/authentik-terraform)).
**Utilisateurs** : par défaut gérés dans l'UI (invitations, groupes) ; optionnellement définissables dans Terraform via `authentik_users` (voir [docs/RBAC.md](docs/RBAC.md)).
Design : docs-site/docs/advanced/planning-conclusions.md (§4).

## Prérequis

- Authentik déjà déployé et accessible (Story 3.3.1).
- Un token API Authentik (utilisateur admin ou service account) avec droits suffisants.

## Perdu l'accès / pas de token API

Si tu ne peux plus te connecter à Authentik (et donc pas créer de token) :

1. **Reset du mot de passe** (utilisateur existant) — depuis la racine du repo :
   ```bash
   ./scripts/reset-authentik-password.sh smadja-paul@protonmail.com 'TonNouveauMotDePasse'
   ```
   Le script se connecte en SSH à la VM OCI management, lance `ak reset_password` (ou crée/met à jour l'utilisateur en superuser + groupe « authentik Admins »). Prérequis : accès SSH à la VM (`ubuntu@<IP>`), clé dans `~/.ssh/oci_mgmt.pem` ou équivalent. L'IP est lue depuis `terraform/oracle-cloud` si disponible, sinon tu la saisis à la demande.

2. **Reset complet** (créer un nouvel admin ou tout réinitialiser) :
   ```bash
   ./scripts/reset-authentik-complete.sh smadja-paul@protonmail.com 'MotDePasse'
   ```
   Menu : reset mot de passe existant, créer un nouvel admin, ou reset complet (suppression BDD).

Après le reset, connecte-toi à https://auth.smadja.dev puis :
- Crée un token : **Directory → Tokens & App passwords → Create token** → utilise-le pour `AUTHENTIK_TOKEN` ou Terraform.
- Si tu as encore « Flow does not apply » ou pas d’accès aux apps : ajoute ton utilisateur au groupe **admin** (Directory → Utilisateurs → ton user → Groupes → admin + family-validated), ou lance `terraform apply` pour que Terraform assigne les groupes à smadja-paul.

## Backend (state)

Le state est stocké dans **OCI Object Storage** (même bucket que Cloudflare/OCI), clé `authentik/terraform.tfstate`. En CI le namespace est injecté par le workflow. En local : remplacer `YOUR_TENANCY_NAMESPACE` dans `backend.tf` par ton namespace (ex. `terraform output -raw tfstate_bucket` depuis `terraform/oracle-cloud`), puis `terraform init -reconfigure`. Si tu avais un state local, utilise `terraform init -reconfigure -migrate-state` pour le copier vers OCI.

## Authentification

Ne pas mettre les identifiants dans le code. Utiliser les variables d'environnement :

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
- **modules/policies** – Policies d'expression (admin_only, family_validated_only, block_public_enrollment, etc.)
- **modules/flows** – Recovery flow, login link, security (password, reputation)
- **modules/apps** – Providers + applications (Omni, LiteLLM, OpenClaw, OIDC, Cloudflare Access), outpost
- **modules/bindings** – Policy bindings (groupe + policy par app)
- **modules/users** – (Optionnel) Utilisateurs + assignation aux groupes
- **docs/RBAC.md** – Matrice RBAC et usage des groupes

## Ordre d'exécution

1. Déployer Authentik (Docker Compose / Helm).
2. Créer un token API dans Authentik (Directory → Tokens & App passwords).
3. `terraform init` puis `terraform apply` dans ce répertoire.
4. Stocker les outputs sensibles (client_secret, tokens) dans ESO/Bitwarden.

### Utilisateur admin (smadja-paul@protonmail.com)

Par défaut, `authentik_users` contient **smadja-paul** (`smadja-paul@protonmail.com`) avec les groupes **admin** et **family-validated**. Les apps Omni, LiteLLM, OpenClaw (et OIDC) ont un policy binding `admin_only` : seuls les utilisateurs du groupe **admin** y ont accès.

**Erreur « Flow does not apply to current user »** : le flow d’authentification a souvent une policy qui restreint l’accès (ex. « uniquement le groupe admin »). Vérifier que l’utilisateur est bien dans le groupe **admin** (Terraform ou UI). Si le flow `default-authentication-flow` a une policy stricte, l’ajouter au groupe admin résout l’erreur.

**Si l'erreur apparaît avant même de saisir ton mail** : ce n'est pas Cloudflare (auth.smadja.dev n'est pas derrière Access). C'est le flow **default-authentication-flow** qui a une policy restreignant qui peut l'utiliser ; en visiteur anonyme tu es refusé. Après avoir récupéré l'accès (script reset) : **Flows** → default-authentication-flow → **Policy / Group Bindings** → supprime la policy qui limite l'accès au flow (le login doit être accessible à tous).

**Correctif immédiat (sans Terraform)** : Authentik → **Directory → Utilisateurs** → ouvrir l’utilisateur (ex. `smadja-paul@protonmail.com`) → onglet **Groupes** → ajouter **admin** et **family-validated** → Enregistrer.

**Gérer l’utilisateur avec Terraform** : si l’utilisateur existe déjà dans Authentik, l’importer puis apply pour synchroniser les groupes :

1. Récupérer le **pk** (ID numérique dans l’URL admin, ex. `.../users/5` → pk = 5). Option : `AUTHENTIK_TOKEN=xxx ./scripts/get-user-uuid.sh smadja-paul`
2. Importer (le provider attend le **pk**, pas l’UUID) :
   ```bash
   export AUTHENTIK_TOKEN=<ton_token>
   terraform import 'module.users[0].authentik_user.users["smadja-paul"]' 5
   ```
3. `terraform apply` pour appliquer l’assignation aux groupes.

## Références

- [Terraform Registry – goauthentik/authentik](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
- [Managing Authentik with Terraform (Tim Van Wassenhove)](https://timvw.be/2025/03/18/managing-authentik-with-terraform/)
- [Manage Authentik Resources in Terraform (Christian Lempa)](https://christianlempa.de/videos/authentik-terraform/)
- [GoAuthentik de A à Y – Gérer les accès aux applications](https://une-tasse-de.cafe/blog/goauthentik/#gerer-les-acces-aux-applications)
- [Integrate with ArgoCD](https://integrations.goauthentik.io/infrastructure/argocd/)
