# Configuration du Recovery Flow Authentik (IaC)

Guide pour configurer le recovery flow Authentik entièrement via Terraform, permettant aux utilisateurs de réinitialiser leur mot de passe via email.

## Prérequis

- ✅ Secrets SMTP Resend créés dans OCI Vault (déjà fait)
- ✅ Authentik déployé et accessible
- ✅ Token API Authentik avec permissions suffisantes

## Étape 1 : Vérifier les secrets SMTP dans OCI Vault

Les secrets SMTP Resend sont déjà créés dans OCI Vault :

```bash
cd terraform/oracle-cloud
terraform output vault_secrets | grep authentik_smtp
```

Tu devrais voir :
- `authentik_smtp_host`
- `authentik_smtp_port`
- `authentik_smtp_username`
- `authentik_smtp_password`
- `authentik_smtp_from`

## Étape 2 : Appliquer la configuration Terraform Authentik

```bash
cd terraform/authentik

# Configure les credentials Authentik
export AUTHENTIK_URL="https://auth.smadja.dev"  # Ton URL Authentik
export AUTHENTIK_TOKEN="ton-token-api-authentik"  # Ton token API

# Récupère le compartment_id depuis les outputs du module oracle-cloud
COMPARTMENT_ID=$(cd ../oracle-cloud && terraform output -raw compartment_id)

# Initialise Terraform (si pas déjà fait)
terraform init

# Vérifie la configuration
terraform plan -var="oci_compartment_id=$COMPARTMENT_ID"

# Applique la configuration
terraform apply -var="oci_compartment_id=$COMPARTMENT_ID"
```

Cette commande va créer :
- Le recovery flow (`default-recovery-flow`)
- Le stage d'identification avec recovery flow (`default-authentication-identification-with-recovery`)
- Tous les stages nécessaires (email, prompt, user write, user login)
- La configuration SMTP depuis OCI Vault

## Étape 3 : Lier le recovery flow au flow de login

Pour que le bouton "Forgot username or password?" apparaisse sur la page de login, il faut lier le recovery flow au flow de login.

### Option A : Via script (recommandé)

```bash
# Récupère le token API Authentik
AUTHENTIK_TOKEN="ton-token-api-authentik"

# Exécute le script de liaison
./scripts/link-recovery-flow.sh https://auth.smadja.dev "$AUTHENTIK_TOKEN"
```

Le script va :
1. Trouver le flow de login par défaut
2. Trouver le stage d'identification avec recovery flow
3. Mettre à jour le binding pour utiliser ce stage

### Option B : Via l'UI Authentik (si tu as accès)

1. Va sur `https://auth.smadja.dev`
2. **Flows** → **default-authentication-flow**
3. Clique sur le stage **Identification**
4. Dans **"Recovery flow"**, sélectionne **"default-recovery-flow"**
5. Sauvegarde

## Étape 4 : Vérifier la configuration

### Vérifier que le recovery flow existe

```bash
# Via l'URL directe
curl -s https://auth.smadja.dev/if/flow/default-recovery-flow/ | grep -i "reset\|password" | head -5
```

### Vérifier que le bouton apparaît sur la page de login

1. Va sur `https://auth.smadja.dev`
2. Tu devrais voir le bouton **"Forgot username or password?"** sous le formulaire de login

### Tester l'envoi d'email

```bash
# Sur la VM management
ssh ubuntu@<VM_IP>
cd ~/homelab/oci-mgmt

# Teste l'envoi d'email
docker compose exec authentik-server ak test_email ton-email@example.com -S default-recovery-email
```

## Étape 5 : Tester le reset de mot de passe

1. Va sur la page de login : `https://auth.smadja.dev`
2. Clique sur **"Forgot username or password?"**
3. Entre ton email ou username
4. Vérifie ta boîte mail (y compris les spams)
5. Clique sur le lien de réinitialisation (valide 30 minutes)
6. Entre ton nouveau mot de passe (2 fois)
7. Tu es automatiquement connecté

## Dépannage

### Le bouton "Forgot password?" n'apparaît pas

- Vérifie que le script `link-recovery-flow.sh` a été exécuté avec succès
- Vérifie dans l'UI Authentik que le recovery flow est bien lié au stage d'identification du flow de login
- Vérifie que le recovery flow existe : `terraform/authentik` → `terraform show | grep recovery`

### Les emails ne sont pas envoyés

1. **Vérifie les logs Authentik** :
   ```bash
   docker compose logs authentik-worker | grep -i email
   ```

2. **Vérifie que les secrets SMTP sont bien lus** :
   ```bash
   cd terraform/authentik
   terraform show | grep -A 10 "authentik_stage_email.recovery_email"
   ```

   Tu devrais voir :
   - `use_global_settings = false`
   - `host = "smtp.resend.com"`
   - `port = 587`
   - `username = "resend"`
   - `from_address = "onboarding@resend.dev"`

3. **Vérifie l'API key Resend** :
   - Dashboard Resend → API Keys
   - Vérifie que la clé est active
   - Vérifie les permissions (`Sending access`)

### Erreur "Domain not verified"

Si tu utilises `onboarding@resend.dev`, c'est normal. Pour utiliser ton propre domaine :
1. Vérifie ton domaine dans Resend
2. Mets à jour le secret `authentik_smtp_from` dans OCI Vault

## Références

- [Guide Resend Setup](../guides/resend-setup.md)
- [Guide Authentik SMTP Terraform](../guides/authentik-smtp-terraform.md)
- [Script de liaison](../scripts/link-recovery-flow.sh)
