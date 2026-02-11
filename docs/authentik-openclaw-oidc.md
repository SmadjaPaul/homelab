# OpenClaw avec Authentik (OIDC + LiteLLM)

## Vue d’ensemble

- **Forward Auth** (existant) : `openclaw.smadja.dev` est protégé par Traefik + Authentik outpost (pas de login dans OpenClaw lui‑même).
- **OIDC** (nouveau, Terraform) : OpenClaw peut utiliser Authentik comme fournisseur d’identité pour son propre login (UI/API). Les utilisateurs se connectent via Authentik puis sont reconnus par OpenClaw.
- **LiteLLM** : une clé API dédiée pour OpenClaw est gérée par Terraform LiteLLM (`terraform/litellm`).

## 1. Homelab Forward Auth — ne pas créer à la main

L’outpost **Homelab Forward Auth** est créé par Terraform. Si tu ne vois que « authentik Embedded Outpost » dans Avant-postes :

1. Lancer un `terraform apply` dans `terraform/authentik` (avec `AUTHENTIK_URL` et `AUTHENTIK_TOKEN`).
2. Après l’apply, l’outpost **Homelab Forward Auth** apparaît dans Avant-postes.
3. Copier son token et le mettre dans `docker/oci-mgmt/.env` : `AUTHENTIK_OUTPOST_TOKEN=...`, puis redémarrer le conteneur `authentik-outpost-proxy`.

## 2. OpenClaw OIDC (Terraform Authentik)

Le fichier `terraform/authentik/applications_openclaw_oidc.tf` crée :

- Un provider **OAuth2/OIDC** « OpenClaw (OIDC) » (client confidentiel, subject = username).
- Une application **OpenClaw (OIDC Login)** avec redirect URIs :
  - `https://openclaw.smadja.dev/auth/callback`
  - `http://localhost:3000/auth/callback` (dév local).
- Un binding groupe **admin** (seuls les utilisateurs du groupe admin peuvent utiliser ce provider).

Après `terraform apply` dans `terraform/authentik` :

```bash
terraform output -json openclaw_oidc
```

Utiliser les valeurs (sans les committer) dans la config OpenClaw, idéalement via un secret (Vault, Composio, etc.) :

- `AUTHENTICATION_METHOD=oidc`
- `OIDC_ISSUER=<issuer>` (ex. `https://auth.smadja.dev/application/o/openclaw-oidc/`)
- `OIDC_CLIENT_ID=openclaw-oidc`
- `OIDC_CLIENT_SECRET=<client_secret de l’output>`
- `OIDC_REDIRECT_URI=https://openclaw.smadja.dev/auth/callback`

Sécurité : ne pas mettre le client secret dans un `.env` versionné ; utiliser un secret manager.

## 3. Clé LiteLLM pour OpenClaw (Terraform LiteLLM)

Dans `terraform/litellm` :

- Une clé API LiteLLM est créée avec l’alias **openclaw** (`litellm_key.openclaw`).
- Si la variable `openclaw_litellm_key` est vide, LiteLLM génère la clé ; sinon la valeur fournie est utilisée.
- Après apply : `terraform output -raw openclaw_litellm_key` donne la clé à configurer dans OpenClaw (ex. `LITELLM_API_KEY` ou équivalent).

Prérequis : `litellm_url` et `litellm_master_key` doivent être configurés pour que le provider LiteLLM puisse créer la clé.
