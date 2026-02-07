---
sidebar_position: 5
---

# Configuration Initiale Authentik

Guide complet pour configurer Authentik dès le début : reset de mot de passe, Omni, groupes, policies, et autres configurations essentielles.

## 📋 Vue d'ensemble

Ce guide couvre :
1. ✅ **Reset de mot de passe via email** (recovery flow)
2. ✅ **Configuration Omni** (Forward Auth)
3. ✅ **Groupes et policies** (admin, family-validated)
4. ✅ **Outpost** (pour Forward Auth)
5. ✅ **Liaison des applications** aux groupes
6. ✅ **Autres configurations recommandées**

## Prérequis

- ✅ Authentik déployé et accessible (`https://auth.smadja.dev`)
- ✅ Token API Authentik avec permissions admin
- ✅ Secrets SMTP dans OCI Vault (déjà configurés avec Resend)
- ✅ Terraform configuré pour le module Authentik

## Étape 1 : Récupérer le Token API Authentik

1. Connecte-toi à `https://auth.smadja.dev`
2. Va dans **Directory** → **Tokens & App passwords**
3. Clique sur **Create token**
4. Nom : `terraform-authentik`
5. Permissions : Coche toutes les permissions (ou au minimum les permissions de lecture/écriture)
6. Copie le token généré

## Étape 2 : Configurer les variables Terraform

```bash
cd terraform/authentik

# Créer un fichier .env (non versionné)
cat > .env <<EOF
export AUTHENTIK_URL="https://auth.smadja.dev"
export AUTHENTIK_TOKEN="ton-token-api-ici"
EOF

source .env
```

## Étape 3 : Appliquer la configuration Terraform

### 3.1 Initialiser Terraform

```bash
cd terraform/authentik
terraform init
```

### 3.2 Récupérer le compartment_id

```bash
# Depuis le module oracle-cloud
COMPARTMENT_ID=$(cd ../oracle-cloud && terraform output -raw compartment_id)
echo "Compartment ID: $COMPARTMENT_ID"
```

### 3.3 Plan et Apply

```bash
# Vérifier ce qui sera créé
terraform plan -var="oci_compartment_id=$COMPARTMENT_ID"

# Appliquer la configuration
terraform apply -var="oci_compartment_id=$COMPARTMENT_ID"
```

Cette commande va créer :
- ✅ **Groupes** : `admin`, `family-validated`
- ✅ **Recovery flow** : pour le reset de mot de passe
- ✅ **Application Omni** : avec provider Forward Auth
- ✅ **Configuration SMTP** : depuis OCI Vault (Resend)

## Étape 4 : Lier le Recovery Flow au Login Flow

Pour que le bouton "Forgot password?" apparaisse sur la page de login :

### Option A : Via script (recommandé)

```bash
# Depuis la racine du repo
./scripts/link-recovery-flow.sh https://auth.smadja.dev "$AUTHENTIK_TOKEN"
```

### Option B : Via l'UI Authentik

1. Va sur `https://auth.smadja.dev`
2. **Flows** → **default-authentication-flow**
3. Clique sur le stage **Identification** (premier stage)
4. Dans **Recovery flow**, sélectionne **default-recovery-flow**
5. Sauvegarde

## Étape 5 : Configurer l'Outpost pour Omni

L'outpost Authentik doit être déployé et configuré pour que Forward Auth fonctionne.

### 5.1 Vérifier l'outpost dans l'UI

1. Va sur `https://auth.smadja.dev`
2. **Applications** → **Outposts**
3. Vérifie qu'il y a un outpost **Proxy** actif
4. Si pas d'outpost, crée-en un :
   - **Name** : `proxy-outpost`
   - **Type** : `Proxy`
   - **Integration** : `Docker`
   - **Application** : Sélectionne toutes les applications qui utilisent Forward Auth (Omni)

### 5.2 Vérifier la configuration Docker

L'outpost doit être configuré dans `docker-compose.yml` :

```yaml
authentik-outpost-proxy:
  image: ghcr.io/goauthentik/authentik-proxy:latest
  container_name: oci-mgmt-authentik-outpost-proxy
  restart: unless-stopped
  environment:
    AUTHENTIK_HOST: "http://authentik-server:9000"
    AUTHENTIK_TOKEN: "${AUTHENTIK_OUTPOST_TOKEN}"
  networks:
    - homelab
```

Si l'outpost n'est pas déployé, redémarre les conteneurs :

```bash
# Sur la VM OCI
cd ~/homelab/oci-mgmt
docker compose up -d authentik-outpost-proxy
```

## Étape 6 : Lier le groupe Admin à Omni

Pour que seuls les membres du groupe `admin` puissent accéder à Omni :

1. Va sur `https://auth.smadja.dev`
2. **Applications** → **Omni**
3. Onglet **Policy / Group / User Bindings**
4. Clique sur **Create**
5. **Group** : Sélectionne `admin`
6. **Order** : `0`
7. Sauvegarde

## Étape 7 : Ajouter ton utilisateur au groupe Admin

1. Va sur `https://auth.smadja.dev`
2. **Directory** → **Users**
3. Trouve ton utilisateur (ou crée-le si nécessaire)
4. Clique sur ton utilisateur
5. Onglet **Groups**
6. Clique sur **Add**
7. Sélectionne le groupe `admin`
8. Sauvegarde

## Étape 8 : Tester la configuration

### 8.1 Tester le reset de mot de passe

1. Va sur `https://auth.smadja.dev`
2. Clique sur **Logout** si tu es connecté
3. Sur la page de login, clique sur **Forgot username or password?**
4. Entre ton email
5. Vérifie ta boîte mail (email de Resend)
6. Clique sur le lien de réinitialisation
7. Entre un nouveau mot de passe

