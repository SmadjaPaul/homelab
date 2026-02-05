# Prochaines étapes - Configuration Authentik OAuth2

## ✅ Ce qui a été fait

1. **Provider OAuth2 `ci-automation` créé** via Terraform
2. **OAuth Source `ci-automation-jwks` créé** pour stocker le JWKS
3. **Configuration automatique activée** :
   - Grant type "Client credentials" activé automatiquement
   - OAuth Source liée au provider automatiquement
   - Tout géré via IaC (pas de drift)

## 📋 Prochaines étapes

### 1. Déployer le JWKS initial (clés RSA)

Le provider et l'OAuth Source sont créés, mais il faut déployer les clés publiques (JWKS) pour que `private_key_jwt` fonctionne.

**Option A : Via GitHub Actions (recommandé)**

1. Aller dans GitHub Actions
2. Sélectionner le workflow **"Deploy Authentik JWKS"**
3. Cliquer sur **"Run workflow"**
4. Le workflow va :
   - Générer une paire de clés RSA 2048-bit
   - Stocker la clé privée dans OCI Vault (`homelab-authentik-private-key-pem`)
   - Déployer la clé publique (JWKS) dans Authentik OAuth Source

**Option B : Manuellement**

```bash
# Générer les clés
openssl genrsa -out /tmp/private_key.pem 2048
openssl rsa -in /tmp/private_key.pem -pubout -out /tmp/public_key.pem

# Convertir en JWK (nécessite Python)
python3 << EOF
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend
import json
import base64

with open('/tmp/public_key.pem', 'rb') as f:
    public_key = serialization.load_pem_public_key(f.read(), backend=default_backend())

public_numbers = public_key.public_numbers()

def int_to_base64url(n):
    byte_length = (n.bit_length() + 7) // 8
    n_bytes = n.to_bytes(byte_length, 'big')
    return base64.urlsafe_b64encode(n_bytes).decode('utf-8').rstrip('=')

jwk = {
    "kty": "RSA",
    "use": "sig",
    "kid": "ci-automation-key-1",
    "alg": "RS256",
    "n": int_to_base64url(public_numbers.n),
    "e": int_to_base64url(public_numbers.e)
}

jwks = {"keys": [jwk]}
print(json.dumps(jwks, indent=2))
EOF

# Stocker la clé privée dans OCI Vault (via script ou UI)
# Mettre à jour le JWKS dans Authentik OAuth Source via API
```

### 2. Configurer le Provider (si pas déjà fait)

**✅ Automatique via Terraform**

La configuration du provider est gérée automatiquement par Terraform. Si vous n'avez pas encore fait `terraform apply` après la création du provider, exécutez :

```bash
cd terraform/authentik
source .env
terraform apply
```

Le provisioner `null_resource.configure_ci_automation_provider` configurera automatiquement :
- Grant type "Client credentials" activé
- OAuth Source `ci-automation-jwks` liée au provider

### 3. Vérifier la configuration

Une fois le JWKS déployé et Terraform appliqué, vérifier dans Authentik UI :

1. **Applications** → **Providers** → `ci-automation` → **Edit**
   - ✅ Grant types : "Client credentials" doit être coché
   - ✅ OAuth Source : `ci-automation-jwks` doit être sélectionné

2. **Directory** → **Sources** → `ci-automation-jwks` → **Edit**
   - ✅ JWKS doit contenir au moins une clé publique

### 4. Tester l'authentification

**En local :**

```bash
cd terraform/authentik
source ./auth-oauth2.sh  # Utilise OAuth2 private_key_jwt
terraform plan  # Devrait fonctionner sans token statique
```

**Via GitHub Actions :**

Déclencher le workflow `.github/workflows/test-authentik-jwt.yml` pour tester l'authentification end-to-end.

### 5. Mettre à jour les workflows (si nécessaire)

Les workflows suivants devraient déjà utiliser `private_key_jwt` :
- ✅ `.github/workflows/terraform-authentik.yml`
- ✅ `.github/workflows/omni-gitops.yml`

Vérifier qu'ils fonctionnent correctement après le déploiement du JWKS.

### 6. Rotation automatique des clés

Le workflow `.github/workflows/authentik-rotate-keys.yml` s'exécute automatiquement **le 1er de chaque mois à 2h UTC** pour faire tourner les clés.

Vous pouvez aussi le déclencher manuellement pour tester.

## 🎯 État actuel

| Composant | État | Action requise |
|-----------|------|----------------|
| Provider OAuth2 `ci-automation` | ✅ Créé | Aucune |
| OAuth Source `ci-automation-jwks` | ✅ Créé | Aucune |
| Grant type "Client credentials" | ✅ Activé (IaC) | Aucune |
| OAuth Source liée au provider | ✅ Configuré (IaC) | Aucune |
| JWKS (clés publiques) | ⏳ À déployer | Déclencher workflow ou manuel |
| Clé privée dans OCI Vault | ⏳ À stocker | Déclencher workflow ou manuel |
| Test d'authentification | ⏳ À faire | Après déploiement JWKS |

## 📝 Commandes utiles

```bash
# Vérifier les outputs Terraform
cd terraform/authentik
terraform output

# Récupérer le client_secret (pour fallback si nécessaire)
terraform output -raw ci_automation_oauth2_client_secret

# Tester l'authentification OAuth2 en local
source ./auth-oauth2.sh
terraform plan

# Vérifier le state Terraform
terraform state list
```

## 🔗 Documentation

- Guide de migration : `.github/PRIVATE_KEY_JWT_MIGRATION.md`
- Checklist de déploiement : `.github/DEPLOYMENT_CHECKLIST.md`
- Guide de test : `.github/TESTING_GUIDE.md`
- Utilisation locale OAuth2 : `README_OAUTH2_LOCAL.md`
