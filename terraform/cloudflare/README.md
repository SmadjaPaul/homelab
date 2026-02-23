# Terraform — Cloudflare (smadja.dev)

DNS, Tunnel Zero Trust, Access, paramètres de zone. State **distant OCI** (même bucket que `terraform/oracle-cloud`).

## Structure (bonnes pratiques)

Le root appelle des **modules** par domaine fonctionnel :

| Module      | Rôle |
|------------|------|
| `modules/dns`     | Enregistrements DNS (root, www, services, CNAME tunnel, OCI, SPF/DMARC) |
| `modules/tunnel`  | Tunnel Cloudflared + config ingress (hostnames → backends) |
| `modules/access`  | Zero Trust : Auth0 IdP integration, applications Access, policies |
| `modules/security`| Zone settings (SSL, HSTS), rulesets (geo, skip challenge) |

Variables et outputs sont centralisés à la racine ; chaque module expose uniquement ce qui est nécessaire.

**Après la refactor en modules** : si ton state contient encore les anciennes adresses (ressources à la racine), un `terraform plan` affichera « X to destroy, Y to add ». Pour éviter destroy/création inutiles, exécute **une fois** la migration du state :

```bash
cd terraform/cloudflare
terraform init -reconfigure   # avec le bon backend
./scripts/migrate-state-to-modules.sh
terraform plan               # devrait afficher 0 to add, 0 to change, 0 to destroy (ou quasi)
```

## Backend (state distant)

Le state est stocké dans **OCI Object Storage** (`homelab-tfstate`). En CI, le namespace est injecté par le workflow.

**En local (première fois ou migration depuis state local) :**

1. Le namespace OCI est déjà renseigné dans `main.tf` (remplacer `YOUR_TENANCY_NAMESPACE` dans main.tf ; en CI le workflow l’injecte) ; en CI le workflow l’injecte via `OCI_NAMESPACE`.
2. Configurer l’auth OCI (`~/.oci/config` ou variables `OCI_CLI_*`).
3. Migrer l’état local vers OCI (si tu avais un state local) :
   ```bash
   terraform init -reconfigure -migrate-state
   ```
4. Ensuite : `terraform plan` / `terraform apply`.

**Pour repasser en state local** (dév) : créer un fichier `backend_override.tf` (ignoré par git) avec :

```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
```

Puis `terraform init -reconfigure`.

## Récupération après un apply partiel (tunnel / Access « already exists »)

Si la CI a détruit des ressources dans le state puis échoué en créant les modules (erreurs `application_already_exists`, `tunnel already exists`), les ressources existent encore dans Cloudflare. Le fichier **`imports.tf`** contient des blocs `import` pour adopter le tunnel et les applications Access existantes. Prochaine étape :

1. Lancer à nouveau le workflow (ou en local : `terraform plan` puis `terraform apply`).
2. Terraform importera les ressources listées dans `imports.tf`, puis appliquera le reste (politiques, etc.).
3. Si tout est vert, tu peux **supprimer ou renommer `imports.tf`** pour éviter des erreurs quand `enable_tunnel = false`.

En cas d’erreur **« Provider produced inconsistent result »** sur l’enregistrement SPF (TXT à la racine), relancer un `terraform apply` une fois ; c’est parfois un effet de bord du provider.

## Applications Access déjà existantes

Si Cloudflare renvoie `application_already_exists (11010)`, les applications sont déjà créées (dashboard ou ancien run). Il faut les importer dans le state :

1. Récupérer l’**application ID** pour chaque app : Zero Trust → Access → Applications → cliquer sur l’app → l’ID est dans l’URL ou les paramètres.
2. **Option 1** : `export TF_VAR_cloudflare_api_token=xxx` puis `./scripts/list-import-access-apps.sh --import` puis `terraform apply -var=enable_zone_settings=false -auto-approve`.
3. **Option 2** — import manuel (zone_id `bda8e2196f6b4f1684c6c9c06d996109`) : voir les IDs avec `./scripts/list-import-access-apps.sh` ou utiliser les IDs documentés (omni: `ed018a9c-0f6c-4ae1-b2ab-e0239c713b45`, openclaw: `d52629cc-...`, litellm: `cda4fd63-...`, grafana: `1aff147e-...`, proxmox: `73441327-...`). Puis `terraform apply -var=enable_zone_settings=false -auto-approve`.

## Auth0 (IdP)
Configuration via `terraform/auth0`. S'assurer que les scopes `openid`, `email`, `profile` sont bien configurés pour que Cloudflare récupère les infos utilisateur.

## Variables

Voir `terraform.tfvars.example`. Secrets : token API Cloudflare, `cloudflare_account_id`, `tunnel_secret`, optionnellement variables OIDC.
