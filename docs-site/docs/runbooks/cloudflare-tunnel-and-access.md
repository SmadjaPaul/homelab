---
sidebar_position: 10
---

# Cloudflare Tunnel et Access — Services inaccessibles / code par email

Runbook pour : **Error 1033 (Cloudflare Tunnel error)**, **HTTP 500** sur les services (llm, openclaw, omni), et **demande systématique du code Cloudflare Access** (one-time PIN par email) au lieu du login Authentik.

## Symptômes

- **Error 1033** sur openclaw.smadja.dev (ou omni, llm, auth) : « The host is configured as a Cloudflare Tunnel, and Cloudflare is currently unable to resolve it. »
- **HTTP 500** sur llm.smadja.dev (ou autre) : « Cette page ne fonctionne pas » / « Unable to process this request ».
- **Code Cloudflare Access** : à chaque visite, Cloudflare demande « Your Cloudflare Access code » (one-time PIN envoyé par email) au lieu d’afficher le login Authentik (SSO).

## Impact

- Services derrière le tunnel (auth, omni, llm, openclaw) inaccessibles ou instables.
- Expérience utilisateur dégradée (double auth : code email + Authentik).

---

## 1. Error 1033 — Tunnel non résolu

**Cause** : Aucun **cloudflared** connecté avec l’ID du tunnel vers lequel pointe le DNS. Souvent le token utilisé par cloudflared ne correspond plus au tunnel géré par Terraform (tunnel recréé ou token jamais mis à jour).

### Diagnostic

1. **Tunnel activé dans Terraform ?**
   ```bash
   cd terraform/cloudflare
   terraform output tunnel_info
   ```
   Si `status = "Tunnel disabled"` → activer avec `enable_tunnel = true`, `cloudflare_account_id`, `tunnel_secret`, puis `terraform apply`.

2. **Token du tunnel (pour cloudflared)** :
   ```bash
   terraform -chdir=terraform/cloudflare output -raw tunnel_token
   ```
   Ce token doit être celui utilisé par **cloudflared** sur la VM OCI (stack docker/oci-mgmt).

3. **Sur la VM OCI** (stack docker/oci-mgmt) :
   ```bash
   docker compose ps
   docker compose logs cloudflared --tail 50
   ```
   - Si `cloudflared` n’est pas running → démarrer la stack (`docker compose up -d`).
   - Si les logs indiquent une erreur de token / connexion → mettre à jour `CLOUDFLARE_TUNNEL_TOKEN` dans `.env` avec le token Terraform ci-dessus, puis `docker compose up -d --force-recreate cloudflared`.

### Résolution

1. Récupérer le token à jour :
   ```bash
   cd terraform/cloudflare
   terraform output -raw tunnel_token
   ```
2. Sur la VM OCI (ou dans les secrets utilisés par Ansible/CI) : mettre `CLOUDFLARE_TUNNEL_TOKEN=<token_affiché>` dans le `.env` de la stack (docker/oci-mgmt).
3. Redémarrer cloudflared :
   ```bash
   docker compose up -d --force-recreate cloudflared
   ```
4. Attendre 1–2 minutes puis retester https://openclaw.smadja.dev (ou llm, omni, auth).

---

## 2. HTTP 500 — Backend ou Traefik

Une fois le tunnel connecté, une **500** vient du backend (Traefik, Authentik, LiteLLM, OpenClaw).

### Diagnostic

- **Traefik** : sur la VM, `docker compose logs traefik --tail 100` pour voir les erreurs de routage ou de forward auth.
- **LiteLLM / OpenClaw** : `docker compose logs litellm` ou `docker compose logs openclaw` (noms de services selon ton compose).
- **Forward Auth** : si Traefik renvoie 500 après un 401/403 de l’outpost Authentik, vérifier qu’Authentik et l’outpost sont up et que `AUTHENTIK_OUTPOST_TOKEN` dans `.env` est valide.

### Résolution

- Redémarrer le service concerné : `docker compose restart <service>`.
- Vérifier les variables d’environnement et les dépendances (PostgreSQL, Redis pour Authentik).

---

## 3. Code Cloudflare Access (one-time PIN) au lieu d’Authentik

**Cause** : Cloudflare Access est activé sur les applications (omni, llm, openclaw, etc.) mais **Authentik n’est pas configuré comme fournisseur d’identité (IdP)**. Par défaut, Access utilise le **One-time PIN** (code envoyé par email).

### Résolution — Activer Authentik comme IdP

**Option A — Script (recommandé)**
À la racine du repo (après `terraform apply` dans `terraform/authentik`) :
```bash
./scripts/sync-authentik-oidc-to-cloudflare.sh
cd terraform/cloudflare && terraform plan && terraform apply
```
Le script génère `terraform/cloudflare/authentik-oidc.auto.tfvars.json` à partir de l’output Authentik. Si l’apply échoue avec **« Authentication error (10000) »**, le token API Cloudflare n’a pas les droits Zero Trust : ajouter la permission **Account → Access: Identity Providers and Groups Edit** (voir [terraform.tfvars.example](../../terraform/cloudflare/terraform.tfvars.example)).

**Option B — Manuel**
1. **Récupérer les paramètres OIDC Authentik** (depuis le repo, avec token Authentik si besoin) :
   ```bash
   cd terraform/authentik
   terraform output -json cloudflare_access_oidc
   ```
   Tu obtiens : `client_id`, `client_secret`, `auth_url`, `token_url`, `certs_url`.

2. **Configurer Terraform Cloudflare** avec ces valeurs. Dans `terraform/cloudflare/terraform.tfvars` (ou en variables d’environnement / -var) :
   ```hcl
   authentik_oidc_enabled = true
   authentik_oidc_client_id     = "<client_id du output>"
   authentik_oidc_client_secret = "<client_secret du output>"
   authentik_oidc_auth_url      = "https://auth.smadja.dev/application/o/authorize/"
   authentik_oidc_token_url     = "https://auth.smadja.dev/application/o/token/"
   authentik_oidc_certs_url     = "https://auth.smadja.dev/application/o/jwks/"
   ```
   (Les URLs peuvent être lues depuis le même output si tu utilises `var.domain`.)

3. **Appliquer** :
   ```bash
   cd terraform/cloudflare
   terraform plan
   terraform apply
   ```
   Les applications Access (Homelab - Omni, LiteLLM, OpenClaw, etc.) seront configurées avec `allowed_idps = [Authentik]`. Les utilisateurs verront alors **Authentik** à la place du code par email (SSO, session 24h selon ta config).

### Vérification

- Ouvrir une fenêtre de navigation privée et aller sur https://llm.smadja.dev (ou omni, openclaw).
- Tu dois être redirigé vers **auth.smadja.dev** (Authentik) pour te connecter, sans demande de « Cloudflare Access code ».

---

## Prévention

- **Tunnel** : après tout `terraform apply` dans `terraform/cloudflare` qui recrée le tunnel (changement de `tunnel_secret` ou recréation de la ressource), récupérer à nouveau `tunnel_token` et mettre à jour le secret utilisé par cloudflared (VM ou CI).
- **Access** : garder `authentik_oidc_enabled = true` et les variables OIDC à jour pour éviter de retomber sur le one-time PIN.
