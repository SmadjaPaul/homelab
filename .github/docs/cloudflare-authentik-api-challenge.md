# Corriger le 403 « Just a moment… » sur l’API Authentik en CI

Quand le job **Authentik** (Terraform ou script) appelle `https://auth.<domain>/api/...`, Cloudflare peut renvoyer une page HTML **« Just a moment… »** (challenge anti-bot) au lieu de la réponse JSON. Les requêtes venant de GitHub Actions n’ont pas de navigateur, donc le challenge bloque l’appel et la CI échoue avec **HTTP 403**.

## Solution : Configuration Rule Cloudflare

Il faut dire à Cloudflare de **ne pas appliquer le challenge** sur les requêtes vers le chemin **`/api/`** du host Authentik.

---

### Option A – Créer la règle à la main (recommandé si le token n’a pas Configuration Rules)

**Où aller dans le dashboard :**

- **Zone** : [dash.cloudflare.com](https://dash.cloudflare.com) → sélectionner la zone (ex. **smadja.dev**).
- **Configuration Rules** : dans le menu de gauche, aller dans **Rules** → **Configuration rules** (ou **Rules** → **Overview** → **Create rule** → choisir **Configuration rule**).
  Sur certaines interfaces : **Security** → **Configuration Rules**.

**Étapes :**

1. Cliquer **Create rule** (ou **Create configuration rule**).
2. **Name** : `Authentik API - skip challenge`
3. **When incoming requests match…** (Expression) — choisir **Edit expression** et coller exactement :
   ```text
   (http.host eq "auth.smadja.dev" and starts_with(http.request.uri.path, "/api/"))
   ```
4. **Then the settings are…** (Configuration) : **Security Level** → **Essentially Off**
5. **Deploy** (ou **Save and deploy**).

Attendre quelques secondes, puis relancer le workflow. Les requêtes vers `https://auth.smadja.dev/api/*` ne seront plus challengées.

---

### Option B – Faire créer la règle par Terraform (CI ou local)

Si ton **token API Cloudflare** a la permission **Zone → Configuration Rules → Edit** :

**En CI (Deploy Stack) :**

1. Repo **Settings** → **Variables and secrets** → **Actions** → **Variables**
2. Créer une variable : nom **`ENABLE_AUTHENTIK_API_SKIP_CHALLENGE`**, valeur **`true`**
3. Déclencher un run du **Deploy Stack** en forçant le job Cloudflare (ex. push un commit qui touche `terraform/cloudflare/` ou workflow_dispatch avec **Run all**). Le job **1. Cloudflare** créera la règle à l’apply.
4. Au run suivant, le job **4. Authentik** pourra appeler l’API sans 403.

**En local :**

1. Dans `terraform/cloudflare/terraform.tfvars` (ou `-var`) : `enable_authentik_api_skip_challenge = true`
2. `terraform apply` dans `terraform/cloudflare/`

La règle est gérée par `terraform/cloudflare/modules/security` (ressource `cloudflare_ruleset.authentik_api_skip_challenge`).

## Vérification

Après création de la règle :

```bash
curl -sS -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  "https://auth.smadja.dev/api/v3/flows/instances/?slug=default-authentication-flow"
```

Le résultat doit être **200**. Si tu reçois du HTML ou 403, revérifier l’expression (host + path) et que la règle est bien déployée.

## Si ça ne marche pas

- **Host** : l’expression doit utiliser exactement le host de ton URL Authentik (ex. `auth.smadja.dev` sans `https://` ni slash final).
- **Règle bien déployée** : dans Configuration Rules, la règle doit être **Deployed** (pas en brouillon).
- **Ordre des règles** : si tu as plusieurs Configuration Rules, celle avec **Security Level → Essentially Off** pour `/api/` doit s’appliquer (vérifier l’expression).
- **Token Cloudflare (Option B)** : si la règle est créée par Terraform, le token doit avoir **Zone** → **Configuration Rules** → **Edit**. Sinon l’apply peut réussir sans créer la règle (ressource en erreur ou ignorée).

## Références

- `terraform/cloudflare/modules/security` – définition Terraform de la règle
- [Cloudflare – Configuration Rules](https://developers.cloudflare.com/rules/configuration-rules/)