### 8.2 Tester l'accès à Omni

1. Va sur `https://omni.smadja.dev`
2. Tu devrais être redirigé vers Authentik pour te connecter
3. Après connexion, tu devrais accéder à Omni

Si tu vois une erreur 401/403, vérifie :
- ✅ L'outpost est démarré (`docker compose ps authentik-outpost-proxy`)
- ✅ Tu es dans le groupe `admin`
- ✅ Le binding groupe → application Omni est créé

## Étape 9 : Autres configurations recommandées

### 9.1 Activer la MFA (TOTP) pour le compte admin (recommandé)

Comme dans le guide [authentikate-your-cloudflared](https://github.com/eclecticbouquet/authentikate-your-cloudflared), il est recommandé d’activer la 2FA sur le compte admin :

1. **Authentik** → **Settings** (icône utilisateur) → **MFA Devices**
2. **Enroll** → **TOTP Device**
3. Scanner le QR code avec une app (Authy, Google Authenticator, etc.) et valider avec un code

Aucune config Terraform : uniquement dans l’UI.

### 9.2 Désactiver le self-registration (recommandé)

Pour un environnement sécurisé, désactive l'inscription libre :

1. **Flows** → **default-enrollment-flow**
2. Clique sur le flow
3. **Settings** → Décoche **Allow user to start this flow**
4. Sauvegarde

Les utilisateurs devront être créés manuellement ou via invitation.

### 9.3 Configurer les invitations (optionnel)

Pour créer des utilisateurs via invitation :

1. **Directory** → **Invitations**
2. Clique sur **Create**
3. Remplis les informations
4. Envoie le lien d'invitation à l'utilisateur

### 9.4 Configurer les webhooks (pour CI/CD)

Si tu veux que la CI réagisse aux événements Authentik :

1. **Events** → **Webhooks**
2. Clique sur **Create**
3. **Name** : `ci-webhook`
4. **URL** : `https://ton-ci-webhook-endpoint`
5. **Events** : Sélectionne les événements (ex: `user_write`, `group_membership_updated`)

### 9.5 Configurer les policies (optionnel)

Pour des règles d'accès plus complexes :

1. **Policies** → **Policies**
2. Crée des policies selon tes besoins :
   - **Expression Policy** : pour des règles basées sur des expressions
   - **Group Membership Policy** : pour vérifier l'appartenance à un groupe
   - **Time-based Policy** : pour limiter l'accès à certaines heures

Puis lie ces policies aux applications dans **Policy / Group / User Bindings**.

### 9.6 Configurer les sources d'utilisateurs (optionnel)

Si tu veux synchroniser des utilisateurs depuis LDAP, OAuth, etc. :

1. **Directory** → **Sources**
2. Crée une source selon ton besoin (LDAP, OAuth, etc.)
3. Configure les mappings d'attributs

## Automatisation via CI

Toutes les étapes manuelles peuvent être exécutées **via CI** après un `terraform apply` :

1. **Workflow GitHub Actions** : `terraform-authentik.yml`
   - Déclenché sur push vers `terraform/authentik/**` ou manuellement.
   - Applique Terraform Authentik puis exécute le script post-terraform.

2. **Secrets GitHub** à configurer :
   - `AUTHENTIK_URL` : https://auth.smadja.dev
   - `AUTHENTIK_TOKEN` : ton token API Authentik
   - (Optionnel) `OCI_COMPARTMENT_ID` : si le state oracle-cloud n’est pas accessible en CI
   - (Optionnel) `ADMIN_USER_EMAIL` ou variable `ADMIN_USER_EMAIL` : utilisateur à ajouter au groupe admin

3. **Script post-terraform** (utilisé par la CI ou en local) :
   ```bash
   ./scripts/authentik-post-terraform.sh https://auth.smadja.dev "$AUTHENTIK_TOKEN" ton-email@example.com
   ```
   Ce script :
   - Lie le recovery flow au login flow
   - Lie le groupe admin à l’application Omni
   - Ajoute l’utilisateur fourni au groupe admin (si email donné)
   - Désactive le self-registration sur le flow d’enrollment

## Résumé des configurations

| Élément | Statut | Action requise |
|---------|--------|----------------|
| Recovery Flow | ✅ Terraform | ✅ CI/script ou UI |
| SMTP (Resend) | ✅ Terraform | Aucune |
| Groupes (admin, family-validated) | ✅ Terraform | Aucune |
| Application Omni + policy admin | ✅ Terraform | Aucune |
| Liaison groupe → Omni | ✅ CI/script | Ou UI |
| Utilisateur → groupe admin | ✅ CI/script (si email fourni) | Ou UI |
| Self-registration désactivé | ✅ CI/script | Ou UI |
| Outpost | ⚠️ UI/Docker | Vérifier/créer dans UI |

## Prochaines étapes

Une fois Authentik configuré :

1. **Configurer Omni** : Intégrer Omni avec Authentik (SAML ou OIDC)
2. **Ajouter d'autres applications** : Nextcloud, Vaultwarden, etc.
3. **Configurer les webhooks** : Pour automatiser le provisionnement
4. **Créer des service accounts** : Pour la CI/CD, ArgoCD, etc.

## Références

- [Guide Recovery Flow](./authentik-password-recovery.md)
- [Guide SMTP Terraform](./authentik-smtp-terraform.md)
- [Runbook Recovery Flow](../runbooks/configure-authentik-recovery-flow.md)
- [Documentation Authentik](https://docs.goauthentik.io/)
