# GitHub Actions – Déploiement stack

## Workflow unique : Deploy Stack (`deploy-stack.yml`)

Un **seul** workflow enchaîne les 4 couches dans l’ordre et **ne lance que les jobs dont les fichiers ont changé** :

1. **Detect changes** — Compare au `main` (paths-filter) et expose quelles couches ont changé.
2. **1. Cloudflare** — Terraform Cloudflare (DNS, tunnel, Zero Trust). S’exécute seulement si `terraform/cloudflare/**` (ou chemins liés) a changé.
3. **2. OCI** — Terraform Oracle Cloud (VMs, Vault). S’exécute seulement si `terraform/oracle-cloud/**` (ou chemins liés) a changé.
4. **3. Deploy oci-mgmt** — Ansible sur la VM (Traefik, Authentik, Omni, LiteLLM, OpenClaw). S’exécute seulement si `docker/oci-mgmt/**`, `ansible/**`, etc. ont changé.
5. **4. Authentik** — Terraform Authentik (applications, outpost). S’exécute seulement si `terraform/authentik/**` (ou chemins liés) a changé.

**Déclenchement :**

- **Push sur `main`** avec modification dans au moins un des paths du workflow → un seul run **Deploy Stack** ; seules les couches concernées font un apply, les autres affichent « Skipped ».
- **workflow_dispatch** avec `run_all: true` (défaut) → toutes les couches sont exécutées (ignore le filtre de paths).

## Secrets et permissions

- **Cloudflare (Deploy Stack, job 1)**
  Par défaut le ruleset « Authentik API - skip challenge » n’est **pas** créé par Terraform (variable `enable_authentik_api_skip_challenge = false`), car le token API n’a souvent pas la permission Configuration Rules. **Créer la règle une fois à la main** : Dashboard → zone (ex. smadja.dev) → **Security** → **Configuration Rules** → Create rule → Expression `(http.host eq "auth.smadja.dev" and starts_with(http.request.uri.path, "/api/"))` → Configuration → Security Level → **Essentially Off** → Deploy. Après ça, le job 4 (Authentik) pourra appeler l’API.
  Si ton token a **Zone → Configuration Rules → Edit**, tu peux mettre `enable_authentik_api_skip_challenge = true` (ex. en variable Terraform en CI) pour que Terraform gère la règle.

## Workflows individuels

- **Cloudflare Infrastructure**, **Terraform Oracle Cloud**, **Deploy OCI Management Stack**, **Terraform Authentik** — Toujours déclenchés par push (paths) ou manuellement (workflow_dispatch). Utiles pour un déploiement ciblé d’une seule couche sans lancer tout le Deploy Stack.
- Pour un **déploiement complet dans l’ordre** avec skip des couches inutiles : utiliser **Deploy Stack** (push ou workflow_dispatch).
