# Configuration Resend pour Authentik (Terraform)

Guide pas à pas pour configurer Resend comme serveur SMTP pour Authentik, entièrement via Terraform.

## Prérequis

- Compte Resend créé : https://resend.com
- Domaine configuré dans Resend (ou utilisation du domaine de test)
- Terraform configuré avec accès à OCI
- Module `terraform/oracle-cloud` déjà déployé

## Étape 1 : Créer une API Key Resend

1. **Connecte-toi à Resend** : https://resend.com/login

2. **Crée une API Key** :
   - Dashboard → API Keys → **Create API Key**
   - **Name** : `authentik-smtp` (ou un nom de ton choix)
   - **Permissions** : `Sending access` (suffisant pour SMTP)
   - **Domain restriction** : Optionnel (recommandé pour la sécurité)
   - Clique sur **Create**

3. **⚠️ IMPORTANT** : Copie l'API key immédiatement (format `re_xxxxx...`)
   - Elle ne sera affichée qu'une seule fois
   - Si tu la perds, tu devras en créer une nouvelle

## Étape 2 : Vérifier ton domaine (recommandé pour la production)

**⚠️ Important** : Resend nécessite un domaine vérifié pour envoyer des emails en production. Sans domaine vérifié, tu recevras une erreur 401/403.

**Option A : Utiliser le domaine de test (pour commencer)**

Tu peux utiliser temporairement `onboarding@resend.dev` (déjà configuré dans tes secrets). Cela fonctionne immédiatement mais les emails peuvent être marqués comme spam.

**Option B : Vérifier ton domaine (recommandé pour la production)**

Pour utiliser `noreply@smadja.dev` au lieu du domaine de test :

1. **Dashboard → Domains → Add Domain**
2. **Ajoute ton domaine** : `smadja.dev`
3. **Configure les DNS records** :
   - **SPF** : `v=spf1 include:_spf.resend.com ~all`
   - **DKIM** : Records fournis par Resend (3 clés CNAME)
   - **DMARC** : `v=DMARC1; p=none; rua=mailto:dmarc@smadja.dev`
4. **Attends la vérification** (quelques minutes)

## Étape 3 : Stocker les secrets dans OCI Vault via Terraform

### Option A : Script helper (recommandé)

Un script helper est disponible pour simplifier la configuration :

```bash
./scripts/setup-resend-smtp.sh
```

Le script te demandera :
- Ton API key Resend
- L'adresse email FROM (ex: `noreply@smadja.dev`)

Il créera automatiquement les secrets dans OCI Vault.

### Option B : Configuration manuelle

```bash
cd terraform/oracle-cloud

# Configure les variables d'environnement avec tes credentials Resend
export TF_VAR_vault_secret_authentik_smtp_host="smtp.resend.com"
export TF_VAR_vault_secret_authentik_smtp_port="587"
export TF_VAR_vault_secret_authentik_smtp_username="resend"  # Toujours "resend" pour Resend
export TF_VAR_vault_secret_authentik_smtp_password="re_xxxxx"  # Ton API key Resend
export TF_VAR_vault_secret_authentik_smtp_from="noreply@smadja.dev"  # Ton domaine vérifié ou onboarding@resend.dev

# Applique les changements
terraform plan  # Vérifie ce qui sera créé
terraform apply
```

**Vérification** :

```bash
# Vérifie que les secrets ont été créés
terraform output vault_secrets | grep authentik_smtp
```

## Étape 4 : Configurer le module Authentik

```bash
cd terraform/authentik

# Récupère le compartment_id depuis les outputs du module oracle-cloud
cd ../oracle-cloud
COMPARTMENT_ID=$(terraform output -raw compartment_id)

cd ../authentik

# Vérifie la configuration avant d'appliquer
terraform plan -var="oci_compartment_id=$COMPARTMENT_ID"

# Applique la configuration
terraform apply -var="oci_compartment_id=$COMPARTMENT_ID"
```

**Ou via `terraform.tfvars`** :

```hcl
oci_compartment_id = "ocid1.compartment.oc1..xxxxx"
```

Puis :

```bash
terraform apply
```

## Étape 5 : Vérifier la configuration

### Vérifier dans Terraform

