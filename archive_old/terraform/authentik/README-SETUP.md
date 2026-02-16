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

## ✅ Ce qui est automatisé (aucune action manuelle)

- **Applications** Omni, LiteLLM, OpenClaw (proxy + OIDC OpenClaw) et **outpost** Homelab Forward Auth : créés par Terraform.
- **Groupes** admin / family-validated et **bindings** vers les applications : gérés par Terraform.
- **Recovery flow** (mot de passe oublié) : le lien vers le flow d’auth par défaut est fait **automatiquement** après l’apply si `AUTHENTIK_URL` et `AUTHENTIK_TOKEN` sont définis (voir [ghndrx/authentik-terraform](https://github.com/ghndrx/authentik-terraform) pour l’inspiration).

## 🔧 Actions manuelles restantes (limitations API / choix métier)

### 1. Token de l’outpost (limitation Authentik)

**Ne pas créer l’outpost à la main.** L’outpost **Homelab Forward Auth** est créé par Terraform (voir `applications_omni.tf`). Si tu ne vois que « authentik Embedded Outpost » dans Avant-postes, lance un `terraform apply` dans `terraform/authentik` (avec `AUTHENTIK_TOKEN` configuré) : l’outpost apparaîtra après l’apply.

Ensuite, récupère le token dans l’UI :

1. Authentik → **Avant-postes** → **Homelab Forward Auth**
2. Copie le **token** (affiché une seule fois à la création)
3. Sur la VM OCI (oci-mgmt), dans `docker/oci-mgmt/.env` :
   `AUTHENTIK_OUTPOST_TOKEN=<token_copié>`
4. Redémarrer le proxy outpost :
   `docker compose -f docker/oci-mgmt/docker-compose.yml up -d authentik-outpost-proxy`

Sans ce token, le forward auth vers Omni/LiteLLM/OpenClaw renverra 500.

**Si tu n’as pas la clé** (outpost créé par Terraform, token jamais copié) :

- **Option A** : Clique sur le **nom** de l’outpost « Homelab Forward Auth » (pas sur le crayon Modifier). Sur la fiche détail, regarde s’il y a un bloc **Token**, **Installation** ou **Déploiement** où le token est affiché ou régénéré.
- **Option B** : **Directory** → **Tokens and App passwords**. Cherche un token dont le propriétaire est le compte de service de l’outpost (nom du type « Outpost: Homelab Forward Auth » ou utilisateur système). Tu peux en créer un nouveau pour ce compte si besoin (Intent: **API Token** ou **App password**).
- **Option C** : Si aucun token n’apparaît, recréer l’outpost pour qu’Authentik en génère un nouveau :
  `cd terraform/authentik && terraform taint authentik_outpost.proxy_forward_auth && terraform apply`
  Puis **tout de suite** dans l’UI : Avant-postes → Homelab Forward Auth → récupérer le token affiché à la recréation.

### 2. Ajouter ton utilisateur au groupe Admin (choix métier)

Le groupe **admin** est lié aux apps par Terraform ; il reste à choisir quels utilisateurs en font partie :

1. Directory → **Groups** → **admin**
2. Onglet **Users** → **Add** → sélectionne ton utilisateur
3. Sauvegarde

(Alternative : Directory → **Users** → ton user → **Groups** → Add → `admin`.)

### 3. (Ancien) Lier le Recovery Flow — désormais automatique

Le lien est fait à l’apply par Terraform. Si tu as appliqué sans token, tu peux encore lancer à la main :
**Option A : Via script**
```bash
cd ../..
./scripts/link-recovery-flow.sh https://auth.smadja.dev "$AUTHENTIK_TOKEN"
```

**Option B : Via l’UI**
1. Flows → `default-authentication-flow`
2. Clique sur le stage **Identification**
3. Dans **Recovery flow**, sélectionne `default-recovery-flow`
4. Sauvegarde

### 4. Désactiver le Self-Registration dans l’UI (optionnel)

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
- ✅ Vérifie que l’outpost est démarré et que `AUTHENTIK_OUTPOST_TOKEN` est set dans `.env` sur la VM
- ✅ Vérifie que ton utilisateur est dans le groupe **admin** (Directory → Groups → admin)
- ✅ Les bindings groupe admin → Omni/LiteLLM/OpenClaw sont créés par Terraform

## 📝 Outputs Terraform

Après `terraform apply`, vérifie les outputs :

```bash
terraform output
```

Les outputs incluent :
- `identification_stage_id` - ID du stage d'identification avec recovery flow
- `recovery_flow_slug` - Slug du recovery flow
- `enrollment_flow_disabled_note` - Instructions pour désactiver le self-registration
- `omni_group_binding_note` - Rappel : groupe admin lié par Terraform ; ajouter ton user au groupe admin dans l’UI

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

- [Terraform Provider Authentik](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
- Exemples Terraform Authentik : [ghndrx/authentik-terraform](https://github.com/ghndrx/authentik-terraform), [gclear96/authentik-terraform-repo](https://github.com/gclear96/authentik-terraform-repo), [dhoppeIT/terraform-authentik-outpost](https://github.com/dhoppeIT/terraform-authentik-outpost), [dhoppeIT/terraform-authentik-token](https://github.com/dhoppeIT/terraform-authentik-token)
