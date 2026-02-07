# Guide de Configuration Terraform Authentik

Ce guide explique comment configurer Authentik via Terraform, incluant le reset de mot de passe, Omni, les groupes, policies, et la désactivation du self-registration.

## 📋 Fichiers de Configuration

- `recovery-flow.tf` - Flow de récupération de mot de passe
- `login-flow-recovery-link.tf` - Liaison du recovery flow au login flow
- `groups.tf` - Groupes (admin, family-validated)
- `applications_omni.tf` - Application Omni avec Forward Auth
- `policies.tf` - Policies pour contrôler l'accès
- `application-bindings.tf` - Bindings groupes/policies → applications
- `security-policies.tf` - Politique mot de passe (recovery) + réputation (brute-force login)
- `enrollment-flow.tf` - Désactivation du self-registration
- `smtp-secrets.tf` - Configuration SMTP depuis OCI Vault

## 🚀 Configuration Initiale

### 1. Prérequis

```bash
# Variables d'environnement
export AUTHENTIK_URL="https://auth.smadja.dev"
export AUTHENTIK_TOKEN="ton-token-api-authentik"

# Récupérer le compartment_id
cd terraform/oracle-cloud
COMPARTMENT_ID=$(terraform output -raw compartment_id)
cd ../authentik
```

### 2. Initialiser Terraform

```bash
cd terraform/authentik
terraform init
```

### 3. Plan et Apply

```bash
# Vérifier ce qui sera créé
terraform plan -var="oci_compartment_id=$COMPARTMENT_ID"

# Appliquer la configuration
terraform apply -var="oci_compartment_id=$COMPARTMENT_ID"
```

## ✅ Ce qui sera créé

### Groupes
- ✅ `admin` - Groupe pour les administrateurs
- ✅ `family-validated` - Groupe pour les utilisateurs validés

### Recovery Flow
- ✅ Flow de récupération de mot de passe (`default-recovery-flow`)
- ✅ Stages : identification, email, prompt password, user write, user login
- ✅ Configuration SMTP depuis OCI Vault (Resend)

### Application Omni
- ✅ Provider Forward Auth pour Omni
- ✅ Application Omni
- ✅ Policy pour restreindre l'accès au groupe admin

### Policies
- ✅ `admin-group-only` - Seuls les membres du groupe admin
- ✅ `family-validated-only` - Seuls les membres du groupe family-validated
- ✅ `block-public-enrollment` - Bloque le self-registration public

### Bindings
- ✅ Policy admin-only → Application Omni
- ✅ Policy block-public-enrollment → Enrollment flow (si supporté)

### Politiques de sécurité (security-policies.tf)
- ✅ **Mot de passe** : 12 caractères min, majuscule/minuscule/chiffre/symbole, HIBP, zxcvbn (appliqué au recovery flow)
- ✅ **Réputation** : blocage après 5 échecs de connexion (IP + username), appliqué au flow d’authentification par défaut

## 🔧 Actions Manuelles Requises

Après avoir appliqué Terraform, certaines configurations doivent être faites manuellement dans l'UI :

### 1. Lier le Recovery Flow au Login Flow

**Option A : Via script (recommandé)**
```bash
cd ../..
./scripts/link-recovery-flow.sh https://auth.smadja.dev "$AUTHENTIK_TOKEN"
```

**Option B : Via l'UI**
1. Flows → `default-authentication-flow`
2. Clique sur le stage **Identification**
3. Dans **Recovery flow**, sélectionne `default-recovery-flow`
4. Sauvegarde

### 2. Lier le groupe Admin à Omni

1. Applications → **Omni**
2. Onglet **Policy / Group / User Bindings**
3. Clique sur **Create**
4. **Group** : Sélectionne `admin`
5. **Order** : `0`
6. Sauvegarde

### 3. Ajouter ton utilisateur au groupe Admin

1. Directory → **Users**
2. Trouve ton utilisateur
3. Onglet **Groups**
4. Clique sur **Add**
5. Sélectionne le groupe `admin`
6. Sauvegarde