```bash
cd terraform/authentik
terraform show | grep -A 20 "authentik_stage_email.recovery_email"
```

Tu devrais voir :
- `use_global_settings = false`
- `host = "smtp.resend.com"`
- `port = 587`
- `username = "resend"`
- `from_address = "noreply@smadja.dev"`

### Tester l'envoi d'email

1. **Via l'UI Authentik** :
   - Va sur `https://authentik.smadja.dev` (ou ton domaine)
   - Settings → Email → Test Email
   - Envoie un email de test à ton adresse

2. **Via la ligne de commande** (sur la VM) :

```bash
ssh ubuntu@<vm-ip>
cd /opt/oci-mgmt

# Test via Authentik CLI
docker compose exec authentik-server ak test_email ton-email@example.com -S default-recovery-email
```

## Étape 6 : Tester le password reset

1. **Va sur la page de login Authentik**
2. **Clique sur "Forgot password?"**
3. **Entre ton email**
4. **Vérifie ta boîte mail** (y compris les spams)
5. **Clique sur le lien de reset**
6. **Change ton mot de passe**

## Dépannage

### Les emails ne sont pas envoyés

1. **Vérifie les logs Authentik** :
   ```bash
   docker compose logs authentik-worker | grep -i email
   docker compose logs authentik-server | grep -i smtp
   ```

2. **Vérifie que les secrets sont bien lus** :
   ```bash
   cd terraform/authentik
   terraform show | grep smtp
   ```

3. **Vérifie l'API key Resend** :
   - Dashboard → API Keys
   - Vérifie que la clé est active
   - Vérifie les permissions (`Sending access`)

### Erreur "Authentication failed"

- Vérifie que `username = "resend"` (toujours en minuscules)
- Vérifie que l'API key commence par `re_`
- Vérifie que l'API key n'a pas expiré ou été révoquée

### Erreur "Domain not verified" ou 401/403

**⚠️ Important** : Resend **nécessite un domaine vérifié** pour envoyer des emails en production. Si tu utilises un domaine non vérifié, tu recevras une erreur 401 ou 403.

**Solutions** :

1. **Temporaire (pour tester)** : Utilise `onboarding@resend.dev` comme adresse FROM
   - C'est le domaine de test fourni par Resend
   - Fonctionne immédiatement sans configuration DNS
   - ⚠️ Les emails peuvent être marqués comme spam

2. **Production (recommandé)** : Vérifie ton domaine dans Resend
   - Dashboard → Domains → Add Domain
   - Ajoute `smadja.dev` (ou ton domaine)
   - Configure les DNS records (SPF, DKIM, DMARC)
   - Une fois vérifié, utilise `noreply@smadja.dev` comme FROM

**Mettre à jour le secret** :

```bash
cd terraform/oracle-cloud
export TF_VAR_vault_secret_authentik_smtp_from="noreply@smadja.dev"  # Après vérification du domaine
terraform apply -target=oci_vault_secret.authentik_smtp_from
```

### Les emails arrivent en spam

- Configure correctement SPF, DKIM et DMARC dans tes DNS
- Utilise un domaine vérifié plutôt que `onboarding@resend.dev`
- Vérifie la réputation de ton domaine sur https://mxtoolbox.com

## Limites Resend (Free Tier)

- ✅ **3000 emails/mois** (largement suffisant pour un homelab)
- ✅ **100 emails/jour** (rate limit)
- ✅ **Domaine personnalisé** supporté
- ✅ **API complète** incluse

## Mise à jour des credentials

Si tu dois changer l'API key :

```bash
cd terraform/oracle-cloud

# Mettre à jour la variable
export TF_VAR_vault_secret_authentik_smtp_password="re_nouvelle-api-key"

terraform apply
```

Puis réappliquer le module Authentik :

```bash
cd terraform/authentik
terraform apply -var="oci_compartment_id=$COMPARTMENT_ID"
```

## Références

- [Resend SMTP Documentation](https://resend.com/docs/send-with-smtp)
- [Resend API Keys](https://resend.com/api-keys)
- [Resend Domain Verification](https://resend.com/domains)
- [Authentik Email Configuration](https://docs.goauthentik.io/docs/flow/stages/email/)
