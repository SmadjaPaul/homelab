---
sidebar_position: 8
---

# Configuration du Reset de Mot de Passe Authentik

Ce guide explique comment activer le reset de mot de passe par les utilisateurs dans Authentik.

## Vue d'ensemble

Le flow de récupération de mot de passe permet aux utilisateurs de réinitialiser leur mot de passe via email, sans intervention de l'administrateur.

## Prérequis

1. **Authentik déployé** et accessible (`https://auth.smadja.dev`)
2. **Configuration SMTP** pour l'envoi d'emails
3. **Token API Authentik** pour Terraform

## Configuration SMTP

### Option 1 : Variables d'environnement (Recommandé)

Ajoute les variables SMTP dans le fichier `.env` sur la VM :

```bash
# Sur la VM OCI
cd ~/homelab/oci-mgmt
nano .env
```

Ajoute ces lignes :

```bash
# Authentik SMTP Configuration
AUTHENTIK_EMAIL__HOST=smtp.gmail.com          # ou ton serveur SMTP
AUTHENTIK_EMAIL__PORT=587
AUTHENTIK_EMAIL__USERNAME=ton-email@gmail.com
AUTHENTIK_EMAIL__PASSWORD=ton-app-password    # App Password pour Gmail
AUTHENTIK_EMAIL__USE_TLS=true
AUTHENTIK_EMAIL__FROM=noreply@smadja.dev
```

Puis redémarre les conteneurs :

```bash
docker compose restart authentik-server authentik-worker
```

### Option 2 : Via l'interface Authentik

1. Va sur `https://auth.smadja.dev`
2. Settings → Email
3. Configure les paramètres SMTP
4. Teste l'envoi d'email

## Déploiement du Flow via Terraform

Le flow de récupération est défini dans `terraform/authentik/recovery-flow.tf`.

### 1. Configurer les variables Terraform

```bash
cd terraform/authentik
export AUTHENTIK_URL="https://auth.smadja.dev"
export AUTHENTIK_TOKEN="ton-token-api"
```

### 2. Appliquer la configuration

```bash
terraform init
terraform plan
terraform apply
```

### 3. Vérifier le flow

1. Va sur `https://auth.smadja.dev/if/flow/default-recovery-flow/`
2. Tu devrais voir le formulaire de récupération de mot de passe

## Utilisation

### Pour les utilisateurs

1. Sur la page de login, clique sur "Forgot password?" ou "Mot de passe oublié?"
2. Entre ton email ou username
3. Reçois un email avec un lien de réinitialisation
4. Clique sur le lien (valide 30 minutes)
5. Entre ton nouveau mot de passe (2 fois)
6. Tu es automatiquement connecté avec le nouveau mot de passe

### URL directe

Les utilisateurs peuvent accéder directement au flow via :
```
https://auth.smadja.dev/if/flow/default-recovery-flow/
```

## Configuration SMTP Recommandée

### Gmail (avec App Password)

```bash
AUTHENTIK_EMAIL__HOST=smtp.gmail.com
AUTHENTIK_EMAIL__PORT=587
AUTHENTIK_EMAIL__USERNAME=ton-email@gmail.com
AUTHENTIK_EMAIL__PASSWORD=xxxx xxxx xxxx xxxx  # App Password (16 caractères)
AUTHENTIK_EMAIL__USE_TLS=true
AUTHENTIK_EMAIL__FROM=noreply@smadja.dev
```

**Créer un App Password Gmail** :
1. Google Account → Security
2. 2-Step Verification → App passwords
3. Génère un mot de passe pour "Mail"
4. Utilise ce mot de passe (pas ton mot de passe Gmail normal)

### ProtonMail

```bash
AUTHENTIK_EMAIL__HOST=mail.protonmail.com
AUTHENTIK_EMAIL__PORT=587
AUTHENTIK_EMAIL__USERNAME=ton-email@protonmail.com
AUTHENTIK_EMAIL__PASSWORD=ton-mot-de-passe-protonmail
AUTHENTIK_EMAIL__USE_TLS=true
AUTHENTIK_EMAIL__FROM=noreply@smadja.dev
```

### SendGrid / Mailgun (pour production)

```bash
AUTHENTIK_EMAIL__HOST=smtp.sendgrid.net
AUTHENTIK_EMAIL__PORT=587
AUTHENTIK_EMAIL__USERNAME=apikey
AUTHENTIK_EMAIL__PASSWORD=SG.ton-api-key
AUTHENTIK_EMAIL__USE_TLS=true
AUTHENTIK_EMAIL__FROM=noreply@smadja.dev
```

## Sécurité

### Limitations

- **Token expiry** : 30 minutes (configurable dans `recovery-flow.tf`)
- **Max attempts** : 5 tentatives (géré par Authentik)
- **Cache timeout** : 5 minutes entre les tentatives

### Bonnes pratiques

1. ✅ Utilise un **App Password** pour Gmail (pas le mot de passe principal)
2. ✅ Configure `AUTHENTIK_EMAIL__FROM` avec un domaine que tu contrôles
3. ✅ Active **SPF/DKIM** sur ton domaine pour éviter le spam
4. ✅ Surveille les logs Authentik pour détecter les abus
5. ✅ Limite le nombre de tentatives (déjà configuré)

## Dépannage

### Les emails ne sont pas envoyés

1. **Vérifie les logs** :
   ```bash
   docker compose logs authentik-worker | grep -i email
   ```

2. **Teste la connexion SMTP** :
   ```bash
   docker compose exec authentik-server python -c "
   import smtplib
   server = smtplib.SMTP('smtp.gmail.com', 587)
   server.starttls()
   server.login('ton-email@gmail.com', 'ton-app-password')
   server.quit()
   print('SMTP OK')
   "
   ```

3. **Vérifie les variables d'environnement** :
   ```bash
   docker compose exec authentik-server env | grep AUTHENTIK_EMAIL
   ```

### Le flow n'apparaît pas

1. Vérifie que Terraform a bien créé le flow :
   ```bash
   cd terraform/authentik
   terraform state list | grep recovery
   ```

2. Vérifie dans l'UI Authentik :
   - Flows → Recovery flows → "Default recovery flow"

### Le lien de réinitialisation ne fonctionne pas

1. Vérifie que `AUTHENTIK_PUBLIC_URL` est correct dans `.env`
2. Vérifie que le token n'a pas expiré (30 minutes)
3. Vérifie les logs Authentik pour les erreurs

## Références

- [Authentik Recovery Flow Documentation](https://docs.goauthentik.io/docs/flow/stages/recovery/)
- [Authentik Email Stage](https://docs.goauthentik.io/docs/flow/stages/email/)
- [Terraform Authentik Provider](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
