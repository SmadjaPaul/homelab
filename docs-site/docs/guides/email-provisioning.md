---
sidebar_position: 9
---

# Provisioning de Boîtes Mail avec Terraform

Ce guide explore les options pour provisionner des boîtes mail avec Terraform (sans self-hosting).

## Problème

**Deux besoins distincts** :

1. **Recevoir des emails** (boîtes mail) : Cloudflare Email Routing peut forwarder
2. **Envoyer des emails** (SMTP sortant) : Authentik a besoin d'un serveur SMTP pour envoyer les password reset, notifications, etc.

⚠️ **Important** : Cloudflare Email Routing ne peut **PAS** être utilisé comme serveur SMTP sortant. Il faut un vrai serveur SMTP pour Authentik.

Il n'existe **pas de provider Terraform standard** pour créer directement des boîtes mail chez les principaux fournisseurs (Gmail, ProtonMail, Zoho, etc.). Les providers existants gèrent principalement les **DNS** (MX, SPF, DKIM, DMARC) plutôt que la création de comptes.

## Options Disponibles

### Option 1 : Cloudflare Email Routing + Forwarding ⭐ **Recommandé**

**Fonctionnalités** :
- ✅ **Gratuit** (inclus dans Cloudflare)
- ✅ **Provider Terraform Cloudflare** existe
- ✅ Gestion DNS complète (MX, SPF, DKIM, DMARC)
- ✅ Forwarding vers n'importe quelle boîte mail existante

**Limitations** :
- ⚠️ **Pas de vraies boîtes mail** : seulement forwarding
- ⚠️ Pas de stockage d'emails
- ⚠️ Pas de webmail

**Utilisation** :
```hcl
# terraform/cloudflare/email-routing.tf
resource "cloudflare_email_routing_address" "noreply" {
  account_id = var.cloudflare_account_id
  email      = "noreply@smadja.dev"
  verified   = true
}

resource "cloudflare_email_routing_rule" "noreply_to_gmail" {
  zone_id = data.cloudflare_zone.smadja_dev.id
  name    = "noreply-forward"
  enabled = true

  matcher {
    type  = "literal"
    field = "to"
    value = "noreply@smadja.dev"
  }

  action {
    type  = "forward"
    value = ["ton-email@gmail.com"]
  }
}
```

**Avantages** :
- ✅ Terraform natif
- ✅ Gratuit
- ✅ Configuration DNS automatique

---

### Option 2 : Migadu (Petit Provider) ⚠️

**Fonctionnalités** :
- ✅ Vraies boîtes mail (IMAP, SMTP, Webmail)
- ✅ Tarifs abordables (~$5-20/mois)
- ✅ API REST disponible

**Limitations** :
- ⚠️ **Pas de provider Terraform officiel**
- ⚠️ Nécessite un provider custom ou `http` provider
- ⚠️ Service moins connu

**Solution** : Créer un provider custom ou utiliser `http` provider :

```hcl
# Exemple avec http provider (non testé)
resource "http" "create_mailbox" {
  url    = "https://www.migadu.com/api/v1/domains/${var.domain}/mailboxes"
  method = "POST"
  headers = {
    Authorization = "Basic ${base64encode("${var.migadu_email}:${var.migadu_password}")}"
    Content-Type  = "application/json"
  }
  request_body = jsonencode({
    local_part = "noreply"
    password   = var.mailbox_password
  })
}
```

---

### Option 3 : Google Workspace / Microsoft 365 ⚠️

**Fonctionnalités** :
- ✅ Vraies boîtes mail professionnelles
- ✅ APIs disponibles (Google Admin SDK, Microsoft Graph)

**Limitations** :
- ❌ **Pas de provider Terraform officiel**
- ❌ Payant (~$6-12/user/mois)
- ❌ Nécessite un provider custom ou scripts

**Solution** : Utiliser `googleworkspace` provider (non-officiel) ou scripts :

```hcl
# Provider non-officiel (exemple)
terraform {
  required_providers {
    googleworkspace = {
      source  = "hashicorp/googleworkspace"
      version = "~> 0.7"
    }
  }
}

resource "googleworkspace_user" "mailbox" {
  primary_email = "noreply@smadja.dev"
  password      = var.mailbox_password
  # ...
}
```

---

### Option 4 : Zoho Mail ⚠️

**Fonctionnalités** :
- ✅ Vraies boîtes mail
- ✅ Gratuit jusqu'à 5 utilisateurs (domaine personnalisé)
- ✅ API Zoho disponible

**Limitations** :
- ❌ **Pas de provider Terraform**
- ❌ Nécessite scripts ou provider custom

**Solution** : Utiliser `http` provider ou scripts Python/curl :

```bash
# Script pour créer une boîte Zoho via API
curl -X POST "https://mail.zoho.com/api/accounts/${account_id}/users" \
  -H "Authorization: Zoho-oauthtoken ${token}" \
  -d '{"emailAddress":"noreply@smadja.dev","password":"..."}'
```

---

### Option 5 : ProtonMail (via API) ⚠️

**Fonctionnalités** :
- ✅ Email chiffré
- ✅ API ProtonMail disponible

**Limitations** :
- ❌ **Pas de provider Terraform**
- ❌ Payant pour API access
- ❌ Complexe à automatiser

---

## Solution SMTP pour Authentik (ENVOI)

Authentik a besoin d'un **serveur SMTP sortant** pour envoyer :
- Password reset emails
- Notifications
- Invitations

### Option 1 : Gmail avec App Password ⭐ **Recommandé pour débuter**

**Avantages** :
- ✅ **Gratuit**
- ✅ Simple à configurer
- ✅ Fiable (Google infrastructure)

