# Configuration SMTP Authentik via Terraform

Ce guide explique comment configurer SMTP pour Authentik **entièrement via Terraform**, en utilisant OCI Vault pour stocker les credentials SMTP.

## Vue d'ensemble

La solution permet de :
1. **Stocker les credentials SMTP dans OCI Vault** via Terraform (`terraform/oracle-cloud`)
2. **Lire ces secrets dans le module Authentik** via des data sources Terraform
3. **Configurer `authentik_stage_email`** avec ces credentials directement dans Terraform

**Avantage** : Tout est géré en Infrastructure as Code, sans configuration manuelle dans l'UI Authentik ou dans `docker-compose.yml`.

## Architecture

```
┌─────────────────────────────────────┐
│ terraform/oracle-cloud/             │
│  - vault-secrets.tf                 │
│    • oci_vault_secret.authentik_    │
│      smtp_host                      │
│    • oci_vault_secret.authentik_    │
│      smtp_port                      │
│    • oci_vault_secret.authentik_    │
│      smtp_username                  │
│    • oci_vault_secret.authentik_    │
│      smtp_password                  │
│    • oci_vault_secret.authentik_    │
│      smtp_from                      │
└──────────────┬──────────────────────┘
               │
               │ OCI Vault (secrets stockés)
               │
               ▼
┌─────────────────────────────────────┐
│ terraform/authentik/                 │
│  - smtp-secrets.tf                  │
│    • data.oci_vault_secrets          │
│    • data.oci_secrets_secret_bundle  │
│  - recovery-flow.tf                 │
│    • authentik_stage_email           │
│      (use_global_settings=false)    │
└─────────────────────────────────────┘
```

## Étape 1 : Créer les credentials SMTP

### Option A : Zoho Mail (gratuit pour freelances, jusqu'à 25 utilisateurs)

**Avantages** :
- ✅ **Gratuit** pour jusqu'à 25 utilisateurs
- ✅ 5GB de stockage par utilisateur
- ✅ SMTP inclus
- ✅ Domaine personnalisé supporté
- ✅ Idéal pour les freelances et petites équipes

