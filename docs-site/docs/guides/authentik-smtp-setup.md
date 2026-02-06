---
sidebar_position: 10
---

# Configuration SMTP pour Authentik

Authentik a besoin d'un **serveur SMTP sortant** pour envoyer des emails (password reset, notifications, etc.).

## Options Disponibles

### Option 1 : Gmail avec App Password ⭐ **Recommandé pour débuter**

**Gratuit** | **Simple** | **Fiable**

**Configuration** :

1. **Créer un App Password Gmail** :
   - Google Account → Security
   - 2-Step Verification → App passwords
   - Génère un mot de passe pour "Mail"
   - Copie le mot de passe (16 caractères, espaces inclus)

2. **Configurer dans `.env`** (sur la VM) :
   ```bash
   AUTHENTIK_EMAIL__HOST=smtp.gmail.com
   AUTHENTIK_EMAIL__PORT=587
   AUTHENTIK_EMAIL__USERNAME=ton-email@gmail.com
   AUTHENTIK_EMAIL__PASSWORD=xxxx xxxx xxxx xxxx  # App Password
   AUTHENTIK_EMAIL__USE_TLS=true
   AUTHENTIK_EMAIL__FROM=noreply@smadja.dev
   ```

3. **Redémarrer Authentik** :
   ```bash
   docker compose restart authentik-server authentik-worker
   ```

**Limite** : Pas de limite explicite, mais Gmail peut throttler si trop d'emails

---

### Option 2 : Resend ⭐⭐⭐ **Meilleur pour production**

**Gratuit jusqu'à 3000 emails/mois** | **Moderne** | **Provider Terraform disponible**

**Avantages** :
- ✅ Gratuit généreux (3000 emails/mois)
- ✅ Bonne délivrabilité
- ✅ API moderne
- ✅ Provider Terraform disponible

**Configuration** :

1. **Créer un compte Resend** : https://resend.com
2. **Générer une API key** : Dashboard → API Keys
3. **Configurer dans `.env`** :
   ```bash
   AUTHENTIK_EMAIL__HOST=smtp.resend.com
   AUTHENTIK_EMAIL__PORT=587
   AUTHENTIK_EMAIL__USERNAME=resend
   AUTHENTIK_EMAIL__PASSWORD=re_ton-api-key-resend
   AUTHENTIK_EMAIL__USE_TLS=true
   AUTHENTIK_EMAIL__FROM=noreply@smadja.dev
   ```

4. **Vérifier le domaine** (optionnel mais recommandé) :
   - Dashboard → Domains → Add domain
   - Ajoute `smadja.dev`
   - Configure les DNS records (SPF, DKIM, DMARC)
   - Utilise `noreply@smadja.dev` comme `FROM`

**Limite** : 3000 emails/mois (largement suffisant pour un homelab)

---

### Option 3 : SendGrid ⭐⭐

**Gratuit jusqu'à 100 emails/jour** | **Provider Terraform disponible**

**Configuration** :

1. **Créer un compte SendGrid** : https://sendgrid.com
2. **Créer une API Key** : Settings → API Keys
3. **Configurer dans `.env`** :
   ```bash
   AUTHENTIK_EMAIL__HOST=smtp.sendgrid.net
   AUTHENTIK_EMAIL__PORT=587
   AUTHENTIK_EMAIL__USERNAME=apikey
   AUTHENTIK_EMAIL__PASSWORD=SG.ton-api-key-sendgrid
   AUTHENTIK_EMAIL__USE_TLS=true
   AUTHENTIK_EMAIL__FROM=noreply@smadja.dev
   ```

**Limite** : 100 emails/jour (suffisant pour un homelab)

---

### Option 4 : Zoho Mail ⭐ **Gratuit pour freelances**

**Gratuit jusqu'à 25 utilisateurs** | **5GB par utilisateur** | **Domaine personnalisé**

**Avantages** :
- ✅ **Gratuit** pour jusqu'à 25 utilisateurs
- ✅ 5GB de stockage par utilisateur
- ✅ SMTP inclus
- ✅ Domaine personnalisé supporté
- ✅ Idéal pour les freelances et petites équipes