**Configuration** :
```bash
# Dans .env sur la VM
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

---

### Option 2 : SendGrid (Gratuit jusqu'à 100 emails/jour) ⭐⭐

**Avantages** :
- ✅ **Gratuit** jusqu'à 100 emails/jour
- ✅ Provider Terraform disponible (non-officiel)
- ✅ API + SMTP
- ✅ Analytics et tracking

**Configuration** :
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

### Option 3 : Resend (Gratuit jusqu'à 3000 emails/mois) ⭐⭐⭐

**Avantages** :
- ✅ **Gratuit** jusqu'à 3000 emails/mois
- ✅ Provider Terraform disponible
- ✅ Moderne et simple
- ✅ Bonne délivrabilité

**Configuration** :
```bash
AUTHENTIK_EMAIL__HOST=smtp.resend.com
AUTHENTIK_EMAIL__PORT=587
AUTHENTIK_EMAIL__USERNAME=resend
AUTHENTIK_EMAIL__PASSWORD=re_ton-api-key-resend
AUTHENTIK_EMAIL__USE_TLS=true
AUTHENTIK_EMAIL__FROM=noreply@smadja.dev
```

**Limite** : 3000 emails/mois (largement suffisant)

---

### Option 4 : ProtonMail (Gratuit, mais limité)

**Avantages** :
- ✅ Email chiffré
- ✅ Gratuit

**Limitations** :
- ⚠️ SMTP nécessite un plan payant (ProtonMail Plus)
- ⚠️ Pas de provider Terraform

**Configuration** (si plan payant) :
```bash
AUTHENTIK_EMAIL__HOST=mail.protonmail.com
AUTHENTIK_EMAIL__PORT=587
AUTHENTIK_EMAIL__USERNAME=ton-email@protonmail.com
AUTHENTIK_EMAIL__PASSWORD=ton-mot-de-passe-protonmail
AUTHENTIK_EMAIL__USE_TLS=true
AUTHENTIK_EMAIL__FROM=noreply@smadja.dev
```

---

### Option 5 : Mailgun (Gratuit jusqu'à 5000 emails/mois)

**Avantages** :
- ✅ **Gratuit** jusqu'à 5000 emails/mois
- ✅ API complète
- ✅ Bonne délivrabilité

**Limitations** :
- ⚠️ Nécessite vérification de domaine
- ⚠️ Pas de provider Terraform officiel

---

## Recommandation : Approche Hybride

### Solution Recommandée : Resend/SendGrid (SMTP) + Cloudflare Email Routing (Réception)

**Pour les boîtes fonctionnelles** (noreply, support, etc.) :

1. **Cloudflare Email Routing** (Terraform) :
   - Gère les DNS (MX, SPF, DKIM, DMARC)
   - Forwarding automatique vers une boîte principale

2. **Scripts d'automatisation** (Python/Bash) :
   - Création de boîtes chez Zoho/Migadu via API
   - Intégration dans le workflow CI/CD

**Exemple d'architecture** :

```
noreply@smadja.dev → Cloudflare Email Routing (Terraform)
                     ↓
                     Forward vers ton-email@gmail.com

support@smadja.dev → Cloudflare Email Routing (Terraform)
                     ↓
                     Forward vers support-gmail@gmail.com
```

**Avantages** :
- ✅ Terraform pour DNS (infrastructure)
- ✅ Scripts pour création de boîtes (si nécessaire)
- ✅ Gratuit (Cloudflare) + forwarding vers boîtes existantes

---

## Implémentation avec Cloudflare

### 1. Activer Email Routing dans Cloudflare

```bash
# Via Cloudflare Dashboard
# Zero Trust → Email → Email Routing → Enable
```

### 2. Configurer avec Terraform

```hcl
# terraform/cloudflare/email-routing.tf
resource "cloudflare_email_routing_address" "noreply" {
  account_id = var.cloudflare_account_id
  email      = "noreply@smadja.dev"
  verified   = true
}

resource "cloudflare_email_routing_rule" "noreply_forward" {
  zone_id = data.cloudflare_zone.smadja_dev.id
  name    = "noreply-forward-to-gmail"
  enabled = true

  matcher {
    type  = "literal"
    field = "to"
    value = "noreply@smadja.dev"
  }

  action {
    type  = "forward"
    value = ["${var.forward_email}"]
  }
}
```

### 3. DNS Records (automatique)

Cloudflare configure automatiquement :
- MX records
- SPF
- DKIM
- DMARC

---

## Alternative : Provider Custom Terraform

Si tu as besoin de vraies boîtes mail, tu peux créer un **provider Terraform custom** :

1. Utiliser le SDK Terraform
2. Wrapper autour de l'API du fournisseur (Zoho, Migadu, etc.)
3. Déployer comme provider local

**Référence** : [Building a Custom Terraform Provider](https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework)

---

## Conclusion

**Pour un homelab** :
- ✅ **Cloudflare Email Routing** (Terraform) pour forwarding
- ✅ Forward vers une boîte principale (Gmail, ProtonMail, etc.)
- ✅ Pas besoin de vraies boîtes mail séparées

**Si besoin de vraies boîtes** :
- ⚠️ Zoho Mail (gratuit, mais scripts nécessaires)
- ⚠️ Migadu (payant, mais API disponible)
- ⚠️ Créer un provider Terraform custom

---

## Références

- [Cloudflare Email Routing](https://developers.cloudflare.com/email-routing/)
- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [Zoho Mail API](https://www.zoho.com/mail/help/api/)
- [Migadu API](https://www.migadu.com/api/)
