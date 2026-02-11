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
  Par défaut le ruleset « Authentik API - skip challenge » n’est **pas** créé par Terraform (variable `enable_authentik_api_skip_challenge = false`), car le token API n’a souvent pas la permission Configuration Rules. Si le job 4 (Authentik) échoue avec **HTTP 403** et une page « Just a moment… », **créer la règle une fois** : voir **[.github/docs/cloudflare-authentik-api-challenge.md](../docs/cloudflare-authentik-api-challenge.md)** pour les étapes détaillées. En résumé : Dashboard → zone → **Security** → **Configuration Rules** → Create rule → Expression `(http.host eq "auth.smadja.dev" and starts_with(http.request.uri.path, "/api/"))` → Security Level **Essentially Off** → Deploy.
  Si ton token a **Zone → Configuration Rules → Edit**, tu peux mettre `enable_authentik_api_skip_challenge = true` pour que Terraform gère la règle.

## Suite après un Deploy Stack réussi

Une fois la pipeline verte, à faire (une fois ou selon besoin) :

1. **Cloudflare – Configuration Rule Authentik**
   Si le job 4 (Authentik) doit pouvoir s’exécuter (appels API sans challenge) : créer la règle à la main (voir « Secrets et permissions » ci‑dessus). Sinon, ignorer.

2. **Authentik – Lien « Mot de passe oublié »**
   Fait **automatiquement** par Terraform à l’apply (si `AUTHENTIK_TOKEN` est set). Sinon : `./scripts/link-recovery-flow.sh https://auth.smadja.dev <AUTHENTIK_TOKEN>`.

3. **Authentik – Token de l’outpost**
   L’outpost **Homelab Forward Auth** est créé par Terraform (job 4). Si tu ne le vois pas dans Avant-postes, lancer d’abord un apply Authentik (job 4 ou `terraform apply` dans `terraform/authentik`). Puis : Avant-postes → Homelab Forward Auth → copier le token → `AUTHENTIK_OUTPOST_TOKEN=...` dans `docker/oci-mgmt/.env` sur la VM → redémarrer `authentik-outpost-proxy`.

4. **Authentik – Accès admin aux apps**
   Vérifier que le groupe **admin** est bien lié aux applications (Omni, LiteLLM, OpenClaw) : Applications → [app] → Policy / Group / User Bindings → ajouter le groupe « admin » si besoin.

5. **Authentik – Inscriptions**
   Les inscriptions publiques sont bloquées par policy. Pour désactiver aussi le flow dans l’UI : Flows → default-enrollment-flow → Settings → décocher « Allow user to start this flow » → Save. Les utilisateurs s’inscrivent via Directory → Invitations.

Ensuite : usage normal (accès aux apps via auth.smadja.dev, invitations, etc.).

## Workflows individuels

- **Cloudflare Infrastructure**, **Terraform Oracle Cloud**, **Deploy OCI Management Stack**, **Terraform Authentik** — Toujours déclenchés par push (paths) ou manuellement (workflow_dispatch). Utiles pour un déploiement ciblé d’une seule couche sans lancer tout le Deploy Stack.
- Pour un **déploiement complet dans l’ordre** avec skip des couches inutiles : utiliser **Deploy Stack** (push ou workflow_dispatch).