**⚠️ Limitations importantes** :
- ❌ **Pas d'accès aux applications professionnelles** (WorkDrive, Writer, Sheets, Show, Cliq, Meeting, Vault) dans le plan gratuit
- ❌ Webmail uniquement (pas d'applications desktop/mobile natives)
- ❌ Limite de 25MB par pièce jointe
- ❌ Pas de collaboration avancée

**Note** : Les applications professionnelles Zoho (suite Workplace) sont disponibles uniquement dans les plans payants à partir de **$5-6/user/mois** (Workplace Standard).

**Configuration** :

1. **Créer un compte Zoho Mail** : https://www.zoho.com/mail/
2. **Ajouter ton domaine** : Settings → Domains → Add Domain (configurer MX, SPF, DKIM, DMARC)
3. **Créer une adresse email** (ex: `noreply@smadja.dev`)
4. **Configurer un App Password** (si 2FA activé) :
   - Settings → Security → App Passwords → Generate
   - Ou désactiver temporairement 2FA pour utiliser le mot de passe principal
5. **Configurer dans `.env`** :
   ```bash
   AUTHENTIK_EMAIL__HOST=smtp.zoho.com
   AUTHENTIK_EMAIL__PORT=587  # TLS (recommandé) ou 465 pour SSL
   AUTHENTIK_EMAIL__USERNAME=noreply@smadja.dev  # Ton adresse Zoho complète
   AUTHENTIK_EMAIL__PASSWORD=ton-mot-de-passe  # Mot de passe ou App Password
   AUTHENTIK_EMAIL__USE_TLS=true
   AUTHENTIK_EMAIL__FROM=noreply@smadja.dev
   ```

**Limite** : Jusqu'à 25 utilisateurs gratuits, 5GB par utilisateur

**⚠️ Terraform** : Il n'existe **pas de provider Terraform officiel** pour Zoho Mail. Cependant, tu peux utiliser notre solution Terraform en stockant les credentials SMTP dans OCI Vault (comme pour les autres providers). La création des comptes email Zoho doit se faire manuellement via l'interface web.

---

### Option 5 : Mailgun

**Gratuit jusqu'à 5000 emails/mois** | **API complète**

**Configuration** :

1. **Créer un compte Mailgun** : https://mailgun.com
2. **Récupère les credentials SMTP** : Dashboard → Sending → SMTP credentials
3. **Configurer dans `.env`** :
   ```bash
   AUTHENTIK_EMAIL__HOST=smtp.mailgun.org
   AUTHENTIK_EMAIL__PORT=587
   AUTHENTIK_EMAIL__USERNAME=postmaster@mg.smadja.dev
   AUTHENTIK_EMAIL__PASSWORD=ton-password-mailgun
   AUTHENTIK_EMAIL__USE_TLS=true
   AUTHENTIK_EMAIL__FROM=noreply@smadja.dev
   ```

**Limite** : 5000 emails/mois (gratuit)

---

## Comparaison

| Service | Gratuit | Limite | Terraform | Délivrabilité | Recommandation |
|---------|---------|--------|-----------|--------------|----------------|
| **Gmail** | ✅ | Illimitée* | ❌ | ⭐⭐⭐ | ⭐ Début |
| **Zoho Mail** | ✅ | 25 users, 5GB/user | ⚠️** | ⭐⭐⭐ | ⭐⭐ Freelance |
| **Resend** | ✅ | 3000/mois | ✅ | ⭐⭐⭐ | ⭐⭐⭐ Production |
| **SendGrid** | ✅ | 100/jour | ✅ | ⭐⭐⭐ | ⭐⭐ Production |
| **Mailgun** | ✅ | 5000/mois | ⚠️ | ⭐⭐⭐ | ⭐⭐ Production |
| **ProtonMail** | ⚠️ | Payant | ❌ | ⭐⭐ | ⚠️ Si besoin chiffrement |

\* Gmail peut throttler si trop d'emails
\*\* Pas de provider Terraform pour créer les comptes, mais credentials SMTP stockables dans OCI Vault

\* Gmail peut throttler si trop d'emails

---

## Configuration via Ansible (CI/CD)

Si tu utilises Ansible pour déployer, configure les variables SMTP dans OCI Vault et utilise-les dans le template :

```yaml
# ansible/roles/oci_mgmt/templates/env.j2
AUTHENTIK_EMAIL__HOST={{ authentik_smtp_host | default('smtp.gmail.com') }}
AUTHENTIK_EMAIL__PORT={{ authentik_smtp_port | default('587') }}
AUTHENTIK_EMAIL__USERNAME={{ authentik_smtp_username | default('') }}
AUTHENTIK_EMAIL__PASSWORD={{ authentik_smtp_password | default('') }}
AUTHENTIK_EMAIL__USE_TLS={{ authentik_smtp_use_tls | default('true') }}
AUTHENTIK_EMAIL__FROM={{ authentik_smtp_from | default('noreply@smadja.dev') }}
```

Puis stocke les secrets dans OCI Vault :
- `homelab-authentik-smtp-host`
- `homelab-authentik-smtp-username`
- `homelab-authentik-smtp-password`

---

## Test de la Configuration

Après configuration, teste l'envoi d'email :

```bash
# Sur la VM
cd ~/homelab/oci-mgmt

# Test via Authentik shell
docker compose exec authentik-server ak shell -c "
from authentik.core.models import User
from authentik.stages.email.models import EmailStage
from authentik.flows.models import Flow
user = User.objects.get(email='ton-email@example.com')
stage = EmailStage.objects.get(name='default-recovery-email')
# Test envoi (nécessite configuration complète)
print('SMTP configuré')
"
```

Ou teste directement depuis l'UI Authentik :
1. Va sur `https://auth.smadja.dev`
2. Settings → Email
3. Test Email → Envoie un email de test

---

## Dépannage

### Les emails ne sont pas envoyés

1. **Vérifie les logs** :
   ```bash
   docker compose logs authentik-worker | grep -i email
   ```

2. **Vérifie les variables d'environnement** :
   ```bash
   docker compose exec authentik-server env | grep AUTHENTIK_EMAIL
   ```

3. **Teste la connexion SMTP** :
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

### Erreur "Authentication failed"

- Vérifie que tu utilises un **App Password** pour Gmail (pas ton mot de passe normal)
- Vérifie que 2-Step Verification est activé sur Gmail
- Pour SendGrid/Resend, vérifie que l'API key est correcte

### Erreur "Connection refused"

- Vérifie que le port est correct (587 pour TLS, 465 pour SSL)
- Vérifie que `USE_TLS` correspond au port utilisé
- Vérifie les règles firewall (normalement pas de problème depuis la VM)

---

## Recommandation Finale

**Pour un homelab** :
- ✅ **Gmail avec App Password** : Simple, gratuit, suffisant pour commencer
- ✅ **Resend** : Si tu veux quelque chose de plus professionnel (3000 emails/mois gratuit)

**Pour les freelances** :
- ✅ **Zoho Mail** : Gratuit jusqu'à 25 utilisateurs, idéal si tu veux un email professionnel avec ton domaine
  - ⚠️ **Note** : Le plan gratuit n'inclut **pas** les applications professionnelles (WorkDrive, Writer, Sheets, etc.)
  - Les applications professionnelles sont disponibles dans les plans payants ($5-6/user/mois)

**Pour la production** :
- ✅ **Resend** ou **SendGrid** : Meilleure délivrabilité, analytics, provider Terraform

---

## Références

- [Authentik Email Configuration](https://docs.goauthentik.io/docs/flow/stages/email/)
- [Resend SMTP](https://resend.com/docs/send-with-smtp)
- [SendGrid SMTP](https://docs.sendgrid.com/for-developers/sending-email/getting-started-smtp)
- [Gmail App Passwords](https://support.google.com/accounts/answer/185833)