### 4. Désactiver le Self-Registration (recommandé)

1. Flows → `default-enrollment-flow`
2. Clique sur **Settings**
3. Décoche **"Allow user to start this flow"**
4. Sauvegarde

**Note** : Une policy `block-public-enrollment` a été créée, mais la désactivation dans l'UI est plus fiable.

## 🧪 Tests

### Tester le Reset de Mot de Passe

1. Va sur `https://auth.smadja.dev`
2. Clique sur **Logout** si connecté
3. Sur la page de login, clique sur **"Forgot username or password?"**
4. Entre ton email
5. Vérifie ta boîte mail (email de Resend)
6. Clique sur le lien de réinitialisation
7. Entre un nouveau mot de passe

### Tester l'Accès à Omni

1. Va sur `https://omni.smadja.dev`
2. Tu devrais être redirigé vers Authentik
3. Connecte-toi avec un compte dans le groupe `admin`
4. Tu devrais accéder à Omni

Si erreur 401/403 :
- ✅ Vérifie que l'outpost est démarré (`docker compose ps authentik-outpost-proxy`)
- ✅ Vérifie que tu es dans le groupe `admin`
- ✅ Vérifie que le binding groupe → Omni est créé

## 📝 Outputs Terraform

Après `terraform apply`, vérifie les outputs :

```bash
terraform output
```

Les outputs incluent :
- `identification_stage_id` - ID du stage d'identification avec recovery flow
- `recovery_flow_slug` - Slug du recovery flow
- `enrollment_flow_disabled_note` - Instructions pour désactiver le self-registration
- `omni_group_binding_note` - Instructions pour lier le groupe admin à Omni

## 🔍 Dépannage

### Erreur : "default-recovery-flow" is not a valid UUID

Cette erreur indique que Terraform essaie de référencer le flow avant qu'il ne soit créé. Les `depends_on` ont été ajoutés pour résoudre ce problème. Si l'erreur persiste :

1. Vérifie que le flow recovery n'existe pas déjà dans Authentik avec le même slug
2. Si oui, utilise une data source au lieu d'une resource :
   ```terraform
   data "authentik_flow" "recovery" {
     slug = "default-recovery-flow"
   }
   ```

### Erreur : Policy binding ne fonctionne pas

Certaines versions du provider Terraform peuvent ne pas supporter tous les types de bindings. Dans ce cas, configure-les manuellement dans l'UI Authentik.

## ➕ Ajouter une nouvelle application

Pour un **proxy (Forward Auth)** comme Omni : créer un fichier `applications_<nom>.tf` avec un `authentik_provider_proxy`, une `authentik_application`, et ajouter le provider à l’outpost existant (`authentik_outpost.proxy_forward_auth` dans `applications_omni.tf`) via `protocol_providers = [..., authentik_provider_proxy.<nouvelle_app>.id]`. Puis ajouter la route Traefik et le hostname dans le tunnel Cloudflare.

Pour une **app OAuth2/OIDC** (Grafana, ArgoCD, etc.) : créer `authentik_provider_oauth2` (redirect_uris, client_id, etc.) et `authentik_application` avec `protocol_provider = authentik_provider_oauth2.<nom>.id`. Pas d’outpost nécessaire pour OAuth.

Policies : lier l’accès à un groupe avec `authentik_policy_binding` (target = application, policy = une `authentik_policy_expression` ou `admin_only` / `family_validated_only`).

Exemple de structure : voir `applications_omni.tf` (proxy) et `cloudflare-access-oidc.tf` (OAuth2).

## 📚 Références

- [Guide Configuration Initiale Authentik](../../docs-site/docs/guides/authentik-initial-setup.md)
- [Guide Recovery Flow](../../docs-site/docs/guides/authentik-password-recovery.md)
- [Runbook Recovery Flow](../../docs-site/docs/runbooks/configure-authentik-recovery-flow.md)
- [Documentation Terraform Provider Authentik](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
