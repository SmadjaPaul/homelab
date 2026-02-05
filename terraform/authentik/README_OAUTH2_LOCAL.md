# Utiliser OAuth2 private_key_jwt en local (sans token statique)

Ce guide explique comment utiliser OAuth2 `private_key_jwt` pour authentifier Terraform localement, sans avoir besoin d'un token statique.

## Prérequis

1. Le provider OAuth2 `ci-automation` doit être créé dans Authentik (via Terraform CI ou manuellement)
2. La clé privée RSA doit être disponible (depuis OCI Vault ou localement)
3. Le client_id doit être connu (par défaut: `ci-automation`)

## Méthode 1 : Script automatique (recommandé)

Le script `auth-oauth2.sh` obtient automatiquement un token OAuth2 et configure les variables d'environnement pour Terraform :

```bash
cd terraform/authentik

# Source le script (il configure AUTHENTIK_URL et AUTHENTIK_TOKEN)
source ./auth-oauth2.sh

# Maintenant vous pouvez utiliser Terraform normalement
terraform plan
terraform apply
```

Le script essaie automatiquement de récupérer la clé privée depuis :
1. OCI Vault (si OCI CLI est configuré)
2. Variable d'environnement `AUTHENTIK_PRIVATE_KEY_PEM`
3. Fichier local `.authentik-private-key.pem`
4. Terraform state du module `oracle-cloud`

## Méthode 2 : Configuration manuelle

### Étape 1 : Obtenir la clé privée

**Depuis OCI Vault :**
```bash
# Récupérer l'OCID du secret depuis Terraform
cd terraform/oracle-cloud
SECRET_OCID=$(terraform output -json | jq -r '.vault_secrets.value.authentik_private_key_pem // empty')

# Récupérer la clé privée
oci vault secret get-secret \
  --secret-id "$SECRET_OCID" \
  --query 'data."secret-content".content' \
  --raw-output | base64 -d > ../authentik/.authentik-private-key.pem

chmod 600 ../authentik/.authentik-private-key.pem
```

**Ou depuis GitHub Secrets (via OCI Vault) :**
```bash
# Si vous avez accès au secret GitHub via OCI Vault
export AUTHENTIK_PRIVATE_KEY_PEM="<votre_clé_privée>"
```

### Étape 2 : Obtenir le client_id

```bash
# Depuis Terraform output (si déjà appliqué)
cd terraform/authentik
terraform output ci_automation_oauth2_client_id

# Ou utiliser la valeur par défaut
export AUTHENTIK_OAUTH2_CLIENT_ID="ci-automation"
```

### Étape 3 : Utiliser le script

```bash
cd terraform/authentik
source ./auth-oauth2.sh
terraform plan
```

## Méthode 3 : Utiliser directement avec curl (debug)

Si vous voulez tester manuellement :

```bash
# Variables
CLIENT_ID="ci-automation"
ISSUER_URL="https://auth.smadja.dev/application/o/${CLIENT_ID}/"
PRIVATE_KEY_PEM="<votre_clé_privée>"

# Générer le JWT (voir le script auth-oauth2.sh pour les détails)
# ...

# Obtenir le token
curl -X POST "${ISSUER_URL}token/" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${CLIENT_ID}" \
  -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
  -d "client_assertion=${CLIENT_ASSERTION}" \
  -d "scope=goauthentik.io/api"

# Utiliser le token
export AUTHENTIK_URL="https://auth.smadja.dev"
export AUTHENTIK_TOKEN="<token_obtenu>"
terraform plan
```

## Configuration des variables d'environnement

Vous pouvez personnaliser le comportement via des variables d'environnement :

```bash
export AUTHENTIK_URL="https://auth.smadja.dev"                    # URL Authentik
export AUTHENTIK_OAUTH2_CLIENT_ID="ci-automation"                # Client ID OAuth2
export AUTHENTIK_OAUTH2_ISSUER_URL="https://auth.smadja.dev/application/o/ci-automation/"  # Issuer URL
export AUTHENTIK_OAUTH2_SCOPE="goauthentik.io/api"               # Scope OAuth2
export AUTHENTIK_PRIVATE_KEY_PEM="<clé_privée>"                  # Clé privée (alternative au fichier)
```

## Sécurité

⚠️ **Important** : Ne commitez jamais la clé privée dans Git !

- Le fichier `.authentik-private-key.pem` est dans `.gitignore`
- Utilisez OCI Vault pour stocker la clé privée de manière sécurisée
- Le script nettoie automatiquement les fichiers temporaires

## Dépannage

### Erreur : "Could not find Authentik private key"

Le script n'a pas trouvé la clé privée. Vérifiez :
1. Que OCI CLI est configuré (`~/.oci/config`)
2. Que le secret `homelab-authentik-private-key-pem` existe dans OCI Vault
3. Ou placez la clé dans `.authentik-private-key.pem`

### Erreur : "Failed to obtain OAuth2 token"

Vérifiez :
1. Que le provider OAuth2 `ci-automation` existe dans Authentik
2. Que "Client credentials" est activé dans le provider
3. Que l'OAuth Source `ci-automation-jwks` est configuré avec la clé publique
4. Que le client_id est correct

### Vérifier que ça fonctionne

```bash
# Tester l'authentification
source ./auth-oauth2.sh

# Vérifier que le token est valide
curl -H "Authorization: Bearer $AUTHENTIK_TOKEN" \
  "${AUTHENTIK_URL}/api/v3/core/users/" | jq .

# Si ça fonctionne, vous verrez la liste des utilisateurs
```

## Avantages

✅ **Pas de token statique** : Utilise OAuth2 avec rotation automatique des clés
✅ **Même mécanisme que la CI** : Cohérence entre local et CI
✅ **Sécurité renforcée** : Clés privées stockées dans OCI Vault
✅ **Rotation automatique** : Les clés sont rotées mensuellement via GitHub Actions