**Limitations du plan gratuit** :
- ❌ **Pas d'accès aux applications professionnelles** (WorkDrive, Writer, Sheets, Show, Cliq, Meeting, Vault)
- ❌ Webmail uniquement (pas d'applications desktop/mobile natives)
- ❌ Limite de 25MB par pièce jointe
- ❌ Pas de collaboration avancée

**Note** : Les applications professionnelles Zoho (suite Workplace) sont disponibles uniquement dans les plans payants à partir de **$5-6/user/mois** (Workplace Standard).

1. **Créer un compte Zoho Mail** : https://www.zoho.com/mail/
2. **Ajouter ton domaine** :
   - Settings → Domains → Add Domain
   - Suivre les instructions DNS (MX, SPF, DKIM, DMARC)
3. **Créer une adresse email** (ex: `noreply@smadja.dev`)
4. **Configurer un mot de passe spécifique à l'application** (si 2FA activé) :
   - Settings → Security → App Passwords → Generate
   - Ou désactiver temporairement 2FA pour utiliser le mot de passe principal
5. **Configurer les secrets dans Terraform** :

```bash
# Dans terraform/oracle-cloud/
export TF_VAR_vault_secret_authentik_smtp_host="smtp.zoho.com"
export TF_VAR_vault_secret_authentik_smtp_port="587"  # TLS (recommandé) ou 465 pour SSL
export TF_VAR_vault_secret_authentik_smtp_username="noreply@smadja.dev"  # Ton adresse Zoho
export TF_VAR_vault_secret_authentik_smtp_password="ton-mot-de-passe"  # Mot de passe ou App Password
export TF_VAR_vault_secret_authentik_smtp_from="noreply@smadja.dev"

terraform apply
```

**Configuration SMTP Zoho** :
- **Serveur SMTP** : `smtp.zoho.com`
- **Port TLS** : `587` (recommandé)
- **Port SSL** : `465` (alternative)
- **Authentification** : Requise (email complet comme username)
- **Sécurité** : TLS ou SSL selon le port

**⚠️ Important** : Il n'existe **pas de provider Terraform officiel** pour Zoho Mail. Cependant, tu peux quand même utiliser notre solution Terraform en stockant les credentials SMTP dans OCI Vault (comme pour les autres providers). La création des comptes email Zoho doit se faire manuellement via l'interface web.

### Option B : Resend (recommandé pour débuter)

1. **Créer un compte Resend** : https://resend.com
2. **Ajouter un domaine** (ou utiliser le domaine de test)
3. **Créer une API key** :
   - Dashboard → API Keys → Create API Key
   - Permissions : "Sending access"
   - Domain restriction : optionnel
   - **⚠️ Important** : Copier l'API key immédiatement (affichée une seule fois)

4. **Configurer les secrets dans Terraform** :

```bash
# Dans terraform/oracle-cloud/
export TF_VAR_vault_secret_authentik_smtp_host="smtp.resend.com"
export TF_VAR_vault_secret_authentik_smtp_port="587"
export TF_VAR_vault_secret_authentik_smtp_username="resend"  # Pour Resend, username = "resend"
export TF_VAR_vault_secret_authentik_smtp_password="re_xxxxx"  # Ton API key Resend
export TF_VAR_vault_secret_authentik_smtp_from="noreply@smadja.dev"  # Ton domaine vérifié

terraform apply
```

### Option B : SendGrid

1. **Créer un compte SendGrid** : https://sendgrid.com
2. **Vérifier un domaine** (Settings → Sender Authentication)
3. **Créer une API key** :
   - Settings → API Keys → Create API Key
   - Permissions : "Mail Send" (Full Access ou Restricted)
   - **⚠️ Important** : Copier l'API key immédiatement

4. **Configurer les secrets** :

```bash
export TF_VAR_vault_secret_authentik_smtp_host="smtp.sendgrid.net"
export TF_VAR_vault_secret_authentik_smtp_port="587"
export TF_VAR_vault_secret_authentik_smtp_username="apikey"  # Pour SendGrid, toujours "apikey"
export TF_VAR_vault_secret_authentik_smtp_password="SG.xxxxx"  # Ton API key SendGrid
export TF_VAR_vault_secret_authentik_smtp_from="noreply@smadja.dev"

terraform apply
```

### Option C : Gmail (App Password)

1. **Activer la validation en 2 étapes** sur ton compte Gmail
2. **Créer un App Password** :
   - Google Account → Security → 2-Step Verification → App passwords
   - Select app : "Mail"
   - Select device : "Other" → "Authentik"
   - Copier le mot de passe généré (16 caractères)

3. **Configurer les secrets** :

```bash
export TF_VAR_vault_secret_authentik_smtp_host="smtp.gmail.com"
export TF_VAR_vault_secret_authentik_smtp_port="587"
export TF_VAR_vault_secret_authentik_smtp_username="ton-email@gmail.com"
export TF_VAR_vault_secret_authentik_smtp_password="xxxx xxxx xxxx xxxx"  # App Password
export TF_VAR_vault_secret_authentik_smtp_from="ton-email@gmail.com"

terraform apply
```

## Étape 2 : Configurer le module Authentik

Une fois les secrets créés dans OCI Vault, configure le module Authentik pour les utiliser :

```bash
cd terraform/authentik

# Récupérer le compartment_id depuis les outputs du module oracle-cloud
cd ../oracle-cloud
COMPARTMENT_ID=$(terraform output -raw compartment_id 2>/dev/null || echo "")

cd ../authentik

# Passer le compartment_id au module Authentik
terraform apply -var="oci_compartment_id=$COMPARTMENT_ID"
```

Ou via un fichier `terraform.tfvars` :

```hcl
oci_compartment_id = "ocid1.compartment.oc1..xxxxx"
```

## Étape 3 : Vérifier la configuration

### Vérifier que les secrets sont lus

```bash
cd terraform/authentik
terraform plan -var="oci_compartment_id=$COMPARTMENT_ID"
```

Tu devrais voir que `authentik_stage_email.recovery_email` utilise `use_global_settings = false` et que les valeurs SMTP sont configurées.

### Tester l'envoi d'email

Une fois Terraform appliqué, teste depuis la VM management :

```bash
ssh ubuntu@<vm-ip>
cd /opt/oci-mgmt
docker compose exec authentik-server ak test_email ton-email@example.com -S default-recovery-email
```

## Comportement selon la configuration

### Si `oci_compartment_id` est défini et les secrets existent

- `authentik_stage_email` utilise `use_global_settings = false`
- Les credentials SMTP sont lus depuis OCI Vault
- Configuration entièrement gérée par Terraform

### Si `oci_compartment_id` est vide ou les secrets n'existent pas

- `authentik_stage_email` utilise `use_global_settings = true`
- Authentik utilise les variables d'environnement `AUTHENTIK_EMAIL__*` depuis `docker-compose.yml`
- Fallback vers la configuration manuelle

## Mise à jour des secrets

Pour mettre à jour un secret SMTP :

```bash
cd terraform/oracle-cloud

# Mettre à jour la variable
export TF_VAR_vault_secret_authentik_smtp_password="nouvelle-api-key"

terraform apply
```

Puis réappliquer le module Authentik :

```bash
cd terraform/authentik
terraform apply -var="oci_compartment_id=$COMPARTMENT_ID"
```

## Intégration avec Ansible (optionnel)

Si tu veux aussi configurer les variables d'environnement dans `docker-compose.yml` via Ansible (pour le fallback), tu peux utiliser les mêmes secrets depuis OCI Vault :

```yaml
# ansible/roles/oci_mgmt/tasks/main.yml
- name: Fetch SMTP secrets from OCI Vault
  shell: |
    oci secrets secret-bundle get \
      --secret-id "{{ vault_secret_authentik_smtp_host_ocid }}" \
      --query 'data."secret-bundle-content".content' \
      --raw-output | base64 -d
  register: smtp_host
  # ... répéter pour port, username, password, from
```

## Limitations

1. **Provider Resend/SendGrid** : Les providers Terraform pour Resend/SendGrid nécessitent une API key existante pour créer de nouvelles API keys. Tu dois donc créer l'API key initiale manuellement, puis la stocker dans OCI Vault via Terraform.

2. **Secrets sensibles** : Les secrets sont stockés en BASE64 dans OCI Vault. Assure-toi que les permissions OCI sont correctement configurées.

3. **Fallback** : Si les secrets OCI ne sont pas disponibles, le système utilise `use_global_settings=true`, ce qui nécessite une configuration manuelle dans `docker-compose.yml`.

## Références

- [Authentik Email Configuration](https://docs.goauthentik.io/install-config/email/)
- [OCI Vault Documentation](https://docs.oracle.com/en-us/iaas/Content/KeyManagement/Concepts/keyoverview.htm)
- [Resend SMTP](https://resend.com/docs/send-with-smtp)
- [SendGrid SMTP](https://docs.sendgrid.com/for-developers/sending-email/getting-started-smtp)
